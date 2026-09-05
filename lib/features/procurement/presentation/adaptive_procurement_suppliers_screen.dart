import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../app/app_ui_tokens.dart';
import '../../../data/app_data_sync.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/procurement_repository.dart';
import '../models/procurement_models.dart';
import 'procurement_suppliers_screen.dart';

class AdaptiveProcurementSuppliersScreen extends StatelessWidget {
  final AppUserProfile profile;

  const AdaptiveProcurementSuppliersScreen({
    super.key,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AppUi.desktopBreakpoint) {
          return ProcurementSuppliersScreen(profile: profile);
        }
        return _DesktopProcurementSuppliersScreen(profile: profile);
      },
    );
  }
}

class _DesktopProcurementSuppliersScreen extends StatefulWidget {
  final AppUserProfile profile;

  const _DesktopProcurementSuppliersScreen({required this.profile});

  @override
  State<_DesktopProcurementSuppliersScreen> createState() =>
      _DesktopProcurementSuppliersScreenState();
}

class _DesktopProcurementSuppliersScreenState
    extends State<_DesktopProcurementSuppliersScreen> {
  final searchController = TextEditingController();
  late Future<List<ProcurementSupplier>> future;
  StreamSubscription<AppDataChange>? subscription;

  @override
  void initState() {
    super.initState();
    future = load();
    subscription = AppDataSync.changes.listen((change) {
      if (mounted && change.affects(AppDataDomain.procurement)) {
        unawaited(refresh());
      }
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<List<ProcurementSupplier>> load() {
    return ProcurementRepository.fetchSuppliers(
      companyId: widget.profile.activeCompanyId,
    );
  }

  Future<void> refresh() async {
    final next = load();
    if (mounted) setState(() => future = next);
    await next;
  }

  Future<void> edit([ProcurementSupplier? supplier]) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _DesktopSupplierEditorDialog(
        companyId: widget.profile.activeCompanyId,
        supplier: supplier,
      ),
    );
    if (changed == true && mounted) await refresh();
  }

  Future<void> archive(ProcurementSupplier supplier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Скрыть «${supplier.name}»?'),
        content: const Text(
          'Поставщик исчезнет из активного списка, но история заявок сохранится.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Скрыть'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ProcurementRepository.archiveSupplier(
      companyId: widget.profile.activeCompanyId,
      supplierId: supplier.id,
    );
    if (mounted) await refresh();
  }

  List<ProcurementSupplier> visible(List<ProcurementSupplier> rows) {
    final query = searchController.text.trim().toLowerCase();
    final result = rows.where((supplier) {
      if (query.isEmpty) return true;
      return <String>[
        supplier.name,
        supplier.inn,
        supplier.contactName,
        supplier.phone,
        supplier.email,
        supplier.comment,
      ].join(' ').toLowerCase().contains(query);
    }).toList();
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  Widget table(List<ProcurementSupplier> rows) {
    if (rows.isEmpty) {
      return PremiumWorkCard(
        radius: 22,
        padding: const EdgeInsets.symmetric(vertical: 54, horizontal: 24),
        child: Column(
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 42,
              color: AppAdaptivePalette.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              'Поставщики не найдены',
              style: TextStyle(
                color: AppAdaptivePalette.textMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    return PremiumWorkCard(
      radius: 24,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth < 1050
                ? 1050.0
                : constraints.maxWidth;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                child: DataTable(
                  showCheckboxColumn: false,
                  headingRowHeight: 50,
                  dataRowMinHeight: 62,
                  dataRowMaxHeight: 74,
                  horizontalMargin: 18,
                  columnSpacing: 22,
                  headingTextStyle: TextStyle(
                    color: AppAdaptivePalette.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                  columns: const [
                    DataColumn(label: Text('Поставщик')),
                    DataColumn(label: Text('ИНН')),
                    DataColumn(label: Text('Контакт')),
                    DataColumn(label: Text('Телефон')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('Комментарий')),
                    DataColumn(label: Text('Действия')),
                  ],
                  rows: rows.map((supplier) {
                    return DataRow(
                      onSelectChanged: (_) => edit(supplier),
                      cells: [
                        DataCell(
                          Text(
                            supplier.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        DataCell(Text(supplier.inn.isEmpty ? '—' : supplier.inn)),
                        DataCell(
                          Text(
                            supplier.contactName.isEmpty
                                ? '—'
                                : supplier.contactName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DataCell(Text(supplier.phone.isEmpty ? '—' : supplier.phone)),
                        DataCell(
                          Text(
                            supplier.email.isEmpty ? '—' : supplier.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 240),
                            child: Text(
                              supplier.comment.isEmpty ? '—' : supplier.comment,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: AppAdaptivePalette.textMuted),
                            ),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Редактировать',
                                onPressed: () => edit(supplier),
                                icon: const Icon(Icons.edit_outlined, size: 19),
                              ),
                              IconButton(
                                tooltip: 'Скрыть',
                                onPressed: () => archive(supplier),
                                icon: const Icon(Icons.visibility_off_outlined, size: 19),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProcurementSupplier>>(
      future: future,
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <ProcurementSupplier>[];
        final rows = visible(all);
        final children = <Widget>[];

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          children.add(
            const PremiumWorkCard(
              radius: 22,
              padding: EdgeInsets.symmetric(vertical: 72),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        } else if (snapshot.hasError) {
          children.add(
            PremiumWorkCard(
              radius: 22,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    'Не удалось загрузить поставщиков',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString().replaceFirst('Exception: ', ''),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppAdaptivePalette.textMuted),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          );
        } else {
          children.addAll([
            PremiumWorkCard(
              radius: 22,
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Название, ИНН, контакт, телефон или email',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppAdaptivePalette.surfaceSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Активных: ${all.length}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Обновить',
                    onPressed: refresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            table(rows),
          ]);
        }

        return AppPage(
          title: 'Поставщики',
          subtitle: 'Контакты и реквизиты поставщиков компании',
          onRefresh: refresh,
          headerTrailing: FilledButton.icon(
            onPressed: edit,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Новый поставщик'),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        );
      },
    );
  }
}

class _DesktopSupplierEditorDialog extends StatefulWidget {
  final String companyId;
  final ProcurementSupplier? supplier;

  const _DesktopSupplierEditorDialog({
    required this.companyId,
    this.supplier,
  });

  @override
  State<_DesktopSupplierEditorDialog> createState() =>
      _DesktopSupplierEditorDialogState();
}

class _DesktopSupplierEditorDialogState
    extends State<_DesktopSupplierEditorDialog> {
  late final TextEditingController name;
  late final TextEditingController inn;
  late final TextEditingController contact;
  late final TextEditingController phone;
  late final TextEditingController email;
  late final TextEditingController comment;
  bool saving = false;
  String? errorText;

  @override
  void initState() {
    super.initState();
    final supplier = widget.supplier;
    name = TextEditingController(text: supplier?.name ?? '');
    inn = TextEditingController(text: supplier?.inn ?? '');
    contact = TextEditingController(text: supplier?.contactName ?? '');
    phone = TextEditingController(text: supplier?.phone ?? '');
    email = TextEditingController(text: supplier?.email ?? '');
    comment = TextEditingController(text: supplier?.comment ?? '');
  }

  @override
  void dispose() {
    name.dispose();
    inn.dispose();
    contact.dispose();
    phone.dispose();
    email.dispose();
    comment.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    if (name.text.trim().length < 2) {
      setState(() => errorText = 'Укажите название поставщика');
      return;
    }
    setState(() {
      saving = true;
      errorText = null;
    });
    try {
      await ProcurementRepository.saveSupplier(
        companyId: widget.companyId,
        existing: widget.supplier,
        name: name.text,
        inn: inn.text,
        contactName: contact.text,
        phone: phone.text,
        email: email.text,
        comment: comment.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        saving = false;
        errorText = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Widget field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      enabled: !saving,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.supplier == null
                          ? 'Новый поставщик'
                          : 'Поставщик',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      field(name, 'Название'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: field(
                              inn,
                              'ИНН',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: field(contact, 'Контактное лицо')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: field(
                              phone,
                              'Телефон',
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: field(
                              email,
                              'Email',
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      field(comment, 'Комментарий', maxLines: 4),
                      if (errorText != null) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            errorText!,
                            style: TextStyle(
                              color: AppAdaptivePalette.danger,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: saving ? null : () => Navigator.pop(context),
                    child: const Text('Отмена'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: saving ? null : save,
                    icon: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(saving ? 'Сохранение…' : 'Сохранить'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
