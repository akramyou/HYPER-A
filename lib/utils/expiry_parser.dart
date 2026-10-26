class ExpiryParser {
  static DateTime? parse(String input, {DateTime? now}) {
    var text = input.trim();
    if (text.isEmpty) return null;
    text = _normalizeDigits(text)
        .replaceAll(RegExp(r'\b(EXP|EXPIRY|EXPIRES|BEST\s*BEFORE|BBE|USE\s*BY|انتهاء|الصلاحية)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'[^0-9/\-. ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final today = now ?? DateTime.now();
    final year = today.year;

    // ISO first: YYYY-MM-DD or YYYY/MM/DD.
    final iso = RegExp(r'\b(20\d{2}|19\d{2})[-/.](\d{1,2})[-/.](\d{1,2})\b').firstMatch(text);
    if (iso != null) return _make(int.parse(iso[1]!), int.parse(iso[2]!), int.parse(iso[3]!));

    // Day/month/year. A two-digit first value <= 12 is ambiguous; interpreted day-first for Arabic markets.
    final dmy = RegExp(r'\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{2}|\d{4})\b').firstMatch(text);
    if (dmy != null) {
      final day = int.parse(dmy[1]!);
      final month = int.parse(dmy[2]!);
      var y = int.parse(dmy[3]!);
      if (y < 100) y += y >= 70 ? 1900 : 2000;
      return _make(y, month, day);
    }


    // Month/year is common on packaged goods: 10/2027 or 10/27. Choose last day of month.
    final monthYear = RegExp(r'\b(\d{1,2})[-/.](\d{2}|\d{4})\b').firstMatch(text);
    if (monthYear != null) {
      final month = int.parse(monthYear[1]!);
      var y = int.parse(monthYear[2]!);
      if (y < 100) y += y >= 70 ? 1900 : 2000;
      if (month >= 1 && month <= 12 && y >= year - 1 && y <= year + 30) {
        return DateTime(y, month + 1, 0);
      }
    }

    return null;
  }

  static DateTime? _make(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) return null;
    return date;
  }

  static String _normalizeDigits(String value) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    final out = StringBuffer();
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      final ai = arabic.indexOf(char);
      final pi = persian.indexOf(char);
      if (ai >= 0) {
        out.write(ai);
      } else if (pi >= 0) {
        out.write(pi);
      } else {
        out.write(char);
      }
    }
    return out.toString();
  }
}
