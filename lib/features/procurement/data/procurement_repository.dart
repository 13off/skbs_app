import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/app_data_sync.dart';
import '../models/procurement_models.dart';

abstract final class ProcurementRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static Future<List<ProcurementRequest>> fetchRequests({
    required String companyId,
  }) async {
    final rows = await _client
        .from('procurement_requests')
        .select(
          'id, company_id, object_id, object_name, supplier_id, title, status, priority, needed_by, expected_delivery_at, ordered_at, delivered_at, total_amount, invoice_number, comment, created_at, updated_at, procurement_suppliers(name), procurement_request_items(id, name, quantity, unit, estimated_unit_price, actual_unit_price, ordered_quantity, delivered_quantity, note, sort_order)',
        )
        .eq('company_id', companyId)
        .order('updated_at', ascending: false)
        .limit(500);

    return rows
        .map<ProcurementRequest>((row) => ProcurementRequest.fromMap(_map(row)))
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  static Future<List<ProcurementSupplier>> fetchSuppliers({
    required String companyId,
    bool includeInactive = false,
  }) async {
    var query = _client
        .from('procurement_suppliers')
        .select('id, name, inn, contact_name, phone, email, comment, is_active')
        .eq('company_id', companyId);
    if (!includeInactive) query = query.eq('is_active', true);
    final rows = await query.order('name').limit(500);
    return rows
        .map<ProcurementSupplier>(
          (row) => ProcurementSupplier.fromMap(_map(row)),
        )
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  static Future<ProcurementDashboardData> fetchDashboard({
    required String companyId,
  }) async {
    final values = await Future.wait<dynamic>([
      fetchRequests(companyId: companyId),
      fetchSuppliers(companyId: companyId),
    ]);
    return ProcurementDashboardData(
      requests: values[0] as List<ProcurementRequest>,
      suppliers: values[1] as List<ProcurementSupplier>,
    );
  }

  static Future<String> saveRequest({
    required ProcurementRequest? existing,
    required String objectId,
    required String supplierId,
    required String title,
    required String priority,
    required DateTime? neededBy,
    required DateTime? expectedDeliveryAt,
    required String invoiceNumber,
    required String comment,
    required List<ProcurementRequestItem> items,
  }) async {
    final response = await _client.rpc(
      'save_procurement_request',
      params: <String, dynamic>{
        'p_request': <String, dynamic>{
          'id': existing?.id ?? '',
          'object_id': objectId,
          'supplier_id': supplierId,
          'title': title.trim(),
          'priority': priority,
          'needed_by': neededBy == null
              ? ''
              : '${neededBy.year.toString().padLeft(4, '0')}-${neededBy.month.toString().padLeft(2, '0')}-${neededBy.day.toString().padLeft(2, '0')}',
          'expected_delivery_at':
              expectedDeliveryAt?.toUtc().toIso8601String() ?? '',
          'invoice_number': invoiceNumber.trim(),
          'comment': comment.trim(),
        },
        'p_items': items.map((item) => item.toMap()).toList(),
      },
    );
    final id = response?.toString().trim() ?? '';
    if (id.isEmpty) throw Exception('Сервис не вернул идентификатор заявки');
    AppDataSync.notifyLocal(const <AppDataDomain>{AppDataDomain.procurement});
    return id;
  }

  static Future<void> setStatus({
    required String requestId,
    required String status,
  }) async {
    await _client.rpc(
      'set_procurement_request_status',
      params: <String, dynamic>{'p_request_id': requestId, 'p_status': status},
    );
    AppDataSync.notifyLocal(const <AppDataDomain>{AppDataDomain.procurement});
  }

  static Future<void> saveSupplier({
    required String companyId,
    ProcurementSupplier? existing,
    required String name,
    required String inn,
    required String contactName,
    required String phone,
    required String email,
    required String comment,
  }) async {
    final data = <String, dynamic>{
      'company_id': companyId,
      'name': name.trim(),
      'inn': inn.trim(),
      'contact_name': contactName.trim(),
      'phone': phone.trim(),
      'email': email.trim(),
      'comment': comment.trim(),
      'is_active': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (existing == null) {
      await _client.from('procurement_suppliers').insert(data);
    } else {
      await _client
          .from('procurement_suppliers')
          .update(data)
          .eq('company_id', companyId)
          .eq('id', existing.id);
    }
    AppDataSync.notifyLocal(const <AppDataDomain>{AppDataDomain.procurement});
  }

  static Future<void> archiveSupplier({
    required String companyId,
    required String supplierId,
  }) async {
    await _client
        .from('procurement_suppliers')
        .update(<String, dynamic>{
          'is_active': false,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('company_id', companyId)
        .eq('id', supplierId);
    AppDataSync.notifyLocal(const <AppDataDomain>{AppDataDomain.procurement});
  }
}
