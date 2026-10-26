import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/branch_config.dart';
import '../models/item_batch_model.dart';
import '../models/item_model.dart';

class ImportResult {
  const ImportResult({required this.added, required this.updated, required this.skipped, required this.branchId, required this.orgCode});
  final int added;
  final int updated;
  final int skipped;
  final String branchId;
  final String orgCode;
}

class DashboardStats {
  const DashboardStats({required this.items, required this.expired, required this.within7, required this.within30, required this.lowStock, required this.activeBatches});
  final int items;
  final int expired;
  final int within7;
  final int within30;
  final int lowStock;
  final int activeBatches;
}

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final base = await getDatabasesPath();
    final path = p.join(base, 'hyper_inventory_v1.db');
    _database = await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createSchema,
    );
    return _database!;
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''CREATE TABLE app_config (
      key TEXT PRIMARY KEY,
      value TEXT
    )''');
    await db.execute('''CREATE TABLE items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      branch_id TEXT NOT NULL,
      org_code TEXT NOT NULL DEFAULT '',
      apps_code TEXT NOT NULL,
      pos_code TEXT NOT NULL,
      description_en TEXT NOT NULL DEFAULT '',
      description_ar TEXT NOT NULL DEFAULT '',
      uom TEXT NOT NULL DEFAULT '',
      wh_stock REAL NOT NULL DEFAULT 0,
      br_stock REAL NOT NULL DEFAULT 0,
      sold_stk REAL NOT NULL DEFAULT 0,
      wh_loc_code TEXT NOT NULL DEFAULT '',
      is_flyer INTEGER NOT NULL DEFAULT 0,
      extra_data TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      UNIQUE(apps_code, pos_code, branch_id)
    )''');
    await db.execute('CREATE INDEX idx_items_name_ar ON items(description_ar)');
    await db.execute('CREATE INDEX idx_items_name_en ON items(description_en)');
    await db.execute('CREATE INDEX idx_items_branch ON items(branch_id)');
    await db.execute('''CREATE TABLE item_batches (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      item_id INTEGER NOT NULL,
      batch_number TEXT NOT NULL DEFAULT '',
      production_date TEXT,
      expiry_date TEXT NOT NULL,
      quantity REAL NOT NULL DEFAULT 0,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      FOREIGN KEY(item_id) REFERENCES items(id) ON DELETE CASCADE
    )''');
    await db.execute('CREATE INDEX idx_batches_expiry ON item_batches(is_active, expiry_date)');
    await db.execute('CREATE INDEX idx_batches_item ON item_batches(item_id)');
    await db.execute('''CREATE TABLE notification_settings (
      id INTEGER PRIMARY KEY CHECK(id = 1),
      expired_enabled INTEGER NOT NULL DEFAULT 1,
      less_than_week_enabled INTEGER NOT NULL DEFAULT 1,
      less_than_month_enabled INTEGER NOT NULL DEFAULT 1,
      one_to_two_months_enabled INTEGER NOT NULL DEFAULT 1,
      two_to_three_months_enabled INTEGER NOT NULL DEFAULT 1,
      low_stock_enabled INTEGER NOT NULL DEFAULT 1
    )''');
    await db.insert('notification_settings', {
      'id': 1,
      'expired_enabled': 1,
      'less_than_week_enabled': 1,
      'less_than_month_enabled': 1,
      'one_to_two_months_enabled': 1,
      'two_to_three_months_enabled': 1,
      'low_stock_enabled': 1,
    });
    await db.execute('''CREATE TABLE audit_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      action TEXT NOT NULL,
      details TEXT NOT NULL,
      created_at TEXT NOT NULL
    )''');
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<void> logAction(String action, String details, {DatabaseExecutor? executor}) async {
    final db = executor ?? await database;
    await db.insert('audit_log', {
      'action': action,
      'details': details,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, Object?>>> getAuditLog({int limit = 100}) async {
    final db = await database;
    return db.query('audit_log', orderBy: 'id DESC', limit: limit);
  }

  Future<BranchConfig> getBranchConfig() async {
    final db = await database;
    final rows = await db.query('app_config', where: 'key = ?', whereArgs: ['branch_config'], limit: 1);
    if (rows.isEmpty) return const BranchConfig();
    try {
      return BranchConfig.fromJson(jsonDecode(rows.first['value'] as String) as Map<String, dynamic>);
    } catch (_) {
      return const BranchConfig();
    }
  }

  Future<void> saveBranchConfig(BranchConfig config) async {
    final db = await database;
    await db.insert('app_config', {'key': 'branch_config', 'value': jsonEncode(config.toJson())}, conflictAlgorithm: ConflictAlgorithm.replace);
    await logAction('settings', 'تم تحديث إعدادات الفرع ${config.branchId}');
  }

  Future<Map<String, bool>> getNotificationSettings() async {
    final db = await database;
    final rows = await db.query('notification_settings', where: 'id = 1', limit: 1);
    final row = rows.isEmpty ? <String, Object?>{} : rows.first;
    return {
      'expired_enabled': row['expired_enabled'] != 0,
      'less_than_week_enabled': row['less_than_week_enabled'] != 0,
      'less_than_month_enabled': row['less_than_month_enabled'] != 0,
      'one_to_two_months_enabled': row['one_to_two_months_enabled'] != 0,
      'two_to_three_months_enabled': row['two_to_three_months_enabled'] != 0,
      'low_stock_enabled': row['low_stock_enabled'] != 0,
    };
  }

  Future<void> saveNotificationSettings(Map<String, bool> values) async {
    final db = await database;
    await db.insert('notification_settings', {
      'id': 1,
      for (final entry in values.entries) entry.key: entry.value ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await logAction('settings', 'تم تحديث أنواع التنبيهات المفعّلة');
  }

  Future<List<InventoryItem>> getItems({String search = '', int? limit, int offset = 0, bool currentBranchOnly = true}) async {
    final db = await database;
    final term = search.trim();
    final config = await getBranchConfig();
    final clauses = <String>[];
    final args = <Object?>[];
    if (currentBranchOnly && config.branchId.isNotEmpty) {
      clauses.add('branch_id = ?');
      args.add(config.branchId);
    }
    if (term.isNotEmpty) {
      clauses.add('(description_ar LIKE ? OR description_en LIKE ? OR apps_code LIKE ? OR pos_code LIKE ? OR wh_loc_code LIKE ?)');
      args.addAll(List.filled(5, '%$term%'));
    }
    final rows = await db.query(
      'items',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'description_ar COLLATE NOCASE ASC, description_en COLLATE NOCASE ASC',
      limit: limit,
      offset: offset,
    );
    return rows.map(InventoryItem.fromMap).toList();
  }

  Future<InventoryItem?> getItem(int id) async {
    final db = await database;
    final rows = await db.query('items', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : InventoryItem.fromMap(rows.first);
  }

  Future<InventoryItem?> findItemByAnyCode(String code) async {
    final db = await database;
    final normalized = code.trim();
    if (normalized.isEmpty) return null;
    final config = await getBranchConfig();
    final where = config.branchId.isEmpty
        ? '(apps_code = ? OR pos_code = ?)'
        : '(apps_code = ? OR pos_code = ?) AND branch_id = ?';
    final args = config.branchId.isEmpty
        ? <Object?>[normalized, normalized]
        : <Object?>[normalized, normalized, config.branchId];
    final rows = await db.query('items', where: where, whereArgs: args, limit: 1);
    return rows.isEmpty ? null : InventoryItem.fromMap(rows.first);
  }

  Future<int> saveManualItem(InventoryItem item) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final id = item.id == null
        ? await db.insert('items', item.toMap())
        : await db.update('items', {...item.toMap(), 'updated_at': now}, where: 'id = ?', whereArgs: [item.id]);
    await logAction(item.id == null ? 'item_add' : 'item_edit', '${item.appsCode} — ${item.displayName}');
    return item.id ?? id;
  }

  Future<List<ItemBatch>> getBatchesForItem(int itemId) async {
    final db = await database;
    final rows = await db.rawQuery('''SELECT b.*, CASE WHEN TRIM(i.description_ar) <> '' THEN i.description_ar ELSE i.description_en END AS item_description_ar, i.description_en AS item_description_en, i.apps_code
      FROM item_batches b JOIN items i ON i.id = b.item_id
      WHERE b.item_id = ? ORDER BY b.expiry_date ASC''', [itemId]);
    return rows.map(ItemBatch.fromMap).toList();
  }

  Future<int> saveBatch(ItemBatch batch) async {
    final db = await database;
    final map = batch.toMap();
    final id = batch.id == null
        ? await db.insert('item_batches', map)
        : await db.update('item_batches', map..remove('created_at'), where: 'id = ?', whereArgs: [batch.id]);
    await logAction(batch.id == null ? 'batch_add' : 'batch_edit', 'الصنف ${batch.itemId}، دفعة ${batch.batchNumber}، انتهاء ${batch.expiryDate}');
    return batch.id ?? id;
  }

  Future<void> deleteBatch(int batchId) async {
    final db = await database;
    final rows = await db.query('item_batches', where: 'id = ?', whereArgs: [batchId], limit: 1);
    await db.delete('item_batches', where: 'id = ?', whereArgs: [batchId]);
    if (rows.isNotEmpty) await logAction('batch_delete', 'حذف الدفعة $batchId للصنف ${rows.first['item_id']}');
  }

  Future<List<Map<String, Object?>>> getJoinedBatches({bool activeOnly = true, bool currentBranchOnly = true}) async {
    final db = await database;
    final config = await getBranchConfig();
    final clauses = <String>[];
    final args = <Object?>[];
    if (activeOnly) clauses.add('b.is_active = 1');
    if (currentBranchOnly && config.branchId.isNotEmpty) {
      clauses.add('i.branch_id = ?');
      args.add(config.branchId);
    }
    final where = clauses.isEmpty ? '' : 'WHERE ${clauses.join(' AND ')}';
    return db.rawQuery('''SELECT b.*, i.branch_id, i.org_code, i.apps_code, i.pos_code, i.description_en AS item_description_en,
      CASE WHEN TRIM(i.description_ar) <> '' THEN i.description_ar ELSE i.description_en END AS item_description_ar,
      i.uom, i.wh_stock, i.br_stock, i.wh_loc_code
      FROM item_batches b JOIN items i ON i.id = b.item_id $where
      ORDER BY b.expiry_date ASC''', args);
  }

  Future<DashboardStats> getDashboardStats({double lowStockThreshold = 5}) async {
    final db = await database;
    final config = await getBranchConfig();
    final scoped = config.branchId.isNotEmpty;
    final itemCount = Sqflite.firstIntValue(await db.rawQuery(
      scoped ? 'SELECT COUNT(*) FROM items WHERE branch_id = ?' : 'SELECT COUNT(*) FROM items',
      scoped ? [config.branchId] : null,
    )) ?? 0;
    final batches = await db.rawQuery(
      scoped
          ? 'SELECT b.* FROM item_batches b JOIN items i ON i.id = b.item_id WHERE b.is_active = 1 AND i.branch_id = ?'
          : 'SELECT b.* FROM item_batches b WHERE b.is_active = 1',
      scoped ? [config.branchId] : null,
    );
    var expired = 0;
    var within7 = 0;
    var within30 = 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final row in batches) {
      final date = DateTime.tryParse((row['expiry_date'] ?? '').toString());
      if (date == null) continue;
      final days = DateTime(date.year, date.month, date.day).difference(today).inDays;
      if (days < 0) expired++;
      if (days >= 0 && days <= 7) within7++;
      if (days >= 0 && days <= 30) within30++;
    }
    final low = Sqflite.firstIntValue(await db.rawQuery(
      scoped
          ? 'SELECT COUNT(*) FROM items WHERE br_stock <= ? AND branch_id = ?'
          : 'SELECT COUNT(*) FROM items WHERE br_stock <= ?',
      scoped ? [lowStockThreshold, config.branchId] : [lowStockThreshold],
    )) ?? 0;
    return DashboardStats(items: itemCount, expired: expired, within7: within7, within30: within30, lowStock: low, activeBatches: batches.length);
  }

  Future<ImportResult> importRows({required List<String> headers, required List<List<dynamic>> rows, required Map<String, int> mapping}) async {
    final db = await database;
    int added = 0;
    int updated = 0;
    int skipped = 0;
    String detectedBranch = '';
    String detectedOrg = '';
    final seen = <String>{};
    String cell(List<dynamic> row, String field) {
      final index = mapping[field];
      if (index == null || index < 0 || index >= row.length) return '';
      return (row[index] ?? '').toString().replaceAll('\uFEFF', '').trim();
    }

    double number(List<dynamic> row, String field, int spreadsheetRow) {
      final text = cell(row, field).replaceAll(',', '');
      if (text.isEmpty) return 0;
      final parsed = double.tryParse(text);
      if (parsed == null || !parsed.isFinite) {
        throw FormatException('قيمة مخزون غير رقمية في الصف $spreadsheetRow، الحقل $field. أُلغي الاستيراد لحماية البيانات.');
      }
      return parsed;
    }

    bool flyer(List<dynamic> row) {
      final v = cell(row, 'is_flyer').toUpperCase();
      return v == 'FLYER' || v == '1' || v == 'TRUE' || v == 'YES';
    }

    await db.transaction((txn) async {
      for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
        final row = rows[rowIndex];
        final spreadsheetRow = rowIndex + 2; // Row 1 contains headers.
        if (row.isEmpty || row.every((v) => v == null || v.toString().trim().isEmpty)) {
          skipped++;
          continue;
        }
        final branch = cell(row, 'branch_id');
        final org = cell(row, 'org_code');
        final appsCode = cell(row, 'apps_code');
        final posCode = cell(row, 'pos_code');
        if (branch.isNotEmpty) {
          if (detectedBranch.isEmpty) {
            detectedBranch = branch;
          } else if (branch != detectedBranch) {
            throw FormatException('يحتوي التقرير على أكثر من فرع ($detectedBranch و$branch). استورد تقرير فرع واحد في كل مرة حتى لا تختلط البيانات.');
          }
        }
        if (org.isNotEmpty) {
          if (detectedOrg.isEmpty) {
            detectedOrg = org;
          } else if (org != detectedOrg) {
            throw FormatException('يحتوي التقرير على أكثر من رمز منظمة ($detectedOrg و$org). أُلغي الاستيراد حتى لا تختلط البيانات.');
          }
        }
        if (branch.isEmpty || appsCode.isEmpty || posCode.isEmpty) {
          skipped++;
          continue;
        }
        final composite = '$branch|$appsCode|$posCode';
        if (!seen.add(composite)) {
          skipped++;
          continue;
        }
        final existing = await txn.query('items', columns: ['id'], where: 'apps_code = ? AND pos_code = ? AND branch_id = ?', whereArgs: [appsCode, posCode, branch], limit: 1);
        if (existing.isNotEmpty) {
          // Critical rule: daily imports update stock fields only. Batch expiry/production data is separate and untouched.
          await txn.update('items', {
            'wh_stock': number(row, 'wh_stock', spreadsheetRow),
            'br_stock': number(row, 'br_stock', spreadsheetRow),
            'sold_stk': number(row, 'sold_stk', spreadsheetRow),
          }, where: 'id = ?', whereArgs: [existing.first['id']]);
          updated++;
        } else {
          final knownIndices = mapping.values.toSet();
          final extra = <String, dynamic>{};
          for (var i = 0; i < headers.length; i++) {
            if (!knownIndices.contains(i) && i < row.length) extra[headers[i]] = row[i]?.toString();
          }
          await txn.insert('items', {
            'branch_id': branch,
            'org_code': org,
            'apps_code': appsCode,
            'pos_code': posCode,
            'description_en': cell(row, 'description_en'),
            'description_ar': cell(row, 'description_ar'),
            'uom': cell(row, 'uom'),
            'wh_stock': number(row, 'wh_stock', spreadsheetRow),
            'br_stock': number(row, 'br_stock', spreadsheetRow),
            'sold_stk': number(row, 'sold_stk', spreadsheetRow),
            'wh_loc_code': cell(row, 'wh_loc_code'),
            'is_flyer': flyer(row) ? 1 : 0,
            'extra_data': jsonEncode(extra),
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
          added++;
        }
      }
      final old = await txn.query('app_config', where: 'key = ?', whereArgs: ['branch_config'], limit: 1);
      BranchConfig config = const BranchConfig();
      if (old.isNotEmpty) {
        try {
          config = BranchConfig.fromJson(jsonDecode(old.first['value'] as String) as Map<String, dynamic>);
        } catch (_) {}
      }
      if (detectedBranch.isNotEmpty || detectedOrg.isNotEmpty) {
        final next = BranchConfig(
          branchId: detectedBranch.isNotEmpty ? detectedBranch : config.branchId,
          orgCode: detectedOrg.isNotEmpty ? detectedOrg : config.orgCode,
          branchName: config.branchName,
          isConfigured: true,
          notificationsEnabled: config.notificationsEnabled,
          defaultMinStock: config.defaultMinStock,
          columnMapping: mapping,
        );
        await txn.insert('app_config', {'key': 'branch_config', 'value': jsonEncode(next.toJson())}, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await logAction('import', 'استيراد تقرير: أضيف $added، حُدّث $updated، تم تجاوز $skipped', executor: txn);
    });
    return ImportResult(added: added, updated: updated, skipped: skipped, branchId: detectedBranch, orgCode: detectedOrg);
  }

  Future<Map<String, dynamic>> exportBackup() async {
    final db = await database;
    return {
      'format': 'hyper_inventory_backup',
      'schemaVersion': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'app_config': await db.query('app_config'),
      'items': await db.query('items'),
      'item_batches': await db.query('item_batches'),
      'notification_settings': await db.query('notification_settings'),
      'audit_log': await db.query('audit_log', orderBy: 'id ASC'),
    };
  }

  Future<void> restoreBackup(Map<String, dynamic> backup) async {
    if (backup['format'] != 'hyper_inventory_backup') throw const FormatException('ملف النسخة الاحتياطية غير صالح.');
    const requiredTables = ['app_config', 'items', 'item_batches', 'notification_settings', 'audit_log'];
    if (requiredTables.any((key) => backup[key] is! List)) {
      throw const FormatException('النسخة الاحتياطية غير مكتملة؛ لم يتم تغيير البيانات الحالية.');
    }
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('item_batches');
      await txn.delete('items');
      await txn.delete('app_config');
      await txn.delete('notification_settings');
      await txn.delete('audit_log');
      Future<void> insertRows(String table, dynamic raw) async {
        if (raw is! List) return;
        for (final entry in raw) {
          if (entry is Map) await txn.insert(table, Map<String, Object?>.from(entry.map((k, v) => MapEntry(k.toString(), v))), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      await insertRows('app_config', backup['app_config']);
      await insertRows('items', backup['items']);
      await insertRows('item_batches', backup['item_batches']);
      await insertRows('notification_settings', backup['notification_settings']);
      await insertRows('audit_log', backup['audit_log']);
      await logAction('backup_restore', 'تم استعادة نسخة احتياطية', executor: txn);
    });
  }
}
