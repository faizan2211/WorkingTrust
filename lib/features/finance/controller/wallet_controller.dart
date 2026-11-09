import '../models/wallet_data.dart';
import '../services/wallet_service.dart';
import 'read_controller.dart';

/// The account's money, from `GET /api/wallet`.
class WalletController extends ReadController<WalletSnapshot> {
  WalletController._();

  static final WalletController instance = WalletController._();

  final WalletService _service = WalletService.instance;

  @override
  WalletSnapshot emptyValue() => (
    balance: null,
    connects: null,
    planActive: false,
    pendingDeposit: null,
    earnings: const [],
    moneyActivity: const [],
    connectsActivity: const [],
  );

  /// The wallet is never shown as a blank screen.
  ///
  /// Its summary card carries the balance and connects the route reported — a
  /// brand-new account legitimately sees `$0.00` and `0` there — and the three
  /// ledgers each name their own nothing-yet state, so an account with no rows
  /// still gets the whole screen rather than an empty page.
  @override
  bool isEmptyValue(WalletSnapshot value) => false;

  @override
  Future<WalletSnapshot> read() => _service.fetch();
}
