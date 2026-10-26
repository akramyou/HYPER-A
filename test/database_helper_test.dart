import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:hyper_inventory/database/database_helper.dart';
import 'package:hyper_inventory/models/item_batch_model.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseHelper.instance.close();
    final path = '${await getDatabasesPath()}/hyper_inventory_v1.db';
    await deleteDatabase(path);
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
  });

  test('daily import updates stock only and preserves batches', () async {
    final db = DatabaseHelper.instance;
    const headers = [
      'BRANCH_ID', 'ORG_CODE', 'APPS_CODE', 'POS_CODE', 'DESCRIPTION',
      'ARB_DESC', 'UOM', 'WH_STOCK', 'BR_STOCK', 'SOLD_STK', 'WH_LOC_CODE', 'FLYER_ITEM',
    ];
    const mapping = {
      'branch_id': 0,
      'org_code': 1,
      'apps_code': 2,
      'pos_code': 3,
      'description_en': 4,
      'description_ar': 5,
      'uom': 6,
      'wh_stock': 7,
      'br_stock': 8,
      'sold_stk': 9,
      'wh_loc_code': 10,
      'is_flyer': 11,
    };

    final initial = await db.importRows(
      headers: headers,
      mapping: mapping,
      rows: const [
        ['ED3', 'EJW', '000123', '100123', 'Sample', 'صنف تجريبي', 'CTN', '10', '8', '2', 'A0', '0'],
        ['ED3', 'EJW', '000123', '100123', 'Sample duplicate', 'صنف مكرر', 'CTN', '99', '99', '99', 'A0', '0'],
      ],
    );
    expect(initial.added, 1);
    expect(initial.skipped, 1);
    final item = (await db.getItems()).single;
    final batchId = await db.saveBatch(ItemBatch(
      itemId: item.id!,
      batchNumber: 'B-001',
      productionDate: '2026-10-01',
      expiryDate: '2027-10-31',
      quantity: 8,
      isActive: true,
    ));
    expect(batchId, greaterThan(0));

    final next = await db.importRows(
      headers: headers,
      mapping: mapping,
      rows: const [['ED3', 'EJW', '000123', '100123', 'Renamed by report', 'اسم مختلف', 'CTN', '4', '-2', '9', 'B2', '1']],
    );
    expect(next.updated, 1);
    final refreshed = (await db.getItems()).single;
    expect(refreshed.whStock, 4);
    expect(refreshed.brStock, -2);
    expect(refreshed.soldStk, 9);
    expect(refreshed.descriptionAr, 'صنف تجريبي');
    final batches = await db.getBatchesForItem(item.id!);
    expect(batches.single.expiryDate, '2027-10-31');
    expect(batches.single.productionDate, '2026-10-01');

    await expectLater(
      db.importRows(
        headers: headers,
        mapping: mapping,
        rows: const [['ED3', 'EJW', '000123', '100123', 'Invalid quantity', 'اسم', 'CTN', 'not-a-number', '1', '0', 'B2', '0']],
      ),
      throwsA(isA<FormatException>()),
    );
    final afterRejectedImport = (await db.getItems()).single;
    expect(afterRejectedImport.whStock, 4, reason: 'A failed import must roll back every row.');
    expect((await db.getBatchesForItem(item.id!)).single.expiryDate, '2027-10-31');
  });
}

