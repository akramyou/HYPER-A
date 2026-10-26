import 'package:flutter_test/flutter_test.dart';
import 'package:hyper_inventory/utils/expiry_parser.dart';

void main() {
  group('ExpiryParser', () {
    final now = DateTime(2026, 10, 26);

    test('parses ISO date', () {
      expect(ExpiryParser.parse('2027-10-15', now: now), DateTime(2027, 10, 15));
    });

    test('parses day-first dates used in the region', () {
      expect(ExpiryParser.parse('31/10/2027', now: now), DateTime(2027, 10, 31));
    });

    test('parses Arabic numerals', () {
      expect(ExpiryParser.parse('انتهاء ٣١/١٠/٢٠٢٧', now: now), DateTime(2027, 10, 31));
    });

    test('uses the last day for month/year expiry labels', () {
      expect(ExpiryParser.parse('EXP 10/2027', now: now), DateTime(2027, 10, 31));
    });

    test('rejects impossible calendar dates', () {
      expect(ExpiryParser.parse('31/02/2027', now: now), isNull);
    });

    test('returns null when no date can be parsed', () {
      expect(ExpiryParser.parse('Product batch ABC', now: now), isNull);
    });
  });
}
