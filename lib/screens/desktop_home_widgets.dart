import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/app_adaptive_palette.dart';
import '../models/task_item_data.dart';
import '../widgets/premium_ui.dart';

Color get _text => AppAdaptivePalette.textPrimary;
Color get _muted => AppAdaptivePalette.textMuted;
Color get _line => AppAdaptivePalette.border;
Color get _soft => AppAdaptivePalette.surfaceSoft;
Color get _surface => AppAdaptivePalette.surface;
Color get _surfaceElevated => AppAdaptivePalette.surfaceElevated;
Color get _input => AppAdaptivePalette.inputSurface;
Color get _success => AppAdaptivePalette.success;

class DesktopObjectSelector extends StatefulWidget {
  final List<String> objectNames;
  final String? selectedObjectName;
  final ValueChanged<String?> onSelected;

  const DesktopObjectSelector({
    super.key,
    required this.objectNames,
    required this.selectedObjectName,
    required this.onSelected,
  });

  @override
  State<DesktopObjectSelector> createState() => _DesktopObjectSelectorState();
}

class _DesktopObjectSelectorState extends State<DesktopObjectSelector>
    with WidgetsBindingObserver {
  final LayerLink layerLink = LayerLink();
  final GlobalKey targetKey = GlobalKey();
  OverlayEntry? menuEntry;

  String? clean(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  String get title => clean(widget.selectedObjectName) ?? 'Все объекты';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant DesktopObjectSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedObjectName != widget.selectedObjectName ||
        !listEquals(oldWidget.objectNames, widget.objectNames)) {
      closeMenu();
    }
  }

  @override
  void didChangeMetrics() => closeMenu();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    closeMenu();
    super.dispose();
  }

  void closeMenu() {
    menuEntry?.remove();
    menuEntry = null;
  }

  void selectObject(String? value) {
    closeMenu();
    widget.onSelected(value);
  }

  void toggleMenu() {
    if (menuEntry != null) {
      closeMenu();
      return;
    }

    final targetContext = targetKey.currentContext;
    final renderBox = targetContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final targetSize = renderBox.size;
    final menuWidth = math.min(math.max(targetSize.width, 420), 560).toDouble();
    final overlay = Overlay.of(context);

    menuEntry = OverlayEntry(
      builder: (overlayContext) {
        final maxHeight = math.min(
          420.0,
          MediaQuery.sizeOf(overlayContext).height * 0.58,
        );
        final selected = clean(widget.selectedObjectName);

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: closeMenu,
                child: const SizedBox.expand(),
              ),
            ),
            CompositedTransformFollower(
              link: layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(0, 8),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: menuWidth,
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _surfaceElevated,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: _line),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 34,
                        spreadRadius: -8,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(10, 8, 10, 10),
                        child: Text(
                          'Выберите объект',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          children: [
                            DesktopObjectMenuItem(
                              icon: Icons.apartment_outlined,
                              title: 'Все объекты',
                              selected: selected == null,
                              onTap: () => selectObject(null),
                            ),
                            ...widget.objectNames.map(
                              (objectName) => DesktopObjectMenuItem(
                                icon: Icons.business_outlined,
                                title: objectName,
                                selected: selected == objectName,
                                onTap: () => selectObject(objectName),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(menuEntry!);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      key: targetKey,
      link: layerLink,
      child: Tooltip(
        message: 'Выбрать объект',
        child: PremiumPressable(
          onTap: toggleMenu,
          borderRadius: BorderRadius.circular(18),
          child: DesktopSelectorShell(
            icon: Icons.apartment_outlined,
            title: title,
            trailing: Icons.expand_more_rounded,
          ),
        ),
      ),
    );
  }
}

class DesktopObjectMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const DesktopObjectMenuItem({
    super.key,
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: PremiumPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppAdaptivePalette.selectedSurface
                : _surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppAdaptivePalette.accent : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: _muted),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  size: 21,
                  color: AppAdaptivePalette.accent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DesktopSelectorShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final IconData? trailing;

  const DesktopSelectorShell({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Icon(icon, size: 21, color: _muted),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _text, fontWeight: FontWeight.w900),
            ),
          ),
          if (trailing != null) Icon(trailing, color: _muted),
        ],
      ),
    );
  }
}

class DesktopDateChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const DesktopDateChip({super.key, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Обновить данные за сегодня',
      child: PremiumPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _input,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_month_outlined, color: _muted),
              SizedBox(width: 9),
              Text(
                text,
                style: TextStyle(color: _muted, fontWeight: FontWeight.w800),
              ),
              SizedBox(width: 9),
              Icon(Icons.refresh_rounded, size: 18, color: _muted),
            ],
          ),
        ),
      ),
    );
  }
}

class DesktopMetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String detail;
  final String footer;
  final double progress;
  final Color accent;
  final VoidCallback onTap;
  final bool compactValue;

  const DesktopMetricCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
    required this.footer,
    required this.progress,
    required this.accent,
    required this.onTap,
    this.compactValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: PremiumWorkCard(
        radius: 26,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _soft,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: _text),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(color: _text, fontWeight: FontWeight.w900),
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, size: 19, color: _muted),
              ],
            ),
            SizedBox(height: 22),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _text,
                fontSize: compactValue ? 28 : 38,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.1,
              ),
            ),
            SizedBox(height: 3),
            Text(
              detail,
              style: TextStyle(color: _muted, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                minHeight: 7,
                value: progress.clamp(0.0, 1.0).toDouble(),
                backgroundColor: _soft,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
            SizedBox(height: 12),
            Text(
              footer,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DesktopTasksCard extends StatelessWidget {
  final List<TaskItemData> tasks;
  final VoidCallback onOpenTasks;
  final ValueChanged<TaskItemData> onOpenTask;

  const DesktopTasksCard({
    super.key,
    required this.tasks,
    required this.onOpenTasks,
    required this.onOpenTask,
  });

  @override
  Widget build(BuildContext context) {
    final visibleTasks = tasks.take(6).toList(growable: false);

    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Задачи сегодня',
                      style: TextStyle(
                        color: _text,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Последние работы по выбранному объекту',
                      style: TextStyle(
                        color: _muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onOpenTasks,
                icon: Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Все задачи'),
              ),
            ],
          ),
          SizedBox(height: 16),
          if (visibleTasks.isEmpty)
            const DesktopEmptyState(
              icon: Icons.assignment_outlined,
              text: 'На сегодня задач нет',
            )
          else
            ...visibleTasks.map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PremiumPressable(
                  onTap: () => onOpenTask(task),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _soft,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _line),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: task.status == 'Выполнено'
                                ? _success
                                : _muted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.work.trim().isEmpty
                                    ? 'Работа без названия'
                                    : task.work.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _text,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                '${task.objectName} · ${task.axes.trim().isEmpty ? 'оси не указаны' : task.axes}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(
                          task.status,
                          style: TextStyle(
                            color: _muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.chevron_right_rounded, color: _muted),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class DesktopFinanceCard extends StatelessWidget {
  final bool visible;
  final String periodTitle;
  final double accrued;
  final double paid;
  final double balance;
  final String Function(double value) formatMoney;
  final VoidCallback onOpenPayments;
  final VoidCallback onPickPeriod;

  const DesktopFinanceCard({
    super.key,
    required this.visible,
    required this.periodTitle,
    required this.accrued,
    required this.paid,
    required this.balance,
    required this.formatMoney,
    required this.onOpenPayments,
    required this.onPickPeriod,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const PremiumWorkCard(
        radius: 26,
        padding: EdgeInsets.all(20),
        child: DesktopEmptyState(
          icon: Icons.dashboard_customize_outlined,
          text: 'Рабочая сводка обновляется автоматически',
        ),
      );
    }

    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Выплаты',
                style: TextStyle(
                  color: _text,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                periodTitle,
                style: TextStyle(color: _muted, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          SizedBox(height: 18),
          PremiumPressable(
            onTap: onOpenPayments,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _soft,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _line),
              ),
              child: Column(
                children: [
                  DesktopFinanceRow(
                    label: 'Начислено',
                    value: formatMoney(accrued),
                  ),
                  const Divider(height: 24),
                  DesktopFinanceRow(
                    label: 'Выплачено',
                    value: formatMoney(paid),
                  ),
                  const Divider(height: 24),
                  DesktopFinanceRow(
                    label: 'Остаток',
                    value: formatMoney(balance),
                    emphasized: true,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onPickPeriod,
            icon: Icon(Icons.tune_rounded),
            label: const Text('Выбрать другой период'),
          ),
        ],
      ),
    );
  }
}

class DesktopFinanceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  const DesktopFinanceRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: _muted, fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: _text,
            fontSize: emphasized ? 18 : 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class DesktopEmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const DesktopEmptyState({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(icon, size: 34, color: _muted),
          SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class DesktopErrorState extends StatelessWidget {
  final Future<void> Function() onRetry;

  const DesktopErrorState({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: PremiumWorkCard(
          radius: 26,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined, size: 42, color: _muted),
              SizedBox(height: 14),
              const Text(
                'Не удалось загрузить главную',
                style: TextStyle(
                  color: _text,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              const Text(
                'Проверь интернет и повтори загрузку.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted),
              ),
              SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onRetry,
                icon: Icon(Icons.refresh_rounded),
                label: const Text('Повторить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
