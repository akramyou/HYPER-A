import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../database/database_helper.dart';
import '../models/item_model.dart';
import '../services/ml_kit_service.dart';
import '../utils/expiry_parser.dart';
import '../widgets/app_theme.dart';
import '../widgets/common_widgets.dart';
import 'item_detail_screen.dart';

class MlToolsScreen extends StatefulWidget {
  const MlToolsScreen({super.key});
  @override
  State<MlToolsScreen> createState() => _MlToolsScreenState();
}

class _MlToolsScreenState extends State<MlToolsScreen> {
  final _picker = ImagePicker();
  final _ml = MlKitService();
  String? _imagePath;
  bool _busy = false;
  String? _tool;
  String? _error;
  String? _recognizedText;
  DateTime? _detectedExpiry;
  List<BarcodeResult> _barcodes = [];
  List<LabelResult> _labels = [];
  InventoryItem? _matchedItem;

  Future<String?> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(context: context, builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('التقاط صورة بالكاميرا'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
      ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('اختيار صورة من المعرض'), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
    ])));
    if (source == null) return null;
    final picked = await _picker.pickImage(source: source, imageQuality: 92);
    return picked?.path;
  }

  Future<void> _runTool(String kind) async {
    setState(() { _busy = true; _tool = kind; _error = null; _recognizedText = null; _detectedExpiry = null; _barcodes = []; _labels = []; _matchedItem = null; });
    try {
      final path = await _pickImage();
      if (!mounted || path == null) return;
      setState(() => _imagePath = path);
      if (kind == 'ocr') {
        final result = await _ml.recognizeText(path);
        if (!mounted) return;
        setState(() { _recognizedText = result.text; _detectedExpiry = ExpiryParser.parse(result.text); });
      } else if (kind == 'barcode') {
        final results = await _ml.scanBarcodes(path);
        if (!mounted) return;
        InventoryItem? match;
        if (results.isNotEmpty) match = await DatabaseHelper.instance.findItemByAnyCode(results.first.value);
        if (!mounted) return;
        setState(() { _barcodes = results; _matchedItem = match; });
      } else {
        setState(() => _labels = []);
        final labels = await _ml.labelImage(path);
        if (!mounted) return;
        setState(() => _labels = labels);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر تنفيذ الأداة: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('أدوات الصورة والذكاء الاصطناعي')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppTheme.greenDark, AppTheme.green]), borderRadius: BorderRadius.circular(20)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('أدوات مساعدة للمخزون', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
            SizedBox(height: 7),
            Text('معالجة الصورة على الجهاز. النتائج مقترحات ولا تُحفظ تلقائيًا في السجلات دون مراجعة المستخدم.', style: TextStyle(color: Color(0xFFE3F4E9), fontSize: 12, height: 1.5)),
          ])),
          const SizedBox(height: 16),
          _ToolTile(icon: Icons.document_scanner_outlined, title: 'قراءة النصوص OCR', description: 'قراءة الملصق ومحاولة اقتراح تاريخ صلاحية.', onTap: _busy ? null : () => _runTool('ocr')),
          const SizedBox(height: 9),
          _ToolTile(icon: Icons.qr_code_scanner_rounded, title: 'مسح الباركود وQR', description: 'استخراج قيمة الرمز والبحث عنها في الأصناف.', onTap: _busy ? null : () => _runTool('barcode')),
          const SizedBox(height: 9),
          _ToolTile(icon: Icons.auto_awesome_mosaic_outlined, title: 'تصنيف الصورة', description: 'عرض التصنيفات العامة التي يقترحها النموذج للصورة.', onTap: _busy ? null : () => _runTool('labels')),
          if (_busy) const Padding(padding: EdgeInsets.only(top: 18), child: Center(child: Column(children: [CircularProgressIndicator(), SizedBox(height: 8), Text('جارٍ تحليل الصورة...')]))),
          if (_imagePath != null) ...[const SizedBox(height: 18), ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(File(_imagePath!), height: 190, width: double.infinity, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink()))],
          if (_error != null) ...[const SizedBox(height: 12), _ResultPanel(title: 'تعذر إكمال العملية', child: Text(_error!, style: const TextStyle(color: AppTheme.red)))],
          if (_tool == 'ocr' && !_busy) ...[
            const SizedBox(height: 12),
            _ResultPanel(title: 'النص المكتشف', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((_recognizedText ?? '').isEmpty ? 'لم يتم التعرف على نص في الصورة.' : _recognizedText!, style: const TextStyle(height: 1.5)),
              const SizedBox(height: 12),
              Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTheme.greenLight, borderRadius: BorderRadius.circular(12)), child: Text(_detectedExpiry == null ? 'لم يتم استخراج تاريخ واضح. أدخل التاريخ يدويًا في شاشة الدفعة.' : 'التاريخ المقترح: ${_detectedExpiry!.year.toString().padLeft(4, '0')}-${_detectedExpiry!.month.toString().padLeft(2, '0')}-${_detectedExpiry!.day.toString().padLeft(2, '0')} — يجب تأكيده يدويًا.', style: const TextStyle(color: AppTheme.greenDark, fontWeight: FontWeight.w700))),
            ])),
            const SizedBox(height: 8),
            const Text('قيد معروف: محرك ML Kit Text Recognition المستخدم يدعم اللاتينية وبعض الأبجديات المحددة، ولا يدرج العربية ضمن اللغات المدعومة رسميًا. لا تعتمد عليه لقراءة العربية دون اختبار محرك بديل.', style: TextStyle(fontSize: 11, color: AppTheme.muted, height: 1.5)),
          ],
          if (_tool == 'barcode' && !_busy) ...[
            const SizedBox(height: 12),
            _ResultPanel(title: 'نتائج الباركود', child: _barcodes.isEmpty ? const Text('لم يتم العثور على باركود واضح.') : Column(children: [
              ..._barcodes.map((b) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.qr_code_2_rounded, color: AppTheme.green), title: SelectableText(b.value, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('النوع: ${b.format}'))),
              if (_matchedItem != null) ListTile(leading: const Icon(Icons.inventory_2_outlined), title: Text(_matchedItem!.displayName), subtitle: Text('تمت مطابقة الرمز مع الصنف ${_matchedItem!.appsCode}'), trailing: const Icon(Icons.chevron_left_rounded), onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ItemDetailScreen(itemId: _matchedItem!.id!)))),
              if (_matchedItem == null) const Text('لم تطابق القيمة أي كود نظام أو POS مسجل في قاعدة البيانات.'),
            ])),
          ],
          if (_tool == 'labels' && !_busy) ...[
            const SizedBox(height: 12),
            _ResultPanel(
              title: 'تصنيفات الصورة',
              child: _labels.isEmpty
                  ? const Text('لم يُرجع النموذج تصنيفات واضحة.')
                  : Column(
                      children: _labels.take(12).map((label) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(child: Text(label.label)),
                            Text('${(label.confidence * 100).toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.green)),
                            const SizedBox(width: 10),
                            SizedBox(width: 80, child: LinearProgressIndicator(value: label.confidence, color: AppTheme.green, backgroundColor: AppTheme.greenLight)),
                          ],
                        ),
                      )).toList(),
                    ),
            ),
            const SizedBox(height: 8),
            const Text('تصنيف الصورة يصف محتواها بشكل عام، ولا يثبت اسم المنتج التجاري أو كوده أو تاريخ صلاحيته.', style: TextStyle(color: AppTheme.muted, fontSize: 11, height: 1.5)),
          ],
        ]),
      );
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.icon, required this.title, required this.description, required this.onTap});
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(child: ListTile(enabled: onTap != null, onTap: onTap, contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7), leading: Container(width: 46, height: 46, decoration: BoxDecoration(color: AppTheme.greenLight, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: AppTheme.green)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text(description, style: const TextStyle(fontSize: 11, height: 1.4))), trailing: const Icon(Icons.chevron_left_rounded, color: AppTheme.muted)));
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE7ECE8)), boxShadow: const [BoxShadow(color: Color(0x07000000), blurRadius: 12, offset: Offset(0, 4))]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)), const SizedBox(height: 10), child]));
}
