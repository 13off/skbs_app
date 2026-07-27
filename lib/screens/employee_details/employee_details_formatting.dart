part of '../employee_details_screen.dart';

extension _EmployeeDetailsFormatting on _EmployeeDetailsScreenState {
  String firstLetter(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return '?';
    return clean.characters.first;
  }

  String formatMoney(int value) {
    final text = value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    );
    return '$text ₽';
  }

  String monthName(int month) {
    const monthNames = <String>[
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь',
    ];
    if (month < 1 || month > 12) return 'Месяц';
    return monthNames[month - 1];
  }
}
