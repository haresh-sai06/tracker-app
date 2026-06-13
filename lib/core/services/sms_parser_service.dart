import 'package:flutter/foundation.dart';
import 'package:tracker_app/domain/entities/transaction.dart';

class ParsedTransaction {
  final double amount;
  final TransactionType type;
  final String merchantName;
  final String? accountLastFour;
  final String? bankName;
  final String rawText;
  final double confidence;

  const ParsedTransaction({
    required this.amount,
    required this.type,
    required this.merchantName,
    this.accountLastFour,
    this.bankName,
    required this.rawText,
    required this.confidence,
  });

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'type': type.name,
      'merchantName': merchantName,
      'accountLastFour': accountLastFour,
      'bankName': bankName,
      'rawText': rawText,
      'confidence': confidence,
    };
  }
}

class SmsParserService {
  /// Entry point to parse SMS. Runs on a background isolate using `compute`.
  static Future<ParsedTransaction?> parseSms(String body) async {
    return await compute(_parseSmsIsolate, body);
  }

  /// The heavy parsing function that runs in the isolate.
  static ParsedTransaction? _parseSmsIsolate(String body) {
    if (body.isEmpty) return null;

    final bodyLower = body.toLowerCase();
    
    // 0. Explicitly Ignore Non-Transactional / Failed Messages
    final ignoreKeywords = [
      'mandate', 'otp ', ' otp', 'code', 'password', ' pin', 'alert',
      'statement', 'outstanding', 'due', 'reminder',
      'cancelled', 'declined', 'unsuccessful', 'failed', 'bounced',
      'requested'
    ];
    for (final keyword in ignoreKeywords) {
      if (bodyLower.contains(keyword)) {
        return null;
      }
    }

    // 1. Try Specific Bank Template Regexes
    
    // HDFC Pattern: "Rs.X debited from a/c XX1234" or "Rs.X credited to a/c XX1234"
    final hdfcDebited = RegExp(
      r'(?:rs\.?|re\.?|inr|rupees?|usd|\$|eur|€)\s*([\d,]+(?:\.\d+)?)\s+(?:debited|debitted)\s+from\s+(?:a/c|acc|account)\s+(?:xx)?(\d{4})(?:\s+to\s+([^,\.]+))?',
      caseSensitive: false,
    );
    final hdfcCredited = RegExp(
      r'(?:rs\.?|re\.?|inr|rupees?|usd|\$|eur|€)\s*([\d,]+(?:\.\d+)?)\s+(?:credited|creditted)\s+to\s+(?:a/c|acc|account)\s+(?:xx)?(\d{4})',
      caseSensitive: false,
    );

    // SBI Pattern: "INR X debited to MERCHANT" or "INR X credited to XX1234"
    final sbiDebited = RegExp(
      r'(?:inr|rs\.?|re\.?|rupees?|usd|\$|eur|€)\s*([\d,]+(?:\.\d+)?)\s+(?:debited|debitted)\s+to\s+([^,\.]+)(?:\s+from\s+[^\s]+)?',
      caseSensitive: false,
    );

    // ICICI Pattern: "Rs X spent on ICICI Bank Card XX1234 at MERCHANT" -> debited
    final iciciSpent = RegExp(
      r'(?:rs\.?|re\.?|inr|rupees?|usd|\$|eur|€)\s*([\d,]+(?:\.\d+)?)\s+spent\s+on\s+icici\s+bank\s+(?:card|a/c)\s+(?:xx)?(\d{4})\s+at\s+([^,\.]+)',
      caseSensitive: false,
    );

    // Paytm / PhonePe / GPay UPI: "Rs X debited via UPI to MERCHANT" or "Rs X sent via UPI to MERCHANT"
    final upiPattern = RegExp(
      r'(?:rs\.?|re\.?|inr|rupees?|usd|\$|eur|€)\s*([\d,]+(?:\.\d+)?)\s+(?:debited|debitted|sent|paid)\s+via\s+upi\s+to\s+([^,\.\s]+(?:\s+[^,\.\s]+)*)',
      caseSensitive: false,
    );

    // Generic Sent From Bank Pattern: "Sent Rs.X From [Bank] A/C Y To Z"
    final genericSent = RegExp(
      r'sent\s+(?:rs\.?|re\.?|inr|rupees?|usd|\$|eur|€)\s*([\d,]+(?:\.\d+)?)\s+from\s+([a-z0-9\s]+?)\s+(?:a/c|acc|account)\s+([^\s\n\r]+)\s+to\s+([^\n\r]+)',
      caseSensitive: false,
    );

    // Check HDFC Debit
    var match = hdfcDebited.firstMatch(body);
    if (match != null) {
      final amount = _parseAmount(match.group(1));
      final account = match.group(2);
      final merchant = (match.group(3) ?? 'HDFC Merchant').trim();
      return ParsedTransaction(
        amount: amount,
        type: TransactionType.debit,
        merchantName: _cleanMerchantName(_capitalize(merchant)),
        accountLastFour: account,
        bankName: 'HDFC',
        rawText: body,
        confidence: 0.95,
      );
    }

    // Check HDFC Credit
    match = hdfcCredited.firstMatch(body);
    if (match != null) {
      final amount = _parseAmount(match.group(1));
      final account = match.group(2);
      return ParsedTransaction(
        amount: amount,
        type: TransactionType.credit,
        merchantName: 'HDFC Deposit',
        accountLastFour: account,
        bankName: 'HDFC',
        rawText: body,
        confidence: 0.95,
      );
    }

    // Check SBI Debit
    match = sbiDebited.firstMatch(body);
    if (match != null) {
      final amount = _parseAmount(match.group(1));
      final merchant = match.group(2)?.trim() ?? 'SBI Merchant';
      return ParsedTransaction(
        amount: amount,
        type: TransactionType.debit,
        merchantName: _cleanMerchantName(_capitalize(merchant)),
        bankName: 'SBI',
        rawText: body,
        confidence: 0.95,
      );
    }

    // Check ICICI Spent
    match = iciciSpent.firstMatch(body);
    if (match != null) {
      final amount = _parseAmount(match.group(1));
      final account = match.group(2);
      final merchant = match.group(3)?.trim() ?? 'ICICI Merchant';
      return ParsedTransaction(
        amount: amount,
        type: TransactionType.debit,
        merchantName: _cleanMerchantName(_capitalize(merchant)),
        accountLastFour: account,
        bankName: 'ICICI',
        rawText: body,
        confidence: 0.95,
      );
    }

    // Check UPI Pattern
    match = upiPattern.firstMatch(body);
    if (match != null) {
      final amount = _parseAmount(match.group(1));
      final merchant = match.group(2)?.trim() ?? 'UPI Merchant';
      return ParsedTransaction(
        amount: amount,
        type: TransactionType.debit,
        merchantName: _cleanMerchantName(_capitalize(merchant)),
        bankName: 'UPI',
        rawText: body,
        confidence: 0.95,
      );
    }

    // Check Generic Sent
    match = genericSent.firstMatch(body);
    if (match != null) {
      final amount = _parseAmount(match.group(1));
      final rawBank = match.group(2)?.trim() ?? 'Bank';
      final account = match.group(3);
      final merchant = match.group(4)?.trim() ?? 'Merchant';
      
      var bank = rawBank;
      if (bank.toLowerCase().endsWith(' bank')) {
        bank = bank.substring(0, bank.length - 5).trim();
      }
      bank = _capitalize(bank);

      return ParsedTransaction(
        amount: amount,
        type: TransactionType.debit,
        merchantName: _cleanMerchantName(_capitalize(merchant)),
        accountLastFour: (account == '****' || account?.toLowerCase() == 'xxxx') ? null : account,
        bankName: bank,
        rawText: body,
        confidence: 0.95,
      );
    }

    // 2. Generic Fallback Parser
    double amount = 0.0;
    TransactionType? type;
    double confidence = 0.0;

    // Detect Amount
    final amountReg = RegExp(r'(?:rs\.?|re\.?|inr|rupees?|usd|\$|eur|€)\s*([\d,]+(?:\.\d+)?)', caseSensitive: false);
    final amountMatch = amountReg.firstMatch(bodyLower);
    if (amountMatch != null) {
      amount = _parseAmount(amountMatch.group(1));
      confidence += 0.4;
    } else {
      // Direct raw numbers that are reasonably large or isolated with decimal
      final fallbackAmountReg = RegExp(r'\b([\d,]+\.\d{2})\b');
      final fallbackAmountMatch = fallbackAmountReg.firstMatch(bodyLower);
      if (fallbackAmountMatch != null) {
        amount = _parseAmount(fallbackAmountMatch.group(1));
        confidence += 0.2;
      }
    }

    if (amount == 0.0) return null; // No readable amount, confidence remains too low.

    // Detect Type strictly
    final debitReg = RegExp(r'\b(debited|debitted|spent|sent|paid|withdrawn|deducted|charged)\b', caseSensitive: false);
    final creditReg = RegExp(r'\b(credited|creditted|received|added|deposited|refunded|reversal)\b', caseSensitive: false);

    final hasDebit = debitReg.hasMatch(bodyLower);
    final hasCredit = creditReg.hasMatch(bodyLower);

    if (hasCredit && !hasDebit) {
      type = TransactionType.credit;
      confidence += 0.4;
    } else if (hasDebit && !hasCredit) {
      type = TransactionType.debit;
      confidence += 0.4;
    } else if (hasDebit && hasCredit) {
      if (bodyLower.contains('refund') || bodyLower.contains('reversal')) {
        type = TransactionType.credit;
        confidence += 0.3;
      } else {
        confidence -= 0.2; // Conflicting without clear context, drop confidence
      }
    }

    if (type == null) {
      return null; // Must definitively know if it's credit or debit.
    }

    // Detect Account Info
    String? accountNum;
    final accReg = RegExp(r'\b(?:a/c|card|acc|x+)\s*(?:xx)?(\d{4})\b', caseSensitive: false);
    final accMatch = accReg.firstMatch(bodyLower);
    if (accMatch != null) {
      accountNum = accMatch.group(1);
      confidence += 0.1;
    }

    // Detect Merchant / Bank
    String merchant = 'Detected Transaction';
    if (type == TransactionType.debit) {
      final merchantReg = RegExp(r'at\s+([^,\.]+)', caseSensitive: false);
      final merchantMatch = merchantReg.firstMatch(bodyLower);
      if (merchantMatch != null) {
        merchant = merchantMatch.group(1)?.trim() ?? '';
      } else {
        final toReg = RegExp(r'to\s+([^,\.\s]+(?:\s+[^,\.\s]+)?)', caseSensitive: false);
        final toMatch = toReg.firstMatch(bodyLower);
        if (toMatch != null) {
          merchant = toMatch.group(1)?.trim() ?? '';
        }
      }
    } else {
      final fromReg = RegExp(r'from\s+([^,\.\s]+(?:\s+[^,\.\s]+)?)', caseSensitive: false);
      final fromMatch = fromReg.firstMatch(bodyLower);
      if (fromMatch != null) {
        merchant = fromMatch.group(1)?.trim() ?? '';
      } else {
        merchant = 'Deposit / Refund';
      }
    }

    String? bankName;
    if (bodyLower.contains('hdfc')) {
      bankName = 'HDFC';
    } else if (bodyLower.contains('sbi')) {
      bankName = 'SBI';
    } else if (bodyLower.contains('icici')) {
      bankName = 'ICICI';
    } else if (bodyLower.contains('paytm')) {
      bankName = 'Paytm';
    } else if (bodyLower.contains('phonepe')) {
      bankName = 'PhonePe';
    } else if (bodyLower.contains('kotak')) {
      bankName = 'Kotak';
    }

    if (confidence >= 0.7) {
      return ParsedTransaction(
        amount: amount,
        type: type,
        merchantName: _cleanMerchantName(_capitalize(merchant)),
        accountLastFour: accountNum,
        bankName: bankName,
        rawText: body,
        confidence: confidence,
      );
    }

    return null;
  }

  static double _parseAmount(String? text) {
    if (text == null) return 0.0;
    try {
      final sanitized = text.replaceAll(',', '').trim();
      return double.parse(sanitized);
    } catch (_) {
      return 0.0;
    }
  }

  static String _cleanMerchantName(String merchant) {
    var clean = merchant.trim();
    // Remove "on DD/MM/YY..." or "on YYYY-MM-DD..."
    clean = clean.replaceAll(RegExp(r'\s+on\s+\d{2}[-/]\d{2}[-/]\d{2,4}.*$', caseSensitive: false), '');
    // Remove "Ref..." or "UPI Ref..." or "RRN..." or "Txn..."
    clean = clean.replaceAll(RegExp(r'\s+(?:ref|upi\s+ref|rrn|txn|ref\s+no|reference)\b.*$', caseSensitive: false), '');
    // Remove "val..." or "value..."
    clean = clean.replaceAll(RegExp(r'\s+val\b.*$', caseSensitive: false), '');
    // Remove "bal..." or "balance..."
    clean = clean.replaceAll(RegExp(r'\s+bal\b.*$', caseSensitive: false), '');
    return clean.trim();
  }

  static String _capitalize(String text) {
    if (text.isEmpty) return 'Detected Merchant';
    final words = text.split(' ');
    final capWords = words.map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    });
    return capWords.join(' ');
  }
}
