from pathlib import Path

path = Path('lib/features/recruitment/data/recruitment_repository.dart')
text = path.read_text(encoding='utf-8')
old = """    final response = await _client.functions.invoke(
      'recruitment-candidate-action',
      body: <String, dynamic>{
        'action': 'create_documents_archive',
        'application_id': applicationId.trim(),
      },
    );
"""
new = """    final response = await _client.functions.invoke(
      'recruitment-documents-archive',
      body: <String, dynamic>{
        'application_id': applicationId.trim(),
      },
    );
"""
if old not in text:
    raise SystemExit('archive invocation pattern not found')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
