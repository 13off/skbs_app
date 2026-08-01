import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../models/employee.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/employee_route_analysis_repository.dart';
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
  late Future<_RouteScreenData> future;

  @override
  void initState() {
    super.initState();
    final source = widget.initialDate ?? DateTime.now();
    selectedDate = DateTime(source.year, source.month, source.day);
    future = load();
  }

  Future<_RouteScreenData> load() async {
    final employeeId = widget.employee.id?.trim() ?? '';
    if (employeeId.isEmpty) {
      throw Exception('Карточка сотрудника не сохранена');
    }
    final route = await EmployeeShiftActionRepository.fetchEmployeeRoute(
      employeeId: employeeId,
      date: selectedDate,
    );
    List<EmployeeRouteGeofence> geofences = const <EmployeeRouteGeofence>[];
    try {
      geofences = await EmployeeRouteAnalysisRepository.fetchGeofences(
        employeeId: employeeId,
        date: selectedDate,
      );
    } catch (_) {
      // Маршрут остаётся доступным даже при временной ошибке геозоны.
    }
    return _RouteScreenData(route: route, geofences: geofences);
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
      child: FutureBuilder<_RouteScreenData>(
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
          final data = snapshot.data!;
          final outsideEpisodes = _outsideEpisodes(data);
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
              _RouteSummary(data: data),
              if (data.gaps.isNotEmpty) ...[
                const SizedBox(height: 14),
                _TrackingGapsCard(gaps: data.gaps),
              ],
              if (outsideEpisodes.isNotEmpty) ...[
                const SizedBox(height: 14),
                _OutsideEpisodesCard(episodes: outsideEpisodes),
              ],
              const SizedBox(height: 14),
              _RouteMap(data: data),
            ],
          );
        },
      ),
    );
  }
}

class _RouteScreenData {
  final EmployeeRouteDay route;
  final List<EmployeeRouteGeofence> geofences;

  const _RouteScreenData({required this.route, required this.geofences});

  List<EmployeeWorkShift> get shifts {
    final values = route.shifts
        .where((shift) => shift.status != 'cancelled')
        .toList(growable: false);
    return values..sort(
        (left, right) => _safeDate(left.startedAt).compareTo(_safeDate(right.startedAt)),
      );
  }

  Set<String> get shiftIds => shifts.map((shift) => shift.id).toSet();

  List<EmployeeLocationPoint> get points {
    final ids = shiftIds;
    final values = route.points.where((point) {
      return point.shiftId.isEmpty || ids.contains(point.shiftId);
    }).toList(growable: false);
    return values
      ..sort((left, right) => left.recordedAt.compareTo(right.recordedAt));
  }

  List<EmployeeTrackingGap> get gaps {
    final ids = shiftIds;
    return route.allGaps
        .where(
          (gap) =>
              ids.contains(gap.shiftId) &&
              gap.duration >= const Duration(minutes: 2),
        )
        .toList(growable: false);
  }

  EmployeeWorkShift? get primaryShift {
    EmployeeWorkShift? result;
    var longest = Duration.zero;
    for (final shift in shifts) {
      final duration = _shiftDuration(shift);
      if (result == null || duration > longest) {
        result = shift;
        longest = duration;
      }
    }
    return result;
  }

  EmployeeRouteGeofence? geofenceForShift(String shiftId) {
    EmployeeWorkShift? shift;
    for (final item in shifts) {
      if (item.id == shiftId) {
        shift = item;
        break;
      }
    }
    if (shift == null) return null;
    for (final geofence in geofences) {
      if (geofence.objectId == shift.objectId) return geofence;
    }
    return null;
  }
}

class _RouteSummary extends StatelessWidget {
  final _RouteScreenData data;

  const _RouteSummary({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.shifts.isEmpty) {
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

    final primary = data.primaryShift!;
    final shortStarts = data.shifts
        .where(
          (shift) =>
              shift.id != primary.id &&
              _shiftDuration(shift) < const Duration(minutes: 5),
        )
        .length;
    final totalDuration = data.shifts.fold<Duration>(
      Duration.zero,
      (sum, shift) => sum + _shiftDuration(shift),
    );

    return PremiumWorkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Основной рабочий интервал за ${_date(data.route.workDate)}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          _SummaryRow('Начало', _dateTime(primary.startedAt)),
          _SummaryRow(
            'Завершение',
            primary.endedAt == null
                ? 'Рабочий день ещё идёт'
                : _dateTime(primary.endedAt),
          ),
          _SummaryRow('Длительность', _duration(totalDuration)),
          _SummaryRow('Рабочих интервалов', '${data.shifts.length}'),
          if (shortStarts > 0)
            _SummaryRow('Коротких запусков', '$shortStarts'),
          _SummaryRow('Получено точек', '${data.points.length}'),
          _SummaryRow('Разрывов геолокации', '${data.gaps.length}'),
          _SummaryRow(
            'Источник',
            data.shifts.any(
              (shift) => shift.trackingMode == 'native_background',
            )
                ? 'Установленное приложение'
                : 'Открытая браузерная версия',
          ),
          if (shortStarts > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Короткие проверки не используются как начало основной смены.',
              style: TextStyle(
                color: AppAdaptivePalette.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrackingGapsCard extends StatelessWidget {
  final List<EmployeeTrackingGap> gaps;

  const _TrackingGapsCard({required this.gaps});

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Разрывы геолокации',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < gaps.length; index++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.timeline_rounded,
                  color: AppAdaptivePalette.danger,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_time(gaps[index].startedAt)}–${_time(gaps[index].endedAt)}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Координат не было ${_duration(gaps[index].duration)}',
                        style: TextStyle(
                          color: AppAdaptivePalette.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (index != gaps.length - 1) const Divider(height: 22),
          ],
        ],
      ),
    );
  }
}

class _OutsideEpisodesCard extends StatelessWidget {
  final List<_OutsideEpisode> episodes;

  const _OutsideEpisodesCard({required this.episodes});

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Выходы за пределы объекта',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < episodes.length; index++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_off_outlined,
                  color: AppAdaptivePalette.danger,
                  size: 21,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        episodes[index].returnedAt == null
                            ? '${_time(episodes[index].startedAt)} — не вернулся'
                            : '${_time(episodes[index].startedAt)}–${_time(episodes[index].returnedAt!)}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_duration(episodes[index].duration)} · до ${_distanceText(episodes[index].maxDistanceFromBorderM)} от объекта',
                        style: TextStyle(
                          color: AppAdaptivePalette.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (episodes[index].approximateStart) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Время выхода приблизительное: перед точкой был разрыв.',
                          style: TextStyle(
                            color: AppAdaptivePalette.danger,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (index != episodes.length - 1) const Divider(height: 22),
          ],
        ],
      ),
    );
  }
}

class _RouteMap extends StatefulWidget {
  final _RouteScreenData data;

  const _RouteMap({required this.data});

  @override
  State<_RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<_RouteMap> {
  EmployeeLocationPoint? selectedPoint;

  @override
  Widget build(BuildContext context) {
    final validPoints = widget.data.points
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

    final segments = _routeSegments(widget.data, validPoints);
    final primary = widget.data.primaryShift;
    final primaryPoints = primary == null
        ? validPoints
        : validPoints
            .where((point) => point.shiftId == primary.id)
            .toList(growable: false);
    final startPoint = _sourcePoint(primaryPoints, 'start') ??
        (primaryPoints.isNotEmpty ? primaryPoints.first : validPoints.first);
    final finishPoint = _sourcePoint(primaryPoints.reversed, 'finish') ??
        (primaryPoints.length > 1 ? primaryPoints.last : null);
    final gapMarkers = <Marker>[];
    for (final gap in widget.data.gaps.take(8)) {
      final point = _firstPointAfterGap(validPoints, gap);
      if (point == null) continue;
      gapMarkers.add(
        Marker(
          point: LatLng(point.latitude, point.longitude),
          width: 32,
          height: 32,
          child: Tooltip(
            message:
                'После разрыва ${_time(gap.startedAt)}–${_time(gap.endedAt)}',
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppAdaptivePalette.danger,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.priority_high_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      );
    }

    return PremiumWorkCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          height: 540,
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
                  onTap: (_, point) => _selectNearest(point, validPoints),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'ru.appstroy.app',
                    maxZoom: 19,
                  ),
                  if (widget.data.geofences.isNotEmpty)
                    CircleLayer(
                      circles: widget.data.geofences
                          .map(
                            (geofence) => CircleMarker(
                              point: LatLng(
                                geofence.latitude,
                                geofence.longitude,
                              ),
                              radius: geofence.radiusM,
                              useRadiusInMeter: true,
                              color: AppAdaptivePalette.accent.withValues(
                                alpha: 0.08,
                              ),
                              borderColor: AppAdaptivePalette.accent.withValues(
                                alpha: 0.55,
                              ),
                              borderStrokeWidth: 2,
                            ),
                          )
                          .toList(growable: false),
                    ),
                  PolylineLayer(
                    polylines: segments
                        .where((points) => points.length > 1)
                        .map(
                          (points) => Polyline(
                            points: points
                                .map(
                                  (point) => LatLng(
                                    point.latitude,
                                    point.longitude,
                                  ),
                                )
                                .toList(growable: false),
                            strokeWidth: 5,
                            color: AppAdaptivePalette.accent,
                          ),
                        )
                        .toList(growable: false),
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(
                          startPoint.latitude,
                          startPoint.longitude,
                        ),
                        width: 44,
                        height: 44,
                        child: const _MapMarker(
                          icon: Icons.play_arrow_rounded,
                          tooltip: 'Начало основной смены',
                        ),
                      ),
                      if (finishPoint != null)
                        Marker(
                          point: LatLng(
                            finishPoint.latitude,
                            finishPoint.longitude,
                          ),
                          width: 44,
                          height: 44,
                          child: const _MapMarker(
                            icon: Icons.stop_rounded,
                            tooltip: 'Завершение основной смены',
                          ),
                        ),
                      ...gapMarkers,
                      if (selectedPoint != null)
                        Marker(
                          point: LatLng(
                            selectedPoint!.latitude,
                            selectedPoint!.longitude,
                          ),
                          width: 38,
                          height: 38,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppAdaptivePalette.accent,
                                width: 4,
                              ),
                            ),
                            child: const Icon(
                              Icons.access_time_rounded,
                              size: 18,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              Positioned(
                left: 10,
                top: 10,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surface
                        .withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    child: Text(
                      'Нажмите на маршрут — увидите время',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
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

  Future<void> _selectNearest(
    LatLng tapped,
    List<EmployeeLocationPoint> points,
  ) async {
    final distance = Distance();
    EmployeeLocationPoint? nearest;
    var nearestMeters = double.infinity;
    for (final point in points) {
      final meters = distance.as(
        LengthUnit.Meter,
        tapped,
        LatLng(point.latitude, point.longitude),
      );
      if (meters < nearestMeters) {
        nearest = point;
        nearestMeters = meters;
      }
    }
    if (nearest == null || nearestMeters > 150) return;
    setState(() => selectedPoint = nearest);
    await _showPoint(nearest);
  }

  Future<void> _showPoint(EmployeeLocationPoint point) async {
    final geofence = widget.data.geofenceForShift(point.shiftId);
    double? distanceFromCenter;
    if (geofence != null) {
      distanceFromCenter = Distance().as(
        LengthUnit.Meter,
        LatLng(geofence.latitude, geofence.longitude),
        LatLng(point.latitude, point.longitude),
      );
    }
    EmployeeTrackingGap? previousGap;
    for (final gap in widget.data.gaps) {
      if (gap.shiftId != point.shiftId || gap.endedAt.isAfter(point.recordedAt)) {
        continue;
      }
      final distance = point.recordedAt.difference(gap.endedAt);
      if (distance <= const Duration(minutes: 2)) previousGap = gap;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _dateTime(point.recordedAt),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            _SummaryRow('Точность', '${point.accuracyM.round()} м'),
            if (point.speedMps != null)
              _SummaryRow(
                'Скорость',
                '${(point.speedMps! * 3.6).round()} км/ч',
              ),
            _SummaryRow('Тип точки', _sourceTitle(point.source)),
            if (geofence != null && distanceFromCenter != null)
              _SummaryRow(
                'Относительно объекта',
                distanceFromCenter <= geofence.radiusM + 40
                    ? 'На объекте'
                    : 'За пределами на ${_distanceText(distanceFromCenter - geofence.radiusM)}',
              ),
            if (previousGap != null) ...[
              const SizedBox(height: 10),
              Text(
                'Перед этой точкой координат не было ${_duration(previousGap.duration)}.',
                style: TextStyle(
                  color: AppAdaptivePalette.danger,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
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
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutsideEpisode {
  final DateTime startedAt;
  final DateTime? returnedAt;
  final DateTime endedAt;
  final double maxDistanceFromBorderM;
  final bool approximateStart;

  const _OutsideEpisode({
    required this.startedAt,
    required this.returnedAt,
    required this.endedAt,
    required this.maxDistanceFromBorderM,
    required this.approximateStart,
  });

  Duration get duration => endedAt.difference(startedAt);
}

List<_OutsideEpisode> _outsideEpisodes(_RouteScreenData data) {
  final result = <_OutsideEpisode>[];
  final distance = Distance();

  for (final shift in data.shifts) {
    final geofence = data.geofenceForShift(shift.id);
    if (geofence == null) continue;
    final points = data.points
        .where((point) => point.shiftId == shift.id)
        .toList(growable: false)
      ..sort((left, right) => left.recordedAt.compareTo(right.recordedAt));
    if (points.isEmpty) continue;

    EmployeeLocationPoint? outsideStart;
    var maxDistanceFromBorder = 0.0;
    for (final point in points) {
      final centerDistance = distance.as(
        LengthUnit.Meter,
        LatLng(geofence.latitude, geofence.longitude),
        LatLng(point.latitude, point.longitude),
      );
      final allowance = point.accuracyM.clamp(20, 60).toDouble();
      final outside = centerDistance > geofence.radiusM + allowance;
      if (outside) {
        outsideStart ??= point;
        maxDistanceFromBorder = math.max(
          maxDistanceFromBorder,
          math.max(0, centerDistance - geofence.radiusM),
        );
        continue;
      }
      if (outsideStart == null) continue;
      final duration = point.recordedAt.difference(outsideStart.recordedAt);
      if (duration >= const Duration(minutes: 2) ||
          maxDistanceFromBorder >= 250) {
        result.add(
          _OutsideEpisode(
            startedAt: outsideStart.recordedAt,
            returnedAt: point.recordedAt,
            endedAt: point.recordedAt,
            maxDistanceFromBorderM: maxDistanceFromBorder,
            approximateStart: _startsAfterGap(
              data.gaps,
              shift.id,
              outsideStart.recordedAt,
            ),
          ),
        );
      }
      outsideStart = null;
      maxDistanceFromBorder = 0;
    }

    if (outsideStart != null) {
      final end = shift.endedAt ?? points.last.recordedAt;
      final duration = end.difference(outsideStart.recordedAt);
      if (duration >= const Duration(minutes: 2) ||
          maxDistanceFromBorder >= 250) {
        result.add(
          _OutsideEpisode(
            startedAt: outsideStart.recordedAt,
            returnedAt: null,
            endedAt: end,
            maxDistanceFromBorderM: maxDistanceFromBorder,
            approximateStart: _startsAfterGap(
              data.gaps,
              shift.id,
              outsideStart.recordedAt,
            ),
          ),
        );
      }
    }
  }

  result.sort((left, right) => left.startedAt.compareTo(right.startedAt));
  return result;
}

bool _startsAfterGap(
  List<EmployeeTrackingGap> gaps,
  String shiftId,
  DateTime startedAt,
) {
  for (final gap in gaps) {
    if (gap.shiftId != shiftId || gap.endedAt.isAfter(startedAt)) continue;
    if (startedAt.difference(gap.endedAt) <= const Duration(minutes: 2)) {
      return true;
    }
  }
  return false;
}

List<List<EmployeeLocationPoint>> _routeSegments(
  _RouteScreenData data,
  List<EmployeeLocationPoint> points,
) {
  final byShift = <String, List<EmployeeLocationPoint>>{};
  for (final point in points) {
    final key = point.shiftId.isEmpty ? '__day__' : point.shiftId;
    byShift.putIfAbsent(key, () => <EmployeeLocationPoint>[]).add(point);
  }

  final result = <List<EmployeeLocationPoint>>[];
  final distance = Distance();
  for (final entry in byShift.entries) {
    final values = entry.value
      ..sort((left, right) => left.recordedAt.compareTo(right.recordedAt));
    if (values.isEmpty) continue;
    var current = <EmployeeLocationPoint>[values.first];
    for (var index = 1; index < values.length; index++) {
      final previous = values[index - 1];
      final next = values[index];
      final timeGap = next.recordedAt.difference(previous.recordedAt);
      final meters = distance.as(
        LengthUnit.Meter,
        LatLng(previous.latitude, previous.longitude),
        LatLng(next.latitude, next.longitude),
      );
      final recordedGap = data.gaps.any(
        (gap) =>
            (gap.shiftId == entry.key || entry.key == '__day__') &&
            gap.startedAt.isBefore(next.recordedAt) &&
            gap.endedAt.isAfter(previous.recordedAt),
      );
      final shouldSplit = recordedGap ||
          timeGap >= EmployeeRouteDay.inferredGapThreshold ||
          meters >= 500;
      if (shouldSplit) {
        result.add(current);
        current = <EmployeeLocationPoint>[next];
      } else {
        current.add(next);
      }
    }
    result.add(current);
  }
  return result;
}

EmployeeLocationPoint? _sourcePoint(
  Iterable<EmployeeLocationPoint> points,
  String source,
) {
  for (final point in points) {
    if (point.source == source) return point;
  }
  return null;
}

EmployeeLocationPoint? _firstPointAfterGap(
  List<EmployeeLocationPoint> points,
  EmployeeTrackingGap gap,
) {
  for (final point in points) {
    if (point.shiftId == gap.shiftId && !point.recordedAt.isBefore(gap.endedAt)) {
      return point;
    }
  }
  return null;
}

Duration _shiftDuration(EmployeeWorkShift shift) {
  final start = shift.startedAt;
  if (start == null) return Duration.zero;
  final end = shift.endedAt ?? DateTime.now();
  if (!end.isAfter(start)) return Duration.zero;
  return end.difference(start);
}

DateTime _safeDate(DateTime? value) =>
    value ?? DateTime.fromMillisecondsSinceEpoch(0);

String _date(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day.$month.${value.year}';
}

String _time(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _dateTime(DateTime? value) {
  if (value == null) return '—';
  return '${_date(value)} ${_time(value)}';
}

String _duration(Duration value) {
  final totalMinutes = math.max(0, value.inMinutes);
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  if (hours == 0) return '$minutes мин';
  if (minutes == 0) return '$hours ч';
  return '$hours ч $minutes мин';
}

String _distanceText(double meters) {
  final safe = math.max(0, meters);
  if (safe < 1000) return '${safe.round()} м';
  return '${(safe / 1000).toStringAsFixed(1)} км';
}

String _sourceTitle(String source) => switch (source) {
      'start' => 'Начало смены',
      'finish' => 'Завершение смены',
      _ => 'Маршрутная точка',
    };

String _error(Object? value) {
  final text = value?.toString().replaceFirst('Exception: ', '').trim() ?? '';
  return text.isEmpty ? 'Неизвестная ошибка' : text;
}
