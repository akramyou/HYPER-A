import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../services/import_service.dart';
import '../services/report_detector.dart';
import '../widgets/app_theme.dart';
import '../widgets/common_widgets.dart';

class ImportReportScreen extends StatefulWidget {
  const ImportReportScreen({super.key, required this.onImported});
  final VoidCallback onImported;
  @override
  State<ImportReportScreen> createState() => _ImportReportScreenState();
}

class _ImportReportScreenState extends State<ImportReportScreen> {
  ParsedReport? _report;
  Map<String, int> _mapping = {};
  String? _fileName;
  bool _loading = false;
  bool _importing = false;
  ImportResult? _result;
  String? _error;
  DateTime _reportDate = DateTime.now();
  String _salesMode = 'period';

  static const _fieldInfo = <String, String>{
    'branch_id': 'معرف الفرع · BRANCH_ID',
    'org_code': 'رمز المنظمة · ORG_CODE',
    'apps_code': 'كود النظام · APPS_CODE',
    'pos_code': 'كود نقطة البيع · POS_CODE',
    'description_en': 'الوصف الإنجليزي · DESCRIPTION',
    'description_ar': 'الوصف العربي · ARB_DESC',
    'uom': 'وحدة القياس · UOM',
    'wh_stock': 'مخزون المستودع · WH_STOCK',
    'br_stock': 'مخزون الفرع · BR_STOCK',
    'sold_stk': 'المباع · SOLD_STK',
    'wh_loc_code': 'موقع التخزين · WH_LOC_CODE',
    'is_flyer': 'النشرة الدعائية · FLYER_ITEM',
    'sys_cal_qty': 'الكمية المحسوبة · SYS_CAL_QTY',
    'mod_qty': 'الكمية المعدلة · MOD_QTY',
  };

  Future<void> _pickFile() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['xlsx', 'csv'], allowMultiple: false, withData: true);
      if (!mounted || picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      final bytes = file.bytes ?? (file.path == null ? null : await File(file.path!).readAsBytes());
      if (bytes == null) throw const FormatException('تعذر قراءة الملف المحدد.');
      final ext = (file.extension ?? file.name.split('.').last).toLowerCase();
      final report = await ImportService.parseBytes(bytes, ext);
      if (!mounted) return;
      if (report.headers.isEmpty) throw const FormatException('لم يتم العثور على صف عناوين.');
      final mapping = ImportService.suggestedMapping(report.headers);
      if (!ReportDetector.looksLikeInventoryReport(report.headers)) {
        setState(() => _error = 'لم نتعرف على التقرير بالكامل. راجع تعيين الأعمدة يدويًا قبل الاستيراد.');
      }
      setState(() { _report = report; _mapping = mapping; _fileName = file.name; });
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر فتح الملف: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _mappingValid => ['branch_id', 'apps_code', 'pos_code', 'wh_stock', 'br_stock', 'sold_stk'].every((key) => _mapping.containsKey(key));

  Future<void> _import() async {
    final report = _report;
    if (report == null) return;
    if (!_mappingValid) {
      setState(() => _error = 'يجب تعيين أعمدة الفرع وكود النظام وPOS ومخزون المستودع والفرع والمباع.');
      return;
    }
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('تأكيد استيراد التقرير'),
      content: Text('سيتم فحص ${report.rows.length} صفًا. الأصناف الموجودة ستتحدث كمياتها فقط (المستودع والفرع والمباع)، ولن يتم حذف أو تغيير تواريخ الدفعات المسجلة. هل تريد المتابعة؟'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('مراجعة')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('استيراد'))],
    ));
    if (!mounted || confirmed != true) return;
    setState(() { _importing = true; _error = null; });
    try {
      final result = await DatabaseHelper.instance.importRows(headers: report.headers, rows: report.rows, mapping: _mapping, sourceName: _fileName ?? '', sourceFormat: report.sourceFormat, sourceFingerprint: report.fingerprint, reportDate: _reportDate, salesMode: _salesMode);
      if (!mounted) return;
      setState(() => _result = result);
      widget.onImported();
    } catch (e) {
      if (mounted) setState(() => _error = 'فشل الاستيراد، ولم يتم اعتماد النتيجة: $e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 28), children: [
    Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE7ECE8))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('الاستيراد الذكي للتقرير اليومي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      const Text('يدعم Excel XLSX وCSV. يتعرف على أعمدة تقرير DAMMAM-3، ويحدّث الكميات فقط للصنف الموجود مع إبقاء جميع دفعات الصلاحية محفوظة.', style: TextStyle(height: 1.5, color: AppTheme.muted, fontSize: 12)),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _loading || _importing ? null : _pickFile, icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.file_open_rounded), label: Text(_loading ? 'جارٍ قراءة الملف...' : 'اختيار ملف XLSX أو CSV'))),
      if (_fileName != null) ...[const SizedBox(height: 12), Row(children: [const Icon(Icons.description_outlined, color: AppTheme.green), const SizedBox(width: 8), Expanded(child: Text(_fileName!, style: const TextStyle(fontWeight: FontWeight.w700))), Text('${_report?.rows.length ?? 0} صف', style: const TextStyle(color: AppTheme.muted, fontSize: 12))])],
    ])),
    if (_fileName != null) ...[
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('إعدادات اللقطة التاريخية', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        const SizedBox(height: 4),
        const Text('تُحفظ نسخة من كميات الأصناف مع كل تقرير حتى يمكن حساب حركة المخزون. اختر تاريخ التقرير وطريقة تفسير SOLD_STK بدقة.', style: TextStyle(fontSize: 12, color: AppTheme.muted, height: 1.45)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _importing ? null : () async {
            final pickedDate = await showDatePicker(context: context, initialDate: _reportDate, firstDate: DateTime(2000), lastDate: DateTime(2100), helpText: 'تاريخ التقرير كما في المصدر');
            if (pickedDate != null && mounted) setState(() => _reportDate = pickedDate);
          },
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text('تاريخ التقرير: ${_dateText(_reportDate)}'),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _salesMode,
          decoration: const InputDecoration(labelText: 'طريقة قراءة SOLD_STK'),
          items: const [
            DropdownMenuItem(value: 'period', child: Text('مبيعات الفترة في التقرير الحالي')),
            DropdownMenuItem(value: 'cumulative', child: Text('عداد تراكمي؛ احسب الفرق عن التقرير السابق')),
          ],
          onChanged: _importing ? null : (value) => setState(() => _salesMode = value ?? 'period'),
        ),
        const SizedBox(height: 8),
        Text(_salesMode == 'period'
            ? 'يُستخدم SOLD_STK كما ورد في هذا التقرير كمبيعات للفترة. لا تختَر هذا الوضع إلا إذا كان المصدر يوضح أن العمود يمثل مبيعات الفترة.'
            : 'يُقارن SOLD_STK بالتقرير السابق للصنف نفسه. أول قراءة تُسجّل كخط أساس ولا تُحسب مبيعات؛ انخفاض العداد يُعلَّم كإعادة ضبط محتملة.',
            style: const TextStyle(fontSize: 11, color: AppTheme.muted, height: 1.5)),
      ]))),
    ],
    if (_error != null) ...[const SizedBox(height: 12), _MessageCard(message: _error!, color: AppTheme.red, icon: Icons.error_outline_rounded)],
    if (_result != null) ...[const SizedBox(height: 12), _resultCard(_result!)],
    if (_report != null) ...[
      const SizedBox(height: 18),
      SectionHeading('تطابق الأعمدة', subtitle: 'يمكن تعديل أي تطابق قبل الحفظ'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              ..._fieldInfo.entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Text(entry.value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 6,
                          child: DropdownButtonFormField<int?>(
                            value: _mapping[entry.key],
                            isExpanded: true,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            items: [
                              const DropdownMenuItem<int?>(value: null, child: Text('غير محدد', overflow: TextOverflow.ellipsis)),
                              ...List.generate(
                                _report!.headers.length,
                                (i) => DropdownMenuItem<int?>(
                                  value: i,
                                  child: Text('${_colLetter(i)} · ${_report!.headers[i]}', overflow: TextOverflow.ellipsis),
                                ),
                              ),
                            ],
                            onChanged: (value) => setState(() {
                              if (value == null) {
                                _mapping.remove(entry.key);
                              } else {
                                _mapping[entry.key] = value;
                              }
                            }),
                          ),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 5),
              _MessageCard(
                message: _mappingValid ? 'الحقول الأساسية محددة وجاهزة للاستيراد.' : 'بعض الحقول الأساسية غير محددة. راجع التطابق قبل الاستيراد.',
                color: _mappingValid ? AppTheme.green : const Color(0xFFB54708),
                icon: _mappingValid ? Icons.check_circle_outline : Icons.info_outline,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 18),
      SectionHeading('معاينة البيانات', subtitle: 'أول 5 صفوف من الملف قبل الاستيراد'),
      Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: MaterialStatePropertyAll(AppTheme.greenLight),
            columns: _report!.headers.take(7).map((header) => DataColumn(
              label: Text(header, style: const TextStyle(fontWeight: FontWeight.w800)),
            )).toList(),
            rows: _report!.rows.take(5).map((row) => DataRow(
              cells: List.generate(
                _report!.headers.length.clamp(0, 7).toInt(),
                (i) => DataCell(SizedBox(
                  width: 120,
                  child: Text(
                    i < row.length ? '${row[i] ?? ''}' : '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
              ),
            )).toList(),
          ),
        ),
      ),
      const SizedBox(height: 18),
      SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _importing || !_mappingValid ? null : _import, icon: _importing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_alt_rounded), label: Text(_importing ? 'جارٍ تحديث قاعدة البيانات...' : 'اعتماد الاستيراد'))),
      const SizedBox(height: 10),
      const Text('ضمانات الاستيراد: لا يتم حذف الدفعات. لا يتم استبدال تواريخ الإنتاج أو الانتهاء. لا تُدمج الأصناف إلا عبر المفتاح (APPS_CODE + POS_CODE + BRANCH_ID). القيم السالبة للمخزون مسموح بها لأنها قد تظهر في التقرير الأصلي.', style: TextStyle(fontSize: 11, height: 1.5, color: AppTheme.muted)),
    ],
  ]);

  Widget _resultCard(ImportResult result) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: result.duplicateReport ? const Color(0xFFFFF4E5) : AppTheme.greenLight, borderRadius: BorderRadius.circular(18)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(result.duplicateReport ? 'لم يُكرر الاستيراد' : 'اكتمل الاستيراد وحُفظت اللقطة التاريخية', style: TextStyle(fontWeight: FontWeight.w900, color: result.duplicateReport ? const Color(0xFFB54708) : AppTheme.greenDark, fontSize: 16)),
    const SizedBox(height: 10),
    if (result.duplicateReport) const Text('هذا الملف سبق استيراده للتاريخ نفسه. لم تُضف بيانات جديدة ولم يتضاعف سجل المبيعات.', style: TextStyle(fontSize: 12, height: 1.5)),
    if (!result.duplicateReport) Wrap(spacing: 8, runSpacing: 8, children: [
      _ResultChip('أضيف', result.added, AppTheme.green),
      _ResultChip('حُدّث', result.updated, const Color(0xFF175CD3)),
      _ResultChip('تُجاوز', result.skipped, const Color(0xFFB54708)),
      _ResultChip('لقطات محفوظة', result.snapshotsSaved, const Color(0xFF067647)),
    ]),
    const SizedBox(height: 10),
    Text('الفرع: ${result.branchId.isEmpty ? 'غير محدد' : result.branchId} · المنظمة: ${result.orgCode.isEmpty ? 'غير محددة' : result.orgCode}', style: const TextStyle(fontSize: 12, color: AppTheme.greenDark)),
    if (!result.duplicateReport && (result.counterResetCount > 0 || result.cumulativeBaselineCount > 0)) ...[
      const SizedBox(height: 6),
      Text('خطوط أساس للعداد: ${result.cumulativeBaselineCount} · انخفاضات/إعادة ضبط للعداد: ${result.counterResetCount}', style: const TextStyle(fontSize: 11, color: Color(0xFFB54708))),
    ],
  ]));

  String _dateText(DateTime value) => '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String _colLetter(int i) {
    var n = i + 1;
    var s = '';
    while (n > 0) { final r = (n - 1) % 26; s = String.fromCharCode(65 + r) + s; n = (n - 1) ~/ 26; }
    return s;
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, required this.color, required this.icon});
  final String message;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(.25))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 19, color: color), const SizedBox(width: 8), Expanded(child: Text(message, style: TextStyle(color: color, fontSize: 12, height: 1.5, fontWeight: FontWeight.w600)))]));
}

class _ResultChip extends StatelessWidget {
  const _ResultChip(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)), child: RichText(text: TextSpan(style: const TextStyle(fontSize: 12, color: AppTheme.ink), children: [TextSpan(text: '$label: '), TextSpan(text: value.toString(), style: TextStyle(fontWeight: FontWeight.w900, color: color))])));
}
