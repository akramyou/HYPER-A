import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/item_batch_model.dart';
import '../models/item_model.dart';
import '../widgets/app_theme.dart';
import '../widgets/common_widgets.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late Future<_AnalyticsData> _future;
  @override
  void initState() { super.initState(); _future = _load(); }
  Future<_AnalyticsData> _load() async {
    final db = DatabaseHelper.instance;
    final config = await db.getBranchConfig();
    return _AnalyticsData(await db.getDashboardStats(lowStockThreshold: config.defaultMinStock), await db.getJoinedBatches(), await db.getItems());
  }

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('التحليل البياني')), body: FutureBuilder<_AnalyticsData>(future: _future, builder: (context, snapshot) {
    if (snapshot.connectionState != ConnectionState.done) return const LoadingView();
    if (snapshot.hasError) return Center(child: Text('تعذر تحميل التحليل: ${snapshot.error}'));
    final data = snapshot.data!;
    final batches = data.batches.map(ItemBatch.fromMap).toList();
    final categories = <String, int>{'منتهية': 0, 'أسبوع': 0, 'شهر': 0, '1–2 شهر': 0, '2–3 أشهر': 0, 'آمنة': 0};
    for (final b in batches) {
      final d = b.daysToExpiry;
      if (d < 0) categories['منتهية'] = categories['منتهية']! + 1;
      else if (d <= 7) categories['أسبوع'] = categories['أسبوع']! + 1;
      else if (d <= 30) categories['شهر'] = categories['شهر']! + 1;
      else if (d <= 60) categories['1–2 شهر'] = categories['1–2 شهر']! + 1;
      else if (d <= 90) categories['2–3 أشهر'] = categories['2–3 أشهر']! + 1;
      else categories['آمنة'] = categories['آمنة']! + 1;
    }
    final stockTotal = data.items.fold<double>(0, (sum, item) => sum + item.brStock);
    final warehouseTotal = data.items.fold<double>(0, (sum, item) => sum + item.whStock);
    return RefreshIndicator(onRefresh: () async => setState(() => _future = _load()), child: ListView(padding: const EdgeInsets.all(16), children: [
      GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.5, mainAxisSpacing: 9, crossAxisSpacing: 9, children: [
        StatCard(title: 'الأصناف', value: data.stats.items.toString(), icon: Icons.inventory_2_outlined, color: AppTheme.green),
        StatCard(title: 'الدفعات النشطة', value: data.stats.activeBatches.toString(), icon: Icons.layers_outlined, color: const Color(0xFF175CD3)),
        StatCard(title: 'الدفعات المنتهية', value: data.stats.expired.toString(), icon: Icons.warning_amber_rounded, color: AppTheme.red),
        StatCard(title: 'المخزون المنخفض', value: data.stats.lowStock.toString(), icon: Icons.trending_down_rounded, color: const Color(0xFFB54708)),
      ]),
      const SizedBox(height: 22),
      SectionHeading('توزيع حالات الصلاحية', subtitle: 'الحساب على أساس كل دفعة نشطة'),
      Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
        SizedBox(height: 225, child: categories.values.fold<int>(0, (a, b) => a + b) == 0 ? const Center(child: Text('لا توجد دفعات لعرض الرسم.')) : PieChart(PieChartData(
          sectionsSpace: 3,
          centerSpaceRadius: 42,
          sections: [
            _section('منتهية', categories['منتهية']!, AppTheme.red),
            _section('أسبوع', categories['أسبوع']!, const Color(0xFFB54708)),
            _section('شهر', categories['شهر']!, const Color(0xFFDC6803)),
            _section('1–2 شهر', categories['1–2 شهر']!, const Color(0xFFE9A23B)),
            _section('2–3 أشهر', categories['2–3 أشهر']!, const Color(0xFFD0B323)),
            _section('آمنة', categories['آمنة']!, AppTheme.green),
          ],
        ))),
        const SizedBox(height: 10),
        Wrap(spacing: 12, runSpacing: 7, children: categories.entries.map((e) => _Legend(color: _colorFor(e.key), label: '${e.key}: ${e.value}')).toList()),
      ]))),
      const SizedBox(height: 22),
      SectionHeading('مقارنة كميات المخزون', subtitle: 'مجموع القيم كما وردت من التقارير'),
      Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 20, 20, 14),
          child: SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 42)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) => Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Text(value.toInt() == 0 ? 'المستودع' : 'الفرع', style: const TextStyle(fontSize: 10)),
                      ),
                    ),
                  ),
                ),
                barGroups: [
                  BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: warehouseTotal < 0 ? 0 : warehouseTotal, color: AppTheme.green, width: 30, borderRadius: BorderRadius.circular(5))]),
                  BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: stockTotal < 0 ? 0 : stockTotal, color: const Color(0xFFE9A23B), width: 30, borderRadius: BorderRadius.circular(5))]),
                ],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      const Text('ملاحظة: يمكن أن تكون كميات الفرع سالبة في تقرير المصدر؛ لا يتم تغييرها أو تصفيرها تلقائيًا عند الاستيراد.', style: TextStyle(color: AppTheme.muted, fontSize: 11, height: 1.5)),
    ]));
  }));

  PieChartSectionData _section(String title, int count, Color color) => PieChartSectionData(value: count == 0 ? 0.001 : count.toDouble(), color: color, radius: 58, title: count == 0 ? '' : '$count', titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800));
  Color _colorFor(String key) => switch (key) {'منتهية' => AppTheme.red, 'أسبوع' => const Color(0xFFB54708), 'شهر' => const Color(0xFFDC6803), '1–2 شهر' => const Color(0xFFE9A23B), '2–3 أشهر' => const Color(0xFFD0B323), _ => AppTheme.green};
}

class _AnalyticsData {
  const _AnalyticsData(this.stats, this.batches, this.items);
  final DashboardStats stats;
  final List<Map<String, Object?>> batches;
  final List<InventoryItem> items;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 5), Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.muted))]);
}
