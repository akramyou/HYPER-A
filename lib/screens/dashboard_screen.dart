import 'package:flutter/material.dart';
import 'package:hyper_dammam3/database/database_helper.dart';
import 'package:hyper_dammam3/screens/items_screen.dart';
import 'package:hyper_dammam3/screens/alerts_screen.dart';
import 'package:hyper_dammam3/screens/reports_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int totalItems = 0;
  int expiredCount = 0;
  int expiringSoonCount = 0;
  int lowStockCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final db = DatabaseHelper.instance;
      final nextTotalItems = await db.getItemCount();
      final nextExpiredCount = (await db.getExpiredBatches()).length;
      final nextExpiringSoonCount = (await db.getExpiringBatches(days: 90)).length;
      final nextLowStockCount = (await db.getLowStockItems()).length;
      if (!mounted) return;
      setState(() {
        totalItems = nextTotalItems;
        expiredCount = nextExpiredCount;
        expiringSoonCount = nextExpiringSoonCount;
        lowStockCount = nextLowStockCount;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديث ملخص المخزون. حاول مرة أخرى.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8F4),
        appBar: AppBar(
          title: const Text(
            'لوحة التحكم',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF203B27)),
          ),
          actions: [
            IconButton(
              tooltip: 'تحديث البيانات',
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2F6B3A)),
              onPressed: _loadStats,
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _loadStats,
          color: const Color(0xFF2F6B3A),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                sliver: SliverToBoxAdapter(child: _buildBrandHeader()),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      const Icon(Icons.space_dashboard_rounded, color: Color(0xFF2F6B3A), size: 21),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'ملخص المخزون',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF203B27)),
                        ),
                      ),
                      if (_isLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7F2E5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'نظرة عامة',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2F6B3A)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
                sliver: SliverGrid(
                  delegate: SliverChildListDelegate([
                    _buildStatCard('إجمالي الأصناف', totalItems.toString(), const Color(0xFF3166A8), Icons.inventory_2_outlined),
                    _buildStatCard('منتهية الصلاحية', expiredCount.toString(), const Color(0xFFC73D3D), Icons.warning_amber_rounded),
                    _buildStatCard('قريبة الانتهاء', expiringSoonCount.toString(), const Color(0xFFC47A16), Icons.event_busy_outlined),
                    _buildStatCard('منخفض المخزون', lowStockCount.toString(), const Color(0xFF7A5AB6), Icons.inventory_outlined),
                  ]),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.08,
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF2F6B3A),
          unselectedItemColor: const Color(0xFF7C837B),
          backgroundColor: Colors.white,
          onTap: (index) {
            if (index == 1) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ItemsScreen()));
            } else if (index == 2) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertsScreen()));
            } else if (index == 3) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()));
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'الرئيسية'),
            BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), label: 'الأصناف'),
            BottomNavigationBarItem(icon: Icon(Icons.notifications_active_outlined), label: 'التنبيهات'),
            BottomNavigationBarItem(icon: Icon(Icons.assessment_outlined), label: 'التقارير'),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ItemsScreen())),
          backgroundColor: const Color(0xFF2F6B3A),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('إضافة صنف', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF6E9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD8E6D2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'مرحباً بك في',
                  style: TextStyle(fontSize: 13, color: Color(0xFF5F6F5C), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                const Text(
                  'الهايبر',
                  style: TextStyle(fontSize: 26, height: 1.2, fontWeight: FontWeight.w900, color: Color(0xFF24532F)),
                ),
                const SizedBox(height: 7),
                const Text(
                  'إدارة المخزون وتواريخ الصلاحية بسهولة',
                  style: TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF4D5F4A)),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_outlined, size: 15, color: Color(0xFF2F6B3A)),
                      SizedBox(width: 5),
                      Text('نظام إدارة المخزون', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2F6B3A))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 98,
            height: 98,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE1E8DC)),
              boxShadow: const [
                BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 4)),
              ],
            ),
            child: Image.asset(
              'assets/images/hyper_logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.storefront_rounded, size: 46, color: Color(0xFF2F6B3A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE5E9E1)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: color.withOpacity(0.10), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 25),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4D554B)),
            ),
          ],
        ),
      ),
    );
  }
}
