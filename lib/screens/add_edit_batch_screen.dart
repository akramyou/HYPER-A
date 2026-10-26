import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../models/item_batch_model.dart';
import '../models/item_model.dart';
import '../services/ml_kit_service.dart';
import '../utils/expiry_parser.dart';
import '../widgets/app_theme.dart';

class AddEditBatchScreen extends StatefulWidget {
  const AddEditBatchScreen({super.key, required this.item, this.batch});
  final InventoryItem item;
  final ItemBatch? batch;
  @override
  State<AddEditBatchScreen> createState() => _AddEditBatchScreenState();
}

class _AddEditBatchScreenState extends State<AddEditBatchScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _batchNo = TextEditingController(text: widget.batch?.batchNumber ?? '');
  late final TextEditingController _quantity = TextEditingController(text: widget.batch?.quantity.toString() ?? '0');
  DateTime? _productionDate;
  DateTime? _expiryDate;
  bool _saving = false;
  bool _scanning = false;
  final _picker = ImagePicker();
  final _ml = MlKitService();

  @override
  void initState() {
    super.initState();
    _productionDate = DateTime.tryParse(widget.batch?.productionDate ?? '');
    _expiryDate = DateTime.tryParse(widget.batch?.expiryDate ?? '');
  }

  @override
  void dispose() { _batchNo.dispose(); _quantity.dispose(); super.dispose(); }

  String _display(DateTime? date) => date == null ? 'اختر التاريخ' : DateFormat('yyyy-MM-dd').format(date);

  Future<DateTime?> _pickDate(DateTime? initial) => showDatePicker(
        context: context,
        initialDate: initial ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        helpText: 'اختر التاريخ',
        cancelText: 'إلغاء',
        confirmText: 'تأكيد',
      );

  Future<void> _scanExpiry() async {
    final source = await showModalBottomSheet<ImageSource>(context: context, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('التقاط صورة بالكاميرا'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
      ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('اختيار صورة من المعرض'), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
    ])));
    if (source == null) return;
    setState(() => _scanning = true);
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 90);
      if (picked == null) return;
      final result = await _ml.recognizeText(picked.path);
      final parsed = ExpiryParser.parse(result.text);
      if (!mounted) return;
      if (parsed == null) {
        await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
          title: const Text('لم يتم العثور على تاريخ واضح'),
          content: SingleChildScrollView(child: Text('النص الذي قرأته الأداة:\n\n${result.text.isEmpty ? 'لا يوجد نص مقروء.' : result.text}\n\nيرجى اختيار تاريخ الانتهاء يدويًا.')),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسنًا'))],
        ));
        return;
      }
      // The OCR result is only a suggestion: the user must explicitly confirm it using the date picker.
      final confirmed = await showDatePicker(context: context, initialDate: parsed, firstDate: DateTime(2000), lastDate: DateTime(2100), helpText: 'تأكيد تاريخ الانتهاء المقروء: ${_display(parsed)}', confirmText: 'اعتماد التاريخ', cancelText: 'إلغاء');
      if (confirmed != null && mounted) setState(() => _expiryDate = confirmed);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(confirmed == null ? 'لم يتم اعتماد التاريخ المقروء.' : 'تم اعتماد التاريخ ${_display(confirmed)} بعد التأكيد.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر قراءة الصورة: $e')));
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_expiryDate == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى تحديد تاريخ الانتهاء.'))); return; }
    if (_productionDate != null && _productionDate!.isAfter(_expiryDate!)) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تاريخ الإنتاج لا يمكن أن يكون بعد تاريخ الانتهاء.'))); return; }
    final quantity = double.tryParse(_quantity.text.trim().replaceAll(',', ''));
    if (quantity == null || !quantity.isFinite || quantity < 0) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الكمية يجب أن تكون رقمًا غير سالب.'))); return; }
    setState(() => _saving = true);
    try {
      await DatabaseHelper.instance.saveBatch(ItemBatch(
        id: widget.batch?.id,
        itemId: widget.item.id!,
        batchNumber: _batchNo.text.trim(),
        productionDate: _productionDate == null ? null : DateFormat('yyyy-MM-dd').format(_productionDate!),
        expiryDate: DateFormat('yyyy-MM-dd').format(_expiryDate!),
        quantity: quantity,
        isActive: widget.batch?.isActive ?? true,
        createdAt: widget.batch?.createdAt,
      ));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ الدفعة: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.batch == null ? 'إضافة دفعة' : 'تعديل الدفعة')),
        body: Form(key: _form, child: ListView(padding: const EdgeInsets.all(16), children: [
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppTheme.greenLight, borderRadius: BorderRadius.circular(16)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.item.displayName, style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.greenDark, fontSize: 16)), const SizedBox(height: 5), Text('كود الصنف: ${widget.item.appsCode} · الفرع: ${widget.item.branchId}', style: const TextStyle(color: AppTheme.muted, fontSize: 12))])),
          const SizedBox(height: 18),
          TextFormField(controller: _batchNo, decoration: const InputDecoration(labelText: 'رقم الدفعة (اختياري)', prefixIcon: Icon(Icons.tag_rounded))),
          const SizedBox(height: 12),
          TextFormField(controller: _quantity, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'كمية الدفعة', prefixIcon: Icon(Icons.numbers_rounded)), validator: (v) { final n = double.tryParse((v ?? '').trim().replaceAll(',', '')); return n == null || !n.isFinite || n < 0 ? 'أدخل كمية صحيحة غير سالبة' : null; }),
          const SizedBox(height: 12),
          _DateButton(label: 'تاريخ الإنتاج', value: _display(_productionDate), icon: Icons.factory_outlined, onTap: () async { final date = await _pickDate(_productionDate); if (date != null) setState(() => _productionDate = date); }),
          const SizedBox(height: 10),
          _DateButton(label: 'تاريخ الانتهاء *', value: _display(_expiryDate), icon: Icons.event_available_outlined, onTap: () async { final date = await _pickDate(_expiryDate); if (date != null) setState(() => _expiryDate = date); }),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: _scanning ? null : _scanExpiry, icon: _scanning ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.document_scanner_outlined), label: Text(_scanning ? 'جارٍ قراءة النص...' : 'قراءة التاريخ من صورة (OCR)')),
          const SizedBox(height: 8),
          const Text('ملاحظة: قراءة OCR اقتراح أولي فقط؛ يجب تأكيد التاريخ أو إدخاله يدويًا. إصدار ML Kit هذا يدعم النص اللاتيني، وقد لا يقرأ العربية بدقة.', style: TextStyle(fontSize: 12, height: 1.5, color: AppTheme.muted)),
          const SizedBox(height: 22),
          FilledButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined), label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ الدفعة')),
        ])),
      );
}

class _DateButton extends StatelessWidget {
  const _DateButton({required this.label, required this.value, required this.icon, required this.onTap});
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: InputDecorator(decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)), child: Row(children: [Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))), const Icon(Icons.calendar_month_outlined, color: AppTheme.green)])));
}
