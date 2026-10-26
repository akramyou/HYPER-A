import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:hyper_inventory/database/database_helper.dart';
import 'package:hyper_inventory/models/item_batch_model.dart';
import 'package:hyper_inventory/models/item_model.dart';

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
    final importedItem = (await db.getItems()).single;
    final item = InventoryItem(
      id: importedItem.id,
      branchId: importedItem.branchId,
      orgCode: importedItem.orgCode,
      appsCode: importedItem.appsCode,
      posCode: importedItem.posCode,
      descriptionEn: importedItem.descriptionEn,
      descriptionAr: importedItem.descriptionAr,
      uom: importedItem.uom,
      whStock: importedItem.whStock,
      brStock: importedItem.brStock,
      soldStk: importedItem.soldStk,
      whLocCode: importedItem.whLocCode,
      reorderLevel: 3,
      isFlyer: importedItem.isFlyer,
      extraData: importedItem.extraData,
      createdAt: importedItem.createdAt,
      updatedAt: importedItem.updatedAt,
    );
    await db.saveManualItem(item);
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
    expect(refreshed.reorderLevel, 3, reason: 'Daily imports must not overwrite manual reorder settings.');
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


  test('per-item reorder level overrides branch default stock threshold', () async {
    final db = DatabaseHelper.instance;
    await db.saveManualItem(const InventoryItem(
      branchId: 'ED3', orgCode: 'EJW', appsCode: 'REORDER-1', posCode: 'POS-REORDER-1',
      descriptionEn: 'Specific threshold item', descriptionAr: 'صنف حد خاص', uom: 'CTN',
      whStock: 20, brStock: 4, soldStk: 0, whLocCode: 'A0', reorderLevel: 2, isFlyer: false,
    ));
    await db.saveManualItem(const InventoryItem(
      branchId: 'ED3', orgCode: 'EJW', appsCode: 'REORDER-2', posCode: 'POS-REORDER-2',
      descriptionEn: 'Default threshold item', descriptionAr: 'صنف حد افتراضي', uom: 'CTN',
      whStock: 20, brStock: 4, soldStk: 0, whLocCode: 'A1', reorderLevel: -1, isFlyer: false,
    ));

    final stats = await db.getDashboardStats(lowStockThreshold: 5);
    expect(stats.lowStock, 1, reason: 'The item with a custom threshold of 2 and stock 4 is not low; the item using branch default 5 is low.');
  });

  test('historical snapshots persist and cumulative SOLD_STK counts deltas', () async {
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

    final first = await db.importRows(
      headers: headers,
      mapping: mapping,
      sourceName: 'day-1.csv',
      sourceFormat: 'CSV',
      sourceFingerprint: 'test-report-day-1',
      reportDate: DateTime(2026, 10, 1),
      salesMode: 'cumulative',
      rows: const [
        ['ED3', 'EJW', '000200', '100200', 'Item 200', 'صنف 200', 'CTN', '10', '8', '100', 'A0', '0'],
      ],
    );
    expect(first.added, 1);
    expect(first.cumulativeBaselineCount, 1);
    expect(await db.countSnapshots(), 1);

    final item = (await db.getItems()).single;
    final expiry = '2027-04-30';
    await db.saveBatch(ItemBatch(
      itemId: item.id!,
      batchNumber: 'B-200',
      productionDate: '2026-10-01',
      expiryDate: expiry,
      quantity: 8,
      isActive: true,
    ));

    final second = await db.importRows(
      headers: headers,
      mapping: mapping,
      sourceName: 'day-2.csv',
      sourceFormat: 'CSV',
      sourceFingerprint: 'test-report-day-2',
      reportDate: DateTime(2026, 10, 2),
      salesMode: 'cumulative',
      rows: const [
        ['ED3', 'EJW', '000200', '100200', 'Changed in report', 'اسم آخر', 'CTN', '8', '5', '116', 'B1', '0'],
      ],
    );
    expect(second.updated, 1);
    expect(await db.countSnapshots(), 2);
    final database = await db.database;
    final snapshot = await database.query(
      'inventory_snapshots',
      columns: ['sales_quantity', 'report_date'],
      where: 'import_id = ?',
      whereArgs: [second.importId],
    );
    expect((snapshot.single['sales_quantity'] as num).toDouble(), 16);
    expect(snapshot.single['report_date'], '2026-10-02');

    final performance = await db.getSalesPerformance(
      from: DateTime(2026, 10, 2),
      to: DateTime(2026, 10, 2),
      salesMode: 'cumulative',
    );
    expect(performance.single['sold_quantity'], 16);
    expect(performance.single['opening_stock'], 8);
    expect(performance.single['closing_stock'], 5);

    final duplicate = await db.importRows(
      headers: headers,
      mapping: mapping,
      sourceName: 'day-2.csv',
      sourceFormat: 'CSV',
      sourceFingerprint: 'test-report-day-2',
      reportDate: DateTime(2026, 10, 2),
      salesMode: 'cumulative',
      rows: const [
        ['ED3', 'EJW', '000200', '100200', 'Changed in report', 'اسم آخر', 'CTN', '8', '5', '116', 'B1', '0'],
      ],
    );
    expect(duplicate.duplicateReport, isTrue);
    expect(await db.countSnapshots(), 2, reason: 'Re-importing the same report for the same date must not duplicate the history.');
    expect((await db.getBatchesForItem(item.id!)).single.expiryDate, expiry);
    expect((await db.getImportHistory(limit: 10)).length, 2);

    final reinterpreted = await db.importRows(
      headers: headers,
      mapping: mapping,
      sourceName: 'day-2.csv',
      sourceFormat: 'CSV',
      sourceFingerprint: 'test-report-day-2',
      reportDate: DateTime(2026, 10, 2),
      salesMode: 'period',
      rows: const [
        ['ED3', 'EJW', '000200', '100200', 'Changed in report', 'اسم آخر', 'CTN', '8', '5', '116', 'B1', '0'],
      ],
    );
    expect(reinterpreted.duplicateReport, isFalse, reason: 'The same source can be re-imported if the user corrects how SOLD_STK is interpreted.');
    expect(await db.countSnapshots(), 3);
  });

}

