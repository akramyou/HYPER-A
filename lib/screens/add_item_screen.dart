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
  late final TextEditingController _reorder = TextEditingController(text: (widget.item?.reorderLevel ?? -1) >= 0 ? widget.item!.reorderLevel.toString() : '');
  bool _flyer = false;
  bool _customUnit = false;
  final TextEditingController _customUom = TextEditingController();
  bool _saving = false;
  static const _units = <String>['CTN', 'PCS', 'EA', 'KGS', 'KG', 'G', 'LTR', 'ML', 'BOX', 'PACK', 'BAG', 'BTL', 'CAN', 'DOZ'];

  @override
  void initState() {
    super.initState();
    _flyer = widget.item?.isFlyer ?? false;
    _customUnit = _uom.text.isNotEmpty && !_units.contains(_uom.text.toUpperCase());
    if (_customUnit) _customUom.text = _uom.text;
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
    for (final c in [_branch, _org, _apps, _pos, _ar, _en, _uom, _customUom, _wh, _br, _sold, _location, _reorder]) { c.dispose(); }
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
        uom: (_customUnit ? _customUom.text : _uom.text).trim(),
        whStock: _num(_wh),
        brStock: _num(_br),
        soldStk: _num(_sold),
        whLocCode: _location.text.trim(),
        reorderLevel: _reorder.text.trim().isEmpty ? -1 : _num(_reorder),
        isFlyer: _flyer,
        extraData: widget.item?.extraData,
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
              DropdownButtonFormField<String>(
                value: _customUnit ? '__custom__' : (_units.contains(_uom.text.toUpperCase()) ? _uom.text.toUpperCase() : 'CTN'),
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'وحدة القياس UOM'),
                items: [
                  ..._units.map((unit) => DropdownMenuItem(value: unit, child: Text(unit))),
                  const DropdownMenuItem(value: '__custom__', child: Text('وحدة أخرى…')),
                ],
                onChanged: (value) => setState(() {
                  _customUnit = value == '__custom__';
                  if (!_customUnit) _uom.text = value ?? 'CTN';
                }),
              ),
              if (_customUnit) ...[
                const SizedBox(height: 10),
                _field(_customUom, 'أدخل وحدة القياس المخصصة', required: true),
              ],
            ]),
            const SizedBox(height: 14),
            _Section('الكميات وموقع التخزين', children: [
              _field(_wh, 'مخزون المستودع WH_STOCK', numeric: true),
              _field(_br, 'مخزون الفرع BR_STOCK', numeric: true),
              _field(_sold, 'الكمية المباعة SOLD_STK', numeric: true),
              _field(_location, 'موقع التخزين WH_LOC_CODE'),
              _field(_reorder, 'حد إعادة الطلب الخاص بالصنف (اختياري؛ فارغ = الافتراضي العام)', numeric: true),
              const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('عند تحديد حد خاص، تُحسب تنبيهات النقص لهذا الصنف مقارنةً به؛ وإلا يُستخدم حد الفرع من الإعدادات.', style: TextStyle(fontSize: 11, color: AppTheme.muted, height: 1.45))),
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
          validator: (v) {
            if (required && (v == null || v.trim().isEmpty)) return 'هذا الحقل مطلوب';
            if (numeric && v != null && v.trim().isNotEmpty) {
              final parsed = double.tryParse(v.trim().replaceAll(',', ''));
              if (parsed == null || !parsed.isFinite) return 'أدخل قيمة رقمية صحيحة.';
              if (identical(controller, _reorder) && parsed < 0) return 'أدخل حدًا يساوي صفرًا أو أكبر، أو اتركه فارغًا.';
            }
            return null;
          },
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
