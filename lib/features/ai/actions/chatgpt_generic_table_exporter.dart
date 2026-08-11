import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:universal_html/html.dart' as html;

import '../../../models/app_user_profile.dart';

/// Универсальные read-only XLSX-выгрузки для ChatGPT.
/// Чтение выполняется текущей пользовательской сессией, поэтому RLS и права
/// компании остаются источником истины.
class ChatGptGenericTableExporter {
  ChatGptGenericTableExporter._();

  static final SupabaseClient _client = Supabase.instance.client;

  static const supportedReportTypes = <String>{
    'employees',
    'tasks',
    'candidates',
    'procurement',
    'suppliers',
    'flights',
  };

  static Future<int> download({
    required AppUserProfile profile,
    required String reportType,
    String? objectName,
    DateTime? month,
  }) async {
    final type = reportType.trim().toLowerCase();
    if (!supportedReportTypes.contains(type)) {
      throw StateError('Этот тип таблицы пока не поддерживается');
    }
    _checkRole(profile, type);

    late final _TableResult result;
    if (type == 'employees') {
      result = await _employees(profile, objectName);
    } else if (type == 'tasks') {
      result = await _tasks(profile, objectName, month);
    } else if (type == 'candidates') {
      result = await _candidates(profile, objectName, month);
    } else if (type == 'procurement') {
      result = await _procurement(profile, objectName, month);
    } else if (type == 'suppliers') {
      result = await _suppliers(profile);
    } else if (type == 'flights') {
      result = await _flights(profile, objectName, month);
    } else {
      throw StateError('Этот тип таблицы пока не поддерживается');
    }

    final excel = Excel.createExcel();
    final sheet = excel[result.sheetName];
    if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');

    sheet.appendRow(
      result.headers.map((value) => TextCellValue(value)).toList(),
    );
    for (final row in result.rows) {
      sheet.appendRow(
        row.map((value) => TextCellValue(_cell(value))).toList(),
      );
    }

    for (var index = 0; index < result.headers.length; index++) {
      sheet.setColumnWidth(index, index == 0 ? 30 : 22);
    }

    final bytes = excel.encode();
    if (bytes == null) throw StateError('Не удалось сформировать Excel');
    _downloadBytes(
      bytes: Uint8List.fromList(bytes),
      fileName: _fileName(
        title: result.fileTitle,
        objectName: objectName,
        month: month,
      ),
    );
    return result.rows.length;
  }

  static void _checkRole(AppUserProfile profile, String type) {
    var allowed = false;
    if (type == 'employees' || type == 'tasks') {
      allowed = profile.isAdmin || profile.isForeman || profile.isDeveloper;
    } else if (type == 'candidates' || type == 'flights') {
      allowed = profile.isAdmin || profile.isHr || profile.isDeveloper;
    } else if (type == 'procurement' || type == 'suppliers') {
      allowed = profile.isAdmin || profile.isProcurement || profile.isDeveloper;
    }
    if (!allowed) throw StateError('Таблица недоступна текущей роли');
  }

  static Future<_TableResult> _employees(
    AppUserProfile profile,
    String? objectName,
  ) async {
    dynamic query = _client
        .from('employees')
        .select('fio,position,phone,object_name,daily_rate,is_active,comment')
        .eq('company_id', profile.activeCompanyId)
        .isFilter('archived_at', null);
    final object = _cleanObject(objectName, profile);
    if (object != null) query = query.eq('object_name', object);
    final dynamic data = await query.order('fio').limit(5000);
    return _TableResult(
      sheetName: 'Сотрудники',
      fileTitle: 'Сотрудники',
      headers: const [
        'ФИО', 'Должность', 'Телефон', 'Объект', 'Ставка', 'Статус', 'Комментарий',
      ],
      rows: _maps(data)
          .map((row) => <dynamic>[
                row['fio'], row['position'], row['phone'], row['object_name'],
                row['daily_rate'], row['is_active'] == true ? 'Активен' : 'Неактивен',
                row['comment'],
              ])
          .toList(growable: false),
    );
  }

  static Future<_TableResult> _tasks(
    AppUserProfile profile,
    String? objectName,
    DateTime? month,
  ) async {
    dynamic query = _client
        .from('tasks')
        .select('task_date,object_name,axes,work,status,not_done_comment')
        .eq('company_id', profile.activeCompanyId)
        .isFilter('deleted_at', null)
        .eq('is_draft', false);
    final object = _cleanObject(objectName, profile);
    if (object != null) query = query.eq('object_name', object);
    if (month != null) {
      query = query
          .gte('task_date', _isoDate(month))
          .lt('task_date', _isoDate(_nextMonth(month)));
    }
    final dynamic data = await query.order('task_date', ascending: false).limit(5000);
    return _TableResult(
      sheetName: 'Задачи',
      fileTitle: 'Задачи',
      headers: const ['Дата', 'Объект', 'Работа', 'Оси / участок', 'Статус', 'Комментарий невыполнения'],
      rows: _maps(data)
          .map((row) => <dynamic>[
                row['task_date'], row['object_name'], row['work'], row['axes'],
                row['status'], row['not_done_comment'],
              ])
          .toList(growable: false),
    );
  }

  static Future<_TableResult> _candidates(
    AppUserProfile profile,
    String? objectName,
    DateTime? month,
  ) async {
    dynamic query = _client
        .from('recruitment_applications')
        .select('full_name,phone,citizenship,position_title,ready_date,status,source,created_at,object_id')
        .eq('company_id', profile.activeCompanyId)
        .isFilter('archived_at', null)
        .eq('is_test_record', false);
    if (month != null) {
      query = query
          .gte('created_at', '${_isoDate(month)}T00:00:00Z')
          .lt('created_at', '${_isoDate(_nextMonth(month))}T00:00:00Z');
    }
    final dynamic data = await query.order('created_at', ascending: false).limit(5000);
    final objectMap = await _objectNames(profile.activeCompanyId);
    final requested = _cleanObject(objectName, profile)?.toLowerCase();
    final rows = _maps(data)
        .where((row) {
          if (requested == null) return true;
          return (objectMap[row['object_id']?.toString()] ?? '').toLowerCase() == requested;
        })
        .map((row) => <dynamic>[
              row['full_name'], row['phone'], row['position_title'], row['citizenship'],
              objectMap[row['object_id']?.toString()] ?? '', row['ready_date'],
              row['status'], row['source'], row['created_at'],
            ])
        .toList(growable: false);
    return _TableResult(
      sheetName: 'Кандидаты',
      fileTitle: 'Кандидаты',
      headers: const ['ФИО', 'Телефон', 'Позиция', 'Гражданство', 'Объект', 'Готов с даты', 'Статус', 'Источник', 'Создан'],
      rows: rows,
    );
  }

  static Future<_TableResult> _procurement(
    AppUserProfile profile,
    String? objectName,
    DateTime? month,
  ) async {
    dynamic query = _client
        .from('procurement_requests')
        .select('title,object_name,status,priority,needed_by,expected_delivery_at,total_amount,invoice_number,comment,created_at')
        .eq('company_id', profile.activeCompanyId);
    final object = _cleanObject(objectName, profile);
    if (object != null) query = query.eq('object_name', object);
    if (month != null) {
      query = query
          .gte('created_at', '${_isoDate(month)}T00:00:00Z')
          .lt('created_at', '${_isoDate(_nextMonth(month))}T00:00:00Z');
    }
    final dynamic data = await query.order('created_at', ascending: false).limit(5000);
    return _TableResult(
      sheetName: 'Снабжение',
      fileTitle: 'Снабжение',
      headers: const ['Заявка', 'Объект', 'Статус', 'Приоритет', 'Нужно к', 'Ожидаемая доставка', 'Сумма', 'Счёт', 'Комментарий', 'Создано'],
      rows: _maps(data)
          .map((row) => <dynamic>[
                row['title'], row['object_name'], row['status'], row['priority'],
                row['needed_by'], row['expected_delivery_at'], row['total_amount'],
                row['invoice_number'], row['comment'], row['created_at'],
              ])
          .toList(growable: false),
    );
  }

  static Future<_TableResult> _suppliers(AppUserProfile profile) async {
    final dynamic data = await _client
        .from('procurement_suppliers')
        .select('name,inn,contact_name,phone,email,comment,is_active,created_at')
        .eq('company_id', profile.activeCompanyId)
        .order('name')
        .limit(5000);
    return _TableResult(
      sheetName: 'Поставщики',
      fileTitle: 'Поставщики',
      headers: const ['Поставщик', 'ИНН', 'Контакт', 'Телефон', 'Email', 'Статус', 'Комментарий', 'Создан'],
      rows: _maps(data)
          .map((row) => <dynamic>[
                row['name'], row['inn'], row['contact_name'], row['phone'], row['email'],
                row['is_active'] == true ? 'Активен' : 'Неактивен', row['comment'], row['created_at'],
              ])
          .toList(growable: false),
    );
  }

  static Future<_TableResult> _flights(
    AppUserProfile profile,
    String? objectName,
    DateTime? month,
  ) async {
    dynamic query = _client
        .from('recruitment_flights')
        .select('application_id,object_id,departure_at,arrival_at,origin,destination,flight_number,status,ticket_original_name,notes')
        .eq('company_id', profile.activeCompanyId);
    if (month != null) {
      query = query
          .gte('departure_at', '${_isoDate(month)}T00:00:00Z')
          .lt('departure_at', '${_isoDate(_nextMonth(month))}T00:00:00Z');
    }
    final dynamic data = await query.order('departure_at', ascending: false).limit(5000);
    final flights = _maps(data);
    final applicationIds = flights
        .map((row) => row['application_id']?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final candidates = <String, String>{};
    for (var start = 0; start < applicationIds.length; start += 100) {
      final end = start + 100 > applicationIds.length ? applicationIds.length : start + 100;
      final chunk = applicationIds.sublist(start, end);
      final dynamic candidateData = await _client
          .from('recruitment_applications')
          .select('id,full_name')
          .eq('company_id', profile.activeCompanyId)
          .inFilter('id', chunk);
      for (final row in _maps(candidateData)) {
        candidates[row['id']?.toString() ?? ''] = row['full_name']?.toString() ?? '';
      }
    }
    final objectMap = await _objectNames(profile.activeCompanyId);
    final requested = _cleanObject(objectName, profile)?.toLowerCase();
    final rows = flights
        .where((row) {
          if (requested == null) return true;
          return (objectMap[row['object_id']?.toString()] ?? '').toLowerCase() == requested;
        })
        .map((row) => <dynamic>[
              candidates[row['application_id']?.toString()] ?? '',
              objectMap[row['object_id']?.toString()] ?? '',
              row['departure_at'], row['arrival_at'], row['origin'], row['destination'],
              row['flight_number'], row['status'], row['ticket_original_name'], row['notes'],
            ])
        .toList(growable: false);
    return _TableResult(
      sheetName: 'Вылеты',
      fileTitle: 'Вылеты',
      headers: const ['Кандидат', 'Объект', 'Вылет', 'Прибытие', 'Откуда', 'Куда', 'Рейс', 'Статус', 'Билет', 'Примечание'],
      rows: rows,
    );
  }

  static List<Map<String, dynamic>> _maps(dynamic data) {
    if (data is! List) return const <Map<String, dynamic>>[];
    return data
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  static Future<Map<String, String>> _objectNames(String companyId) async {
    final dynamic data = await _client
        .from('objects')
        .select('id,name')
        .eq('company_id', companyId)
        .limit(1000);
    return <String, String>{
      for (final row in _maps(data))
        row['id']?.toString() ?? '': row['name']?.toString() ?? '',
    };
  }

  static String? _cleanObject(String? objectName, AppUserProfile profile) {
    final requested = objectName?.trim() ?? '';
    if (requested.isNotEmpty &&
        requested.toLowerCase() != 'все объекты' &&
        requested.toLowerCase() != 'все доступные объекты') {
      return requested;
    }
    final assigned = profile.objectName.trim();
    return assigned.isEmpty ? null : assigned;
  }

  static DateTime _nextMonth(DateTime month) => month.month == 12
      ? DateTime(month.year + 1, 1, 1)
      : DateTime(month.year, month.month + 1, 1);

  static String _isoDate(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static String _cell(dynamic value) => value?.toString().trim() ?? '';

  static String _fileName({
    required String title,
    required String? objectName,
    required DateTime? month,
  }) {
    final parts = <String>[title];
    final object = objectName?.trim() ?? '';
    if (object.isNotEmpty) parts.add(object);
    if (month != null) {
      parts.add('${month.year}-${month.month.toString().padLeft(2, '0')}');
    }
    final safe = parts.join('_').replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
    return '$safe.xlsx';
  }

  static void _downloadBytes({
    required Uint8List bytes,
    required String fileName,
  }) {
    final blob = html.Blob(
      <Object>[bytes],
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }
}

class _TableResult {
  final String sheetName;
  final String fileTitle;
  final List<String> headers;
  final List<List<dynamic>> rows;

  const _TableResult({
    required this.sheetName,
    required this.fileTitle,
    required this.headers,
    required this.rows,
  });
}
