import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../features/company/data/company_repository.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/premium_ui.dart';
import '../data/procurement_repository.dart';
import '../models/procurement_models.dart';

class ProcurementRequestEditorScreen extends StatefulWidget {
  final AppUserProfile profile;
  final ProcurementRequest? request;

  const ProcurementRequestEditorScreen({
    super.key,
    required this.profile,
    this.request,
  });

  @override
  State<ProcurementRequestEditorScreen> createState() =>
      _ProcurementRequestEditorScreenState();
}

class _ProcurementRequestEditorScreenState
    extends State<ProcurementRequestEditorScreen> {
  late final TextEditingController titleController;
  late final TextEditingController invoiceController;
  late final TextEditingController commentController;
  late Future<void> initialLoad;
  List<CompanyObject> objects = const <CompanyObject>[];
  List<ProcurementSupplier> suppliers = const <ProcurementSupplier>[];
  final List<_ItemDraft> items = <_ItemDraft>[];
  String objectId = '';
  String supplierId = '';
  String priority = 'normal';
  DateTime? neededBy;
  bool saving = false;
  String? errorText;

  bool get editing => widget.request != null;

  @override
  void initState() {
    super.initState();
    final request = widget.request;
    titleController = TextEditingController(text: request?.title ?? '');
    invoiceController = TextEditingController(text: request?.invoiceNumber ?? '');
    commentController = TextEditingController(text: request?.comment ?? '');
    objectId = request?.objectId ?? '';
    supplierId = request?.supplierId ?? '';
    priority = request?.priority ?? 'normal';
    neededBy = request?.neededBy;
    if (request != null && request.items.isNotEmpty) {
      items.addAll(request.items.map(_ItemDraft.fromItem));
    } else {
      items.add(_ItemDraft());
    }
    initialLoad = loadDirectories();
  }

  @override
  void dispose() {
    titleController.dispose();
    invoiceController.dispose();
    commentController.dispose();
    for (final item in items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> loadDirectories() async {
    final values = await Future.wait<dynamic>([
      CompanyRepository.fetchObjects(widget.profile.activeCompanyId),
      ProcurementRepository.fetchSuppliers(
        companyId: widget.profile.activeCompanyId,
      ),
    ]);
    objects = values[0] as List<CompanyObject>;
    suppliers = values[1] as List<ProcurementSupplier>;
    if (objectId.isEmpty && objects.isNotEmpty) objectId = objects.first.id;
    if (supplierId.isNotEmpty &&
        !suppliers.any((supplier) => supplier.id == supplierId)) {
      supplierId = '';
    }
  }

  double number(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;
  }

  Future<void> pickNeededBy() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: neededBy ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3, 12, 31),
    );
    if (selected != null && mounted) setState(() => neededBy = selected);
  }

  void addItem() => setState(() => items.add(_ItemDraft()));

  void removeItem(int index) {
    if (items.length == 1) return;
    final removed = items.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  Future<void> save() async {
    if (saving) return;
    final cleanItems = items
        .where((item) => item.name.text.trim().isNotEmpty)
        .map(
          (item) => ProcurementRequestItem(
            name: item.name.text.trim(),
            quantity: number(item.quantity.text),
            unit: item.unit.text.trim(),
            estimatedUnitPrice: number(item.price.text),
            actualUnitPrice: item.actualUnitPrice,
            orderedQuantity: item.orderedQuantity,
            deliveredQuantity: item.deliveredQuantity,
            note: item.note.text.trim(),
          ),
        )
        .toList();
    if (titleController.text.trim().length < 2) {
      setState(() => errorText = 'Укажите название заявки');
      return;
    }
    if (objectId.isEmpty) {
      setState(() => errorText = 'Выберите объект');
      return;
    }
    if (cleanItems.isEmpty || cleanItems.any((item) => item.quantity <= 0)) {
      setState(() => errorText = 'Укажите позиции и количество');
      return;
    }

    setState(() {
      saving = true;
      errorText = null;
    });
    try {
      await ProcurementRepository.saveRequest(
        existing: widget.request,
        objectId: objectId,
        supplierId: supplierId,
        title: titleController.text,
        priority: priority,
        neededBy: neededBy,
        expectedDeliveryAt: widget.request?.expectedDeliveryAt,
        invoiceNumber: invoiceController.text,
        comment: commentController.text,
        items: cleanItems,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          errorText = error.toString().replaceFirst('Exception: ', '');
          saving = false;
        });
      }
    }
  }

  String dateText(DateTime? value) {
    if (value == null) return 'Не указан';
    return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
  }

  Widget itemCard(int index, _ItemDraft item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumWorkCard(
        radius: 20,
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Позиция ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
                if (items.length > 1)
                  IconButton(
                    tooltip: 'Удалить позицию',
                    onPressed: saving ? null : () => removeItem(index),
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
            TextField(
              controller: item.name,
              enabled: !saving,
              decoration: const InputDecoration(labelText: 'Материал / оборудование'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: item.quantity,
                    enabled: !saving,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Количество'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: item.unit,
                    enabled: !saving,
                    decoration: const InputDecoration(labelText: 'Единица'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: item.price,
              enabled: !saving,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Цена за единицу, ₽'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: item.note,
              enabled: !saving,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Примечание'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Заявка' : 'Новая заявка'),
        actions: [
          TextButton(
            onPressed: saving ? null : save,
            child: const Text('Сохранить'),
          ),
        ],
      ),
      body: PremiumBackdrop(
        child: FutureBuilder<void>(
          future: initialLoad,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Не удалось загрузить справочники: ${snapshot.error}'));
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
              children: [
                TextField(
                  controller: titleController,
                  enabled: !saving,
                  decoration: const InputDecoration(
                    labelText: 'Название заявки',
                    prefixIcon: Icon(Icons.assignment_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: objects.any((item) => item.id == objectId) ? objectId : null,
                  decoration: const InputDecoration(
                    labelText: 'Объект',
                    prefixIcon: Icon(Icons.apartment_rounded),
                  ),
                  items: objects
                      .map((object) => DropdownMenuItem(value: object.id, child: Text(object.name)))
                      .toList(),
                  onChanged: saving ? null : (value) => setState(() => objectId = value ?? ''),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: suppliers.any((item) => item.id == supplierId) ? supplierId : '',
                  decoration: const InputDecoration(
                    labelText: 'Поставщик',
                    prefixIcon: Icon(Icons.storefront_outlined),
                  ),
                  items: <DropdownMenuItem<String>>[
                    const DropdownMenuItem(value: '', child: Text('Пока не выбран')),
                    ...suppliers.map((supplier) => DropdownMenuItem(value: supplier.id, child: Text(supplier.name))),
                  ],
                  onChanged: saving ? null : (value) => setState(() => supplierId = value ?? ''),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: const InputDecoration(
                    labelText: 'Приоритет',
                    prefixIcon: Icon(Icons.priority_high_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Низкий')),
                    DropdownMenuItem(value: 'normal', child: Text('Обычный')),
                    DropdownMenuItem(value: 'high', child: Text('Высокий')),
                    DropdownMenuItem(value: 'urgent', child: Text('Срочно')),
                  ],
                  onChanged: saving ? null : (value) => setState(() => priority = value ?? 'normal'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: AppAdaptivePalette.border),
                  ),
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('Нужно к дате'),
                  trailing: Text(dateText(neededBy), style: const TextStyle(fontWeight: FontWeight.w800)),
                  onTap: saving ? null : pickNeededBy,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: invoiceController,
                  enabled: !saving,
                  decoration: const InputDecoration(
                    labelText: 'Счёт / накладная',
                    prefixIcon: Icon(Icons.receipt_long_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: commentController,
                  enabled: !saving,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Комментарий',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(child: Text('Состав заявки', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                    TextButton.icon(onPressed: saving ? null : addItem, icon: const Icon(Icons.add_rounded), label: const Text('Добавить')),
                  ],
                ),
                const SizedBox(height: 8),
                ...List<Widget>.generate(items.length, (index) => itemCard(index, items[index])),
                if (errorText != null) ...[
                  const SizedBox(height: 4),
                  Text(errorText!, textAlign: TextAlign.center, style: TextStyle(color: AppAdaptivePalette.danger, fontWeight: FontWeight.w800)),
                ],
                const SizedBox(height: 16),
                PremiumActionButton(
                  onPressed: saving ? null : save,
                  icon: Icons.save_outlined,
                  label: editing ? 'Сохранить' : 'Создать заявку',
                  isLoading: saving,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ItemDraft {
  final TextEditingController name;
  final TextEditingController quantity;
  final TextEditingController unit;
  final TextEditingController price;
  final TextEditingController note;
  final double actualUnitPrice;
  final double orderedQuantity;
  final double deliveredQuantity;

  _ItemDraft({
    String nameValue = '',
    String quantityValue = '1',
    String unitValue = 'шт.',
    String priceValue = '',
    String noteValue = '',
    this.actualUnitPrice = 0,
    this.orderedQuantity = 0,
    this.deliveredQuantity = 0,
  })  : name = TextEditingController(text: nameValue),
        quantity = TextEditingController(text: quantityValue),
        unit = TextEditingController(text: unitValue),
        price = TextEditingController(text: priceValue),
        note = TextEditingController(text: noteValue);

  factory _ItemDraft.fromItem(ProcurementRequestItem item) => _ItemDraft(
        nameValue: item.name,
        quantityValue: _format(item.quantity),
        unitValue: item.unit,
        priceValue: item.estimatedUnitPrice == 0 ? '' : _format(item.estimatedUnitPrice),
        noteValue: item.note,
        actualUnitPrice: item.actualUnitPrice,
        orderedQuantity: item.orderedQuantity,
        deliveredQuantity: item.deliveredQuantity,
      );

  static String _format(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');

  void dispose() {
    name.dispose();
    quantity.dispose();
    unit.dispose();
    price.dispose();
    note.dispose();
  }
}
