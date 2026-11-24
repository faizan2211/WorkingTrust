import 'package:flutter_test/flutter_test.dart';
import 'package:working_trust/features/finance/services/transaction_pdf_export.dart';

void main() {
  test('builds a PDF transaction report', () async {
    final bytes = await TransactionPdfExport.build([
      (
        id: 'tx-1',
        at: DateTime(2026, 11, 14),
        type: 'Withdrawal',
        details: 'Project payout',
        client: 'Example Client',
        status: 'Paid',
        amount: 35,
        isCredit: false,
      ),
    ]);

    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(500));
  });
}
