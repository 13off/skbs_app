class TimesheetAbsenceReason {
  TimesheetAbsenceReason._();

  static const String sick = 'sick';
  static const String dayOff = 'day_off';
  static const String noShow = 'no_show';

  static const List<String> values = <String>[sick, dayOff, noShow];

  static bool isValid(String? value) => value != null && values.contains(value);

  static String? normalize(String? value) {
    final clean = value?.trim().toLowerCase();
    return isValid(clean) ? clean : null;
  }

  static String labelFor(String? value) {
    switch (normalize(value)) {
      case sick:
        return 'Болезнь';
      case dayOff:
        return 'Выходной';
      case noShow:
        return 'Прогул';
      default:
        return 'Причина';
    }
  }
}
