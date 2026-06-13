import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:tracker_app/domain/entities/transaction.dart';

class ExportConfig {
  final String title;
  final DateTimeRange? dateRange;
  final String accountName;
  final String currencySymbol;

  const ExportConfig({
    required this.title,
    this.dateRange,
    required this.accountName,
    required this.currencySymbol,
  });
}

class PdfExportParams {
  final List<Transaction> transactions;
  final ExportConfig config;
  final Map<String, String> categoryNames;

  const PdfExportParams({
    required this.transactions,
    required this.config,
    required this.categoryNames,
  });
}

class PdfExportService {
  /// Generates a structured financial PDF statement in a background Isolate.
  static Future<Uint8List> generatePdf({
    required List<Transaction> transactions,
    required ExportConfig config,
    required Map<String, String> categoryNames,
  }) async {
    return compute(
      _generatePdfRaw,
      PdfExportParams(
        transactions: transactions,
        config: config,
        categoryNames: categoryNames,
      ),
    );
  }
}

/// Top-level or static helper function to generate PDF bytes, keeping standard isolate compatibility.
Future<Uint8List> _generatePdfRaw(PdfExportParams params) async {
  final pdf = pw.Document(
    title: params.config.title,
    author: 'Tracker App',
    creator: 'Tracker App',
  );

  // Parse transaction summary data
  double totalCredits = 0.0;
  double totalDebits = 0.0;
  int txCount = 0;

  for (final tx in params.transactions) {
    if (tx.isDeleted) continue;
    txCount++;
    if (tx.type == TransactionType.credit) {
      totalCredits += tx.amount;
    } else if (tx.type == TransactionType.debit) {
      totalDebits += tx.amount;
    }
  }

  final netBalance = totalCredits - totalDebits;
  final currencySymbol = params.config.currencySymbol;

  // Format Helper
  String formatAmount(double val) {
    return '$currencySymbol${val.toStringAsFixed(2)}';
  }

  // Pre-load Helvetica font styles
  final fontBase = pw.Font.helvetica();
  final fontBold = pw.Font.helveticaBold();

  // Create document pages using MultiPage to safely overflow across sheets
  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      theme: pw.ThemeData.withFont(
        base: fontBase,
        bold: fontBold,
      ),
      header: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'TRACKER APP',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 22,
                        color: PdfColor.fromHex('#2563eb'), // Premium Royal Blue
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      params.config.title,
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 14,
                        color: PdfColor.fromHex('#1e293b'),
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    if (params.config.dateRange != null)
                      pw.Text(
                        'Period: ${DateFormat('yyyy-MM-dd').format(params.config.dateRange!.start)} to ${DateFormat('yyyy-MM-dd').format(params.config.dateRange!.end)}',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Account: ${params.config.accountName}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Divider(thickness: 1.5, color: PdfColor.fromHex('#e2e8f0')),
            pw.SizedBox(height: 16),
          ],
        );
      },
      footer: (pw.Context context) {
        return pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 20),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
            ),
          ),
          padding: const pw.EdgeInsets.only(top: 10),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated by Tracker App — Data stored locally on your device',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
              ),
            ],
          ),
        );
      },
      build: (pw.Context context) {
        return [
          // 1. Summary Box Section
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#f8fafc'),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: PdfColor.fromHex('#cbd5e1'), width: 1),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  'Total Inflow',
                  formatAmount(totalCredits),
                  PdfColor.fromHex('#16a34a'), // bright green
                  fontBold,
                ),
                _buildSummaryDivider(),
                _buildSummaryItem(
                  'Total Outflow',
                  '- ${formatAmount(totalDebits)}',
                  PdfColor.fromHex('#dc2626'), // bright red
                  fontBold,
                ),
                _buildSummaryDivider(),
                _buildSummaryItem(
                  'Net Balance',
                  netBalance >= 0
                      ? formatAmount(netBalance)
                      : '- ${formatAmount(netBalance.abs())}',
                  netBalance >= 0 ? PdfColor.fromHex('#2563eb') : PdfColor.fromHex('#475569'),
                  fontBold,
                ),
                _buildSummaryDivider(),
                _buildSummaryItem(
                  'Transactions',
                  '$txCount items',
                  PdfColor.fromHex('#0f172a'),
                  fontBold,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),

          // 2. Section Heading
          pw.Text(
            'Transactions Journal',
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 14,
              color: PdfColor.fromHex('#0f172a'),
            ),
          ),
          pw.SizedBox(height: 10),

          // 3. Transactions Table
          if (params.transactions.isEmpty)
            pw.Container(
              padding: const pw.EdgeInsets.all(24),
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColor.fromHex('#cbd5e1')),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Text(
                'No transactions match the selected criteria for this period.',
                style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 11),
              ),
            )
          else
            pw.Table(
              columnWidths: const {
                0: pw.FixedColumnWidth(65),  // Date
                1: pw.FlexColumnWidth(2.2),  // Description
                2: pw.FlexColumnWidth(1.1),  // Category
                3: pw.FixedColumnWidth(75),  // Amount
                4: pw.FixedColumnWidth(50),  // Type
              },
              border: pw.TableBorder(
                horizontalInside: pw.BorderSide(
                  color: PdfColor.fromHex('#cbd5e1'),
                  width: 0.5,
                ),
                bottom: pw.BorderSide(
                  color: PdfColor.fromHex('#cbd5e1'),
                  width: 1,
                ),
              ),
              children: [
                // Table Header Row
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#1e293b'),
                    borderRadius: const pw.BorderRadius.only(
                      topLeft: pw.Radius.circular(4),
                      topRight: pw.Radius.circular(4),
                    ),
                  ),
                  children: [
                    _buildTableHeaderCell('Date', fontBold),
                    _buildTableHeaderCell('Description', fontBold),
                    _buildTableHeaderCell('Category', fontBold),
                    _buildTableHeaderCell('Amount', fontBold, alignRight: true),
                    _buildTableHeaderCell('Type', fontBold, alignCenter: true),
                  ],
                ),
                // Table Data Rows
                ...List.generate(params.transactions.length, (index) {
                  final tx = params.transactions[index];
                  if (tx.isDeleted) return pw.TableRow(children: []);

                  final isCredit = tx.type == TransactionType.credit;
                  final categoryName = params.categoryNames[tx.category] ?? 'Uncategorized';
                  final dateStr = DateFormat('yyyy-MM-dd').format(tx.dateTime);
                  final amtStr = formatAmount(tx.amount);
                  final typeStr = isCredit ? 'Credit' : 'Debit';

                  final rowBgColor = index % 2 == 1
                      ? PdfColor.fromHex('#f8fafc') // Alternating row color
                      : PdfColors.white;

                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: rowBgColor),
                    children: [
                      _buildTableCell(dateStr),
                      _buildTableCell(tx.description),
                      _buildTableCell(categoryName),
                      _buildTableCell(
                        isCredit ? '+$amtStr' : '-$amtStr',
                        color: isCredit ? PdfColor.fromHex('#16a34a') : PdfColor.fromHex('#dc2626'),
                        fontBold: true,
                        alignRight: true,
                      ),
                      _buildTableCell(
                        typeStr,
                        color: isCredit ? PdfColor.fromHex('#16a34a') : PdfColors.black,
                        alignCenter: true,
                      ),
                    ],
                  );
                }),
              ],
            ),
        ];
      },
    ),
  );

  return pdf.save();
}

pw.Widget _buildSummaryItem(String label, String value, PdfColor valueColor, pw.Font fontBold) {
  return pw.Column(
    mainAxisSize: pw.MainAxisSize.min,
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.Text(
        label.toUpperCase(),
        style: const pw.TextStyle(
          fontSize: 8,
          color: PdfColors.grey600,
        ),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        value,
        style: pw.TextStyle(
          font: fontBold,
          fontSize: 12,
          color: valueColor,
        ),
      ),
    ],
  );
}

pw.Widget _buildSummaryDivider() {
  return pw.Container(
    height: 24,
    width: 0.5,
    color: PdfColor.fromHex('#cbd5e1'),
  );
}

pw.Widget _buildTableHeaderCell(String text, pw.Font fontBold, {bool alignRight = false, bool alignCenter = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
    child: pw.Text(
      text,
      textAlign: alignRight
          ? pw.TextAlign.right
          : alignCenter
              ? pw.TextAlign.center
              : pw.TextAlign.left,
      style: pw.TextStyle(
        font: fontBold,
        fontSize: 9,
        color: PdfColors.white,
      ),
    ),
  );
}

pw.Widget _buildTableCell(
  String text, {
  PdfColor? color,
  bool fontBold = false,
  bool alignRight = false,
  bool alignCenter = false,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 8),
    child: pw.Text(
      text,
      textAlign: alignRight
          ? pw.TextAlign.right
          : alignCenter
              ? pw.TextAlign.center
              : pw.TextAlign.left,
      style: pw.TextStyle(
        fontSize: 8.5,
        color: color ?? PdfColors.black,
        fontWeight: fontBold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}
