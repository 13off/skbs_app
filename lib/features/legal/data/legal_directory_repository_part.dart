part of 'legal_repository.dart';

abstract final class _LegalDirectories {
  static Future<List<LegalDirectoryItem>> fetchEmployeeDirectory() async {
    final response = await _client.rpc('legal_employee_directory');
    return _list(response).map<LegalDirectoryItem>((value) {
      final row = _map(value);
      final position = _clean(row['position']?.toString());
      final object = _clean(row['object_name']?.toString());
      final subtitle = <String>[
        if (position.isNotEmpty) position,
        if (object.isNotEmpty) object,
        if (row['is_active'] != true) 'Уволен',
      ].join(' • ');
      return LegalDirectoryItem(
        id: row['id']?.toString() ?? '',
        title: row['fio']?.toString() ?? '',
        subtitle: subtitle,
        objectName: object,
      );
    }).where((item) => item.id.isNotEmpty && item.title.isNotEmpty).toList();
  }

  static Future<List<LegalDirectoryItem>> fetchObjectDirectory() async {
    final response = await _client.rpc('legal_object_directory');
    return _list(response).map<LegalDirectoryItem>((value) {
      final row = _map(value);
      return LegalDirectoryItem(
        id: row['id']?.toString() ?? '',
        title: row['name']?.toString() ?? '',
      );
    }).where((item) => item.id.isNotEmpty && item.title.isNotEmpty).toList();
  }

  static Future<List<LegalDirectoryItem>> fetchResponsibleDirectory() async {
    final response = await _client.rpc('legal_responsible_directory');
    return _list(response).map<LegalDirectoryItem>((value) {
      final row = _map(value);
      final role = row['role']?.toString() ?? '';
      return LegalDirectoryItem(
        id: row['id']?.toString() ?? '',
        title: row['full_name']?.toString() ?? '',
        subtitle: switch (role) {
          'owner' => 'Руководитель',
          'admin' => 'Администратор',
          'lawyer' => 'Юрист',
          _ => role,
        },
      );
    }).where((item) => item.id.isNotEmpty && item.title.isNotEmpty).toList();
  }

  static Future<List<LegalCounterparty>> fetchCounterparties() async {
    final rows = await _client
        .from('legal_counterparties')
        .select(
          'id, name, category, inn, kpp, ogrn, contact_name, phone, email, comment, status',
        )
        .neq('status', 'archived')
        .order('name');
    return rows
        .map<LegalCounterparty>(
          (row) => LegalCounterparty.fromMap(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  static Future<LegalCounterparty> addCounterparty({
    required String name,
    required String category,
    String inn = '',
    String kpp = '',
    String ogrn = '',
    String contactName = '',
    String phone = '',
    String email = '',
    String comment = '',
  }) async {
    final userId = _client.auth.currentUser?.id;
    final row = await _client
        .from('legal_counterparties')
        .insert(<String, dynamic>{
          'name': name.trim(),
          'category': category.trim().isEmpty ? 'other' : category.trim(),
          'inn': inn.trim(),
          'kpp': kpp.trim(),
          'ogrn': ogrn.trim(),
          'contact_name': contactName.trim(),
          'phone': phone.trim(),
          'email': email.trim(),
          'comment': comment.trim(),
          'created_by': userId,
        })
        .select(
          'id, name, category, inn, kpp, ogrn, contact_name, phone, email, comment, status',
        )
        .single();
    _notifyLegalChanged('legal_counterparties');
    return LegalCounterparty.fromMap(row);
  }

  static Future<Map<String, String>> responsibleNames() async {
    final users = await fetchResponsibleDirectory();
    return <String, String>{for (final user in users) user.id: user.title};
  }
}
