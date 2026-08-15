import 'package:flutter_test/flutter_test.dart';
import 'package:skbs_app/features/legal/data/legal_workspace_repository.dart';

void main() {
  test('legal workspace employee parses all linked counters', () {
    final employee = LegalWorkspaceEmployee.fromMap(<String, dynamic>{
      'id': 'employee-1',
      'fio': 'Иванов Иван',
      'position': 'Бетонщик',
      'object_id': 'object-1',
      'object_name': 'Объект',
      'is_active': true,
      'documents_count': 8,
      'contracts_count': 2,
      'acts_count': 3,
      'matters_count': 1,
      'fines_count': 2,
      'pending_fines_count': 1,
    });

    expect(employee.documentsCount, 8);
    expect(employee.contractsCount, 2);
    expect(employee.actsCount, 3);
    expect(employee.finesCount, 2);
    expect(employee.pendingFinesCount, 1);
  });

  test('workspace separates contracts and acts', () {
    LegalWorkspaceDocument document(String category) =>
        LegalWorkspaceDocument(
          sourceType: 'legal_document',
          sourceId: category,
          employeeId: '',
          employeeName: '',
          objectId: '',
          objectName: '',
          title: category,
          category: category,
          documentType: category,
          status: 'signed',
          fileName: '',
          bucketName: '',
          storagePath: '',
          documentDate: null,
          legalDocumentId: category,
        );

    final snapshot = LegalWorkspaceSnapshot(
      employees: const <LegalWorkspaceEmployee>[],
      objects: const <LegalWorkspaceObject>[],
      documents: <LegalWorkspaceDocument>[
        document('contract'),
        document('act'),
        document('document'),
      ],
      recoveries: const <LegalWorkspaceRecovery>[],
    );

    expect(snapshot.contracts.length, 1);
    expect(snapshot.acts.length, 1);
  });
}
