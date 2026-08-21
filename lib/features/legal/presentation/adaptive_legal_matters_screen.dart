import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../data/app_data_sync.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/premium_ui.dart';
import '../../shared/presentation/specialist_desktop_table.dart';
import '../../shared/presentation/specialist_desktop_ui.dart';
import '../data/legal_process_repository.dart';
import '../data/legal_repository.dart';
import '../models/legal_models.dart';
import 'legal_matters_screen.dart';
import '../../../navigation/app_page_route.dart';

class AdaptiveLegalMattersScreen extends StatelessWidget {
  final bool highRiskOnly;
  final bool managerOnly;
  final AppUserProfile? profile;

  const AdaptiveLegalMattersScreen({
    super.key,
    this.highRiskOnly = false,
    this.managerOnly = false,
    this.profile,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!kIsWeb || constraints.maxWidth < specialistDesktopBreakpoint) {
          return LegalMattersScreen(
            highRiskOnly: highRiskOnly,
            managerOnly: managerOnly,
            profile: profile,
          );
        }
        return _DesktopLegalMattersScreen(
          highRiskOnly: highRiskOnly,
          managerOnly: managerOnly,
          profile: profile,
        );
      },
    );
  }
}

class _DesktopLegalMattersScreen extends StatefulWidget {
  final bool highRiskOnly;
  final bool managerOnly;
  final AppUserProfile? profile;

  const _DesktopLegalMattersScreen({
    required this.highRiskOnly,
    required this.managerOnly,
    required this.profile,
  });

  @override
  State<_DesktopLegalMattersScreen> createState() =>
      _DesktopLegalMattersScreenState();
}

class _DesktopLegalMattersScreenState
    extends State<_DesktopLegalMattersScreen> {
  final searchController = TextEditingController();
  late Future<List<LegalMatter>> future;
  StreamSubscription<AppDataChange>? subscription;
  bool attentionOnly = false;
  String? type;
  String? risk;
  String? status;
  String? objectName;

  bool get managerMode => widget.profile?.isAdmin == true;

  @override
  void initState() {
    super.initState();
    attentionOnly = widget.highRiskOnly || widget.managerOnly;
    if (widget.highRiskOnly) risk = LegalRiskLevel.high;
    future = load();
    subscription = AppDataSync.changes.listen((change) {
      if (mounted && change.affects(AppDataDomain.legal)) refresh();
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Future<List<LegalMatter>> load() async {
    var matters = await LegalRepository.fetchMatters(
      search: searchController.text,
      attentionOnly: attentionOnly,
    );
    if (widget.highRiskOnly)
      matters = matters.where((item) => item.isHighRisk).toList();
    if (widget.managerOnly)
      matters = matters.where((item) => item.needsManager).toList();
    return matters;
  }

  Future<void> refresh() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  Future<void> openEditor([LegalMatter? matter]) async {
    final saved = await Navigator.push<bool>(
      context,
      AppPageRoute<bool>(
        builder: (_) => LegalMatterEditorScreen(matter: matter),
      ),
    );
    if (mounted && saved == true) await refresh();
  }

  Future<void> openDetails(LegalMatter matter) async {
    await Navigator.push<void>(
      context,
      AppPageRoute<void>(
        builder: (_) =>
            LegalMatterDetailsScreen(matter: matter, canDecide: managerMode),
      ),
    );
    if (mounted) await refresh();
  }

  bool typeMatches(LegalMatter matter) {
    final selected = type;
    if (selected == null) return true;
    if (selected == legalCourtMatterType) return legalMatterIsCourt(matter);
    if (selected == LegalMatterType.dispute) {
      return matter.matterType == LegalMatterType.dispute &&
          !legalMatterIsCourt(matter);
    }
    return matter.matterType == selected;
  }

  List<LegalMatter> filtered(List<LegalMatter> matters) {
    final objects = matters
        .map((item) => item.objectName.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    final safeObject = objectName != null && objects.contains(objectName)
        ? objectName
        : null;

    final result = matters.where((matter) {
      if (!typeMatches(matter)) return false;
      if (risk != null && matter.riskLevel != risk) return false;
      if (status != null && matter.status != status) return false;
      if (safeObject != null && matter.objectName.trim() != safeObject)
        return false;
      return true;
    }).toList();

    result.sort((a, b) {
      int rank(LegalMatter item) {
        if (item.riskLevel == LegalRiskLevel.critical) return 0;
        if (item.isOverdue) return 1;
        if (item.riskLevel == LegalRiskLevel.high || item.needsManager)
          return 2;
        return 3;
      }

      final rankCompare = rank(a).compareTo(rank(b));
      if (rankCompare != 0) return rankCompare;
      return (a.dueAt ?? DateTime(9999)).compareTo(b.dueAt ?? DateTime(9999));
    });
    return result;
  }

  List<String> objectOptions(List<LegalMatter> matters) {
    return matters
        .map((item) => item.objectName.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  String date(DateTime? value) {
    if (value == null) return 'Без срока';
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
  }

  Color riskColor(LegalMatter matter) {
    if (matter.riskLevel == LegalRiskLevel.critical || matter.isOverdue)
      return specialistDanger;
    if (matter.riskLevel == LegalRiskLevel.high || matter.needsManager)
      return specialistWarning;
    if (matter.riskLevel == LegalRiskLevel.low) return specialistSuccess;
    return specialistMuted;
  }

  Widget filters(List<LegalMatter> matters) {
    final objects = objectOptions(matters);
    final typeValues = <String>[
      legalCourtMatterType,
      LegalMatterType.claim,
      LegalMatterType.violation,
      LegalMatterType.dispute,
      LegalMatterType.contractProblem,
      LegalMatterType.employeeRequest,
      LegalMatterType.penaltyRisk,
      LegalMatterType.managerDecision,
      LegalMatterType.task,
      LegalMatterType.other,
    ];

    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 420,
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Название, сотрудник, объект или контрагент',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  tooltip: 'Найти',
                  onPressed: refresh,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
              onSubmitted: (_) => refresh(),
            ),
          ),
          SizedBox(
            width: 205,
            child: DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Тип дела'),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Все дела'),
                ),
                ...typeValues.map(
                  (value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value == legalCourtMatterType
                          ? 'Судебные дела'
                          : LegalMatterType.title(value),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => type = value),
            ),
          ),
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<String>(
              initialValue: risk,
              decoration: const InputDecoration(labelText: 'Риск'),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Все риски'),
                ),
                ...LegalRiskLevel.values.map(
                  (value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(LegalRiskLevel.title(value)),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => risk = value),
            ),
          ),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<String>(
              initialValue: status,
              decoration: const InputDecoration(labelText: 'Статус'),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Все статусы'),
                ),
                ...LegalMatterStatus.values.map(
                  (value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(LegalMatterStatus.title(value)),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => status = value),
            ),
          ),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              initialValue: objects.contains(objectName) ? objectName : null,
              decoration: const InputDecoration(labelText: 'Объект'),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Все объекты'),
                ),
                ...objects.map(
                  (value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => objectName = value),
            ),
          ),
          if (!widget.highRiskOnly && !widget.managerOnly)
            FilterChip(
              selected: attentionOnly,
              avatar: const Icon(Icons.priority_high_rounded, size: 18),
              label: const Text('Требуют внимания'),
              onSelected: (value) {
                setState(() {
                  attentionOnly = value;
                  future = load();
                });
              },
            ),
        ],
      ),
    );
  }

  Widget summary(List<LegalMatter> matters) {
    final open = matters
        .where(
          (item) =>
              item.status != LegalMatterStatus.closed &&
              item.status != LegalMatterStatus.resolved,
        )
        .length;
    final courts = matters.where(legalMatterIsCourt).length;
    final claims = matters
        .where((item) => item.matterType == LegalMatterType.claim)
        .length;
    final overdue = matters.where((item) => item.isOverdue).length;
    final manager = matters.where((item) => item.needsManager).length;

    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _MatterSummary(
            icon: Icons.gavel_outlined,
            label: 'Открытые',
            value: '$open',
          ),
          _MatterSummary(
            icon: Icons.account_balance_outlined,
            label: 'Суды',
            value: '$courts',
          ),
          _MatterSummary(
            icon: Icons.outgoing_mail,
            label: 'Претензии',
            value: '$claims',
          ),
          _MatterSummary(
            icon: Icons.event_busy_outlined,
            label: 'Просрочены',
            value: '$overdue',
            color: overdue > 0 ? specialistDanger : specialistMuted,
          ),
          _MatterSummary(
            icon: Icons.approval_outlined,
            label: 'Решение руководителя',
            value: '$manager',
            color: manager > 0 ? specialistWarning : specialistMuted,
          ),
        ],
      ),
    );
  }

  Widget table(List<LegalMatter> matters) {
    return SpecialistDesktopTable(
      minWidth: 1240,
      columns: const [
        SpecialistTableColumn('Дело', flex: 4),
        SpecialistTableColumn('Тип', flex: 2),
        SpecialistTableColumn('Риск', flex: 2),
        SpecialistTableColumn('Статус', flex: 2),
        SpecialistTableColumn('Связи', flex: 3),
        SpecialistTableColumn('Срок', flex: 2),
        SpecialistTableColumn('Ответственный', flex: 2),
        SpecialistTableColumn('Руководитель', flex: 2),
      ],
      rows: matters.map((matter) {
        final links = <String>[
          if (matter.employeeName.isNotEmpty) matter.employeeName,
          if (matter.objectName.isNotEmpty) matter.objectName,
          if (matter.counterpartyName.isNotEmpty) matter.counterpartyName,
        ];
        return SpecialistTableRowData(
          onTap: () => openDetails(matter),
          cells: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                specialistCellText(matter.title, weight: FontWeight.w900),
                if (matter.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  specialistCellText(
                    matter.description,
                    color: specialistMuted,
                    weight: FontWeight.w600,
                    maxLines: 1,
                  ),
                ],
              ],
            ),
            specialistCellText(legalMatterDisplayType(matter), maxLines: 1),
            SpecialistStatusPill(
              label: matter.riskTitle,
              color: riskColor(matter),
            ),
            SpecialistStatusPill(
              label: matter.statusTitle,
              color:
                  matter.status == LegalMatterStatus.closed ||
                      matter.status == LegalMatterStatus.resolved
                  ? specialistSuccess
                  : specialistMuted,
            ),
            specialistCellText(
              links.isEmpty ? 'Не привязано' : links.join(' • '),
              color: specialistMuted,
            ),
            SpecialistStatusPill(
              label: date(matter.dueAt),
              color: matter.isOverdue ? specialistDanger : specialistMuted,
            ),
            specialistCellText(
              matter.responsibleName.isEmpty
                  ? 'Не назначен'
                  : matter.responsibleName,
              color: specialistMuted,
            ),
            matter.needsManager
                ? SpecialistStatusPill(
                    label: 'Требуется решение',
                    color: specialistWarning,
                  )
                : specialistCellText(
                    matter.decisionStatus == 'approved'
                        ? 'Согласовано'
                        : matter.decisionStatus == 'rejected'
                        ? 'Отклонено'
                        : 'Не требуется',
                    color: specialistMuted,
                    maxLines: 1,
                  ),
          ],
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LegalMatter>>(
      future: future,
      builder: (context, snapshot) {
        final source = snapshot.data ?? const <LegalMatter>[];
        final visible = filtered(source);
        final children = <Widget>[filters(source), const SizedBox(height: 16)];

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          children.add(
            const SpecialistMessageCard(
              icon: Icons.gavel_outlined,
              title: 'Загружаем дела',
              loading: true,
            ),
          );
        } else if (snapshot.hasError) {
          children.add(
            SpecialistMessageCard(
              icon: Icons.cloud_off_outlined,
              title: 'Не удалось загрузить дела',
              description: snapshot.error.toString(),
              actionLabel: 'Повторить',
              onAction: refresh,
            ),
          );
        } else {
          children.add(summary(source));
          children.add(const SizedBox(height: 16));
          if (visible.isEmpty) {
            children.add(
              SpecialistMessageCard(
                icon: Icons.folder_open_outlined,
                title: source.isEmpty
                    ? 'Юридических дел пока нет'
                    : 'По фильтрам ничего не найдено',
                description: source.isEmpty
                    ? 'Создайте первое дело. Суд и претензия создаются здесь же — отдельные дублирующие разделы не нужны.'
                    : 'Измените поиск или фильтры.',
                actionLabel: managerMode || source.isNotEmpty
                    ? null
                    : 'Создать дело',
                onAction: managerMode || source.isNotEmpty
                    ? null
                    : () => openEditor(),
              ),
            );
          } else {
            children.add(table(visible));
          }
        }

        return SpecialistDesktopPage(
          storageKey: 'desktop-legal-matters',
          title: managerMode ? 'Решения и риски' : 'Юридические дела',
          showBackButton: Navigator.of(context).canPop(),
          subtitle: managerMode
              ? 'Дела, по которым требуется решение руководителя'
              : 'Единый реестр: обычные дела, суды, претензии, нарушения и споры',
          trailing: Wrap(
            spacing: 10,
            children: [
              IconButton.filledTonal(
                tooltip: 'Обновить',
                onPressed: refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
              if (!managerMode)
                FilledButton.icon(
                  onPressed: () => openEditor(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Создать дело'),
                ),
            ],
          ),
          onRefresh: refresh,
          children: children,
        );
      },
    );
  }
}

class _MatterSummary extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _MatterSummary({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? specialistMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: specialistSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: specialistLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: effectiveColor),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: specialistMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: effectiveColor,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
