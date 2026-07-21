import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
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

  Color statusColor(String status) {
    return switch (status) {
      'completed' => const Color(0xFF28704E),
      'failed' => const Color(0xFF874540),
      'cancelled' => const Color(0xFF6C7075),
      'confirmed' => const Color(0xFF705D28),
      _ => AppColors.textMuted,
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
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
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
                        color: AppColors.border,
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
                          style: const TextStyle(
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
                  _detailLine('Статус', statusTitle(record.status)),
                  _detailLine('Тип', AiActionAuditRecord.actionTypeTitle(record.actionType)),
                  _detailLine('Пользователь', record.actorLabel),
                  _detailLine('Дата', formatDate(record.createdAt)),
                  _detailLine(
                    'Объект',
                    record.objectName.isEmpty ? 'Все доступные объекты' : record.objectName,
                  ),
                  if (record.confirmedAt != null)
                    _detailLine('Подтверждено', formatDate(record.confirmedAt!)),
                  if (record.completedAt != null)
                    _detailLine('Завершено', formatDate(record.completedAt!)),
                  if (record.targetEntityType.isNotEmpty)
                    _detailLine('Результат', record.targetEntityType),
                  if (record.targetEntityId.isNotEmpty)
                    _detailLine('ID результата', record.targetEntityId),
                  if (record.errorText.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _warningCard(record.errorText),
                  ],
                  const SizedBox(height: 22),
                  const Text(
                    'Точное предложение',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  if (record.payload.isEmpty)
                    const Text('Данные предложения отсутствуют')
                  else
                    ...record.payload.entries.map(
                      (entry) => _detailLine(entry.key, payloadValue(entry.value)),
                    ),
                  const SizedBox(height: 16),
                  SelectableText(
                    'Action ID: ${record.actionId}\nAudit ID: ${record.id}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
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

  Widget _detailLine(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _warningCard(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0EF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8C7C4)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF874540),
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
                    DropdownMenuItem(value: 'proposed', child: Text('Предложено')),
                    DropdownMenuItem(value: 'confirmed', child: Text('Подтверждено')),
                    DropdownMenuItem(value: 'completed', child: Text('Выполнено')),
                    DropdownMenuItem(value: 'cancelled', child: Text('Отменено')),
                    DropdownMenuItem(value: 'failed', child: Text('Ошибка')),
                  ],
                  onChanged: (value) => setState(() => statusFilter = value ?? 'all'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: typeFilter,
                  decoration: const InputDecoration(labelText: 'Действие'),
                  items: [
                    const DropdownMenuItem(value: 'all', child: Text('Все действия')),
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
                  onChanged: (value) => setState(() => typeFilter = value ?? 'all'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildRecord(AiActionAuditRecord record) {
    final color = statusColor(record.status);
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
                  color: color.withValues(alpha: .10),
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
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${statusTitle(record.status)} • ${formatDate(record.createdAt)}',
                      style: TextStyle(color: color, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${record.actorLabel}${record.objectName.isEmpty ? '' : ' • ${record.objectName}'}',
                      style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600),
                    ),
                    if (record.errorText.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        record.errorText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF874540), fontWeight: FontWeight.w700),
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
    return Scaffold(
      appBar: AppBar(
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
                  _warningCard(errorText!)
                else if (visible.isEmpty)
                  const PremiumWorkCard(
                    radius: 22,
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'В журнале пока нет подходящих действий.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700),
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
