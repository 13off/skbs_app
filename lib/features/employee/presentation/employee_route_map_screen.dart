import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../models/employee.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/employee_work_action_repository.dart';

class EmployeeRouteMapScreen extends StatefulWidget {
  final Employee employee;
  final bool canEditGeofence;

  const EmployeeRouteMapScreen({
    super.key,
    required this.employee,
    required this.canEditGeofence,
  });

  @override
  State<EmployeeRouteMapScreen> createState() => _EmployeeRouteMapScreenState();
}

class _EmployeeRouteMapScreenState extends State<EmployeeRouteMapScreen> {
  late DateTime selectedDate;
  late Future<EmployeeRouteDay> future;
  bool isSavingGeofence = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedDate = DateTime(now.year, now.month, now.day);
    future = load();
  }

  Future<EmployeeRouteDay> load() {
    final employeeId = widget.employee.id?.trim() ?? '';
    if (employeeId.isEmpty) {
      return Future<EmployeeRouteDay>.error(
        Exception('Карточка сотрудника не сохранена'),
      );
    }
    return EmployeeWorkActionRepository.fetchEmployeeRoute(
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

  Future<void> setGeofence(EmployeeRouteDay route) async {
    final objectId = widget.employee.objectId?.trim() ?? '';
    if (objectId.isEmpty || isSavingGeofence) {
      _message('У сотрудника не определён объект');
      return;
    }
    final currentRadius = route.geofences.isEmpty
        ? 250.0
        : route.geofences.first.radiusM;
    final controller = TextEditingController(
      text: currentRadius.round().toString(),
    );
    final radius = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Контрольная точка объекта'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Встаньте на объекте. Текущее местоположение станет центром, '
              'в пределах которого сотрудник сможет начать смену.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Допустимый радиус, метров',
                hintText: '250',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value == null || value < 30 || value > 5000) return;
              Navigator.pop(dialogContext, value);
            },
            child: const Text('Сохранить здесь'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (radius == null) return;

    setState(() => isSavingGeofence = true);
    try {
      final point = await currentLocation();
      await EmployeeWorkActionRepository.setObjectGeofence(
        objectId: objectId,
        point: point,
        radiusM: radius,
      );
      await refresh();
      if (mounted) _message('Контрольная точка объекта сохранена');
    } catch (error) {
      if (mounted) _message(_error(error));
    } finally {
      if (mounted) setState(() => isSavingGeofence = false);
    }
  }

  Future<EmployeeLocationPoint> currentLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw Exception('Включите геолокацию на устройстве');
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Разрешите AppСтрой доступ к геопозиции');
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        timeLimit: Duration(seconds: 25),
      ),
    );
    return EmployeeLocationPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyM: position.accuracy,
      altitudeM: position.altitude,
      speedMps: position.speed,
      headingDeg: position.heading,
      isMock: position.isMocked,
      recordedAt: position.timestamp,
    );
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Маршруты смен',
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
                      onPressed: () => changeDay(1),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (widget.canEditGeofence) ...[
                FilledButton.tonalIcon(
                  onPressed: isSavingGeofence ? null : () => setGeofence(route),
                  icon: isSavingGeofence
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.edit_location_alt_outlined),
                  label: Text(
                    route.geofences.isEmpty
                        ? 'Настроить точку объекта'
                        : 'Обновить точку объекта',
                  ),
                ),
                const SizedBox(height: 14),
              ],
              _RouteSummary(route: route),
              const SizedBox(height: 14),
              _RouteMap(route: route),
            ],
          );
        },
      ),
    );
  }

  void changeDay(int delta) {
    setState(() {
      selectedDate = selectedDate.add(Duration(days: delta));
      future = load();
    });
  }
}

class _RouteSummary extends StatelessWidget {
  final EmployeeRouteDay route;

  const _RouteSummary({required this.route});

  @override
  Widget build(BuildContext context) {
    final shift = route.shifts.isEmpty ? null : route.shifts.first;
    return PremiumWorkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            shift == null ? 'Смена не найдена' : 'Смена за ${_date(route.workDate)}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (shift == null)
            const Text('За выбранную дату сотрудник не начинал смену.')
          else ...[
            _SummaryRow('Начало', _dateTime(shift.startedAt)),
            _SummaryRow(
              'Завершение',
              shift.endedAt == null ? 'Смена ещё идёт' : _dateTime(shift.endedAt),
            ),
            _SummaryRow('Записано точек', '${route.points.length}'),
            _SummaryRow(
              'Режим',
              shift.trackingMode == 'native_background'
                  ? 'Фоновая запись приложения'
                  : 'Только открытая PWA',
            ),
          ],
          if (route.geofences.isEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Контрольная точка объекта не настроена.',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
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
    final routePoints = route.points
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList(growable: false);
    final geofencePoints = route.geofences
        .map((geofence) => LatLng(geofence.latitude, geofence.longitude))
        .toList(growable: false);
    final cameraPoints = <LatLng>[...routePoints, ...geofencePoints];
    if (cameraPoints.isEmpty) {
      return const PremiumWorkCard(
        child: SizedBox(
          height: 300,
          child: Center(
            child: Text('На карте пока нечего показывать.'),
          ),
        ),
      );
    }
    final start = routePoints.isEmpty ? null : routePoints.first;
    final finish = routePoints.length < 2 ? null : routePoints.last;
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
                  if (route.geofences.isNotEmpty)
                    CircleLayer(
                      circles: route.geofences.map((geofence) {
                        return CircleMarker(
                          point: LatLng(
                            geofence.latitude,
                            geofence.longitude,
                          ),
                          radius: geofence.radiusM,
                          useRadiusInMeter: true,
                          color: AppAdaptivePalette.accent.withValues(alpha: 0.12),
                          borderColor: AppAdaptivePalette.accent,
                          borderStrokeWidth: 2,
                        );
                      }).toList(growable: false),
                    ),
                  if (routePoints.length > 1)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: routePoints,
                          strokeWidth: 5,
                          color: AppAdaptivePalette.accent,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (start != null)
                        Marker(
                          point: start,
                          width: 44,
                          height: 44,
                          child: const _MapMarker(
                            icon: Icons.play_arrow_rounded,
                            tooltip: 'Начало смены',
                          ),
                        ),
                      if (finish != null)
                        Marker(
                          point: finish,
                          width: 44,
                          height: 44,
                          child: const _MapMarker(
                            icon: Icons.stop_rounded,
                            tooltip: 'Конец смены',
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
                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.86),
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
  return text.isEmpty ? 'Не удалось выполнить действие' : text;
}
