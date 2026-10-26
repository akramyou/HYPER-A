import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/item_batch_model.dart';
import '../models/item_model.dart';
import '../widgets/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'add_edit_batch_screen.dart';
import 'add_item_screen.dart';

class ItemDetailScreen extends StatefulWidget {
  const ItemDetailScreen({super.key, required this.itemId});
  final int itemId;
  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late Future<_ItemDetailData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ItemDetailData> _load() async {
    final db = DatabaseHelper.instance;
    final item = await db.getItem(widget.itemId);
    if (item == null) throw StateError('الصنف غير موجود.');
    return _ItemDetailData(item, await db.getBatchesForItem(widget.itemId));
  }

  Future<void> _refresh() async => setState(() => _future = _load());

  Future<void> _addBatch(InventoryItem item, {ItemBatch? batch}) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AddEditBatchScreen(item: item, batch: batch)));
    if (mounted) await _refresh();
  }

  Future<void> _deleteBatch(ItemBatch batch) async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('حذف الدفعة؟'),
      content: Text('سيتم حذف سجل الدفعة ${batch.batchNumber.isEmpty ? '(بدون رقم)' : batch.batchNumber} وتاريخ انتهائها. لا يمكن التراجع عن الحذف.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف'))],
    ));
    if (confirmed == true) {
      await DatabaseHelper.instance.deleteBatch(batch.id!);
      if (mounted) await _refresh();
    }
  }

  Future<void> _editItem(InventoryItem item) async {
    await Navigator.of(context).push(MaterialPageRoute<bool>(builder: (_) => AddItemScreen(item: item)));
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_ItemDetailData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Scaffold(body: LoadingView());
          if (snapshot.hasError) return Scaffold(appBar: AppBar(), body: Center(child: Text('تعذر تحميل التفاصيل: ${snapshot.error}')));
          final data = snapshot.data!;
          final item = data.item;
          return Scaffold(
            appBar: AppBar(title: const Text('تفاصيل الصنف'), actions: [IconButton(tooltip: 'تعديل بيانات الصنف', onPressed: () => _editItem(item), icon: const Icon(Icons.edit_outlined))]),
            floatingActionButton: FloatingActionButton.extended(onPressed: () => _addBatch(item), backgroundColor: AppTheme.green, foregroundColor: Colors.white, icon: const Icon(Icons.add), label: const Text('إضافة دفعة')),
            body: RefreshIndicator(onRefresh: _refresh, child: ListView(padding: const EdgeInsets.all(16), children: [
              Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppTheme.greenDark, AppTheme.green]), borderRadius: BorderRadius.circular(20)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.displayName, style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _Tag('كود النظام ${item.appsCode}'), _Tag('POS ${item.posCode}'), _Tag('الفرع ${item.branchId}'),
                ]),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(child: _StockValue(label: 'مخزون المستودع', value: formatQuantity(item.whStock))),
                  Expanded(child: _StockValue(label: 'مخزون الفرع', value: formatQuantity(item.brStock))),
                  Expanded(child: _StockValue(label: 'المباع', value: formatQuantity(item.soldStk))),
                ]),
              ])),
              const SizedBox(height: 18),
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                _InfoRow('الوصف الإنجليزي', item.descriptionEn.isEmpty ? '—' : item.descriptionEn),
                _InfoRow('الوصف العربي', item.descriptionAr.isEmpty ? '—' : item.descriptionAr),
                _InfoRow('وحدة القياس', item.uom.isEmpty ? '—' : item.uom),
                _InfoRow('موقع التخزين', item.whLocCode.isEmpty ? '—' : item.whLocCode),
                _InfoRow('رمز المنظمة', item.orgCode.isEmpty ? '—' : item.orgCode),
                _InfoRow('النشرة الدعائية', item.isFlyer ? 'نعم' : 'لا'),
              ]))),
              const SizedBox(height: 20),
              SectionHeading('دفعات الصنف', subtitle: 'لكل دفعة تاريخ إنتاج وانتهاء مستقل', trailing: Text('${data.batches.length} دفعة', style: const TextStyle(color: AppTheme.muted, fontSize: 12))),
              if (data.batches.isEmpty)
                const EmptyState(icon: Icons.event_note_outlined, title: 'لا توجد دفعات مسجلة', message: 'أضف دفعة لتسجيل الكمية وتاريخ الإنتاج والانتهاء لهذا الصنف.')
              else
                ...data.batches.map((batch) => _BatchCard(batch: batch, onEdit: () => _addBatch(item, batch: batch), onDelete: () => _deleteBatch(batch))),
              const SizedBox(height: 84),
            ])),
          );
        },
      );
}

class _ItemDetailData {
  const _ItemDetailData(this.item, this.batches);
  final InventoryItem item;
  final List<ItemBatch> batches;
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: Colors.white.withOpacity(.15), borderRadius: BorderRadius.circular(20)), child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)));
}

class _StockValue extends StatelessWidget {
  const _StockValue({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Color(0xFFD8EDE0), fontSize: 10)), const SizedBox(height: 5), Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17))]);
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 115, child: Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 12))), const SizedBox(width: 8), Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)))]));
}

class _BatchCard extends StatelessWidget {
  const _BatchCard({required this.batch, required this.onEdit, required this.onDelete});
  final ItemBatch batch;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 9), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Expanded(child: Text(batch.batchNumber.isEmpty ? 'دفعة دون رقم' : 'رقم الدفعة: ${batch.batchNumber}', style: const TextStyle(fontWeight: FontWeight.w800))), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: batch.statusColor.withOpacity(.12), borderRadius: BorderRadius.circular(20)), child: Text(batch.expiryStatus, style: TextStyle(color: batch.statusColor, fontWeight: FontWeight.w800, fontSize: 11)))]),
    const SizedBox(height: 12),
    Row(children: [Expanded(child: _DateValue(label: 'الإنتاج', value: batch.productionDate ?? '—')), Expanded(child: _DateValue(label: 'الانتهاء', value: batch.expiryDate)), Expanded(child: _DateValue(label: 'الكمية', value: formatQuantity(batch.quantity)))]),
    const SizedBox(height: 7),
    Row(mainAxisAlignment: MainAxisAlignment.end, children: [TextButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 17), label: const Text('تعديل')), TextButton.icon(onPressed: onDelete, icon: const Icon(Icons.delete_outline, size: 17, color: AppTheme.red), label: const Text('حذف', style: TextStyle(color: AppTheme.red)))]),
  ])));
}

class _DateValue extends StatelessWidget {
  const _DateValue({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.muted)), const SizedBox(height: 5), Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))]);
}
