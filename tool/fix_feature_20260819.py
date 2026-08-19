from pathlib import Path

repo = Path('lib/features/recruitment/data/recruitment_flight_repository.dart')
text = repo.read_text(encoding='utf-8')
result_anchor = '    final result = RecruitmentFlight.fromMap(_map(row));\n\n'
start = text.index('    final reminderKeys = <String>{};', text.index(result_anchor))
end = text.index("    await _client.rpc(\n      'replace_recruitment_flight_reminders'", start)
validation = text[start:end]
text = text[:start] + text[end:]
insert_anchor = '''    if (arrivalAt != null && !arrivalAt.isAfter(departureAt)) {
      throw Exception('Прибытие должно быть позже вылета');
    }

'''
if insert_anchor not in text:
    raise SystemExit('arrival validation anchor not found')
text = text.replace(insert_anchor, insert_anchor + validation, 1)
repo.write_text(text, encoding='utf-8')
print('reminder validation moved before persistence')
