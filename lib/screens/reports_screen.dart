import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database_helper.dart';
import '../models/item_batch_model.dart';
import '../models/item_model.dart';
import '../widgets/app_theme.dart';
import '../widgets/common_widgets.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _kind = 'all';
  late Future<_ReportData> _future;
  @override
  void initState() { super.initState(); _future = _load(); }
  Future<_ReportData> _load() async => _ReportData(await DatabaseHelper.instance.getItems(), await DatabaseHelper.instance.getJoinedBatches(), await DatabaseHelper.instance.getAuditLog(limit: 50));
  Future<void> _refresh() async => setState(() => _future = _load());

  List<ItemBatch> _filteredBatches(_ReportData data) => data.batches.map(ItemBatch.fromMap).where((batch) {
    switch (_kind) {
      case 'expired': return batch.daysToExpiry < 0;
      case 'upcoming': return batch.daysToExpiry >= 0 && batch.daysToExpiry <= 90;
      case 'week': return batch.daysToExpiry >= 0 && batch.daysToExpiry <= 7;
      default: return true;
    }
  }).toList();

  String _reportText(_ReportData data) {
    final buffer = StringBuffer('تقرير نظام هايبر لإدارة المخزون\nتاريخ الإنشاء: ${DateTime.now().toIso8601String()}\n');
    buffer.writeln('نوع التقرير: ${switch (_kind) {'all' => 'جميع الدفعات', 'expired' => 'الدفعات المنتهية', 'upcoming' => 'الدفعات خلال 90 يومًا', 'week' => 'الدفعات خلال أسبوع', _ => 'تقرير المخزون'}}');
    buffer.writeln('إجمالي الأصناف: ${data.items.length}');
    if (_kind == 'stock') {
      for (final item in data.items) {
        buffer.writeln('${item.appsCode}\t${item.displayName}\tالفرع: ${item.branchId}\tمخزون المستودع: ${formatQuantity(item.whStock)}\tمخزون الفرع: ${formatQuantity(item.brStock)}\tالمباع: ${formatQuantity(item.soldStk)}');
      }
    } else {
      for (final batch in _filteredBatches(data)) {
        buffer.writeln('${batch.itemName}\tكود: ${batch.appsCode}\tدفعة: ${batch.batchNumber}\tانتهاء: ${batch.expiryDate}\tالأيام: ${batch.daysToExpiry}\tالكمية: ${formatQuantity(batch.quantity)}\tالحالة: ${batch.expiryStatus}');
      }
    }
    return buffer.toString();
  }

  Future<void> _share(_ReportData data) async {
    final text = _reportText(data);
    await Share.share(text, subject: 'تقرير هايبر للمخزون والصلاحية');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('التقارير')), 
        body: FutureBuilder<_ReportData>(future: _future, builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const LoadingView();
          if (snapshot.hasError) return Center(child: Text('تعذر إنشاء التقرير: ${snapshot.error}'));
          final data = snapshot.data!;
          final batches = _filteredBatches(data);
          return RefreshIndicator(onRefresh: _refresh, child: ListView(padding: const EdgeInsets.all(16), children: [
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('إنشاء تقرير قابل للمشاركة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('اختر نوع التقرير، راجع النتائج، ثم شارك ملخصًا نصيًا يمكن فتحه على الهاتف أو إرساله للإدارة.', style: TextStyle(color: AppTheme.muted, fontSize: 12, height: 1.5)),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(value: _kind, decoration: const InputDecoration(labelText: 'نوع التقرير'), items: const [
                DropdownMenuItem(value: 'all', child: Text('جميع الدفعات')),
                DropdownMenuItem(value: 'expired', child: Text('الدفعات المنتهية')),
                DropdownMenuItem(value: 'upcoming', child: Text('الدفعات خلال 90 يومًا')),
                DropdownMenuItem(value: 'week', child: Text('الدفعات خلال أسبوع')),
                DropdownMenuItem(value: 'stock', child: Text('تقرير الكميات لجميع الأصناف')),
              ], onChanged: (v) => setState(() => _kind = v ?? 'all')),
              const SizedBox(height: 12),
              FilledButton.icon(onPressed: () => _share(data), icon: const Icon(Icons.ios_share_rounded), label: const Text('مشاركة التقرير النصي')),
            ]))),
            const SizedBox(height: 18),
            SectionHeading('معاينة التقرير', subtitle: _kind == 'stock' ? '${data.items.length} صنفًا' : '${batches.length} دفعة'),
            if (_kind == 'stock') ...data.items.take(60).map((item) => _StockReportCard(item: item))
            else if (batches.isEmpty) const EmptyState(icon: Icons.description_outlined, title: 'لا توجد بيانات مطابقة', message: 'غيّر نوع التقرير أو سجّل دفعات للأصناف.')
            else ...batches.take(100).map((batch) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
              leading: CircleAvatar(backgroundColor: batch.statusColor.withOpacity(.12), child: Icon(Icons.event_note_outlined, color: batch.statusColor)),
              title: Text(batch.itemName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('انتهاء ${batch.expiryDate} · ${batch.expiryStatus}', style: const TextStyle(fontSize: 11)),
              trailing: Text(formatQuantity(batch.quantity), style: const TextStyle(fontWeight: FontWeight.w900)),
            ))),
            if (data.audit.isNotEmpty) ...[
              const SizedBox(height: 20),
              SectionHeading('آخر العمليات المسجلة'),
              ...data.audit.take(10).map((entry) => Card(margin: const EdgeInsets.only(bottom: 6), child: ListTile(leading: const Icon(Icons.history_rounded, color: AppTheme.muted), title: Text((entry['action'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), subtitle: Text((entry['details'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis), trailing: Text((entry['created_at'] ?? '').toString().replaceFirst('T', '\n').split('.').first, textAlign: TextAlign.end, style: const TextStyle(fontSize: 9, color: AppTheme.muted))))),
            ],
          ]));
        }),
      );
}

class _ReportData {
  const _ReportData(this.items, this.batches, this.audit);
  final List<InventoryItem> items;
  final List<Map<String, Object?>> batches;
  final List<Map<String, Object?>> audit;
}

class _StockReportCard extends StatelessWidget {
  const _StockReportCard({required this.item});
  final InventoryItem item;
  @override
  Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(title: Text(item.displayName, maxLines: 2, overflow: TextOverflow.ellipsis), subtitle: Text('${item.appsCode} · المستودع ${formatQuantity(item.whStock)} · الفرع ${formatQuantity(item.brStock)}', style: const TextStyle(fontSize: 11)), trailing: Text(item.whLocCode, style: const TextStyle(color: AppTheme.muted))));
}
