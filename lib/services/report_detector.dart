class ReportDetector {
  static String normalize(String value) => value
      .replaceAll('\uFEFF', '')
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s\-./]+'), '_')
      .replaceAll(RegExp(r'[^a-z0-9_\u0600-\u06ff]'), '');

  static const Map<String, List<String>> aliases = {
    'branch_id': ['branch_id', 'branch', 'branch_code', 'store_id', 'معرف_الفرع', 'الفرع'],
    'org_code': ['org_code', 'organization_code', 'org', 'رمز_المنظمة'],
    'apps_code': ['apps_code', 'app_code', 'item_code', 'sku', 'system_code', 'كود_الصنف'],
    'pos_code': ['pos_code', 'pos', 'barcode', 'point_of_sale_code', 'كود_pos', 'باركود'],
    'description_en': ['description', 'description_en', 'item_name', 'english_description', 'name_en'],
    'description_ar': ['arb_desc', 'description_ar', 'arabic_description', 'name_ar', 'الوصف_العربي'],
    'uom': ['uom', 'unit', 'unit_of_measure', 'وحدة_القياس'],
    'wh_stock': ['wh_stock', 'warehouse_stock', 'warehouse_qty', 'wh_qty', 'كمية_المستودع'],
    'br_stock': ['br_stock', 'branch_stock', 'branch_qty', 'stock', 'كمية_الفرع'],
    'sold_stk': ['sold_stk', 'sold_stock', 'sold_qty', 'sales_qty', 'الكمية_المباعة'],
    'wh_loc_code': ['wh_loc_code', 'warehouse_location', 'location', 'loc_code', 'موقع_التخزين'],
    'is_flyer': ['flyer_item', 'is_flyer', 'flyer', 'عرض'],
  };

  static Map<String, int> autoMap(List<String> headers) {
    final normalized = headers.map(normalize).toList();
    final result = <String, int>{};
    for (final entry in aliases.entries) {
      final choices = entry.value.map(normalize).toSet();
      final index = normalized.indexWhere(choices.contains);
      if (index >= 0) result[entry.key] = index;
    }
    return result;
  }

  static bool looksLikeInventoryReport(List<String> headers) {
    final mapped = autoMap(headers);
    return mapped.containsKey('apps_code') &&
        mapped.containsKey('pos_code') &&
        mapped.containsKey('br_stock');
  }
}
