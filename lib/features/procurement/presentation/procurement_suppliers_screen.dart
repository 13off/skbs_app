import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../data/app_data_sync.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/procurement_repository.dart';
import '../models/procurement_models.dart';

class ProcurementSuppliersScreen extends StatefulWidget {
  final AppUserProfile profile;

  const ProcurementSuppliersScreen({super.key, required this.profile});

  @override
  State<ProcurementSuppliersScreen> createState() => _ProcurementSuppliersScreenState();
}

class _ProcurementSuppliersScreenState extends State<ProcurementSuppliersScreen> {
  late Future<List<ProcurementSupplier>> future;
  StreamSubscription<AppDataChange>? subscription;

  @override
  void initState() {
    super.initState();
    future = load();
    subscription = AppDataSync.changes.listen((change) {
      if (change.affects(AppDataDomain.procurement) && mounted) refresh();
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  Future<List<ProcurementSupplier>> load() => ProcurementRepository.fetchSuppliers(
        companyId: widget.profile.activeCompanyId,
      );

  Future<void> refresh() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  Future<void> edit([ProcurementSupplier? supplier]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SupplierEditor(
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
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Скрыть')),
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

  Widget card(ProcurementSupplier supplier) {
    final contact = <String>[
      if (supplier.contactName.isNotEmpty) supplier.contactName,
      if (supplier.phone.isNotEmpty) supplier.phone,
      if (supplier.email.isNotEmpty) supplier.email,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumPressable(
        onTap: () => edit(supplier),
        borderRadius: BorderRadius.circular(22),
        child: PremiumWorkCard(
          radius: 22,
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppAdaptivePalette.surfaceSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.storefront_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    if (contact.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(contact, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppAdaptivePalette.textMuted, fontWeight: FontWeight.w600)),
                    ],
                    if (supplier.inn.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text('ИНН ${supplier.inn}', style: TextStyle(color: AppAdaptivePalette.textMuted, fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') edit(supplier);
                  if (value == 'archive') archive(supplier);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Редактировать')),
                  PopupMenuItem(value: 'archive', child: Text('Скрыть')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Поставщики',
      headerTrailing: IconButton(
        tooltip: 'Добавить поставщика',
        onPressed: edit,
        icon: const Icon(Icons.add_rounded),
      ),
      child: FutureBuilder<List<ProcurementSupplier>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: PremiumActionButton(onPressed: refresh, icon: Icons.refresh_rounded, label: 'Повторить'));
          }
          final rows = snapshot.data ?? const <ProcurementSupplier>[];
          if (rows.isEmpty) {
            return Center(child: PremiumActionButton(onPressed: edit, icon: Icons.add_rounded, label: 'Добавить поставщика'));
          }
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 36),
              itemCount: rows.length,
              itemBuilder: (_, index) => card(rows[index]),
            ),
          );
        },
      ),
    );
  }
}

class _SupplierEditor extends StatefulWidget {
  final String companyId;
  final ProcurementSupplier? supplier;

  const _SupplierEditor({required this.companyId, this.supplier});

  @override
  State<_SupplierEditor> createState() => _SupplierEditorState();
}

class _SupplierEditorState extends State<_SupplierEditor> {
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
      if (mounted) {
        setState(() {
          saving = false;
          errorText = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
      padding: EdgeInsets.fromLTRB(18, 18, 18, 24 + bottom),
      decoration: BoxDecoration(
        color: AppAdaptivePalette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text(widget.supplier == null ? 'Новый поставщик' : 'Поставщик', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          TextField(controller: name, enabled: !saving, decoration: const InputDecoration(labelText: 'Название')),
          const SizedBox(height: 10),
          TextField(controller: inn, enabled: !saving, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ИНН')),
          const SizedBox(height: 10),
          TextField(controller: contact, enabled: !saving, decoration: const InputDecoration(labelText: 'Контактное лицо')),
          const SizedBox(height: 10),
          TextField(controller: phone, enabled: !saving, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Телефон')),
          const SizedBox(height: 10),
          TextField(controller: email, enabled: !saving, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 10),
          TextField(controller: comment, enabled: !saving, maxLines: 3, decoration: const InputDecoration(labelText: 'Комментарий')),
          if (errorText != null) ...[
            const SizedBox(height: 12),
            Text(errorText!, textAlign: TextAlign.center, style: TextStyle(color: AppAdaptivePalette.danger, fontWeight: FontWeight.w800)),
          ],
          const SizedBox(height: 18),
          PremiumActionButton(onPressed: saving ? null : save, icon: Icons.save_outlined, label: 'Сохранить', isLoading: saving),
        ],
      ),
    );
  }
}
