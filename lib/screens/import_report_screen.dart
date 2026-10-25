import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hyper_dammam3/database/database_helper.dart';
import 'package:hyper_dammam3/models/branch_config.dart';
import 'package:hyper_dammam3/services/report_detector.dart';

class ImportReportScreen extends StatefulWidget {
  const ImportReportScreen({super.key});

  @override
  State<ImportReportScreen> createState() => _ImportReportScreenState();
}

class _ImportReportScreenState extends State<ImportReportScreen> {
  bool isLoading = false;
  bool isCheckingConfig = true;
  bool isConfigured = false;
  String message = '';
  List<String> headers = [];
  List<Map<String, dynamic>> allRows = [];
  Map<String, String> suggestedMapping = {};

  @override
  void initState() {
    super.initState();
    _checkConfigured();
  }

  Future<void> _checkConfigured() async {
    try {
      final configured = await DatabaseHelper.instance.isConfigured();
      if (!mounted) return;
      setState(() {
        isConfigured = configured;
        isCheckingConfig = false;
        if (!configured && message.isEmpty) {
          message = 'مرحباً! يرجى رفع أول تقرير لتحديد إعدادات الفرع تلقائياً.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        isCheckingConfig = false;
        message = 'تعذر قراءة إعدادات الفرع: $error';
      });
    }
  }

  Future<void> _pickFile() async {
    if (isLoading || isCheckingConfig) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'csv'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty || result.files.single.path == null) {
        return;
      }

      setState(() {
        isLoading = true;
        message = '';
        headers = [];
        allRows = [];
        suggestedMapping = {};
      });

      final selectedFile = result.files.single;
      final extension = (selectedFile.extension ?? '').toLowerCase();
      final bytes = await File(selectedFile.path!).readAsBytes();
      late final List<List<String>> tableData;

      if (extension == 'csv') {
        // UTF-8 decoding preserves Arabic headers and product descriptions.
        final csvText = utf8.decode(bytes, allowMalformed: true).replaceFirst('\uFEFF', '');
        final parsed = const CsvToListConverter(shouldParseNumbers: false).convert(csvText);
        tableData = parsed
            .map((row) => row.map((value) => value?.toString() ?? '').toList())
            .toList();
      } else if (extension == 'xlsx') {
        final workbook = Excel.decodeBytes(bytes);
        List<List<String>>? selectedRows;
        for (final sheet in workbook.tables.values) {
          final candidateRows = sheet.rows
              .map((row) => row.map((cell) => _excelCellToString(cell?.value)).toList())
              .toList();
          if (candidateRows.any((row) => row.any((cell) => cell.trim().isNotEmpty))) {
            selectedRows = candidateRows;
            break;
          }
        }
        if (selectedRows == null) {
          throw const FormatException('لم يتم العثور على ورقة عمل تحتوي على بيانات في ملف Excel.');
        }
        tableData = selectedRows;
      } else {
        throw const FormatException('صيغة الملف غير مدعومة. اختر ملف XLSX أو CSV.');
      }

      if (tableData.isEmpty) {
        throw const FormatException('الملف فارغ أو لا يحتوي على صف عناوين.');
      }

      final parsedHeaders = tableData.first.map((value) => value.trim()).toList();
      if (parsedHeaders.every((header) => header.isEmpty)) {
        throw const FormatException('لم يتم العثور على عناوين للأعمدة في الصف الأول.');
      }

      final rows = <Map<String, dynamic>>[];
      for (var i = 1; i < tableData.length; i++) {
        final row = tableData[i];
        final mappedRow = <String, dynamic>{};
        for (var j = 0; j < parsedHeaders.length && j < row.length; j++) {
          final header = parsedHeaders[j];
          if (header.isNotEmpty) mappedRow[header] = row[j];
        }
        if (mappedRow.values.any((value) => value.toString().trim().isNotEmpty)) {
          rows.add(mappedRow);
        }
      }
      if (rows.isEmpty) {
        throw const FormatException('لا توجد صفوف بيانات أسفل عناوين الأعمدة.');
      }

      final configured = await DatabaseHelper.instance.isConfigured();
      final mapping = ReportDetector.suggestMapping(parsedHeaders);
      final branchInfo = ReportDetector.detectBranchInfo(rows);

      if (!mounted) return;
      setState(() {
        headers = parsedHeaders;
        allRows = rows;
        suggestedMapping = mapping;
        isConfigured = configured;
        isLoading = false;
        if (!configured) {
          message = 'تم اكتشاف التقرير. الفرع: ${branchInfo['branch_id'] ?? 'غير واضح'} | '
              'المنظمة: ${branchInfo['org_code'] ?? 'غير واضح'}';
        } else {
          message = 'تمت قراءة الملف بنجاح. عدد صفوف البيانات: ${rows.length}';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        message = 'خطأ أثناء قراءة الملف: $error';
        isLoading = false;
      });
    }
  }

  String _excelCellToString(dynamic value) {
    if (value == null) return '';
    if (value is TextCellValue) return _excelTextSpanToString(value.value);
    if (value is FormulaCellValue) return value.formula;
    if (value is IntCellValue) return value.value.toString();
    if (value is DoubleCellValue) return value.value.toString();
    if (value is BoolCellValue) return value.value ? 'true' : 'false';
    if (value is DateCellValue) {
      return DateTime(value.year, value.month, value.day).toIso8601String().split('T').first;
    }
    if (value is DateTimeCellValue) return value.asDateTimeLocal().toIso8601String();
    if (value is TimeCellValue) return value.asDuration().toString();
    return value.toString();
  }

  // excel 4.x represents text cells as TextSpan so it can retain rich text.
  // Flatten nested spans into plain text before mapping spreadsheet columns.
  String _excelTextSpanToString(dynamic span) {
    final buffer = StringBuffer();

    void appendSpan(dynamic current) {
      final text = current.text;
      if (text is String) buffer.write(text);
      final children = current.children;
      if (children is Iterable) {
        for (final child in children) {
          appendSpan(child);
        }
      }
    }

    appendSpan(span);
    return buffer.toString();
  }

  Future<void> _saveConfigAndImport() async {
    if (allRows.isEmpty || isLoading) return;
    final hasItemCode = suggestedMapping.values.any(
      (field) => field == 'apps_code' || field == 'pos_code',
    );
    if (!hasItemCode) {
      setState(() => message = 'لم أتمكن من تحديد عمود كود الصنف تلقائياً. لم تُحفظ الإعدادات؛ تأكد من أن التقرير يحتوي على عمود كود النظام أو كود نقطة البيع.');
      return;
    }
    setState(() {
      isLoading = true;
      message = 'جارٍ حفظ إعدادات الفرع واستيراد البيانات...';
    });

    try {
      final db = DatabaseHelper.instance;
      final branchInfo = ReportDetector.detectBranchInfo(allRows);
      final branchId = branchInfo['branch_id'] ?? 'غير محدد';
      final orgCode = branchInfo['org_code'] ?? 'غير محدد';
      final config = BranchConfig(
        branchId: branchId,
        orgCode: orgCode,
        branchName: 'فرع $branchId',
        columnMapping: suggestedMapping,
        isConfigured: true,
      );
      await db.saveBranchConfig(config);
      final summary = await db.smartImport(
        rows: allRows,
        branchId: branchId,
        orgCode: orgCode,
        columnMapping: suggestedMapping,
      );
      if (!mounted) return;
      setState(() {
        isConfigured = true;
        isLoading = false;
        message = 'تم تكوين الفرع والاستيراد بنجاح:\n'
            'أصناف جديدة: ${summary['inserted']}\n'
            'أصناف محدثة (كميات فقط): ${summary['updated']}\n'
            'صفوف متخطاة: ${summary['skipped']}\n'
            'ملاحظة: تم الحفاظ على تواريخ الدفعات الموجودة كما هي.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        message = 'تعذر استيراد التقرير: $error';
      });
    }
  }

  Future<void> _importOnly() async {
    if (allRows.isEmpty || isLoading) return;
    setState(() {
      isLoading = true;
      message = 'جارٍ تحديث بيانات الأصناف...';
    });

    try {
      final db = DatabaseHelper.instance;
      final config = await db.getBranchConfig();
      final savedBranchId = await db.getConfig('branch_id');
      final savedOrgCode = await db.getConfig('org_code');
      final activeMapping = config.columnMapping.isNotEmpty ? config.columnMapping : suggestedMapping;
      final hasItemCode = activeMapping.values.any(
        (field) => field == 'apps_code' || field == 'pos_code',
      );
      if (!hasItemCode) {
        if (!mounted) return;
        setState(() {
          isLoading = false;
          message = 'لم يتم العثور على ربط صالح لكود الصنف. لم تُستورد أي بيانات؛ راجع عناوين أعمدة التقرير.';
        });
        return;
      }
      final summary = await db.smartImport(
        rows: allRows,
        branchId: config.branchId ?? savedBranchId ?? 'غير محدد',
        orgCode: config.orgCode ?? savedOrgCode ?? 'غير محدد',
        columnMapping: activeMapping,
      );
      if (!mounted) return;
      setState(() {
        isLoading = false;
        message = 'تم تحديث التقرير:\n'
            'أصناف جديدة: ${summary['inserted']}\n'
            'أصناف محدثة: ${summary['updated']}\n'
            'صفوف متخطاة: ${summary['skipped']}\n'
            '(تم الحفاظ على تواريخ الانتهاء والإنتاج كما هي)';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        message = 'تعذر تحديث التقرير: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(isCheckingConfig
              ? 'تحميل إعدادات الفرع...'
              : isConfigured
                  ? 'استيراد تقرير يومي'
                  : 'تكوين الفرع من التقرير الأول'),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ElevatedButton.icon(
                onPressed: isLoading || isCheckingConfig ? null : _pickFile,
                icon: const Icon(Icons.file_upload),
                label: Text(isLoading ? 'يرجى الانتظار...' : 'اختر ملف إكسل أو CSV'),
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              ),
              const SizedBox(height: 12),
              if (headers.isNotEmpty) ...[
                const Text('الأعمدة المكتشفة:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: headers.map((header) => Chip(label: Text(header))).toList(),
                ),
                const SizedBox(height: 12),
                if (!isConfigured && suggestedMapping.isNotEmpty) ...[
                  const Text('تطابق الأعمدة المقترح:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  ...suggestedMapping.entries.take(8).map(
                        (entry) => ListTile(
                          dense: true,
                          title: Text(entry.key),
                          subtitle: Text('← ${entry.value}'),
                        ),
                      ),
                ],
              ],
              const SizedBox(height: 16),
              if (message.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.blue.shade50,
                  child: Text(message),
                ),
              if (isLoading) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading || isCheckingConfig || allRows.isEmpty
                      ? null
                      : (isConfigured ? _importOnly : _saveConfigAndImport),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  child: Text(isConfigured ? 'استيراد وتحديث الكميات' : 'حفظ الإعدادات واستيراد البيانات'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
