import 'package:flutter_test/flutter_test.dart';
import 'package:hyper_inventory/services/report_detector.dart';

void main() {
  group('ReportDetector', () {
    const headers = [
      'BRANCH_ID', 'ORG_CODE', 'APPS_CODE', 'POS_CODE', 'DESCRIPTION',
      'ARB_DESC', 'UOM', 'WH_STOCK', 'BR_STOCK', 'SYS_CAL_QTY',
      'MOD_QTY', 'WH_LOC_CODE', 'SOLD_STK', 'FLYER_ITEM',
    ];

    test('maps the real report headings', () {
      final mapping = ReportDetector.autoMap(headers);
      expect(mapping['branch_id'], 0);
      expect(mapping['org_code'], 1);
      expect(mapping['apps_code'], 2);
      expect(mapping['pos_code'], 3);
      expect(mapping['description_en'], 4);
      expect(mapping['description_ar'], 5);
      expect(mapping['uom'], 6);
      expect(mapping['wh_stock'], 7);
      expect(mapping['br_stock'], 8);
      expect(mapping['wh_loc_code'], 11);
      expect(mapping['sold_stk'], 12);
      expect(mapping['is_flyer'], 13);
    });

    test('recognizes inventory report structure', () {
      expect(ReportDetector.looksLikeInventoryReport(headers), isTrue);
      expect(ReportDetector.looksLikeInventoryReport(['Name', 'Expiry']), isFalse);
    });
  });
}
