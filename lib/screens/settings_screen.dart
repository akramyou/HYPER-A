import 'dart:convert';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database_helper.dart';
import '../models/branch_config.dart';
import '../widgets/app_theme.dart';
import '../widgets/common_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _form = GlobalKey<FormState>();
  final _branchId = TextEditingController();
  final _orgCode = TextEditingController();
  final _branchName = TextEditingController();
  final _minStock = TextEditingController(text: '5');
  Map<String, bool> _notifications = {};
  bool _loading = true;
  bool _busy = false;
  List<Map<String, Object?>> _audit = [];
  Map<String, int> _columnMapping = <String, int>{};
  bool _notificationsEnabled = true;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _branchId.dispose(); _orgCode.dispose(); _branchName.dispose(); _minStock.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final db = DatabaseHelper.instance;
      final config = await db.getBranchConfig();
      final settings = await db.getNotificationSettings();
      final audit = await db.getAuditLog(limit: 12);
      if (!mounted) return;
      _branchId.text = config.branchId;
      _orgCode.text = config.orgCode;
      _branchName.text = config.branchName;
      _minStock.text = config.defaultMinStock.toString();
      if (mounted) setState(() { _notifications = settings; _audit = audit; _columnMapping = config.columnMapping; _notificationsEnabled = config.notificationsEnabled; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveConfig() async {
    if (!_form.currentState!.validate()) return;
    final threshold = double.tryParse(_minStock.text.trim());
    if (threshold == null || !threshold.isFinite || threshold < 0) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل حدًا أدنى صحيحًا للمخزون.'))); return; }
    setState(() => _busy = true);
    try {
      await DatabaseHelper.instance.saveBranchConfig(BranchConfig(branchId: _branchId.text.trim(), orgCode: _orgCode.text.trim(), branchName: _branchName.text.trim(), isConfigured: _branchId.text.trim().isNotEmpty, notificationsEnabled: _notificationsEnabled, defaultMinStock: threshold, columnMapping: _columnMapping));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الإعدادات.')));
      if (mounted) await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ الإعدادات: $e')));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _setGlobalNotifications(bool value) async {
    final previous = _notificationsEnabled;
    setState(() => _notificationsEnabled = value);
    try {
      await DatabaseHelper.instance.saveBranchConfig(BranchConfig(
        branchId: _branchId.text.trim(),
        orgCode: _orgCode.text.trim(),
        branchName: _branchName.text.trim(),
        isConfigured: _branchId.text.trim().isNotEmpty,
        notificationsEnabled: value,
        defaultMinStock: double.tryParse(_minStock.text.trim()) ?? 5,
        columnMapping: _columnMapping,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _notificationsEnabled = previous);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ إعداد التنبيهات: $e')));
    }
  }

  Future<void> _toggle(String key, bool value) async {
    final previous = Map<String, bool>.from(_notifications);
    final next = Map<String, bool>.from(_notifications)..[key] = value;
    setState(() => _notifications = next);
    try {
      await DatabaseHelper.instance.saveNotificationSettings(next);
    } catch (e) {
      if (!mounted) return;
      setState(() => _notifications = previous);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ إعداد التنبيه: $e')));
    }
  }

  Future<void> _exportBackup() async {
    setState(() => _busy = true);
    try {
      final backup = await DatabaseHelper.instance.exportBackup();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/hyper_inventory_backup_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(backup), flush: true);
      await Share.shareXFiles([XFile(file.path)], subject: 'نسخة احتياطية من هايبر', text: 'نسخة احتياطية محلية لبيانات المخزون والدفعات والإعدادات. احتفظ بها في مكان آمن.');
      await DatabaseHelper.instance.logAction('backup_export', 'إنشاء ملف نسخة احتياطية');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر إنشاء النسخة الاحتياطية: $e')));
    } finally { if (mounted) { setState(() => _busy = false); await _load(); } }
  }

  Future<void> _restoreBackup() async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('استعادة نسخة احتياطية'),
      content: const Text('ستستبدل بيانات التطبيق الحالية بالبيانات الموجودة في ملف النسخة الاحتياطية. صدّر نسخة من الوضع الحالي أولًا إذا كنت تحتاج إليها.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('متابعة'))],
    ));
    if (!mounted || confirmed != true) return;
    setState(() => _busy = true);
    try {
      final pick = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['json'], withData: true);
      if (!mounted || pick == null || pick.files.isEmpty) return;
      final f = pick.files.single;
      final bytes = f.bytes ?? (f.path == null ? null : await File(f.path!).readAsBytes());
      if (bytes == null) throw const FormatException('تعذر قراءة الملف.');
      final parsed = jsonDecode(utf8.decode(bytes));
      if (parsed is! Map<String, dynamic>) throw const FormatException('تنسيق النسخة الاحتياطية غير صحيح.');
      const requiredTables = ['app_config', 'items', 'item_batches', 'notification_settings', 'audit_log'];
      if (requiredTables.any((key) => parsed[key] is! List)) throw const FormatException('النسخة الاحتياطية غير مكتملة؛ لم يتم تغيير البيانات الحالية.');
      await DatabaseHelper.instance.restoreBackup(parsed);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت استعادة النسخة الاحتياطية.')));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشلت الاستعادة: $e')));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    return Scaffold(appBar: AppBar(title: const Text('الإعدادات والنسخ الاحتياطي')), body: ListView(padding: const EdgeInsets.all(16), children: [
      _section('بيانات الفرع', 'يكتشف التطبيق المعرف من التقرير الأول، ويمكن تعديل الاسم والحد الأدنى يدويًا.', Form(key: _form, child: Column(children: [
        TextFormField(controller: _branchId, decoration: const InputDecoration(labelText: 'معرف الفرع BRANCH_ID'), validator: (v) => (v == null || v.trim().isEmpty) ? 'معرف الفرع مطلوب' : null),
        const SizedBox(height: 10),
        TextFormField(controller: _orgCode, decoration: const InputDecoration(labelText: 'رمز المنظمة ORG_CODE')),
        const SizedBox(height: 10),
        TextFormField(controller: _branchName, decoration: const InputDecoration(labelText: 'اسم الفرع (اختياري)')),
        const SizedBox(height: 10),
        TextFormField(controller: _minStock, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'حد المخزون المنخفض الافتراضي'), validator: (v) => double.tryParse((v ?? '').trim()) == null ? 'أدخل رقمًا صحيحًا' : null),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _busy ? null : _saveConfig, icon: const Icon(Icons.save_outlined), label: const Text('حفظ إعدادات الفرع'))),
      ]))),
      const SizedBox(height: 16),
      _section('أنواع التنبيه', 'تظهر التنبيهات بحسب كل دفعة نشطة؛ لا تتأثر بتحديث كميات التقرير اليومي.', Column(children: [
        _SettingSwitch(title: 'تفعيل جميع التنبيهات', value: _notificationsEnabled, onChanged: _setGlobalNotifications),
        const Divider(height: 8),
        _SettingSwitch(title: 'الدفعات المنتهية', value: _notifications['expired_enabled'] ?? true, onChanged: (v) => _toggle('expired_enabled', v)),
        _SettingSwitch(title: 'أقل من أسبوع', value: _notifications['less_than_week_enabled'] ?? true, onChanged: (v) => _toggle('less_than_week_enabled', v)),
        _SettingSwitch(title: 'أقل من شهر', value: _notifications['less_than_month_enabled'] ?? true, onChanged: (v) => _toggle('less_than_month_enabled', v)),
        _SettingSwitch(title: 'من شهر إلى شهرين', value: _notifications['one_to_two_months_enabled'] ?? true, onChanged: (v) => _toggle('one_to_two_months_enabled', v)),
        _SettingSwitch(title: 'من شهرين إلى 3 أشهر', value: _notifications['two_to_three_months_enabled'] ?? true, onChanged: (v) => _toggle('two_to_three_months_enabled', v)),
        _SettingSwitch(title: 'المخزون المنخفض', value: _notifications['low_stock_enabled'] ?? true, onChanged: (v) => _toggle('low_stock_enabled', v)),
      ])),
      const SizedBox(height: 16),
      _section('حماية البيانات', 'يعمل النظام محليًا دون الحاجة إلى حساب أو اتصال دائم بالإنترنت. النسخ الاحتياطي لا يُرفع تلقائيًا لأي خادم.', Column(children: [
        SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _busy ? null : _exportBackup, icon: const Icon(Icons.backup_outlined), label: const Text('تصدير نسخة احتياطية JSON'))),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _busy ? null : _restoreBackup, icon: const Icon(Icons.restore_rounded), label: const Text('استعادة نسخة احتياطية'))),
        if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
      ])),
      const SizedBox(height: 16),
      _section('سجل العمليات', 'آخر ${_audit.length} عملية محفوظة محليًا.', Column(children: _audit.isEmpty ? [const Text('لا توجد عمليات مسجلة بعد.')] : _audit.map((entry) => ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.history_rounded, color: AppTheme.muted),
        title: Text((entry['action'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        subtitle: Text((entry['details'] ?? '').toString(), style: const TextStyle(fontSize: 11)),
        trailing: Text((entry['created_at'] ?? '').toString().split('T').first, style: const TextStyle(fontSize: 10, color: AppTheme.muted)),
      )).toList())),
      const SizedBox(height: 16),
      Card(color: AppTheme.greenLight, child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [const Icon(Icons.verified_user_outlined, color: AppTheme.green), const SizedBox(width: 10), const Expanded(child: Text('حافظ على ملفات النسخ الاحتياطية في مكان آمن. لا تتم مزامنة البيانات تلقائيًا بين الأجهزة.', style: TextStyle(fontSize: 12, color: AppTheme.greenDark, height: 1.5)))]))),
      const SizedBox(height: 20),
    ]));
  }

  Widget _section(String title, String subtitle, Widget child) => Card(margin: const EdgeInsets.only(bottom: 2), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.ink)), const SizedBox(height: 5), Text(subtitle, style: const TextStyle(color: AppTheme.muted, fontSize: 12, height: 1.5)), const SizedBox(height: 14), child])));
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({required this.title, required this.value, required this.onChanged});
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)), value: value, activeColor: AppTheme.green, onChanged: onChanged);
}
