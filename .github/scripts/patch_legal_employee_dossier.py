from pathlib import Path

# 1. Подключаем новый экран досье и убираем старую дублирующую карточку.
path = Path('lib/features/legal/presentation/legal_workspace_screen.dart')
source = path.read_text()
import_line = "import 'legal_employee_dossier_screen.dart';\n"
anchor = "import 'legal_documents_screen.dart';\n"
if import_line not in source:
    source = source.replace(anchor, anchor + import_line)

old_builder = '''                builder: (_) => _EmployeeDossierScreen(
                  employee: item,
                  documents: data.workspace.documents
                      .where((document) => document.employeeId == item.id)
                      .toList(),
                  matters: data.matters
                      .where((matter) => matter.employeeId == item.id)
                      .toList(),
                  recoveries: data.workspace.recoveries
                      .where((recovery) => recovery.employeeId == item.id)
                      .toList(),
                ),'''
new_builder = '''                builder: (_) => LegalEmployeeDossierScreen(employee: item),'''
if old_builder not in source:
    raise SystemExit('employee dossier builder anchor not found')
source = source.replace(old_builder, new_builder, 1)

start = source.index('class _EmployeeDossierScreen extends StatefulWidget {')
end = source.index('class _ObjectLegalDossierScreen extends StatefulWidget {', start)
source = source[:start] + source[end:]
path.write_text(source)

# 2. Позволяем открыть редактор юридического документа сразу на нужном сотруднике/объекте.
path = Path('lib/features/legal/presentation/legal_document_editor_part.dart')
source = path.read_text()
old_widget = '''class LegalDocumentEditorScreen extends StatefulWidget {
  final LegalDocument? document;

  const LegalDocumentEditorScreen({super.key, this.document});'''
new_widget = '''class LegalDocumentEditorScreen extends StatefulWidget {
  final LegalDocument? document;
  final String? initialEmployeeId;
  final String? initialObjectId;

  const LegalDocumentEditorScreen({
    super.key,
    this.document,
    this.initialEmployeeId,
    this.initialObjectId,
  });'''
if old_widget not in source:
    raise SystemExit('document editor widget anchor not found')
source = source.replace(old_widget, new_widget, 1)
anchor = '''      managerApproval = item.requiresManagerApproval;
    }
    directoriesFuture = loadDirectories();'''
replacement = '''      managerApproval = item.requiresManagerApproval;
    } else {
      employeeId = widget.initialEmployeeId;
      objectId = widget.initialObjectId == null || widget.initialObjectId!.isEmpty
          ? allObjectsScopeValue
          : widget.initialObjectId;
    }
    directoriesFuture = loadDirectories();'''
if anchor not in source:
    raise SystemExit('document editor init anchor not found')
source = source.replace(anchor, replacement, 1)
path.write_text(source)

# 3. Исправляем декларативные поля персональных данных без нестабильного tear-off в const.
path = Path('lib/features/legal/presentation/legal_employee_dossier_screen.dart')
source = path.read_text()
source = source.replace('final value = field.value(dossier);', 'final value = field.resolve(dossier);')
old_fields = '''class _DossierField {
  final String label;
  final String Function(LegalEmployeeDossier dossier) value;

  const _DossierField.custom(this.label, this.value);

  const _DossierField.key(String label, String key)
      : this.custom(label, _DossierFieldValue(key).call);
}

class _DossierFieldValue {
  final String key;

  const _DossierFieldValue(this.key);

  String call(LegalEmployeeDossier dossier) => dossier.text(key);
}
'''
new_fields = '''class _DossierField {
  final String label;
  final String? key;
  final String Function(LegalEmployeeDossier dossier)? resolver;

  const _DossierField.key(this.label, this.key) : resolver = null;

  const _DossierField.custom(this.label, this.resolver) : key = null;

  String resolve(LegalEmployeeDossier dossier) {
    final custom = resolver;
    if (custom != null) return custom(dossier);
    return dossier.text(key ?? '');
  }
}
'''
if old_fields not in source:
    raise SystemExit('dossier fields anchor not found')
source = source.replace(old_fields, new_fields, 1)
path.write_text(source)
