import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hyper_inventory/services/import_service.dart';

void main() {
  group('ImportService CSV', () {
    test('preserves Arabic text and maps the supplied report headers', () async {
      const csv = 'BRANCH_ID,ORG_CODE,APPS_CODE,POS_CODE,DESCRIPTION,ARB_DESC,UOM,WH_STOCK,BR_STOCK,SOLD_STK,WH_LOC_CODE,FLYER_ITEM\nED3,EJW,000123,100123,Sample,صنف تجريبي,CTN,10,8,2,A0,0';
      final report = await ImportService.parseBytes(Uint8List.fromList(utf8.encode(csv)), 'csv');
      expect(report.headers.first, 'BRANCH_ID');
      expect(report.rows.single[5], 'صنف تجريبي');
      expect(report.rows.single[2], '000123');
    });

    test('rejects unsupported workbook extensions clearly', () async {
      await expectLater(
        ImportService.parseBytes(Uint8List.fromList(utf8.encode('a,b')), 'xls'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
