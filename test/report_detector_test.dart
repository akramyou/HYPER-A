import 'package:flutter_test/flutter_test.dart';
import 'package:hyper_dammam3/services/report_detector.dart';
import 'package:hyper_dammam3/utils/expiry_parser.dart';

void main() {
  group('ReportDetector', () {
    test('maps common English and Arabic report headers', () {
      final mapping = ReportDetector.suggestMapping([
        'Item Code',
        'POS Code',
        'الوصف العربي',
        'رصيد الفرع',
      ]);

      expect(mapping['Item Code'], 'apps_code');
      expect(mapping['POS Code'], 'pos_code');
      expect(mapping['الوصف العربي'], 'description_ar');
      expect(mapping['رصيد الفرع'], 'br_stock');
    });

    test('detects branch and organization from report rows', () {
      final result = ReportDetector.detectBranchInfo([
        {'Branch ID': 'B-101', 'Org Code': 'ORG-7'},
      ]);

      expect(result['branch_id'], 'B-101');
      expect(result['org_code'], 'ORG-7');
    });
  });

  group('ExpiryParser', () {
    test('parses day/month/year dates', () {
      expect(ExpiryParser.parse('15/04/2027'), DateTime(2027, 4, 15));
    });

    test('returns null for invalid input', () {
      expect(ExpiryParser.parse('not a date'), isNull);
    });
  });
}
