import 'package:flutter/material.dart';

class ItemBatch {
  const ItemBatch({
    this.id,
    required this.itemId,
    required this.batchNumber,
    required this.productionDate,
    required this.expiryDate,
    required this.quantity,
    required this.isActive,
    this.createdAt,
    this.itemName = '',
    this.appsCode = '',
  });

  final int? id;
  final int itemId;
  final String batchNumber;
  final String? productionDate;
  final String expiryDate;
  final double quantity;
  final bool isActive;
  final String? createdAt;
  final String itemName;
  final String appsCode;

  int get daysToExpiry {
    final date = DateTime.tryParse(expiryDate);
    if (date == null) return 999999;
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    return DateTime(date.year, date.month, date.day).difference(normalizedToday).inDays;
  }

  String get expiryStatus {
    if (daysToExpiry < 0) return 'منتهية';
    if (daysToExpiry <= 7) return 'أقل من أسبوع';
    if (daysToExpiry <= 30) return 'أقل من شهر';
    if (daysToExpiry <= 60) return 'من شهر إلى شهرين';
    if (daysToExpiry <= 90) return 'من شهرين إلى 3 أشهر';
    return 'آمنة';
  }

  Color get statusColor {
    if (daysToExpiry < 0) return const Color(0xFFB42318);
    if (daysToExpiry <= 7) return const Color(0xFFB54708);
    if (daysToExpiry <= 30) return const Color(0xFFDC6803);
    if (daysToExpiry <= 60) return const Color(0xFFE9A23B);
    if (daysToExpiry <= 90) return const Color(0xFFD0B323);
    return const Color(0xFF16803C);
  }

  factory ItemBatch.fromMap(Map<String, Object?> map) => ItemBatch(
        id: map['id'] as int?,
        itemId: (map['item_id'] as num?)?.toInt() ?? 0,
        batchNumber: (map['batch_number'] ?? '').toString(),
        productionDate: map['production_date']?.toString(),
        expiryDate: (map['expiry_date'] ?? '').toString(),
        quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
        isActive: map['is_active'] == 1 || map['is_active'] == true,
        createdAt: map['created_at']?.toString(),
        itemName: (map['item_description_ar'] ?? map['item_description_en'] ?? '').toString(),
        appsCode: (map['apps_code'] ?? '').toString(),
      );

  Map<String, Object?> toMap({bool includeId = false}) => {
        if (includeId && id != null) 'id': id,
        'item_id': itemId,
        'batch_number': batchNumber,
        'production_date': productionDate,
        'expiry_date': expiryDate,
        'quantity': quantity,
        'is_active': isActive ? 1 : 0,
        'created_at': createdAt ?? DateTime.now().toIso8601String(),
      };
}
