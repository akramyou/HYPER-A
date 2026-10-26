import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/item_batch_model.dart';
import '../models/item_model.dart';
import '../widgets/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'item_detail_screen.dart';
import 'settings_screen.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String _filter = 'all';
  late Future<_AlertData> _future;

  @override
  void initState() { super.initState(); _future = _load(); }

  Future<_AlertData> _load() async {
    final db = DatabaseHelper.instance;
    final config = await db.getBranchConfig();
    return _AlertData(await db.getJoinedBatches(), await db.getItems(), await db.getNotificationSettings(), config.defaultMinStock, config.notificationsEnabled);
  }

  Future<void> _refresh() async => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) => FutureBuilder<_AlertData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const LoadingView();
          if (snapshot.hasError) return Center(child: Text('تعذر تحميل التنبيهات: ${snapshot.error}'));
          final data = snapshot.data!;
          final enabled = data.settings;
          final activeBatches = data.batches.where((row) => row['is_active'] == 1).map(ItemBatch.fromMap).toList();
          final filtered = data.notificationsEnabled ? activeBatches.where((b) => _matches(b, enabled)).toList() : <ItemBatch>[];
          final lowStock = data.items.where((i) => i.brStock <= (i.reorderLevel >= 0 ? i.reorderLevel : data.threshold)).toList();
          final selectedBatches = _filter == 'low_stock' ? <ItemBatch>[] : filtered.where(_filter == 'all' ? (_) => true : (batch) => _keyFor(batch) == _filter).toList();
          return RefreshIndicator(onRefresh: _refresh, child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 28), children: [
            Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE7ECE8))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('مركز التنبيهات', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppTheme.ink)),
              const SizedBox(height: 5),
              const Text('تعتمد الحالات على كل دفعة بشكل مستقل، ولا تُحذف تواريخ الصلاحية عند استيراد تقرير يومي.', style: TextStyle(color: AppTheme.muted, fontSize: 12, height: 1.5)),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(value: _filter, decoration: const InputDecoration(labelText: 'تصفية التنبيهات'), items: const [
                DropdownMenuItem(value: 'all', child: Text('جميع التنبيهات')),
                DropdownMenuItem(value: 'expired', child: Text('منتهية الصلاحية')),
                DropdownMenuItem(value: 'week', child: Text('خلال أسبوع')),
                DropdownMenuItem(value: 'month', child: Text('خلال شهر')),
                DropdownMenuItem(value: 'two_months', child: Text('من شهر إلى شهرين')),
                DropdownMenuItem(value: 'three_months', child: Text('من شهرين إلى 3 أشهر')),
                DropdownMenuItem(value: 'low_stock', child: Text('المخزون المنخفض')),
              ], onChanged: (v) => setState(() => _filter = v ?? 'all')),
            ])),
            const SizedBox(height: 18),
            if (_filter == 'all' || _filter == 'low_stock') ...[
              SectionHeading('المخزون المنخفض', subtitle: 'حد التنبيه الحالي: ${formatQuantity(data.threshold)}'),
              if (!data.notificationsEnabled || !enabled['low_stock_enabled']!) const _DisabledAlertNote(label: 'تنبيه المخزون المنخفض معطّل من الإعدادات.'),
              if (data.notificationsEnabled && enabled['low_stock_enabled']!) ...[
                if (lowStock.isEmpty) const _NoAlerts(message: 'لا توجد أصناف أقل من الحد الأدنى الحالي.'),
                ...lowStock.map((item) => _LowStockCard(item: item)),
              ],
              const SizedBox(height: 18),
            ],
            if (_filter != 'low_stock') ...[
              SectionHeading('تنبيهات الدفعات', subtitle: '${selectedBatches.length} دفعة مطابقة للفلتر'),
              if (!data.notificationsEnabled) const _DisabledAlertNote(label: 'جميع التنبيهات معطّلة من الإعدادات.'),
              if (selectedBatches.isEmpty) const _NoAlerts(message: 'لا توجد دفعات ضمن هذه الفئة، أو أن التنبيه معطّل من الإعدادات.'),
              ...selectedBatches.map((batch) => _BatchAlertCard(batch: batch, onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ItemDetailScreen(itemId: batch.itemId))).then((_) => _refresh()))),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const SettingsScreen())).then((_) => _refresh()), icon: const Icon(Icons.tune_rounded), label: const Text('إدارة أنواع التنبيه')),
          ]));
        },
      );

  bool _matches(ItemBatch batch, Map<String, bool> settings) {
    final key = _keyFor(batch);
    final enabledKey = switch (key) {
      'expired' => 'expired_enabled',
      'week' => 'less_than_week_enabled',
      'month' => 'less_than_month_enabled',
      'two_months' => 'one_to_two_months_enabled',
      'three_months' => 'two_to_three_months_enabled',
      _ => '',
    };
    if (enabledKey.isEmpty) return false;
    if (settings[enabledKey] != true) return false;
    return true;
  }

  String _keyFor(ItemBatch batch) {
    final days = batch.daysToExpiry;
    if (days < 0) return 'expired';
    if (days <= 7) return 'week';
    if (days <= 30) return 'month';
    if (days <= 60) return 'two_months';
    if (days <= 90) return 'three_months';
    return 'safe';
  }
}

class _AlertData {
  const _AlertData(this.batches, this.items, this.settings, this.threshold, this.notificationsEnabled);
  final List<Map<String, Object?>> batches;
  final List<InventoryItem> items;
  final Map<String, bool> settings;
  final double threshold;
  final bool notificationsEnabled;
}

class _NoAlerts extends StatelessWidget {
  const _NoAlerts({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [const Icon(Icons.check_circle_outline, color: AppTheme.green), const SizedBox(width: 10), Expanded(child: Text(message, style: const TextStyle(color: AppTheme.muted)))])));
}

class _DisabledAlertNote extends StatelessWidget {
  const _DisabledAlertNote({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 12)));
}

class _LowStockCard extends StatelessWidget {
  const _LowStockCard({required this.item});
  final InventoryItem item;
  @override
  Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
        leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: AppTheme.red.withOpacity(.10), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.inventory_2_outlined, color: AppTheme.red)),
        title: Text(item.displayName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('كود ${item.appsCode} · موقع ${item.whLocCode.isEmpty ? 'غير محدد' : item.whLocCode}', style: const TextStyle(fontSize: 11)),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [const Text('المخزون', style: TextStyle(color: AppTheme.muted, fontSize: 10)), Text(formatQuantity(item.brStock), style: const TextStyle(color: AppTheme.red, fontWeight: FontWeight.w900, fontSize: 16))]),
      ));
}

class _BatchAlertCard extends StatelessWidget {
  const _BatchAlertCard({required this.batch, required this.onTap});
  final ItemBatch batch;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
        onTap: onTap,
        leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: batch.statusColor.withOpacity(.12), borderRadius: BorderRadius.circular(13)), child: Icon(batch.daysToExpiry < 0 ? Icons.warning_amber_rounded : Icons.event_busy_outlined, color: batch.statusColor)),
        title: Text(batch.itemName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('انتهاء: ${batch.expiryDate} · كمية الدفعة ${formatQuantity(batch.quantity)}', style: const TextStyle(fontSize: 11)),
        trailing: SizedBox(width: 85, child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text(batch.expiryStatus, style: TextStyle(fontSize: 10, color: batch.statusColor, fontWeight: FontWeight.w800)), Text(batch.daysToExpiry < 0 ? 'منذ ${batch.daysToExpiry.abs()} يوم' : 'بعد ${batch.daysToExpiry} يوم', style: const TextStyle(fontSize: 10, color: AppTheme.muted))])),
      ));
}
