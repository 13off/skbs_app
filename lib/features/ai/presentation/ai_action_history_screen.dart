import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../widgets/premium_ui.dart';
import '../data/ai_action_audit_repository.dart';

class AiActionHistoryScreen extends StatefulWidget {
  final AppUserProfile profile;

  const AiActionHistoryScreen({super.key, required this.profile});

  @override
  State<AiActionHistoryScreen> createState() => _AiActionHistoryScreenState();
}

class _AiActionHistoryScreenState extends State<AiActionHistoryScreen> {
  final TextEditingController searchController = TextEditingController();
  List<AiActionAuditRecord> records = const <AiActionAuditRecord>[];
  bool loading = true;
  String? errorText;
  String statusFilter = 'all';
  String typeFilter = 'all';

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      errorText = null;
    });
    try {
      final result = await AiActionAuditRepository.fetchHistory(
        companyId: widget.profile.activeCompanyId,
      );
      if (!mounted) return;
      setState(() {
        records = result;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorText = error.toString().replaceFirst('Exception: ', '').trim();
      });
    }
  }

  List<AiActionAuditRecord> get visibleRecords {
    final query = searchController.text.trim().toLowerCase();
    return records.where((record) {
      if (statusFilter != 'all' && record.status != statusFilter) return false;
      if (typeFilter != 'all' && record.actionType != typeFilter) return false;
      if (query.isEmpty) return true;
      final haystack = <String>[
        record.title,
        record.actorLabel,
        record.objectName,
        record.actionType,
        record.targetEntityType,
        record.targetEntityId,
        record.errorText,
        jsonEncode(record.payload),
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList(growable: false);
  }

  Set<String> get actionTypes => records
      .map((record) => record.actionType)
      .where((type) => type.isNotEmpty)
      .toSet();

  String statusTitle(String status) {
    return switch (status) {
      'proposed' => 'Предложено',
      'confirmed' => 'Подтверждено',
      'completed' => 'Выполнено',
      'cancelled' => 'Отменено',
      'failed' => 'Ошибка',
      _ => status,
    };
  }

  IconData statusIcon(String status) {
    return switch (status) {
      'completed' => Icons.verified_rounded,
      'failed' => Icons.error_outline_rounded,
      'cancelled' => Icons.cancel_outlined,
      'confirmed' => Icons.fact_check_outlined,
      _ => Icons.schedule_outlined,
    };
  }

  Color statusColor(String status, ColorScheme scheme) {
    return switch (status) {
      'completed' => scheme.primary,
      'failed' => scheme.error,
      'cancelled' => scheme.onSurfaceVariant,
      'confirmed' => scheme.tertiary,
      _ => scheme.onSurfaceVariant,
    };
  }

  String formatDate(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.${local.year} • $hour:$minute';
  }

  String payloadValue(Object? value) {
    if (value == null) return '—';
    if (value is Iterable) return value.join(', ');
    if (value is Map) return jsonEncode(value);
    final text = value.toString().trim();
    return text.isEmpty ? '—' : text;
  }

  Future<void> openDetails(AiActionAuditRecord record) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: .78,
          minChildSize: .48,
          maxChildSize: .94,
          builder: (context, scrollController) {
            final scheme = Theme.of(context).colorScheme;
            return Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          record.title,
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontSize: 23,
                            height: 1.15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _detailLine(
                    'Статус',
                    statusTitle(record.status),
                    scheme,
                  ),
                  _detailLine(
                    'Тип',
                    AiActionAuditRecord.actionTypeTitle(record.actionType),
                    scheme,
                  ),
                  _detailLine('Пользователь', record.actorLabel, scheme),
                  _detailLine('Дата', formatDate(record.createdAt), scheme),
                  _detailLine(
                    'Объект',
                    record.objectName.isEmpty
                        ? 'Все доступные объекты'
                        : record.objectName,
                    scheme,
                  ),
                  if (record.confirmedAt != null)
                    _detailLine(
                      'Подтверждено',
                      formatDate(record.confirmedAt!),
                      scheme,
                    ),
                  if (record.completedAt != null)
                    _detailLine(
                      'Завершено',
                      formatDate(record.completedAt!),
                      scheme,
                    ),
                  if (record.targetEntityType.isNotEmpty)
                    _detailLine(
                      'Результат',
                      record.targetEntityType,
                      scheme,
                    ),
                  if (record.targetEntityId.isNotEmpty)
                    _detailLine(
                      'ID результата',
                      record.targetEntityId,
                      scheme,
                    ),
                  if (record.errorText.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _warningCard(record.errorText, scheme),
                  ],
                  const SizedBox(height: 22),
                  Text(
                    'Точное предложение',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (record.payload.isEmpty)
                    Text(
                      'Данные предложения отсутствуют',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    )
                  else
                    ...record.payload.entries.map(
                      (entry) => _detailLine(
                        entry.key,
                        payloadValue(entry.value),
                        scheme,
                      ),
                    ),
                  const SizedBox(height: 16),
                  SelectableText(
                    'Action ID: ${record.actionId}\nAudit ID: ${record.id}',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailLine(String title, String value, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              title,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _warningCard(String text, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.error.withValues(alpha: .35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: scheme.onErrorContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget buildFilters() {
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Поиск по журналу',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: statusFilter,
                  decoration: const InputDecoration(labelText: 'Статус'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Все статусы')),
                    DropdownMenuItem(
                      value: 'proposed',
                      child: Text('Предложено'),
                    ),
                    DropdownMenuItem(
                      value: 'confirmed',
                      child: Text('Подтверждено'),
                    ),
                    DropdownMenuItem(
                      value: 'completed',
                      child: Text('Выполнено'),
                    ),
                    DropdownMenuItem(
                      value: 'cancelled',
                      child: Text('Отменено'),
                    ),
                    DropdownMenuItem(value: 'failed', child: Text('Ошибка')),
                  ],
                  onChanged: (value) =>
                      setState(() => statusFilter = value ?? 'all'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: typeFilter,
                  decoration: const InputDecoration(labelText: 'Действие'),
                  items: [
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text('Все действия'),
                    ),
                    ...actionTypes.map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(
                          AiActionAuditRecord.actionTypeTitle(type),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => typeFilter = value ?? 'all'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildRecord(AiActionAuditRecord record) {
    final scheme = Theme.of(context).colorScheme;
    final color = statusColor(record.status, scheme);
    return PremiumWorkCard(
      radius: 22,
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => openDetails(record),
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(statusIcon(record.status), color: color),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.title,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${statusTitle(record.status)} • ${formatDate(record.createdAt)}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${record.actorLabel}${record.objectName.isEmpty ? '' : ' • ${record.objectName}'}',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (record.errorText.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        record.errorText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = visibleRecords;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Журнал действий ИИ'),
        actions: [
          IconButton(
            onPressed: loading ? null : load,
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: PremiumWorkBackdrop(
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
              children: [
                buildFilters(),
                const SizedBox(height: 14),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (errorText != null)
                  _warningCard(errorText!, scheme)
                else if (visible.isEmpty)
                  PremiumWorkCard(
                    radius: 22,
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'В журнале пока нет подходящих действий.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  ...visible.map(
                    (record) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: buildRecord(record),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
