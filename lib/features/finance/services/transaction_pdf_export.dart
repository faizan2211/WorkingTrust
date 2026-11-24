import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/transaction_feed.dart';

class TransactionPdfExport {
  TransactionPdfExport._();

  static Future<Uint8List> build(List<TransactionRow> rows) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Text(
            'WorkingTrust Transactions',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
        build: (context) => [
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 12),
            child: pw.Text(
              'Generated ${DateTime.now().toLocal().toString().split('.').first}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Date',
              'Type',
              'Details',
              'Client',
              'Status',
              'Amount',
            ],
            data: [
              for (final row in rows)
                [
                  row.dateLabel,
                  row.type,
                  row.details,
                  row.client ?? '',
                  row.status ?? '',
                  row.amountLabel,
                ],
            ],
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF004743),
            ),
            oddRowDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF4F7F6),
            ),
            border: pw.TableBorder.all(
              color: const PdfColor.fromInt(0xFFD8E1DF),
              width: 0.5,
            ),
            cellAlignments: const {5: pw.Alignment.centerRight},
            columnWidths: const {
              0: pw.FlexColumnWidth(1.1),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(2.4),
              3: pw.FlexColumnWidth(1.6),
              4: pw.FlexColumnWidth(1),
              5: pw.FlexColumnWidth(1),
            },
          ),
        ],
      ),
    );
    return document.save();
  }
}
