class ProcurementRequestItem {
  final String id;
  final String name;
  final double quantity;
  final String unit;
  final double estimatedUnitPrice;
  final double actualUnitPrice;
  final double orderedQuantity;
  final double deliveredQuantity;
  final String note;

  const ProcurementRequestItem({
    this.id = '',
    required this.name,
    required this.quantity,
    required this.unit,
    this.estimatedUnitPrice = 0,
    this.actualUnitPrice = 0,
    this.orderedQuantity = 0,
    this.deliveredQuantity = 0,
    this.note = '',
  });

  double get estimatedTotal => quantity * estimatedUnitPrice;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'name': name.trim(),
    'quantity': quantity,
    'unit': unit.trim().isEmpty ? 'шт.' : unit.trim(),
    'estimated_unit_price': estimatedUnitPrice,
    'actual_unit_price': actualUnitPrice,
    'ordered_quantity': orderedQuantity,
    'delivered_quantity': deliveredQuantity,
    'note': note.trim(),
  };

  factory ProcurementRequestItem.fromMap(Map<String, dynamic> map) {
    return ProcurementRequestItem(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      quantity: _number(map['quantity']),
      unit: map['unit']?.toString() ?? 'шт.',
      estimatedUnitPrice: _number(map['estimated_unit_price']),
      actualUnitPrice: _number(map['actual_unit_price']),
      orderedQuantity: _number(map['ordered_quantity']),
      deliveredQuantity: _number(map['delivered_quantity']),
      note: map['note']?.toString() ?? '',
    );
  }
}

class ProcurementSupplier {
  final String id;
  final String name;
  final String inn;
  final String contactName;
  final String phone;
  final String email;
  final String comment;
  final bool isActive;

  const ProcurementSupplier({
    required this.id,
    required this.name,
    this.inn = '',
    this.contactName = '',
    this.phone = '',
    this.email = '',
    this.comment = '',
    this.isActive = true,
  });

  factory ProcurementSupplier.fromMap(Map<String, dynamic> map) {
    return ProcurementSupplier(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      inn: map['inn']?.toString() ?? '',
      contactName: map['contact_name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      comment: map['comment']?.toString() ?? '',
      isActive: map['is_active'] != false,
    );
  }
}

class ProcurementRequest {
  final String id;
  final String companyId;
  final String objectId;
  final String objectName;
  final String supplierId;
  final String supplierName;
  final String title;
  final String status;
  final String priority;
  final DateTime? neededBy;
  final DateTime? expectedDeliveryAt;
  final DateTime? orderedAt;
  final DateTime? deliveredAt;
  final double totalAmount;
  final String invoiceNumber;
  final String comment;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ProcurementRequestItem> items;

  const ProcurementRequest({
    required this.id,
    required this.companyId,
    required this.objectId,
    required this.objectName,
    required this.supplierId,
    required this.supplierName,
    required this.title,
    required this.status,
    required this.priority,
    required this.neededBy,
    required this.expectedDeliveryAt,
    required this.orderedAt,
    required this.deliveredAt,
    required this.totalAmount,
    required this.invoiceNumber,
    required this.comment,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
  });

  bool get isClosed => status == 'delivered' || status == 'canceled';
  bool get isDelivery => status == 'ordered' || status == 'in_delivery';
  bool get isOverdue {
    final deadline = expectedDeliveryAt ?? neededBy;
    return !isClosed && deadline != null && deadline.isBefore(DateTime.now());
  }

  String get statusTitle => switch (status) {
    'draft' => 'Черновик',
    'submitted' => 'На согласовании',
    'approved' => 'Согласовано',
    'purchasing' => 'Закупка',
    'ordered' => 'Заказано',
    'in_delivery' => 'В доставке',
    'delivered' => 'Доставлено',
    'canceled' => 'Отменено',
    _ => status,
  };

  String get priorityTitle => switch (priority) {
    'low' => 'Низкий',
    'high' => 'Высокий',
    'urgent' => 'Срочно',
    _ => 'Обычный',
  };

  String? get nextStatus => switch (status) {
    'draft' => 'submitted',
    'submitted' => 'approved',
    'approved' => 'purchasing',
    'purchasing' => 'ordered',
    'ordered' => 'in_delivery',
    'in_delivery' => 'delivered',
    _ => null,
  };

  String? get nextActionTitle => switch (status) {
    'draft' => 'Отправить',
    'submitted' => 'Согласовать',
    'approved' => 'Начать закупку',
    'purchasing' => 'Заказано',
    'ordered' => 'Передано в доставку',
    'in_delivery' => 'Принять доставку',
    _ => null,
  };

  factory ProcurementRequest.fromMap(Map<String, dynamic> map) {
    final supplier = _map(map['procurement_suppliers']);
    final rawItems = map['procurement_request_items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((item) => ProcurementRequestItem.fromMap(Map<String, dynamic>.from(item)))
              .toList()
        : <ProcurementRequestItem>[];
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return ProcurementRequest(
      id: map['id']?.toString() ?? '',
      companyId: map['company_id']?.toString() ?? '',
      objectId: map['object_id']?.toString() ?? '',
      objectName: map['object_name']?.toString() ?? '',
      supplierId: map['supplier_id']?.toString() ?? '',
      supplierName: supplier['name']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      status: map['status']?.toString() ?? 'submitted',
      priority: map['priority']?.toString() ?? 'normal',
      neededBy: _date(map['needed_by']),
      expectedDeliveryAt: _date(map['expected_delivery_at']),
      orderedAt: _date(map['ordered_at']),
      deliveredAt: _date(map['delivered_at']),
      totalAmount: _number(map['total_amount']),
      invoiceNumber: map['invoice_number']?.toString() ?? '',
      comment: map['comment']?.toString() ?? '',
      createdAt: _date(map['created_at']) ?? DateTime.now(),
      updatedAt: _date(map['updated_at']) ?? DateTime.now(),
      items: items,
    );
  }
}

class ProcurementDashboardData {
  final List<ProcurementRequest> requests;
  final List<ProcurementSupplier> suppliers;

  const ProcurementDashboardData({required this.requests, required this.suppliers});

  int get requiresAttention => requests.where((item) => item.status == 'submitted' || item.isOverdue).length;
  int get inPurchase => requests.where((item) => const {'approved', 'purchasing', 'ordered'}.contains(item.status)).length;
  int get inDelivery => requests.where((item) => item.status == 'in_delivery').length;
  int get delivered => requests.where((item) => item.status == 'delivered').length;
  double get openAmount => requests.where((item) => !item.isClosed).fold(0, (sum, item) => sum + item.totalAmount);
}

double _number(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _date(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : DateTime.tryParse(text)?.toLocal();
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}
