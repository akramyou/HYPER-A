import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/branch_config.dart';
import '../widgets/app_theme.dart';
import '../widgets/common_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onItems, required this.onAlerts, required this.onImport});
  final VoidCallback onItems;
  final VoidCallback onAlerts;
  final VoidCallback onImport;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashboardData> _load() async {
    final db = DatabaseHelper.instance;
    final config = await db.getBranchConfig();
    final stats = await db.getDashboardStats(lowStockThreshold: config.defaultMinStock);
    final batches = await db.getJoinedBatches();
    final upcoming = batches.where((row) {
      final expiry = DateTime.tryParse((row['expiry_date'] ?? '').toString());
      if (expiry == null) return false;
      final now = DateTime.now();
      final days = DateTime(expiry.year, expiry.month, expiry.day).difference(DateTime(now.year, now.month, now.day)).inDays;
      return days >= 0 && days <= 30;
    }).take(5).toList();
    return _DashboardData(config, stats, upcoming);
  }

  Future<void> _refresh() async => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) => FutureBuilder<_DashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const LoadingView();
          if (snapshot.hasError) return Center(child: Text('تعذر تحميل لوحة التحكم: ${snapshot.error}'));
          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _welcomeCard(data.config),
                const SizedBox(height: 22),
                SectionHeading('ملخص المخزون', subtitle: 'ملخص مباشر من قاعدة البيانات المحلية'),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.38,
                  children: [
                    StatCard(title: 'إجمالي الأصناف', value: data.stats.items.toString(), icon: Icons.inventory_2_outlined, color: AppTheme.green, onTap: widget.onItems),
                    StatCard(title: 'دفعات منتهية', value: data.stats.expired.toString(), icon: Icons.error_outline_rounded, color: AppTheme.red, onTap: widget.onAlerts),
                    StatCard(title: 'تنتهي خلال 7 أيام', value: data.stats.within7.toString(), icon: Icons.schedule_rounded, color: const Color(0xFFB54708), onTap: widget.onAlerts),
                    StatCard(title: 'مخزون منخفض', value: data.stats.lowStock.toString(), icon: Icons.inventory_outlined, color: const Color(0xFF946200), onTap: widget.onAlerts),
                  ],
                ),
                const SizedBox(height: 22),
                SectionHeading('إجراءات سريعة'),
                Row(children: [
                  Expanded(child: _QuickAction(icon: Icons.upload_file_rounded, title: 'استيراد تقرير', subtitle: 'تحديث الكميات', color: AppTheme.green, onTap: widget.onImport)),
                  const SizedBox(width: 10),
                  Expanded(child: _QuickAction(icon: Icons.notifications_active_outlined, title: 'مراجعة التنبيهات', subtitle: 'الدفعات الحرجة', color: AppTheme.red, onTap: widget.onAlerts)),
                ]),
                const SizedBox(height: 22),
                SectionHeading('دفعات تقترب من الانتهاء', subtitle: 'أقرب خمس دفعات خلال 30 يومًا', trailing: TextButton(onPressed: widget.onAlerts, child: const Text('عرض الكل'))),
                if (data.upcoming.isEmpty)
                  const Card(child: Padding(padding: EdgeInsets.all(20), child: Row(children: [Icon(Icons.check_circle_outline, color: AppTheme.green), SizedBox(width: 10), Expanded(child: Text('لا توجد دفعات مسجلة تنتهي خلال 30 يومًا.'))])))
                else
                  ...data.upcoming.map((row) => _UpcomingCard(row: row)),
                const SizedBox(height: 12),
                if (data.stats.items == 0)
                  Card(
                    color: AppTheme.greenLight,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('ابدأ باستيراد تقرير المبيعات', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.greenDark)),
                        const SizedBox(height: 6),
                        const Text('سيكتشف النظام رقم الفرع ورمز المنظمة من التقرير، ثم يهيّئ سجل الأصناف تلقائيًا.'),
                        const SizedBox(height: 12),
                        FilledButton.icon(onPressed: widget.onImport, icon: const Icon(Icons.upload_file), label: const Text('اختيار تقرير XLSX أو CSV')),
                      ]),
                    ),
                  ),
              ],
            ),
          );
        },
      );

  Widget _welcomeCard(BranchConfig config) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppTheme.greenDark, AppTheme.green]), borderRadius: BorderRadius.circular(22)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('مرحبًا بك في هايبر', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 6),
            Text(config.isConfigured ? 'الفرع: ${config.branchId}  •  المنظمة: ${config.orgCode}' : 'نظام محلي لإدارة المخزون والصلاحية', style: const TextStyle(color: Color(0xFFE3F4E9), fontSize: 12)),
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.white.withOpacity(.14), borderRadius: BorderRadius.circular(30)), child: const Text('يعمل محليًا على هذا الجهاز', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
          ])),
          const SizedBox(width: 12),
          Container(width: 92, height: 92, padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.asset('assets/images/hyper_logo.png', fit: BoxFit.contain))),
        ]),
      );
}

class _DashboardData {
  const _DashboardData(this.config, this.stats, this.upcoming);
  final BranchConfig config;
  final DashboardStats stats;
  final List<Map<String, Object?>> upcoming;
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE7ECE8))), child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: color)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(fontSize: 10, color: AppTheme.muted))])),
        ])),
      );
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.row});
  final Map<String, Object?> row;
  @override
  Widget build(BuildContext context) {
    final expiry = (row['expiry_date'] ?? '').toString();
    final date = DateTime.tryParse(expiry);
    final now = DateTime.now();
    final days = date == null ? null : DateTime(date.year, date.month, date.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    final ar = (row['item_description_ar'] ?? '').toString();
    final en = (row['item_description_en'] ?? '').toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: AppTheme.gold.withOpacity(.22), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.hourglass_bottom_rounded, color: Color(0xFF8A6B00))),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(ar.isNotEmpty ? ar : en, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text('انتهاء الصلاحية: $expiry', style: const TextStyle(fontSize: 11, color: AppTheme.muted))])),
        const SizedBox(width: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: AppTheme.gold.withOpacity(.20), borderRadius: BorderRadius.circular(20)), child: Text(days == null ? '—' : '$days يوم', style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF8A6B00), fontSize: 11))),
      ])),
    );
  }
}
