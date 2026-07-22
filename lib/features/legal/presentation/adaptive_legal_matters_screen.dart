import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../data/app_data_sync.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/premium_ui.dart';
import '../../shared/presentation/specialist_desktop_table.dart';
import '../../shared/presentation/specialist_desktop_ui.dart';
import '../data/legal_repository.dart';
import '../models/legal_models.dart';
import 'legal_matters_screen.dart';

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
    if (widget.highRiskOnly) {
      matters = matters.where((item) => item.isHighRisk).toList();
    }
    if (widget.managerOnly) {
      matters = matters.where((item) => item.needsManager).toList();
    }
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
      CupertinoPageRoute<bool>(
        builder: (_) => LegalMatterEditorScreen(matter: matter),
      ),
    );
    if (mounted && saved == true) await refresh();
  }

  Future<void> openDetails(LegalMatter matter) async {
    await Navigator.push<void>(
      context,
      CupertinoPageRoute<void>(
        builder: (_) =>
            LegalMatterDetailsScreen(matter: matter, canDecide: managerMode),
      ),
    );
    if (mounted) await refresh();
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
      if (risk != null && matter.riskLevel != risk) return false;
      if (status != null && matter.status != status) return false;
      if (safeObject != null && matter.objectName.trim() != safeObject) {
        return false;
      }
      return true;
    }).toList();

    result.sort((a, b) {
      int rank(LegalMatter item) {
        if (item.riskLevel == LegalRiskLevel.critical) return 0;
        if (item.riskLevel == LegalRiskLevel.high) return 1;
        if (item.isOverdue || item.needsManager) return 2;
        return 3;
      }

      final compare = rank(a).compareTo(rank(b));
      if (compare != 0) return compare;
      final first = a.dueAt ?? DateTime(9999);
      final second = b.dueAt ?? DateTime(9999);
      return first.compareTo(second);
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
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day.$month.${local.year}';
  }

  Color riskColor(LegalMatter matter) {
    if (matter.riskLevel == LegalRiskLevel.critical || matter.isOverdue) {
      return specialistDanger;
    }
    if (matter.riskLevel == LegalRiskLevel.high || matter.needsManager) {
      return specialistWarning;
    }
    if (matter.riskLevel == LegalRiskLevel.low) return specialistSuccess;
    return specialistMuted;
  }

  Widget filters(List<LegalMatter> matters) {
    final objects = objectOptions(matters);
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Название, описание, объект или контрагент',
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
          const SizedBox(width: 12),
          SizedBox(
            width: 185,
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
          const SizedBox(width: 12),
          SizedBox(
            width: 190,
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
          const SizedBox(width: 12),
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
          if (!widget.highRiskOnly && !widget.managerOnly) ...[
            const SizedBox(width: 12),
            FilterChip(
              selected: attentionOnly,
              avatar: const Icon(Icons.priority_high_rounded, size: 18),
              label: const Text('Внимание'),
              onSelected: (value) {
                setState(() {
                  attentionOnly = value;
                  future = load();
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget summary(List<LegalMatter> matters) {
    final high = matters.where((item) => item.isHighRisk).length;
    final overdue = matters.where((item) => item.isOverdue).length;
    final manager = matters.where((item) => item.needsManager).length;
    final open = matters
        .where(
          (item) =>
              item.status != LegalMatterStatus.closed &&
              item.status != LegalMatterStatus.resolved,
        )
        .length;

    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _Summary(
            icon: Icons.gavel_outlined,
            label: 'Открытые',
            value: '$open',
          ),
          _Summary(
            icon: Icons.warning_amber_rounded,
            label: 'Высокий риск',
            value: '$high',
            color: specialistWarning,
          ),
          _Summary(
            icon: Icons.event_busy_outlined,
            label: 'Просрочены',
            value: '$overdue',
            color: overdue > 0 ? specialistDanger : specialistMuted,
          ),
          _Summary(
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
      minWidth: 1260,
      columns: const [
        SpecialistTableColumn('Вопрос', flex: 4),
        SpecialistTableColumn('Тип', flex: 2),
        SpecialistTableColumn('Риск', flex: 2),
        SpecialistTableColumn('Статус', flex: 2),
        SpecialistTableColumn('Объект', flex: 2),
        SpecialistTableColumn('Срок', flex: 2),
        SpecialistTableColumn('Ответственный', flex: 2),
        SpecialistTableColumn('Руководитель', flex: 2),
      ],
      rows: matters
          .map(
            (matter) => SpecialistTableRowData(
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
                specialistCellText(matter.typeTitle, maxLines: 1),
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
                specialistCellText(matter.objectName, color: specialistMuted),
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
                    ? const SpecialistStatusPill(
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
            ),
          )
          .toList(),
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
              title: 'Загружаем юридические вопросы',
              loading: true,
            ),
          );
        } else if (snapshot.hasError) {
          children.add(
            SpecialistMessageCard(
              icon: Icons.cloud_off_outlined,
              title: 'Не удалось загрузить вопросы',
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
              const SpecialistMessageCard(
                icon: Icons.search_off_rounded,
                title: 'Вопросы не найдены',
                description: 'Измените поиск или выбранные фильтры.',
              ),
            );
          } else {
            children.add(table(visible));
          }
        }

        return SpecialistDesktopPage(
          storageKey: 'desktop-legal-matters',
          title: managerMode ? 'Решения и риски' : 'Юридические вопросы',
          showBackButton: Navigator.of(context).canPop(),
          subtitle: managerMode
              ? 'Вопросы, по которым требуется решение руководителя'
              : 'Претензии, нарушения, споры, задачи и риски компании',
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
                  label: const Text('Добавить вопрос'),
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

class _Summary extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _Summary({
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
