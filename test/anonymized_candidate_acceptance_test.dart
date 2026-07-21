import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/documents/data/exact_docx_service.dart';
import 'package:skbs_app/features/recruitment/models/candidate_onboarding_models.dart';
import 'package:skbs_app/features/recruitment/models/employee_mobilization_models.dart';

void main() {
  const values = <String, String>{
    'employee_full_name': 'Тестов Тест Тестович',
    'employee_short_name': 'Тестов Т. Т.',
    'employee_position': 'Тестовая должность',
    'employee_phone': '+7 000 000-00-00',
    'employment_date': '01.08.2026',
    'document_date': '21.07.2026',
    'work_address': 'Тестовый объект',
    'employer_name': 'Тестовая организация',
    'employer_representative': 'Директор Тестовый Представитель',
    'employer_basis': 'Тестовый устав',
    'work_schedule': 'Тестовый график работы',
    'salary_terms': 'Тестовая ставка 0 рублей',
    'contract_number': 'ТЕСТ-001',
    'contract_city': 'Тестовый город',
    'employee_birth_date': '01.01.1990',
    'employee_birth_place': 'Тестовый город',
    'passport_series': '0000',
    'passport_number': '000000',
    'passport_issued_by': 'Тестовый орган',
    'passport_issued_date': '01.01.2010',
    'passport_department_code': '000-000',
    'registration_address': 'Тестовый адрес регистрации',
    'living_address': 'Тестовый адрес проживания',
    'employee_inn': '000000000000',
    'employee_snils': '000-000-000 00',
    'bank_account': '00000000000000000000',
    'bank_name': 'Тестовый банк',
    'bank_bik': '000000000',
    'bank_corr_account': '00000000000000000000',
    'bank_inn': '0000000000',
    'bank_kpp': '000000000',
    'bank_okpo': '00000000',
    'bank_ogrn': '0000000000000',
    'bank_swift': 'TEST0000',
    'bank_address': 'Тестовый адрес банка',
    'bank_office_address': 'Тестовый адрес отделения',
    'employer_address': 'Тестовый юридический адрес',
    'employer_details': 'ИНН 0000000000, КПП 000000000, ОГРН 0000000000000',
  };

  test('обезличенный комплект форм полностью собирается', () {
    for (final code in candidateOnboardingFormCodes) {
      final result = ExactDocxService.build(
        templateCode: code,
        values: values,
        fileBaseName: 'ТЕСТ_${candidateOnboardingFormTitle(code)}',
      );
      expect(result.missingFields, isEmpty, reason: code);
      expect(result.bytes, isNotEmpty, reason: code);
      final archive = ZipDecoder().decodeBytes(result.bytes);
      final document = archive.findFile('word/document.xml');
      expect(document, isNotNull, reason: code);
      final xml = utf8.decode(document!.content as List<int>);
      expect(xml, contains('Тестов Тест Тестович'), reason: code);
      expect(xml, isNot(contains('ООО «СКБС»')), reason: code);
    }
  });

  test('выход сотрудника считается завершённым только при 8 из 8', () {
    const candidate = EmployeeMobilizationCandidate(
      applicationId: 'application-test',
      companyId: 'company-test',
      employeeId: 'employee-test',
      fullName: 'Тестов Тест Тестович',
      positionTitle: 'Тестовая должность',
      objectId: 'object-test',
      objectName: 'Тестовый объект',
    );
    final draft = EmployeeMobilization.empty(candidate);
    expect(draft.completedSteps, 0);
    expect(draft.isCompleted, isFalse);

    final completed = EmployeeMobilization(
      id: 'mobilization-test',
      companyId: candidate.companyId,
      applicationId: candidate.applicationId,
      employeeId: candidate.employeeId,
      objectId: candidate.objectId,
      plannedStartDate: DateTime(2026, 8, 1),
      ticketBooked: true,
      arrivalConfirmed: true,
      accommodationConfirmed: true,
      medicalCleared: true,
      clothingIssued: true,
      safetyInducted: true,
      objectAssigned: true,
      attendanceEnabled: true,
      status: 'completed',
      notes: 'Тестовая запись',
      completedAt: DateTime(2026, 8, 1),
    );

    expect(completed.completedSteps, 8);
    expect(completed.isCompleted, isTrue);
  });
}
