import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../widgets/app_theme.dart';
import '../widgets/common_widgets.dart';

class SalesPerformanceScreen extends StatefulWidget {
  const SalesPerformanceScreen({super.key});

  @override
  State<SalesPerformanceScreen> createState() => _SalesPerformanceScreenState();
}

class _SalesPerformanceScreenState extends State<SalesPerformanceScreen> {
  late DateTime _from;
  late DateTime _to;
  String _salesMode = 'period';
  String _view = 'top';
  final _search = TextEditingController();
  late Future<_SalesScreenData> _future;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _to = DateTime(now.year, now.month, now.day);
    _from = _to.subtract(const Duration(days: 29));
    _future = _load();
    _search.addListener(_searchChanged);
  }

  @override
  void dispose() {
    _search.removeListener(_searchChanged);
    _search.dispose();
    super.dispose();
  }

  Future<_SalesScreenData> _load() async {
    final db = DatabaseHelper.instance;
    return _SalesScreenData(
      await db.getSalesPerformance(from: _from, to: _to, salesMode: _salesMode),
      await db.getImportHistory(limit: 20, from: _from, to: _to),
      await db.countSnapshots(),
    );
  }

  void _refresh() => setState(() => _future = _load());
  void _searchChanged() => setState(() => _future = _load());

  Future<void> _selectDate({required bool from}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: from ? 'بداية فترة التحليل' : 'نهاية فترة التحليل',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (from) {
        _from = picked;
        if (_from.isAfter(_to)) _to = picked;
      } else {
        _to = picked;
        if (_to.isBefore(_from)) _from = picked;
      }
      _future = _load();
    });
  }

  List<Map<String, Object?>> _filterRows(List<Map<String, Object?>> source) {
    final q = _search.text.trim().toLowerCase();
    var rows = source.where((row) {
      final text = '${row['description_ar'] ?? ''} ${row['description_en'] ?? ''} ${row['apps_code'] ?? ''} ${row['pos_code'] ?? ''}'.toLowerCase();
      if (q.isNotEmpty && !text.contains(q)) return false;
      final sold = (row['sold_quantity'] as num?)?.toDouble() ?? 0;
      final cover = (row['days_cover'] as num?)?.toDouble();
      switch (_view) {
        case 'slow':
          final average = source.isEmpty ? 0.0 : source.map((e) => (e['sold_quantity'] as num?)?.toDouble() ?? 0).fold<double>(0, (a, b) => a + b) / source.length;
          return sold <= average * 0.25;
        case 'turnover': return ((row['turnover_ratio'] as num?)?.toDouble() ?? 0) > 0;
        case 'low_cover': return cover != null && cover <= 7;
        case 'no_sales': return sold <= 0;
        default: return true;
      }
    }).toList();
    switch (_view) {
      case 'slow': rows.sort((a, b) => ((a['sold_quantity'] as num?)?.toDouble() ?? 0).compareTo((b['sold_quantity'] as num?)?.toDouble() ?? 0)); break;
      case 'turnover': rows.sort((a, b) => ((b['turnover_ratio'] as num?)?.toDouble() ?? 0).compareTo((a['turnover_ratio'] as num?)?.toDouble() ?? 0)); break;
      case 'low_cover': rows.sort((a, b) => ((a['days_cover'] as num?)?.toDouble() ?? 1e12).compareTo((b['days_cover'] as num?)?.toDouble() ?? 1e12)); break;
      case 'no_sales': rows.sort((a, b) => ((a['br_stock'] as num?)?.toDouble() ?? 0).compareTo((b['br_stock'] as num?)?.toDouble() ?? 0)); break;
      default: rows.sort((a, b) => ((b['sold_quantity'] as num?)?.toDouble() ?? 0).compareTo((a['sold_quantity'] as num?)?.toDouble() ?? 0));
    }
    return rows;
  }

  String _dateText(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  double _number(Map<String, Object?> row, String key) => (row[key] as num?)?.toDouble() ?? 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('حركة المبيعات ودوران الأصناف')),
    body: FutureBuilder<_SalesScreenData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const LoadingView();
        if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('تعذر حساب حركة الأصناف: ${snapshot.error}')));
        final data = snapshot.data!;
        final rows = _filterRows(data.performance);
        final totalSales = data.performance.fold<double>(0, (sum, row) => sum + _number(row, 'sold_quantity'));
        final totalOnHand = data.performance.fold<double>(0, (sum, row) => sum + _number(row, 'br_stock'));
        return RefreshIndicator(onRefresh: () async => _refresh(), child: ListView(padding: const EdgeInsets.all(16), children: [
          Card(child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('فترة التحليل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => _selectDate(from: true), icon: const Icon(Icons.calendar_month_outlined), label: Text('من ${_dateText(_from)}'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: () => _selectDate(from: false), icon: const Icon(Icons.event_outlined), label: Text('إلى ${_dateText(_to)}'))),
            ]),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _salesMode,
              decoration: const InputDecoration(labelText: 'طريقة احتساب SOLD_STK'),
              items: const [
                DropdownMenuItem(value: 'period', child: Text('العمود يمثل مبيعات كل تقرير')),
                DropdownMenuItem(value: 'cumulative', child: Text('العمود عداد تراكمي؛ استخدم الفروق')),
              ],
              onChanged: (v) => setState(() { _salesMode = v ?? 'period'; _future = _load(); }),
            ),
            const SizedBox(height: 8),
            const Text('تُحتفظ بلقطات كل تقرير تاريخيًا ولا يستبدل التقرير الجديد السجلات السابقة. النتائج تقديرية وتعتمد على اختيار معنى SOLD_STK الصحيح وعلى انتظام تقارير الفترة.', style: TextStyle(fontSize: 11, color: AppTheme.muted, height: 1.5)),
          ]))),
          const SizedBox(height: 12),
          GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.55, children: [
            StatCard(title: 'حركات مبيعات تقديرية', value: formatQuantity(totalSales), icon: Icons.trending_up_rounded, color: AppTheme.green),
            StatCard(title: 'المخزون الحالي للأصناف', value: formatQuantity(totalOnHand), icon: Icons.inventory_2_outlined, color: const Color(0xFF175CD3)),
            StatCard(title: 'أصناف في التحليل', value: data.performance.length.toString(), icon: Icons.category_outlined, color: const Color(0xFF7A5AF8)),
            StatCard(title: 'لقطات محفوظة تاريخيًا', value: data.snapshots.toString(), icon: Icons.history_rounded, color: const Color(0xFFB54708)),
          ]),
          const SizedBox(height: 16),
          TextField(controller: _search, decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'ابحث بالاسم أو الكود', suffixIcon: IconButton(onPressed: () => _search.clear(), icon: const Icon(Icons.clear)))),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _view,
            decoration: const InputDecoration(labelText: 'عرض الأداء'),
            items: const [
              DropdownMenuItem(value: 'top', child: Text('الأكثر مبيعًا في الفترة')),
              DropdownMenuItem(value: 'slow', child: Text('الأبطأ حركة / منخفض المبيعات')),
              DropdownMenuItem(value: 'turnover', child: Text('أعلى معدل دوران تقديري')),
              DropdownMenuItem(value: 'low_cover', child: Text('تغطية مخزون 7 أيام أو أقل')),
              DropdownMenuItem(value: 'no_sales', child: Text('لم تسجل لها مبيعات في الفترة')),
            ],
            onChanged: (v) => setState(() => _view = v ?? 'top'),
          ),
          const SizedBox(height: 12),
          SectionHeading('نتيجة التحليل', subtitle: '${rows.length} صنفًا · ${_dateText(_from)} إلى ${_dateText(_to)}'),
          if (data.snapshots == 0) const _InfoBox(text: 'لا توجد ذاكرة تاريخية بعد. استورد التقارير عبر تواريخ متتابعة لبدء قياس حركة الأصناف. استيراد تقرير واحد لا يكفي لحساب دوران موثوق.'),
          if (rows.isEmpty) const EmptyState(icon: Icons.query_stats_outlined, title: 'لا توجد نتائج', message: 'وسّع فترة التاريخ أو اختر عرضًا آخر أو استورد تقريرًا تاريخيًا.'),
          ...rows.take(250).map((row) => _PerformanceCard(row: row, number: _number)),
          const SizedBox(height: 20),
          SectionHeading('سجل التقارير المستوردة', subtitle: 'آخر التقارير في الفترة المحددة؛ تبقى هذه السجلات محفوظة بعد الاستيرادات التالية.'),
          if (data.imports.isEmpty) const Text('لا توجد تقارير مستوردة في هذه الفترة.', style: TextStyle(color: AppTheme.muted)),
          ...data.imports.map((entry) => Card(margin: const EdgeInsets.only(bottom: 7), child: ListTile(
            leading: const Icon(Icons.history_rounded, color: AppTheme.green),
            title: Text((entry['source_name'] ?? 'تقرير').toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('تاريخ التقرير ${entry['report_date']} · ${entry['source_format']} · ${entry['sales_mode'] == 'cumulative' ? 'عداد تراكمي' : 'مبيعات فترة'}\n${entry['row_count']} صف · أضيف ${entry['added']} · حُدّث ${entry['updated']} · تُجاوز ${entry['skipped']}', style: const TextStyle(fontSize: 11, height: 1.45)),
            isThreeLine: true,
            trailing: Icon((entry['counter_reset_count'] as num? ?? 0) > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline, color: (entry['counter_reset_count'] as num? ?? 0) > 0 ? AppTheme.red : AppTheme.green),
          ))),
          const SizedBox(height: 10),
          const _InfoBox(text: 'ملاحظة منهجية: معدل الدوران = الكمية المباعة خلال الفترة ÷ متوسط المخزون الافتتاحي والختامي. أيام التغطية = مخزون نهاية الفترة ÷ متوسط المبيعات اليومية. لا يمكن حساب معدل دقيق قبل توفر لقطات كافية وتعريف واضح لعمود SOLD_STK. لا تتضمن البيانات المتاحة أسعار التكلفة أو إيرادات المبيعات، لذلك لا نحسب هامش ربح أو دورانًا بالقيمة المالية.'),
        ]));
      },
    ),
  );
}

class _SalesScreenData {
  const _SalesScreenData(this.performance, this.imports, this.snapshots);
  final List<Map<String, Object?>> performance;
  final List<Map<String, Object?>> imports;
  final int snapshots;
}

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard({required this.row, required this.number});
  final Map<String, Object?> row;
  final double Function(Map<String, Object?>, String) number;

  @override
  Widget build(BuildContext context) {
    final arabic = (row['description_ar'] ?? '').toString();
    final english = (row['description_en'] ?? '').toString();
    final daysCover = (row['days_cover'] as num?)?.toDouble();
    final counterReset = row['counter_reset'] == true;
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(13), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(arabic.isNotEmpty ? arabic : english, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
      const SizedBox(height: 4),
      Text('${row['apps_code']} · POS ${row['pos_code']} · ${row['uom']}', style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
      const Divider(height: 18),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _Metric(label: 'كمية المبيعات', value: formatQuantity(number(row, 'sold_quantity'))),
        _Metric(label: 'مخزون أول الفترة', value: formatQuantity(number(row, 'opening_stock'))),
        _Metric(label: 'مخزون آخر الفترة', value: formatQuantity(number(row, 'closing_stock'))),
        _Metric(label: 'متوسط المخزون', value: formatQuantity(number(row, 'average_stock'))),
        _Metric(label: 'دوران تقديري', value: '${number(row, 'turnover_ratio').toStringAsFixed(2)}×'),
        _Metric(label: 'أيام التغطية', value: daysCover == null ? 'غير متاح' : daysCover.toStringAsFixed(1)),
      ]),
      const SizedBox(height: 7),
      Row(children: [const Icon(Icons.calendar_month_outlined, size: 14, color: AppTheme.muted), const SizedBox(width: 5), Expanded(child: Text('اللقطات: ${row['reports_count']} · ${row['first_report_date']} إلى ${row['last_report_date']}', style: const TextStyle(fontSize: 10, color: AppTheme.muted))), if (counterReset) const Tooltip(message: 'انخفاض في العداد؛ اعتُبرت الزيادة بعد إعادة الضبط تقديرية', child: Icon(Icons.warning_amber_rounded, color: AppTheme.red, size: 18))]),
    ])));
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: AppTheme.greenLight.withOpacity(.65), borderRadius: BorderRadius.circular(10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.muted)), const SizedBox(height: 3), Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.ink))]));
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: const Color(0xFFFFF4E5), border: Border.all(color: const Color(0xFFF7C873)), borderRadius: BorderRadius.circular(12)), child: Text(text, style: const TextStyle(fontSize: 12, height: 1.55, color: Color(0xFF7A4B00))));
}
