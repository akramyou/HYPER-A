class InventoryItem {
  const InventoryItem({
    this.id,
    required this.branchId,
    required this.orgCode,
    required this.appsCode,
    required this.posCode,
    required this.descriptionEn,
    required this.descriptionAr,
    required this.uom,
    required this.whStock,
    required this.brStock,
    required this.soldStk,
    required this.whLocCode,
    required this.isFlyer,
    this.extraData,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String branchId;
  final String orgCode;
  final String appsCode;
  final String posCode;
  final String descriptionEn;
  final String descriptionAr;
  final String uom;
  final double whStock;
  final double brStock;
  final double soldStk;
  final String whLocCode;
  final bool isFlyer;
  final String? extraData;
  final String? createdAt;
  final String? updatedAt;

  String get displayName => descriptionAr.trim().isNotEmpty ? descriptionAr : descriptionEn;

  factory InventoryItem.fromMap(Map<String, Object?> map) => InventoryItem(
        id: map['id'] as int?,
        branchId: (map['branch_id'] ?? '').toString(),
        orgCode: (map['org_code'] ?? '').toString(),
        appsCode: (map['apps_code'] ?? '').toString(),
        posCode: (map['pos_code'] ?? '').toString(),
        descriptionEn: (map['description_en'] ?? '').toString(),
        descriptionAr: (map['description_ar'] ?? '').toString(),
        uom: (map['uom'] ?? '').toString(),
        whStock: _asDouble(map['wh_stock']),
        brStock: _asDouble(map['br_stock']),
        soldStk: _asDouble(map['sold_stk']),
        whLocCode: (map['wh_loc_code'] ?? '').toString(),
        isFlyer: map['is_flyer'] == 1 || map['is_flyer'] == true,
        extraData: map['extra_data']?.toString(),
        createdAt: map['created_at']?.toString(),
        updatedAt: map['updated_at']?.toString(),
      );

  Map<String, Object?> toMap({bool includeId = false}) => {
        if (includeId && id != null) 'id': id,
        'branch_id': branchId,
        'org_code': orgCode,
        'apps_code': appsCode,
        'pos_code': posCode,
        'description_en': descriptionEn,
        'description_ar': descriptionAr,
        'uom': uom,
        'wh_stock': whStock,
        'br_stock': brStock,
        'sold_stk': soldStk,
        'wh_loc_code': whLocCode,
        'is_flyer': isFlyer ? 1 : 0,
        'extra_data': extraData,
        'created_at': createdAt ?? DateTime.now().toIso8601String(),
        'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
      };
}

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse((value ?? '0').toString().replaceAll(',', '').trim()) ?? 0;
}
