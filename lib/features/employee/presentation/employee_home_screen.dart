import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/employee_shift_runtime.dart';
import '../data/employee_task_cabinet_repository.dart';

class EmployeeHomeScreen extends StatefulWidget {
  final AppUserProfile profile;
  final ValueNotifier<String> selectedEmployeeId;

  const EmployeeHomeScreen({
    super.key,
    required this.profile,
    required this.selectedEmployeeId,
  });

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  final runtime = EmployeeShiftRuntime.instance;
  late Future<EmployeeTaskCabinetData> future;
  bool starting = false;
  bool finishing = false;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<EmployeeTaskCabinetData> load() async {
    final data = await EmployeeTaskCabinetRepository.fetch(
      employeeId: widget.selectedEmployeeId.value,
    );
    final employeeId = data.profile.employeeId;
    if (widget.selectedEmployeeId.value != employeeId) {
      widget.selectedEmployeeId.value = employeeId;
    }
    await runtime.bind(employeeId);
    await runtime.preparePermission();
    return data;
  }

  Future<void> refresh() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  Future<void> startDay(String employeeId) async {
    if (starting) return;
    setState(() => starting = true);
    try {
      await runtime.start(employeeId);
      if (mounted) message('Рабочий день начат');
    } on EmployeeLocationPermissionException catch (error) {
      if (!mounted) return;
      message(error.message);
      if (error.openSettingsRequired && !kIsWeb) {
        await openSettingsDialog(error.message);
      }
    } catch (error) {
      if (mounted) message(cleanError(error));
    } finally {
      if (mounted) setState(() => starting = false);
    }
  }

  Future<void> finishDay() async {
    if (finishing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Завершить рабочий день?'),
        content: const Text(
          'После завершения продолжить этот рабочий день нельзя.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Завершить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => finishing = true);
    try {
      await runtime.finish();
      if (mounted) message('Рабочий день завершён');
    } catch (error) {
      if (mounted) message(cleanError(error));
    } finally {
      if (mounted) setState(() => finishing = false);
    }
  }

  Future<void> openSettingsDialog(String text) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Нужен доступ в настройках'),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Позже'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await runtime.openSettings();
            },
            child: const Text('Открыть настройки'),
          ),
        ],
      ),
    );
  }

  void message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EmployeeTaskCabinetData>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const AppPage(
            title: 'Главная',
            child: SizedBox(
              height: 420,
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return AppPage(
            title: 'Главная',
            subtitle: 'Не удалось загрузить данные',
            onRefresh: refresh,
            child: PremiumWorkCard(
              child: Text(
                cleanError(snapshot.error),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          );
        }

        final data = snapshot.data!;
        return AppPage(
          title: 'Главная',
          subtitle: data.profile.currentObject.trim().isEmpty
              ? null
              : 'Объект: ${data.profile.currentObject.trim()}',
          onRefresh: refresh,
          child: ValueListenableBuilder<EmployeeWorkDaySnapshot>(
            valueListenable: runtime.state,
            builder: (context, state, _) {
              final active = state.employeeId == data.profile.employeeId &&
                  state.isActive;
              final startedAt = active ? state.shift?.startedAt : null;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 34),
                child: Column(
                  children: [
                    Center(
                      child: _RoundWorkButton(
                        active: active,
                        loading: starting,
                        startedAt: startedAt,
                        onPressed: active || starting
                            ? null
                            : () => startDay(data.profile.employeeId),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      active
                          ? 'Рабочий день начат. Геолокация записывается в фоне.'
                          : 'Нажмите кнопку перед началом рабочего дня.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (active) ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        width: 320,
                        child: OutlinedButton.icon(
                          onPressed: finishing ? null : finishDay,
                          icon: finishing
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.stop_circle_outlined),
                          label: Text(
                            finishing
                                ? 'Завершаем…'
                                : 'Завершить рабочий день',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _RoundWorkButton extends StatelessWidget {
  final bool active;
  final bool loading;
  final DateTime? startedAt;
  final VoidCallback? onPressed;

  const _RoundWorkButton({
    required this.active,
    required this.loading,
    required this.startedAt,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: !active,
      label: active ? 'Рабочий день идёт' : 'Начать работу',
      child: Material(
        color: active ? scheme.surfaceContainerHighest : scheme.primary,
        shape: const CircleBorder(),
        elevation: active ? 2 : 8,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: 228,
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    CircularProgressIndicator(
                      color: scheme.onPrimary,
                    )
                  else
                    Icon(
                      active
                          ? Icons.work_history_rounded
                          : Icons.play_arrow_rounded,
                      size: 62,
                      color: active ? scheme.onSurface : scheme.onPrimary,
                    ),
                  const SizedBox(height: 12),
                  Text(
                    loading
                        ? 'Запускаем…'
                        : active
                            ? 'Работа идёт'
                            : 'Начать работу',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: active ? scheme.onSurface : scheme.onPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (active && startedAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'с ${formatTime(startedAt!)}',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String cleanError(Object? value) {
  final text = value?.toString().replaceFirst('Exception: ', '').trim() ?? '';
  return text.isEmpty ? 'Не удалось выполнить действие' : text;
}
