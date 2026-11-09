import 'dart:async';

import '../../../core/network/network_exceptions.dart';
import '../models/transaction_feed.dart';
import '../services/reports_service.dart';
import '../services/withdrawals_service.dart';
import 'overview_controller.dart';
import 'read_controller.dart';
import 'read_state.dart';
import 'wallet_controller.dart';

/// The account's payout requests, and the one action that makes a new one.
///
/// The history is the Transactions feed asked for its `Withdrawal` type alone,
/// so a row here is the same row that page shows and the device adds nothing to
/// it. A request names approved jobs by id; the server prices them, moves the
/// balance and answers with the rows it wrote, after which every figure on the
/// tab is read back rather than assumed.
class WithdrawalsController extends ReadController<List<TransactionRow>> {
  WithdrawalsController._();

  static final WithdrawalsController instance = WithdrawalsController._();

  /// How many payout rows the tab lists.
  static const int historyLimit = 10;

  /// How many jobs the route takes in one request — its own schema's cap.
  static const int requestMax = WithdrawalsService.requestMax;

  final ReportsService _reports = ReportsService.instance;
  final WithdrawalsService _service = WithdrawalsService.instance;

  bool _submitting = false;
  String _writeError = '';

  /// Whether a request is in flight, so the sheet can disable its own button.
  bool get isSubmitting => _submitting;

  /// What the last request was refused with, in the route's words.
  String get writeError => _writeError;

  @override
  List<TransactionRow> emptyValue() => const [];

  @override
  bool isEmptyValue(List<TransactionRow> value) => value.isEmpty;

  @override
  Future<List<TransactionRow>> read() async {
    final feed = await _reports.fetchTransactions(
      limit: historyLimit,
      type: TransactionFilter.withdrawal,
    );
    return feed.rows;
  }

  /// Asks the server to pay out the jobs named by [assignmentIds] and answers
  /// how many rows it created. Nothing is deducted on the device: a refusal —
  /// no billing method, a job already withdrawn, a balance too small — leaves
  /// the figures alone and [writeError] carries the reason.
  Future<int?> submit(List<String> assignmentIds) async {
    if (_submitting) return null;
    _submitting = true;
    _writeError = '';
    notifyListeners();
    try {
      final count = await _service.request(assignmentIds);
      await refresh();
      // The balance and the pending total both moved, so both routes are asked
      // again instead of being corrected by hand.
      unawaited(WalletController.instance.refresh());
      unawaited(OverviewController.instance.refresh());
      return count;
    } on NetworkException catch (e) {
      _writeError = SessionExpiry.isExpired(e.statusCode)
          ? SessionExpiry.message
          : e.message;
    } catch (e) {
      _writeError = '$e';
    } finally {
      _submitting = false;
      notifyListeners();
    }
    return null;
  }
}
