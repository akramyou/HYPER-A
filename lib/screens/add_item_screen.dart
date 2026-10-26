import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/item_model.dart';
import '../widgets/app_theme.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key, this.item});
  final InventoryItem? item;

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _branch = TextEditingController(text: widget.item?.branchId ?? '');
  late final TextEditingController _org = TextEditingController(text: widget.item?.orgCode ?? '');
  late final TextEditingController _apps = TextEditingController(text: widget.item?.appsCode ?? '');
  late final TextEditingController _pos = TextEditingController(text: widget.item?.posCode ?? '');
  late final TextEditingController _ar = TextEditingController(text: widget.item?.descriptionAr ?? '');
  late final TextEditingController _en = TextEditingController(text: widget.item?.descriptionEn ?? '');
  late final TextEditingController _uom = TextEditingController(text: widget.item?.uom ?? 'CTN');
  late final TextEditingController _wh = TextEditingController(text: widget.item?.whStock.toString() ?? '0');
  late final TextEditingController _br = TextEditingController(text: widget.item?.brStock.toString() ?? '0');
  late final TextEditingController _sold = TextEditingController(text: widget.item?.soldStk.toString() ?? '0');
  late final TextEditingController _location = TextEditingController(text: widget.item?.whLocCode ?? '');
  bool _flyer = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _flyer = widget.item?.isFlyer ?? false;
    _loadBranch();
  }

  Future<void> _loadBranch() async {
    final config = await DatabaseHelper.instance.getBranchConfig();
    if (!mounted || widget.item != null) return;
    if (_branch.text.isEmpty) _branch.text = config.branchId;
    if (_org.text.isEmpty) _org.text = config.orgCode;
  }

  @override
  void dispose() {
    for (final c in [_branch, _org, _apps, _pos, _ar, _en, _uom, _wh, _br, _sold, _location]) { c.dispose(); }
    super.dispose();
  }

  double _num(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '')) ?? 0;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final now = DateTime.now().toIso8601String();
      final item = InventoryItem(
        id: widget.item?.id,
        branchId: _branch.text.trim(),
        orgCode: _org.text.trim(),
        appsCode: _apps.text.trim(),
        posCode: _pos.text.trim(),
        descriptionAr: _ar.text.trim(),
        descriptionEn: _en.text.trim(),
        uom: _uom.text.trim(),
        whStock: _num(_wh),
        brStock: _num(_br),
        soldStk: _num(_sold),
        whLocCode: _location.text.trim(),
        isFlyer: _flyer,
        createdAt: widget.item?.createdAt ?? now,
        updatedAt: now,
      );
      await DatabaseHelper.instance.saveManualItem(item);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ الصنف. قد يكون الكود موجودًا بالفعل. التفاصيل: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.item == null ? 'إضافة صنف يدوي' : 'تعديل بيانات الصنف')),
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            _Section('تعريف الصنف', children: [
              _field(_branch, 'معرف الفرع BRANCH_ID', required: true),
              _field(_org, 'رمز المنظمة ORG_CODE'),
              _field(_apps, 'كود النظام APPS_CODE', required: true, enabled: widget.item == null),
              _field(_pos, 'كود نقطة البيع POS_CODE', required: true, enabled: widget.item == null),
              _field(_ar, 'اسم الصنف بالعربية'),
              _field(_en, 'اسم الصنف بالإنجليزية'),
              _field(_uom, 'وحدة القياس UOM'),
            ]),
            const SizedBox(height: 14),
            _Section('الكميات وموقع التخزين', children: [
              _field(_wh, 'مخزون المستودع WH_STOCK', numeric: true),
              _field(_br, 'مخزون الفرع BR_STOCK', numeric: true),
              _field(_sold, 'الكمية المباعة SOLD_STK', numeric: true),
              _field(_location, 'موقع التخزين WH_LOC_CODE'),
              SwitchListTile(value: _flyer, onChanged: (v) => setState(() => _flyer = v), title: const Text('الصنف ضمن النشرة الدعائية'), contentPadding: EdgeInsets.zero),
            ]),
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined), label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ الصنف')),
          ]),
        ),
      );

  Widget _field(TextEditingController controller, String label, {bool required = false, bool numeric = false, bool enabled = true}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true, signed: true) : TextInputType.text,
          decoration: InputDecoration(labelText: label),
          validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null : null,
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section(this.title, {required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE7ECE8))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.greenDark)), const SizedBox(height: 14), ...children]));
}
