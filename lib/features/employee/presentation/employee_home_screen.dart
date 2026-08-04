import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/employee_route_analysis_repository.dart';
import '../data/employee_shift_runtime.dart';
import '../data/employee_task_cabinet_repository.dart';
import 'premium_round_work_button.dart';

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
  bool checkingLocation = false;
  bool cancellingStart = false;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<EmployeeTaskCabinetData> load({bool forceRefresh = false}) async {
    final data = await EmployeeTaskCabinetRepository.fetch(
      employeeId: widget.selectedEmployeeId.value,
      forceRefresh: forceRefresh,
    );
    final employeeId = data.profile.employeeId;
    if (widget.selectedEmployeeId.value != employeeId) {
      widget.selectedEmployeeId.value = employeeId;
    }
    await runtime.bind(employeeId);
    return data;
  }

  Future<void> refresh() async {
    final next = load(forceRefresh: true);
    setState(() => future = next);
    await next;
  }

  Future<void> startDay(String employeeId) async {
    if (starting || checkingLocation || cancellingStart) return;
    if (!await confirmUnusualStartTime()) return;
    if (!mounted) return;
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

  Future<bool> confirmUnusualStartTime() async {
    final now = DateTime.now();
    final normalTime = now.hour >= 5 && now.hour < 22;
    if (normalTime) return true;

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Сейчас ${timeText(now)}'),
        content: const Text(
          'Начать ночную смену или только проверить, работает ли геолокация?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'check'),
            child: const Text('Проверить геолокацию'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'start'),
            child: const Text('Начать смену'),
          ),
        ],
      ),
    );
    if (action == 'check') {
      await checkCurrentLocation();
      return false;
    }
    return action == 'start';
  }

  Future<void> checkCurrentLocation() async {
    if (checkingLocation || starting || finishing || cancellingStart) return;
    setState(() => checkingLocation = true);
    try {
      if (!kIsWeb && !await Geolocator.isLocationServiceEnabled()) {
        throw const LocationServiceDisabledException();
      }
      if (!kIsWeb) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          throw const PermissionDeniedException('Доступ к геопозиции запрещён');
        }
      }

      final settings = kIsWeb
          ? WebSettings(
              accuracy: LocationAccuracy.high,
              maximumAge: const Duration(seconds: 30),
              timeLimit: const Duration(seconds: 45),
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              timeLimit: Duration(seconds: 25),
            );
      final position = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );
      if (!mounted) return;
      final recordedAt = position.timestamp.toLocal();
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Геолокация работает'),
          content: Text(
            'Время: ${timeText(recordedAt)}\n'
            'Точность: ${position.accuracy.round()} м',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Готово'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final text = employeeLocationErrorMessage(error);
      if (kIsWeb && isEmployeeLocationError(error)) {
        await openWebLocationDialog(text);
      } else {
        message(text);
      }
    } finally {
      if (mounted) setState(() => checkingLocation = false);
    }
  }

  Future<void> cancelAccidentalStart(String employeeId) async {
    if (cancellingStart || starting || finishing || checkingLocation) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Отменить ошибочный старт?'),
        content: const Text(
          'Смена будет помечена отменённой и не попадёт в рабочий маршрут.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Нет'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Отменить старт'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => cancellingStart = true);
    try {
      await EmployeeRouteAnalysisRepository.cancelRecentShift(
        employeeId: employeeId,
      );
      await runtime.reload(employeeId);
      if (mounted) message('Ошибочный старт отменён');
    } catch (error) {
      if (mounted) message(cleanError(error));
    } finally {
      if (mounted) setState(() => cancellingStart = false);
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
              final active =
                  state.employeeId == data.profile.employeeId && state.isActive;
              final startedAt = active ? state.shift?.startedAt : null;
              final canCancelStart =
                  active &&
                  startedAt != null &&
                  DateTime.now().difference(startedAt) <=
                      const Duration(minutes: 10);
              final loading =
                  starting || finishing || checkingLocation || cancellingStart;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PremiumRoundWorkButton(
                        active: active,
                        loading: loading,
                        startedAt: startedAt,
                        onPressed: loading
                            ? null
                            : active
                            ? finishDay
                            : () => startDay(data.profile.employeeId),
                      ),
                      const SizedBox(height: 14),
                      if (!active)
                        TextButton.icon(
                          onPressed: loading ? null : checkCurrentLocation,
                          icon: const Icon(Icons.my_location_rounded),
                          label: const Text('Проверить геолокацию'),
                        ),
                      if (canCancelStart)
                        TextButton.icon(
                          onPressed: loading
                              ? null
                              : () => cancelAccidentalStart(
                                  data.profile.employeeId,
                                ),
                          icon: const Icon(Icons.undo_rounded),
                          label: const Text('Отменить ошибочный старт'),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

String timeText(DateTime value) {
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
