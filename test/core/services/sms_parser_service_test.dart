import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_app/core/services/sms_parser_service.dart';
import 'package:tracker_app/domain/entities/transaction.dart';

void main() {
  group('SmsParserService.parseSmsBody', () {
    test('parses a transaction alert instead of dropping the word alert', () {
      final parsed = SmsParserService.parseSmsBody(
        'Alert: Rs.500.00 debited from a/c XX1234 to SWIGGY',
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 500);
      expect(parsed.type, TransactionType.debit);
      expect(parsed.accountLastFour, '1234');
      expect(parsed.bankName, 'HDFC');
      expect(parsed.merchantName, 'Swiggy');
    });

    test('parses a starred account mask on a notification-style alert', () {
      final parsed = SmsParserService.parseSmsBody(
        'Transaction Alert: Rs.1,250.50 debited from a/c **9876 to AMAZON',
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 1250.50);
      expect(parsed.accountLastFour, '9876');
      expect(parsed.merchantName, 'Amazon');
    });

    test('keeps a completed debit that also mentions the amount due', () {
      final parsed = SmsParserService.parseSmsBody(
        'Rs.250.00 debited from a/c XX4321 to ZOMATO. Total due Rs.0',
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 250);
      expect(parsed.accountLastFour, '4321');
      expect(parsed.merchantName, 'Zomato');
    });

    test('still ignores OTP codes and declined attempts', () {
      expect(
        SmsParserService.parseSmsBody('Your OTP code is 482913 for Rs.500'),
        isNull,
      );
      expect(
        SmsParserService.parseSmsBody(
          'Payment declined: Rs.500.00 debited from a/c XX1234 to SWIGGY',
        ),
        isNull,
      );
      expect(
        SmsParserService.parseSmsBody('Minimum amount due Rs.2,000.00'),
        isNull,
      );
    });

    test('parses an ICICI spend that masks the card with X characters', () {
      final parsed = SmsParserService.parseSmsBody(
        'Rs 199.00 spent on ICICI Bank Card XXXX4412 at BIG BAZAAR',
      );

      expect(parsed, isNotNull);
      expect(parsed!.amount, 199);
      expect(parsed.accountLastFour, '4412');
      expect(parsed.bankName, 'ICICI');
      expect(parsed.merchantName, 'Big Bazaar');
    });
  });
}
