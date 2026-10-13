import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_app/features/business/business_home_screen.dart';

void main() {
  group('formatMoney', () {
    test('formats rupees and paisa correctly', () {
      expect(formatMoney(123456), 'Rs 1,234.56');
    });

    test('formats whole rupees correctly', () {
      expect(formatMoney(50000), 'Rs 500.00');
    });

    test('formats negative balances correctly', () {
      expect(formatMoney(-500), '-Rs 5.00');
    });
  });

  group('parseAmountMinor', () {
    test('converts rupees into minor units', () {
      expect(parseAmountMinor('123.45'), 12345);
    });

    test('accepts comma-separated amounts', () {
      expect(parseAmountMinor('1,234.56'), 123456);
    });

    test('rejects invalid or non-positive amounts', () {
      expect(parseAmountMinor('abc'), isNull);
      expect(parseAmountMinor('0'), isNull);
      expect(parseAmountMinor('-20'), isNull);
    });
  });
}
