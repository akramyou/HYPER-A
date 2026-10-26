import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

import 'report_detector.dart';

class ParsedReport {
  const ParsedReport({required this.headers, required this.rows, required this.sheetName, required this.sourceFormat, required this.fingerprint});
  final List<String> headers;
  final List<List<dynamic>> rows;
  final String sheetName;
  final String sourceFormat;
  final String fingerprint;
}

class ImportService {
  static Future<ParsedReport> parseBytes(Uint8List bytes, String extension) async {
    final ext = extension.toLowerCase().replaceAll('.', '');
    if (ext == 'csv' || ext == 'txt') return _parseCsv(bytes);
    if (ext == 'xlsx') return _parseXlsx(bytes);
    throw FormatException('صيغة الملف غير مدعومة: .$ext. الصيغ المدعومة هي XLSX وCSV.');
  }

  static ParsedReport _parseCsv(Uint8List bytes) {
    var text = utf8.decode(bytes, allowMalformed: true).replaceFirst('\uFEFF', '');
    // Handle common UTF-16 CSV exports when a BOM is present.
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      text = String.fromCharCodes([for (var i = 2; i + 1 < bytes.length; i += 2) bytes[i] | (bytes[i + 1] << 8)]);
    } else if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      text = String.fromCharCodes([for (var i = 2; i + 1 < bytes.length; i += 2) (bytes[i] << 8) | bytes[i + 1]]);
    }
    final parsed = const CsvToListConverter(shouldParseNumbers: false, eol: '\n').convert(text);
    if (parsed.isEmpty) throw const FormatException('الملف لا يحتوي على بيانات.');
    final headers = parsed.first.map((e) => (e ?? '').toString().trim()).toList();
    final rows = parsed.skip(1).map((r) => List<dynamic>.generate(headers.length, (i) => i < r.length ? r[i] : '')).toList();
    return ParsedReport(headers: headers, rows: rows, sheetName: 'CSV', sourceFormat: 'CSV', fingerprint: _logicalFingerprint('CSV', headers, rows));
  }

  static ParsedReport _parseXlsx(Uint8List bytes) {
    final workbook = Excel.decodeBytes(bytes);
    if (workbook.tables.isEmpty) throw const FormatException('لم يتم العثور على ورقة بيانات داخل ملف XLSX.');
    final sheetName = workbook.tables.keys.first;
    final sheet = workbook.tables[sheetName];
    if (sheet == null || sheet.rows.isEmpty) throw const FormatException('ورقة Excel فارغة.');
    final matrix = sheet.rows.map((row) => row.map(_cellToText).toList()).toList();
    final headers = matrix.first.map((v) => (v ?? '').toString().trim()).toList();
    final rows = matrix.skip(1).map((row) => List<dynamic>.generate(headers.length, (i) => i < row.length ? row[i] : '')).toList();
    return ParsedReport(headers: headers, rows: rows, sheetName: sheetName, sourceFormat: 'XLSX', fingerprint: _logicalFingerprint('XLSX', headers, rows));
  }

  static String _logicalFingerprint(String format, List<String> headers, List<List<dynamic>> rows) {
    final canonical = <String, Object?>{
      'format': format,
      'headers': headers.map((value) => value.trim().toLowerCase()).toList(),
      'rows': rows.map((row) => row.map((value) => (value ?? '').toString().trim()).toList()).toList(),
    };
    return sha256.convert(utf8.encode(jsonEncode(canonical))).toString();
  }

  static String _cellToText(Data? cell) {
    final value = cell?.value;
    if (value == null) return '';
    if (value is TextCellValue) return value.value.toPlainText();
    if (value is IntCellValue) return value.value.toString();
    if (value is DoubleCellValue) return value.value.toString();
    if (value is BoolCellValue) return value.value ? 'TRUE' : 'FALSE';
    if (value is DateCellValue) {
      final date = value.asDateTimeLocal();
      return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
    if (value is DateTimeCellValue) return value.asDateTimeLocal().toIso8601String();
    if (value is FormulaCellValue) return value.formula;
    return value.toString();
  }

  static Map<String, int> suggestedMapping(List<String> headers) => ReportDetector.autoMap(headers);
}
