import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../models/employee.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/employee_shift_action_repository.dart';

class EmployeeRouteMapScreen extends StatefulWidget {
  final Employee employee;
  final bool canEditGeofence;
  final DateTime? initialDate;

  const EmployeeRouteMapScreen({
    super.key,
    required this.employee,
    this.canEditGeofence = false,
    this.initialDate,
  });

  @override
  State<EmployeeRouteMapScreen> createState() => _EmployeeRouteMapScreenState();
}

class _EmployeeRouteMapScreenState extends State<EmployeeRouteMapScreen> {
  late DateTime selectedDate;
  late Future<EmployeeRouteDay> future;

  @override
  void initState() {
    super.initState();
    final source = widget.initialDate ?? DateTime.now();
    selectedDate = DateTime(source.year, source.month, source.day);
    future = load();
  }

  Future<EmployeeRouteDay> load() {
    final employeeId = widget.employee.id?.trim() ?? '';
    if (employeeId.isEmpty) {
      return Future<EmployeeRouteDay>.error(
        Exception('Карточка сотрудника не сохранена'),
      );
    }
    return EmployeeShiftActionRepository.fetchEmployeeRoute(
      employeeId: employeeId,
      date: selectedDate,
    );
  }

  Future<void> refresh() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 31)),
      helpText: 'Маршрут за день',
      cancelText: 'Отмена',
      confirmText: 'Показать',
    );
    if (picked == null) return;
    setState(() {
      selectedDate = DateTime(picked.year, picked.month, picked.day);
      future = load();
    });
  }

  void changeDay(int delta) {
    setState(() {
      selectedDate = selectedDate.add(Duration(days: delta));
      future = load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Маршрут сотрудника',
      subtitle: '${widget.employee.name} · ${widget.employee.objectName}',
      onRefresh: refresh,
      child: FutureBuilder<EmployeeRouteDay>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const SizedBox(
              height: 420,
              child: Center(child: CircularProgressIndicator.adaptive()),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return PremiumWorkCard(
              child: Text('Не удалось загрузить маршрут: ${_error(snapshot.error)}'),
            );
          }
          final route = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PremiumWorkCard(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Предыдущий день',
                      onPressed: () => changeDay(-1),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: pickDate,
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(_date(selectedDate)),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Следующий день',
                      onPressed: () => changeDay(1),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _RouteSummary(route: route),
              const SizedBox(height: 14),
              _RouteMap(route: route),
            ],
          );
        },
      ),
    );
  }
}

class _RouteSummary extends StatelessWidget {
  final EmployeeRouteDay route;

  const _RouteSummary({required this.route});

  @override
  Widget build(BuildContext context) {
    if (route.shifts.isEmpty) {
      return const PremiumWorkCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Рабочий день не найден',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 8),
            Text('За выбранную дату сотрудник не начинал рабочий день.'),
          ],
        ),
      );
    }

    final first = route.shifts.first;
    final last = route.shifts.last;
    return PremiumWorkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Рабочий день за ${_date(route.workDate)}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          _SummaryRow('Начало', _dateTime(first.startedAt)),
          _SummaryRow(
            'Завершение',
            last.endedAt == null ? 'Рабочий день ещё идёт' : _dateTime(last.endedAt),
          ),
          _SummaryRow('Получено точек', '${route.points.length}'),
          _SummaryRow(
            'Источник',
            route.shifts.any((shift) => shift.trackingMode == 'native_background')
                ? 'Установленное приложение'
                : 'Открытая браузерная версия',
          ),
        ],
      ),
    );
  }
}

class _RouteMap extends StatelessWidget {
  final EmployeeRouteDay route;

  const _RouteMap({required this.route});

  @override
  Widget build(BuildContext context) {
    final validPoints = route.points
        .where(
          (point) =>
              point.latitude >= -90 &&
              point.latitude <= 90 &&
              point.longitude >= -180 &&
              point.longitude <= 180 &&
              !point.isMock,
        )
        .toList(growable: false);
    final cameraPoints = validPoints
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList(growable: false);

    if (cameraPoints.isEmpty) {
      return const PremiumWorkCard(
        child: SizedBox(
          height: 360,
          child: Center(child: Text('За выбранную дату координаты не получены.')),
        ),
      );
    }

    final pointsByShift = <String, List<LatLng>>{};
    for (final point in validPoints) {
      final key = point.shiftId.isEmpty ? '__day__' : point.shiftId;
      pointsByShift
          .putIfAbsent(key, () => <LatLng>[])
          .add(LatLng(point.latitude, point.longitude));
    }

    final startPoints = validPoints
        .where((point) => point.source == 'start')
        .toList(growable: false);
    final finishPoints = validPoints
        .where((point) => point.source == 'finish')
        .toList(growable: false);
    final start = startPoints.isNotEmpty
        ? LatLng(startPoints.first.latitude, startPoints.first.longitude)
        : cameraPoints.first;
    final finish = finishPoints.isNotEmpty
        ? LatLng(finishPoints.last.latitude, finishPoints.last.longitude)
        : cameraPoints.length > 1
            ? cameraPoints.last
            : null;

    return PremiumWorkCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          height: 520,
          child: Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: cameraPoints.first,
                  initialZoom: 16,
                  initialCameraFit: cameraPoints.length > 1
                      ? CameraFit.coordinates(
                          coordinates: cameraPoints,
                          padding: const EdgeInsets.all(54),
                          maxZoom: 18,
                        )
                      : null,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'ru.appstroy.app',
                    maxZoom: 19,
                  ),
                  PolylineLayer(
                    polylines: pointsByShift.values
                        .where((points) => points.length > 1)
                        .map(
                          (points) => Polyline(
                            points: points,
                            strokeWidth: 5,
                            color: AppAdaptivePalette.accent,
                          ),
                        )
                        .toList(growable: false),
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: start,
                        width: 44,
                        height: 44,
                        child: const _MapMarker(
                          icon: Icons.play_arrow_rounded,
                          tooltip: 'Начало рабочего дня',
                        ),
                      ),
                      if (finish != null)
                        Marker(
                          point: finish,
                          width: 44,
                          height: 44,
                          child: const _MapMarker(
                            icon: Icons.stop_rounded,
                            tooltip: 'Завершение рабочего дня',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              Positioned(
                left: 10,
                bottom: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surface
                        .withValues(alpha: 0.86),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      '© OpenStreetMap contributors',
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  final IconData icon;
  final String tooltip;

  const _MapMarker({required this.icon, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.onPrimary,
            width: 2,
          ),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.onPrimary),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

String _date(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day.$month.${value.year}';
}

String _dateTime(DateTime? value) {
  if (value == null) return '—';
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${_date(value)} $hour:$minute';
}

String _error(Object? value) {
  final text = value?.toString().replaceFirst('Exception: ', '').trim() ?? '';
  return text.isEmpty ? 'Неизвестная ошибка' : text;
}
