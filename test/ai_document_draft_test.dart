import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/ai/documents/ai_document_draft.dart';
import 'package:skbs_app/features/ai/models/ai_assistant_result.dart';
import 'package:skbs_app/models/employee.dart';
import 'package:skbs_app/models/employee_private_data.dart';

AiAssistantAction action({
  required String kind,
  String title = '',
  String prompt = '',
}) {
  return AiAssistantAction(
    id: 'action-1',
    type: 'prepare_document',
    title: title,
    buttonLabel: 'Открыть документ',
    confirmationRequired: true,
    payload: <String, dynamic>{
      'document_kind': kind,
      'title': title,
      'object_name': 'Мурманск',
      'date': '2026-07-20',
      'employee_id': 'employee-1',
      'employee_name': 'Иванов Иван Иванович',
      'source_prompt': prompt,
    },
  );
}

void main() {
  const employee = Employee(
    'Иванов Иван Иванович',
    'Бетонщик',
    'не отмечен',
    id: 'employee-1',
    objectName: 'Мурманск',
    dailyRate: 6000,
  );

  test('заявление о приёме заполняет доступные рабочие данные', () {
    final draft = AiDocumentDraftBuilder.build(
      action: action(kind: 'job_application'),
      companyName: 'ООО «СКБС»',
      employee: employee,
      privateData: const EmployeePrivateData(
        employeeId: 'employee-1',
        employmentStartDate: '21.07.2026',
      ),
    );

    expect(draft.title, 'Заявление о приёме на работу');
    expect(draft.body, contains('ООО «СКБС»'));
    expect(draft.body, contains('Иванов Иван Иванович'));
    expect(draft.body, contains('Бетонщик'));
    expect(draft.body, contains('21.07.2026'));
    expect(draft.body, contains('ЧЕРНОВИК — ТРЕБУЕТ ПРОВЕРКИ'));
    expect(draft.missingFields, isEmpty);
  });

  test('банковское заявление не придумывает отсутствующие реквизиты', () {
    final draft = AiDocumentDraftBuilder.build(
      action: action(kind: 'salary_transfer_application'),
      companyName: 'ООО «СКБС»',
      employee: employee,
      privateData: EmployeePrivateData.empty('employee-1'),
    );

    expect(draft.missingFields, contains('наименование банка'));
    expect(draft.missingFields, contains('номер счёта'));
    expect(draft.missingFields, contains('БИК'));
    expect(draft.body, contains('[указать наименование банка]'));
    expect(draft.body, contains('[указать номер счёта]'));
    expect(draft.body, contains('[указать БИК]'));
    expect(draft.body, isNot(contains('00000000000000000000')));
  });

  test('трудовой договор остаётся явно проверяемым черновиком', () {
    final draft = AiDocumentDraftBuilder.build(
      action: action(kind: 'employment_contract'),
      companyName: 'ООО «СКБС»',
      employee: employee,
      privateData: const EmployeePrivateData(
        employeeId: 'employee-1',
        passportSeries: '5700',
        passportNumber: '123456',
        employmentStartDate: '21.07.2026',
      ),
    );

    expect(draft.body, contains('ТРУДОВОЙ ДОГОВОР — ЧЕРНОВИК'));
    expect(draft.body, contains('должны быть проверены и дополнены'));
    expect(draft.body, contains('6000 руб. за смену'));
    expect(draft.body, contains('Работодатель: __________________'));
    expect(draft.body, contains('Работник: __________________'));
  });

  test('служебная записка переносит исходный запрос в редактируемый текст', () {
    const prompt = 'Проверить отсутствующие чеки по выплатам за июль';
    final draft = AiDocumentDraftBuilder.build(
      action: action(kind: 'service_memo', prompt: prompt),
      companyName: 'ООО «СКБС»',
      employee: employee,
    );

    expect(draft.body, contains(prompt));
    expect(draft.body, contains('Объект: Мурманск'));
    expect(draft.body, contains('Прошу: [указать требуемое решение]'));
  });
}
