import 'dart:convert';

import 'package:file_selector/file_selector.dart';

import '../models/employee.dart';
import '../models/employee_private_data.dart';
import 'employee_private_data_repository.dart';
import 'employee_repository.dart';

class EmployeePrivateDataImportResult {
  final int sourceRows;
  final int updatedEmployees;
  final List<String> notFoundNames;

  const EmployeePrivateDataImportResult({
    required this.sourceRows,
    required this.updatedEmployees,
    required this.notFoundNames,
  });
}

class EmployeePrivateDataImporter {
  static String _normalizeName(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _text(Map<String, dynamic> row, String key) {
    return row[key]?.toString().trim() ?? '';
  }

  static String _merged(
    Map<String, dynamic> row,
    String key,
    String currentValue,
  ) {
    final importedValue = _text(row, key);
    return importedValue.isEmpty ? currentValue : importedValue;
  }

  static Future<EmployeePrivateDataImportResult?> pickAndImport({
    String? objectName,
  }) async {
    const typeGroup = XTypeGroup(
      label: 'Личные данные сотрудников',
      extensions: <String>['json'],
    );

    final file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[typeGroup],
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('Выбранный файл пуст');
    }

    var sourceText = utf8.decode(bytes).trim();
    if (sourceText.startsWith('\ufeff')) {
      sourceText = sourceText.substring(1);
    }

    final decoded = jsonDecode(sourceText);
    final List<dynamic> sourceRows;

    if (decoded is List<dynamic>) {
      sourceRows = decoded;
    } else if (decoded is Map<String, dynamic> &&
        decoded['employees'] is List) {
      sourceRows = List<dynamic>.from(decoded['employees'] as List);
    } else {
      throw Exception('Неверный формат JSON: не найден список employees');
    }

    final employees = await EmployeeRepository.fetchEmployees(
      objectName: objectName,
      includeFired: true,
      forceRefresh: true,
    );

    final employeesById = <String, Employee>{};
    final employeesByName = <String, List<Employee>>{};

    for (final employee in employees) {
      final employeeId = employee.id?.trim() ?? '';
      if (employeeId.isNotEmpty) {
        employeesById[employeeId] = employee;
      }

      final nameKey = _normalizeName(employee.name);
      employeesByName.putIfAbsent(nameKey, () => <Employee>[]).add(employee);
    }

    final privateDataByEmployeeId =
        await EmployeePrivateDataRepository.fetchMapByEmployeeIds(
          employeesById.keys.toList(),
        );

    var updatedEmployees = 0;
    final notFoundNames = <String>[];

    for (final rawRow in sourceRows) {
      if (rawRow is! Map) continue;

      final row = Map<String, dynamic>.from(rawRow);
      final importedId = _text(row, 'employee_id');
      final importedName = _text(row, 'fio');

      List<Employee> targets = <Employee>[];

      if (importedId.isNotEmpty && employeesById.containsKey(importedId)) {
        targets = <Employee>[employeesById[importedId]!];
      } else if (importedName.isNotEmpty) {
        targets = List<Employee>.from(
          employeesByName[_normalizeName(importedName)] ?? const <Employee>[],
        );
      }

      if (targets.isEmpty) {
        notFoundNames.add(importedName.isEmpty ? importedId : importedName);
        continue;
      }

      for (final employee in targets) {
        final employeeId = employee.id?.trim() ?? '';
        if (employeeId.isEmpty) continue;

        final current =
            privateDataByEmployeeId[employeeId] ??
            EmployeePrivateData.empty(employeeId);

        final next = EmployeePrivateData(
          employeeId: employeeId,
          phone: _merged(row, 'phone', current.phone),
          birthDate: _merged(row, 'birth_date', current.birthDate),
          birthPlace: _merged(row, 'birth_place', current.birthPlace),
          passportSeries: _merged(
            row,
            'passport_series',
            current.passportSeries,
          ),
          passportNumber: _merged(
            row,
            'passport_number',
            current.passportNumber,
          ),
          passportIssuedBy: _merged(
            row,
            'passport_issued_by',
            current.passportIssuedBy,
          ),
          passportIssuedDate: _merged(
            row,
            'passport_issued_date',
            current.passportIssuedDate,
          ),
          passportDepartmentCode: _merged(
            row,
            'passport_department_code',
            current.passportDepartmentCode,
          ),
          snils: _merged(row, 'snils', current.snils),
          inn: _merged(row, 'inn', current.inn),
          registrationAddress: _merged(
            row,
            'registration_address',
            current.registrationAddress,
          ),
          livingAddress: _merged(row, 'living_address', current.livingAddress),
          clothesSize: _merged(row, 'clothes_size', current.clothesSize),
          shoeSize: _merged(row, 'shoe_size', current.shoeSize),
          bankName: _merged(row, 'bank_name', current.bankName),
          bankCard: _merged(row, 'bank_card', current.bankCard),
          bankAccount: _merged(row, 'bank_account', current.bankAccount),
          bankBik: _merged(row, 'bank_bik', current.bankBik),
          bankCorrAccount: _merged(
            row,
            'bank_corr_account',
            current.bankCorrAccount,
          ),
          bankInn: _merged(row, 'bank_inn', current.bankInn),
          bankKpp: _merged(row, 'bank_kpp', current.bankKpp),
          bankOkpo: _merged(row, 'bank_okpo', current.bankOkpo),
          bankOgrn: _merged(row, 'bank_ogrn', current.bankOgrn),
          bankSwift: _merged(row, 'bank_swift', current.bankSwift),
          bankAddress: _merged(row, 'bank_address', current.bankAddress),
          bankOfficeAddress: _merged(
            row,
            'bank_office_address',
            current.bankOfficeAddress,
          ),
          contractNumber: _merged(
            row,
            'contract_number',
            current.contractNumber,
          ),
          employmentStartDate: _merged(
            row,
            'employment_start_date',
            current.employmentStartDate,
          ),
          dismissalDate: _merged(row, 'dismissal_date', current.dismissalDate),
          comment: _merged(row, 'comment', current.comment),
        );

        await EmployeePrivateDataRepository.upsert(next);
        privateDataByEmployeeId[employeeId] = next;
        updatedEmployees++;
      }
    }

    return EmployeePrivateDataImportResult(
      sourceRows: sourceRows.length,
      updatedEmployees: updatedEmployees,
      notFoundNames: notFoundNames,
    );
  }
}
