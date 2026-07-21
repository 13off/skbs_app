class PeriodTimesheetLaunchIntent {
  PeriodTimesheetLaunchIntent._();

  static DateTime? _pendingMonth;

  static DateTime? parseYearMonth(String value) {
    final match = RegExp(r'^(20\d{2})-(0[1-9]|1[0-2])$').firstMatch(value.trim());
    if (match == null) return null;

    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    if (year == null || month == null) return null;

    return DateTime(year, month, 1);
  }

  static bool setFromYearMonth(String value) {
    final parsed = parseYearMonth(value);
    if (parsed == null) return false;
    _pendingMonth = parsed;
    return true;
  }

  static DateTime? take() {
    final value = _pendingMonth;
    _pendingMonth = null;
    return value;
  }

  static void clear() => _pendingMonth = null;
}
