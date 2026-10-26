import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/alerts_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/import_report_screen.dart';
import 'screens/items_screen.dart';
import 'screens/ml_tools_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/sales_performance_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HyperInventoryApp());
}

class HyperInventoryApp extends StatelessWidget {
  const HyperInventoryApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'هايبر | إدارة المخزون والصلاحية',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child ?? const SizedBox.shrink()),
        home: const AppShell(),
      );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  int _revision = 0;

  void _refreshAll() => setState(() => _revision++);

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) _refreshAll();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardScreen(key: ValueKey('dashboard-$_revision'), onItems: () => setState(() => _index = 1), onAlerts: () => setState(() => _index = 2), onImport: () => setState(() => _index = 3)),
      ItemsScreen(key: ValueKey('items-$_revision'), onChanged: _refreshAll),
      AlertsScreen(key: ValueKey('alerts-$_revision')),
      ImportReportScreen(key: ValueKey('import-$_revision'), onImported: _refreshAll),
    ];
    const titles = ['الرئيسية', 'الأصناف', 'التنبيهات', 'استيراد التقرير'];
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 14,
        title: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(9), child: Image.asset('assets/images/hyper_logo.png', width: 40, height: 40, fit: BoxFit.cover)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titles[_index], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const Text('إدارة المخزون وتواريخ الصلاحية', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: Color(0xFF667085))),
          ])),
        ]),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'المزيد',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              switch (value) {
                case 'analytics': _open(const AnalyticsScreen()); break;
                case 'reports': _open(const ReportsScreen()); break;
                case 'sales': _open(const SalesPerformanceScreen()); break;
                case 'ml': _open(const MlToolsScreen()); break;
                case 'settings': _open(const SettingsScreen()); break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'analytics', child: ListTile(leading: Icon(Icons.insights_rounded), title: Text('التحليل البياني'), dense: true)),
              PopupMenuItem(value: 'reports', child: ListTile(leading: Icon(Icons.description_outlined), title: Text('التقارير والفلاتر المتقدمة'), dense: true)),
              PopupMenuItem(value: 'sales', child: ListTile(leading: Icon(Icons.query_stats_rounded), title: Text('حركة المبيعات ودوران الأصناف'), dense: true)),
              PopupMenuItem(value: 'ml', child: ListTile(leading: Icon(Icons.document_scanner_outlined), title: Text('أدوات الصورة والذكاء الاصطناعي'), dense: true)),
              PopupMenuItem(value: 'settings', child: ListTile(leading: Icon(Icons.settings_outlined), title: Text('الإعدادات والنسخ الاحتياطي'), dense: true)),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2_rounded), label: 'الأصناف'),
          NavigationDestination(icon: Icon(Icons.notifications_none_rounded), selectedIcon: Icon(Icons.notifications_active_rounded), label: 'التنبيهات'),
          NavigationDestination(icon: Icon(Icons.upload_file_outlined), selectedIcon: Icon(Icons.upload_file_rounded), label: 'الاستيراد'),
        ],
      ),
    );
  }
}
