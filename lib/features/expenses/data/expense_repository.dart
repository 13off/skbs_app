import 'package:supabase_flutter/supabase_flutter.dart';

class ExpenseCategoryData {
  final String id;
  final String name;
  final int sortOrder;

  const ExpenseCategoryData({
    required this.id,
    required this.name,
    required this.sortOrder,
  });

  factory ExpenseCategoryData.fromMap(Map<String, dynamic> map) {
    return ExpenseCategoryData(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class ExpenseObjectData {
  final String id;
  final String name;
  final bool isActive;

  const ExpenseObjectData({
    required this.id,
    required this.name,
    required this.isActive,
  });

  factory ExpenseObjectData.fromMap(Map<String, dynamic> map) {
    return ExpenseObjectData(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      isActive: map['is_active'] as bool? ?? true,
    );
  }
}

class ExpenseItemData {
  final String id;
  final String sourceType;
  final DateTime date;
  final String name;
  final double amount;
  final String? categoryId;
  final String categoryName;
  final String? objectId;
  final String? objectName;
  final String comment;
  final String? paymentType;
  final bool isEditable;

  const ExpenseItemData({
    required this.id,
    required this.sourceType,
    required this.date,
    required this.name,
    required this.amount,
    required this.categoryId,
    required this.categoryName,
    required this.objectId,
    required this.objectName,
    required this.comment,
    required this.paymentType,
    required this.isEditable,
  });

  bool get isPayment => sourceType == 'payment';

  factory ExpenseItemData.fromMap(Map<String, dynamic> map) {
    return ExpenseItemData(
      id: map['id']?.toString() ?? '',
      sourceType: map['source_type']?.toString() ?? 'manual',
      date: DateTime.tryParse(map['expense_date']?.toString() ?? '') ??
          DateTime.now(),
      name: map['name']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      categoryId: map['category_id']?.toString(),
      categoryName: map['category_name']?.toString() ?? 'Без статьи',
      objectId: map['object_id']?.toString(),
      objectName: map['object_name']?.toString(),
      comment: map['comment']?.toString() ?? '',
      paymentType: map['payment_type']?.toString(),
      isEditable: map['is_editable'] as bool? ?? false,
    );
  }
}

class ExpensesSnapshot {
  final List<ExpenseCategoryData> categories;
  final List<ExpenseObjectData> objects;
  final List<ExpenseItemData> rows;

  const ExpensesSnapshot({
    required this.categories,
    required this.objects,
    required this.rows,
  });

  factory ExpensesSnapshot.fromMap(Map<String, dynamic> map) {
    List<Map<String, dynamic>> maps(String key) {
      final value = map[key];
      if (value is! List) return const <Map<String, dynamic>>[];
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    }

    return ExpensesSnapshot(
      categories: maps('categories')
          .map(ExpenseCategoryData.fromMap)
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false),
      objects: maps('objects')
          .map(ExpenseObjectData.fromMap)
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false),
      rows: maps('rows')
          .map(ExpenseItemData.fromMap)
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false),
    );
  }
}

class ExpenseRepository {
  ExpenseRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String _date(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  Future<ExpensesSnapshot> fetchSnapshot({
    required DateTime from,
    required DateTime to,
  }) async {
    final raw = await _client.rpc(
      'get_expenses_center',
      params: <String, dynamic>{
        'p_start_date': _date(from),
        'p_end_date': _date(to),
      },
    );
    if (raw is! Map) {
      return const ExpensesSnapshot(categories: [], objects: [], rows: []);
    }
    return ExpensesSnapshot.fromMap(Map<String, dynamic>.from(raw));
  }

  Future<List<ExpenseCategoryData>> fetchCategories() async {
    final raw = await _client
        .from('expense_categories')
        .select('id,name,sort_order')
        .order('sort_order')
        .order('name');
    return (raw as List)
        .whereType<Map>()
        .map((item) => ExpenseCategoryData.fromMap(
              Map<String, dynamic>.from(item),
            ))
        .toList(growable: false);
  }

  Future<void> createCategory(String name) async {
    await _client.from('expense_categories').insert(<String, dynamic>{
      'name': name.trim(),
    });
  }

  Future<void> updateCategory(String id, String name) async {
    await _client.from('expense_categories').update(<String, dynamic>{
      'name': name.trim(),
    }).eq('id', id);
  }

  Future<void> deleteCategory(String id) async {
    await _client.from('expense_categories').delete().eq('id', id);
  }

  Future<void> createExpense({
    required String name,
    required double amount,
    required DateTime date,
    String? categoryId,
    String? objectId,
    String comment = '',
  }) async {
    await _client.from('expenses').insert(<String, dynamic>{
      'name': name.trim(),
      'amount': amount,
      'expense_date': _date(date),
      'category_id': categoryId,
      'object_id': objectId,
      'comment': comment.trim(),
    });
  }

  Future<void> updateExpense({
    required String id,
    required String name,
    required double amount,
    required DateTime date,
    String? categoryId,
    String? objectId,
    String comment = '',
  }) async {
    await _client.from('expenses').update(<String, dynamic>{
      'name': name.trim(),
      'amount': amount,
      'expense_date': _date(date),
      'category_id': categoryId,
      'object_id': objectId,
      'comment': comment.trim(),
    }).eq('id', id);
  }

  Future<void> deleteExpense(String id) async {
    await _client.from('expenses').delete().eq('id', id);
  }
}
