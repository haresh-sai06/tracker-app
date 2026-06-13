import 'package:flutter/foundation.dart';
import 'package:tracker_app/core/services/sms_parser_service.dart';

class NotificationParserService {
  /// Map of known package names to human-friendly bank names
  static const Map<String, String> bankPackages = {
    'com.snapwork.hdfc': 'HDFC Bank',
    'com.sbi.sbifreedom': 'SBI (YONO)',
    'com.sbi.anywhere': 'SBI',
    'net.one97.paytm': 'Paytm',
    'com.phonepe.app': 'PhonePe',
    'com.google.android.apps.nbu.paisa.user': 'GPay / UPI',
    'com.icicibank.imobile': 'ICICI Bank',
    'com.axis.mobile': 'Axis Bank',
    'in.amazon.mShop.android.shopping': 'Amazon Pay',
  };

  /// Parses an incoming notification message and returns a ParsedTransaction as a fallback.
  static Future<ParsedTransaction?> parseNotification({
    required String packageName,
    required String title,
    required String text,
  }) async {
    if (text.isEmpty && title.isEmpty) return null;

    // Combine title and text to provide enough text content context to regex
    final combinedText = '$title: $text';

    // Delegate parsing logic to the existing sms parser isolate to run off-main-thread
    final parsed = await SmsParserService.parseSms(combinedText);
    if (parsed == null) return null;

    final mappedBank = bankPackages[packageName] ?? parsed.bankName;

    return ParsedTransaction(
      amount: parsed.amount,
      type: parsed.type,
      merchantName: parsed.merchantName,
      accountLastFour: parsed.accountLastFour,
      bankName: mappedBank,
      rawText: text.isNotEmpty ? text : combinedText,
      confidence: parsed.confidence,
    );
  }
}
