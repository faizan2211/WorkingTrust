import 'json_read.dart';

/// The wallet, as `GET /api/wallet` reports it.
///
/// Every field is the backend's own column: `balance` is the stored
/// `walletBalance`, `connects` the stored `connects`, and the three lists are
/// the rows the website's Wallet page reads — the newest 30 money entries, the
/// newest 20 connects entries and the approved jobs that paid out.
///
/// A money amount is nullable because a row that does not carry one must not be
/// shown as `$0.00`: the screens render a dash instead of inventing a figure.
typedef WalletSnapshot = ({
  double? balance,
  int? connects,
  bool planActive,
  WalletDeposit? pendingDeposit,
  List<WalletEarning> earnings,
  List<MoneyRow> moneyActivity,
  List<ConnectsRow> connectsActivity,
});

/// A deposit the account has paid for but the server has not yet credited.
typedef WalletDeposit = ({
  String id,
  String packageName,
  double? amountUsd,
  int? connects,
  String status,
  DateTime? at,
});

/// One approved job that has been paid out.
typedef WalletEarning = ({
  String id,
  String taskTitle,
  String clientName,
  double? amount,
  DateTime? at,
  bool withdrawalRequested,
  String? withdrawalStatus,
});

/// One `WalletTransaction` row.
typedef MoneyRow = ({
  String id,
  String type,
  double? amount,
  String reason,
  DateTime? at,
});

/// One `ConnectsLedger` row.
typedef ConnectsRow = ({String id, int? delta, String reason, DateTime? at});

WalletSnapshot walletFromJson(Map<String, dynamic> json) {
  final deposit = json['pendingDeposit'];
  return (
    balance: jsonAmount(json['balance']),
    connects: jsonCount(json['connects']),
    planActive: jsonFlag(json['planActive']),
    pendingDeposit: deposit is Map<String, dynamic>
        ? (
            id: jsonText(deposit['id']),
            packageName: jsonText(deposit['packageName']),
            amountUsd: jsonAmount(deposit['amountUsd']),
            connects: jsonCount(deposit['connects']),
            status: jsonText(deposit['status']),
            at: jsonDate(deposit['createdAt']),
          )
        : null,
    earnings: [
      for (final row in jsonRows(json['earningsByJob']))
        if (jsonText(row['id']).isNotEmpty)
          (
            id: jsonText(row['id']),
            taskTitle: jsonText(row['taskTitle']),
            clientName: jsonText(row['clientName']),
            amount: jsonAmount(row['amount']),
            at: jsonDate(row['updatedAt']),
            withdrawalRequested: jsonFlag(row['withdrawalRequested']),
            withdrawalStatus: jsonText(row['withdrawalStatus']).isNotEmpty
                ? jsonText(row['withdrawalStatus'])
                : null,
          ),
    ],
    moneyActivity: [
      for (final row in jsonRows(json['transactions']))
        if (jsonText(row['id']).isNotEmpty)
          (
            id: jsonText(row['id']),
            type: jsonText(row['type']),
            amount: jsonAmount(row['amount']),
            reason: jsonText(row['reason']),
            at: jsonDate(row['createdAt']),
          ),
    ],
    connectsActivity: [
      for (final row in jsonRows(json['connectsActivity']))
        if (jsonText(row['id']).isNotEmpty)
          (
            id: jsonText(row['id']),
            delta: jsonCount(row['delta']),
            reason: jsonText(row['reason']),
            at: jsonDate(row['createdAt']),
          ),
    ],
  );
}

/// The money row as the ledger line the wallet shows: its reason, the day it
/// landed and the signed amount. `WalletTransaction.amount` is stored positive
/// for a credit and negative for a debit, so the sign is kept as it arrived.
/// The connects figure as the screens that spend it show it. A wallet no read
/// has answered yet is a dash, never a number the app guessed.
extension WalletSnapshotText on WalletSnapshot {
  String get bidsLabel => connects == null ? '—' : '$connects';
}

extension MoneyRowText on MoneyRow {
  String get amountLabel => amount == null ? '—' : usd(amount!);
}

extension ConnectsRowText on ConnectsRow {
  /// A ledger delta is a whole number of connects, shown with its own sign.
  String get deltaLabel =>
      delta == null ? '—' : (delta! > 0 ? '+$delta' : '$delta');
}

extension WalletEarningText on WalletEarning {
  String get amountLabel => amount == null ? '—' : usd(amount!);

  /// The page pays a job out of its own amount, falling back to the task.
  String get statusLabel {
    if (!withdrawalRequested) return 'Paid out';
    final status = (withdrawalStatus ?? '').toUpperCase();
    return switch (status) {
      'PENDING' => 'Withdrawal pending',
      'REJECTED' => 'Withdrawal rejected',
      'APPROVED' => 'Withdrawal approved',
      'PAID' => 'Withdrawn',
      _ => 'Withdrawal requested',
    };
  }
}
