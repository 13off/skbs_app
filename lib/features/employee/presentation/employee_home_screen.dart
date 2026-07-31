import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

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
      if (kIsWeb) {
        await openWebLocationDialog(error.message);
      } else {
        message(error.message);
        if (error.openSettingsRequired) {
          await openSettingsDialog(error.message);
        }
      }
    } catch (error) {
      if (!mounted) return;
      final text = employeeLocationErrorMessage(error);
      if (kIsWeb && isEmployeeLocationError(error)) {
        await openWebLocationDialog(text);
      } else {
        message(text);
      }
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
      if (!mounted) return;
      final text = employeeLocationErrorMessage(error);
      if (kIsWeb && isEmployeeLocationError(error)) {
        await openWebLocationDialog(text);
      } else {
        message(text);
      }
    } finally {
      if (mounted) setState(() => finishing = false);
    }
  }

  Future<void> openWebLocationDialog(String text) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Геопозиция недоступна'),
        content: Text(text),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
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
              : data.profile.currentObject.trim(),
          onRefresh: refresh,
          child: ValueListenableBuilder<EmployeeWorkDaySnapshot>(
            valueListenable: runtime.state,
            builder: (context, state, _) {
              final active = state.employeeId == data.profile.employeeId &&
                  state.isActive;
              final startedAt = active ? state.shift?.startedAt : null;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
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
                    if (active) ...[
                      const SizedBox(height: 30),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton.tonalIcon(
                            onPressed: finishing ? null : finishDay,
                            icon: finishing
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.stop_circle_outlined),
                            label: Text(
                              finishing
                                  ? 'Завершаем…'
                                  : 'Завершить рабочий день',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final dimension = width < 390 ? 244.0 : 272.0;
    final foreground = active ? scheme.onSurface : Colors.white;

    return Semantics(
      button: !active,
      label: active ? 'Рабочий день идёт' : 'Начать работу',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        width: dimension,
        height: dimension,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: active
                ? (dark
                    ? const [Color(0xFF38434D), Color(0xFF171E25)]
                    : const [Color(0xFFFFFFFF), Color(0xFFDDE4EB)])
                : const [Color(0xFF43A9F4), Color(0xFF075A9F)],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: dark ? 0.16 : 0.72),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: active
                  ? Colors.black.withValues(alpha: dark ? 0.38 : 0.16)
                  : scheme.primary.withValues(alpha: dark ? 0.52 : 0.38),
              blurRadius: active ? 38 : 54,
              spreadRadius: active ? -12 : -8,
              offset: const Offset(0, 24),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: active ? 0.10 : 0.28),
              blurRadius: 16,
              spreadRadius: -8,
              offset: const Offset(-8, -10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Ink(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.35, -0.45),
                  radius: 1.15,
                  colors: active
                      ? (dark
                          ? const [Color(0xFF303B45), Color(0xFF131A20)]
                          : const [Color(0xFFF8FAFC), Color(0xFFD4DDE5)])
                      : const [Color(0xFF359DE9), Color(0xFF07528F)],
                ),
                border: Border.all(
                  color: Colors.white.withValues(
                    alpha: active ? (dark ? 0.10 : 0.78) : 0.22,
                  ),
                  width: 1.2,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    left: 42,
                    right: 42,
                    top: 22,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.48),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (loading)
                          const SizedBox.square(
                            dimension: 48,
                            child: CircularProgressIndicator(
                              strokeWidth: 4,
                              color: Colors.white,
                            ),
                          )
                        else
                          Icon(
                            active
                                ? Icons.work_history_rounded
                                : Icons.play_arrow_rounded,
                            size: active ? 58 : 72,
                            color: foreground,
                          ),
                        const SizedBox(height: 14),
                        Text(
                          loading
                              ? 'Запускаем…'
                              : active
                                  ? 'Работа идёт'
                                  : 'Начать работу',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: foreground,
                            fontSize: width < 390 ? 22 : 24,
                            height: 1.05,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.55,
                          ),
                        ),
                        if (active && startedAt != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            'с ${formatTime(startedAt!)}',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
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

String employeeLocationErrorMessage(Object? value) {
  if (value is EmployeeLocationPermissionException) return value.message;
  if (value is TimeoutException) {
    return 'Телефон не передал координату. Проверьте геолокацию и повторите.';
  }
  if (value is PermissionDeniedException) {
    return 'Доступ к геопозиции запрещён. Разрешите его и повторите.';
  }
  if (value is LocationServiceDisabledException) {
    return 'На телефоне отключены службы геолокации. Включите их и повторите.';
  }
  if (value is PositionUpdateException) {
    final text = cleanError(value);
    if (text != 'Не удалось выполнить действие') return text;
  }

  final text = cleanError(value);
  if (text == 'Не удалось выполнить действие') {
    return 'Не удалось получить геопозицию. Проверьте разрешение '
        'и повторите запуск рабочего дня.';
  }
  return text;
}

bool isEmployeeLocationError(Object? value) {
  if (value is EmployeeLocationPermissionException ||
      value is TimeoutException ||
      value is PermissionDeniedException ||
      value is LocationServiceDisabledException ||
      value is PositionUpdateException) {
    return true;
  }
  return _isOpaqueErrorText(_rawErrorText(value));
}

String cleanError(Object? value) {
  final text = _rawErrorText(value);
  return text.isEmpty || _isOpaqueErrorText(text)
      ? 'Не удалось выполнить действие'
      : text;
}

String _rawErrorText(Object? value) {
  return value?.toString().replaceFirst('Exception: ', '').trim() ?? '';
}

bool _isOpaqueErrorText(String text) {
  final normalized = text.toLowerCase();
  return normalized == '[object object]' ||
      normalized.startsWith('instance of ');
}
