import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database_helper.dart';
import '../models/branch_config.dart';
import '../models/item_batch_model.dart';
import '../models/item_model.dart';
import '../widgets/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'sales_performance_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _kind = 'all_batches';
  DateTime? _from;
  DateTime? _to;
  final TextEditingController _search = TextEditingController();
  late Future<_ReportData> _future;

  static const Map<String, String> _kinds = {
    'all_batches': 'جميع الدفعات',
    'expired': 'دفعات منتهية الصلاحية',
    'week': 'تنتهي خلال 7 أيام',
    'month': 'تنتهي خلال 8–30 يومًا',
    '31_60': 'تنتهي خلال 31–60 يومًا',
    '61_90': 'تنتهي خلال 61–90 يومًا',
    'safe': 'دفعات آمنة (أكثر من 90 يومًا)',
    'stock': 'كل الأصناف والمخزون',
    'out': 'مخزون صفر / غير متوفر',
    'negative': 'مخزون سالب يحتاج مراجعة',
    'critical': 'مخزون حرج',
    'low': 'مخزون منخفض',
    'available': 'أصناف متوفرة',
    'flyer': 'أصناف النشرة الدعائية',
  };

  @override
  void initState() {
    super.initState();
    _future = _load();
    _search.addListener(_refresh);
  }

  @override
  void dispose() {
    _search.removeListener(_refresh);
    _search.dispose();
    super.dispose();
  }

  Future<_ReportData> _load() async {
    final db = DatabaseHelper.instance;
    return _ReportData(
      await db.getItems(),
      await db.getJoinedBatches(),
      await db.getAuditLog(limit: 50),
      await db.getBranchConfig(),
      await db.getImportHistory(limit: 15),
    );
  }

  void _refresh([String? _]) => setState(() => _future = _load());

  Future<void> _chooseDate({required bool from}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: from ? (_from ?? DateTime(now.year, now.month, 1)) : (_to ?? now),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: from ? 'تاريخ انتهاء الصلاحية من' : 'تاريخ انتهاء الصلاحية إلى',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (from) {
        _from = picked;
        if (_to != null && _from!.isAfter(_to!)) _to = picked;
      } else {
        _to = picked;
        if (_from != null && _to!.isBefore(_from!)) _from = picked;
      }
      _future = _load();
    });
  }

  String _dateText(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  bool get _isStockReport => ['stock', 'out', 'negative', 'critical', 'low', 'available', 'flyer'].contains(_kind);
  double _stock(Map<String, Object?> row) => (row['br_stock'] as num?)?.toDouble() ?? 0;

  List<InventoryItem> _filteredItems(_ReportData data) {
    final q = _search.text.trim().toLowerCase();
    final threshold = data.config.defaultMinStock;
    return data.items.where((item) {
      final text = '${item.displayName} ${item.descriptionAr} ${item.descriptionEn} ${item.appsCode} ${item.posCode} ${item.whLocCode}'.toLowerCase();
      if (q.isNotEmpty && !text.contains(q)) return false;
      final itemThreshold = item.reorderLevel >= 0 ? item.reorderLevel : threshold;
      switch (_kind) {
        case 'out': return item.brStock <= 0;
        case 'negative': return item.brStock < 0;
        case 'critical': return item.brStock > 0 && item.brStock <= itemThreshold * 0.5;
        case 'low': return item.brStock > itemThreshold * 0.5 && item.brStock <= itemThreshold;
        case 'available': return item.brStock > itemThreshold;
        case 'flyer': return item.isFlyer;
        default: return true;
      }
    }).toList()
      ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
  }

  List<ItemBatch> _filteredBatches(_ReportData data) => data.batches.map(ItemBatch.fromMap).where((batch) {
    final date = DateTime.tryParse(batch.expiryDate);
    if (date == null) return false;
    final q = _search.text.trim().toLowerCase();
    final text = '${batch.itemName} ${batch.appsCode} ${batch.batchNumber}'.toLowerCase();
    if (q.isNotEmpty && !text.contains(q)) return false;
    final normalizedDate = DateTime(date.year, date.month, date.day);
    if (_from != null && normalizedDate.isBefore(DateTime(_from!.year, _from!.month, _from!.day))) return false;
    if (_to != null && normalizedDate.isAfter(DateTime(_to!.year, _to!.month, _to!.day))) return false;
    final days = batch.daysToExpiry;
    switch (_kind) {
      case 'expired': return days < 0;
      case 'week': return days >= 0 && days <= 7;
      case 'month': return days >= 8 && days <= 30;
      case '31_60': return days >= 31 && days <= 60;
      case '61_90': return days >= 61 && days <= 90;
      case 'safe': return days > 90;
      default: return true;
    }
  }).toList();

  String _reportText(_ReportData data, List<InventoryItem> items, List<ItemBatch> batches) {
    final buffer = StringBuffer('تقرير نظام Hyper Inventory\n');
    buffer.writeln('تاريخ الإنشاء: ${DateTime.now().toIso8601String()}');
    buffer.writeln('نوع التقرير: ${_kinds[_kind]}');
    if (_from != null || _to != null) buffer.writeln('مدى انتهاء الصلاحية: ${_from == null ? '—' : _dateText(_from!)} إلى ${_to == null ? '—' : _dateText(_to!)}');
    buffer.writeln('الفرع: ${data.config.branchId.isEmpty ? 'كل الفروع' : data.config.branchId}');
    if (_isStockReport) {
      buffer.writeln('عدد الأصناف المطابقة: ${items.length}');
      for (final item in items) {
        buffer.writeln('${item.appsCode}\t${item.posCode}\t${item.displayName}\tالفرع ${item.branchId}\tالمستودع ${formatQuantity(item.whStock)}\tمخزون الفرع ${formatQuantity(item.brStock)}\tالمباع حسب آخر تقرير ${formatQuantity(item.soldStk)}\tالموقع ${item.whLocCode}');
      }
    } else {
      buffer.writeln('عدد الدفعات المطابقة: ${batches.length}');
      for (final batch in batches) {
        buffer.writeln('${batch.itemName}\tكود ${batch.appsCode}\tدفعة ${batch.batchNumber}\tإنتاج ${batch.productionDate ?? '—'}\tانتهاء ${batch.expiryDate}\tالأيام ${batch.daysToExpiry}\tالكمية ${formatQuantity(batch.quantity)}\tالحالة ${batch.expiryStatus}');
      }
    }
    return buffer.toString();
  }

  Future<void> _share(_ReportData data, List<InventoryItem> items, List<ItemBatch> batches) async {
    await Share.share(_reportText(data, items, batches), subject: 'تقرير Hyper Inventory');
  }

  Future<void> _openSales() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SalesPerformanceScreen()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('التقارير والتحليل التشغيلي'), actions: [IconButton(tooltip: 'تحليل حركة الأصناف', onPressed: _openSales, icon: const Icon(Icons.query_stats_rounded))]),
    body: FutureBuilder<_ReportData>(future: _future, builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const LoadingView();
      if (snapshot.hasError) return Center(child: Text('تعذر إنشاء التقرير: ${snapshot.error}'));
      final data = snapshot.data!;
      final items = _filteredItems(data);
      final batches = _filteredBatches(data);
      final count = _isStockReport ? items.length : batches.length;
      return RefreshIndicator(onRefresh: () async => setState(() => _future = _load()), child: ListView(padding: const EdgeInsets.all(16), children: [
        Card(child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('مركز إعداد التقارير', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('استخدم الفلاتر المسبقة والبحث والتاريخ لتحديد التقرير. تاريخ البداية والنهاية يطبّقان على تقارير الدفعات بحسب تاريخ الانتهاء.', style: TextStyle(fontSize: 12, color: AppTheme.muted, height: 1.5)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _kind,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'نوع التقرير أو حالة المخزون'),
            items: _kinds.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (value) => setState(() => _kind = value ?? 'all_batches'),
          ),
          const SizedBox(height: 10),
          TextField(controller: _search, decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: 'بحث بالاسم أو كود الصنف أو POS أو الدفعة', suffixIcon: IconButton(onPressed: () => _search.clear(), icon: const Icon(Icons.clear_rounded)))),
          const SizedBox(height: 10),
          if (!_isStockReport) Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => _chooseDate(from: true), icon: const Icon(Icons.calendar_month_outlined), label: Text('من ${_from == null ? 'أي تاريخ' : _dateText(_from!)}'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: () => _chooseDate(from: false), icon: const Icon(Icons.event_outlined), label: Text('إلى ${_to == null ? 'أي تاريخ' : _dateText(_to!)}'))),
          ]),
          if (_from != null || _to != null) Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => setState(() { _from = null; _to = null; _future = _load(); }), icon: const Icon(Icons.filter_alt_off_outlined), label: const Text('مسح فترة التاريخ'))),
          if (_isStockReport) const Padding(padding: EdgeInsets.only(top: 4), child: Text('تقرير حالة مخزون؛ لا يطبّق مرشح تاريخ الانتهاء على الأصناف.', style: TextStyle(fontSize: 11, color: AppTheme.muted))),
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: () => _share(data, items, batches), icon: const Icon(Icons.ios_share_rounded), label: const Text('مشاركة التقرير المطابق للفلاتر')),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _openSales, icon: const Icon(Icons.trending_up_rounded), label: const Text('فتح تقرير الأكثر مبيعًا ومعدل الدوران')),
        ]))),
        const SizedBox(height: 16),
        SectionHeading('معاينة التقرير', subtitle: '$count نتيجة · ${_kinds[_kind]}'),
        if (_isStockReport) ...[
          if (items.isEmpty) const EmptyState(icon: Icons.inventory_2_outlined, title: 'لا توجد أصناف مطابقة', message: 'غيّر حالة المخزون أو البحث.'),
          ...items.take(200).map((item) => _StockReportCard(item: item)),
        ] else ...[
          if (batches.isEmpty) const EmptyState(icon: Icons.event_busy_outlined, title: 'لا توجد دفعات مطابقة', message: 'غيّر الحالة أو المدى الزمني، أو سجّل دفعات للأصناف.'),
          ...batches.take(250).map((batch) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
            leading: CircleAvatar(backgroundColor: batch.statusColor.withOpacity(.12), child: Icon(Icons.event_note_outlined, color: batch.statusColor)),
            title: Text(batch.itemName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('كود ${batch.appsCode} · دفعة ${batch.batchNumber.isEmpty ? '—' : batch.batchNumber}\nإنتاج ${batch.productionDate ?? '—'} · انتهاء ${batch.expiryDate} · ${batch.expiryStatus}', style: const TextStyle(fontSize: 11, height: 1.45)),
            isThreeLine: true,
            trailing: Text(formatQuantity(batch.quantity), style: const TextStyle(fontWeight: FontWeight.w900)),
          ))),
        ],
        const SizedBox(height: 20),
        SectionHeading('آخر التقارير المستوردة', subtitle: 'سجل مستقل لا يُستبدل عند رفع تقرير جديد'),
        if (data.imports.isEmpty) const Text('لا توجد تقارير مستوردة بعد.', style: TextStyle(color: AppTheme.muted)),
        ...data.imports.take(8).map((entry) => Card(margin: const EdgeInsets.only(bottom: 6), child: ListTile(
          dense: true,
          leading: const Icon(Icons.history_rounded, color: AppTheme.green),
          title: Text((entry['source_name'] ?? 'تقرير').toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('تاريخ ${entry['report_date']} · ${entry['row_count']} صف · أضيف ${entry['added']} · حُدّث ${entry['updated']} · تُجاوز ${entry['skipped']}', style: const TextStyle(fontSize: 11, height: 1.4)),
        ))),
        if (data.audit.isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionHeading('آخر عمليات النظام'),
          ...data.audit.take(10).map((entry) => Card(margin: const EdgeInsets.only(bottom: 6), child: ListTile(leading: const Icon(Icons.history_toggle_off_rounded, color: AppTheme.muted), title: Text((entry['action'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), subtitle: Text((entry['details'] ?? '').toString(), maxLines: 2, overflow: TextOverflow.ellipsis), trailing: Text((entry['created_at'] ?? '').toString().replaceFirst('T', '\n').split('.').first, textAlign: TextAlign.end, style: const TextStyle(fontSize: 9, color: AppTheme.muted))))),
        ],
      ]));
    }),
  );
}

class _ReportData {
  const _ReportData(this.items, this.batches, this.audit, this.config, this.imports);
  final List<InventoryItem> items;
  final List<Map<String, Object?>> batches;
  final List<Map<String, Object?>> audit;
  final BranchConfig config;
  final List<Map<String, Object?>> imports;
}

class _StockReportCard extends StatelessWidget {
  const _StockReportCard({required this.item});
  final InventoryItem item;
  @override
  Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
    leading: CircleAvatar(backgroundColor: item.brStock <= 0 ? AppTheme.red.withOpacity(.12) : AppTheme.greenLight, child: Icon(item.brStock <= 0 ? Icons.inventory_2_outlined : Icons.check_circle_outline, color: item.brStock <= 0 ? AppTheme.red : AppTheme.green)),
    title: Text(item.displayName, maxLines: 2, overflow: TextOverflow.ellipsis),
    subtitle: Text('${item.appsCode} · POS ${item.posCode} · المستودع ${formatQuantity(item.whStock)} · الفرع ${formatQuantity(item.brStock)}\nالمباع حسب آخر تقرير ${formatQuantity(item.soldStk)} · الموقع ${item.whLocCode}\nحد إعادة الطلب ${item.reorderLevel >= 0 ? formatQuantity(item.reorderLevel) : 'حد الفرع الافتراضي'}', style: const TextStyle(fontSize: 11, height: 1.45)),
    isThreeLine: true,
  ));
}
