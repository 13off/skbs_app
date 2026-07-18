import 'package:supabase_flutter/supabase_flutter.dart';

import '../../dispatcher/data/dispatcher_summary_repository.dart';

class ManagerReportObjectOption {
  final String id;
  final String name;
  final String address;

  const ManagerReportObjectOption({
    required this.id,
    required this.name,
    required this.address,
  });

  factory ManagerReportObjectOption.fromJson(Map<String, dynamic> json) {
    return ManagerReportObjectOption(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
    );
  }
}

class ManagerReportDetailItem {
  final String id;
  final String title;
  final String subtitle;
  final String note;

  const ManagerReportDetailItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.note,
  });

  factory ManagerReportDetailItem.fromJson(Map<String, dynamic> json) {
    return ManagerReportDetailItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Запись',
      subtitle: json['subtitle']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
    );
  }
}

class ManagerReportsCenter {
  final DateTime reportDate;
  final ManagerReportObjectOption? selectedObject;
  final List<ManagerReportObjectOption> objects;
  final Map<String, dynamic> metrics;
  final Map<String, dynamic> trend;
  final Map<String, List<ManagerReportDetailItem>> details;
  final List<DispatcherSummaryRun> dispatcherRuns;

  const ManagerReportsCenter({
    required this.reportDate,
    required this.selectedObject,
    required this.objects,
    required this.metrics,
    required this.trend,
    required this.details,
    required this.dispatcherRuns,
  });

  factory ManagerReportsCenter.fromJson(Map<String, dynamic> json) {
    final selected = _map(json['selected_object']);
    final rawDetails = _map(json['details']);
    final parsedDetails = <String, List<ManagerReportDetailItem>>{};
    for (final entry in rawDetails.entries) {
      parsedDetails[entry.key] = _list(entry.value)
          .map((item) => ManagerReportDetailItem.fromJson(_map(item)))
          .toList();
    }

    return ManagerReportsCenter(
      reportDate:
          DateTime.tryParse(json['report_date']?.toString() ?? '') ?? DateTime.now(),
      selectedObject: selected.isEmpty
          ? null
          : ManagerReportObjectOption.fromJson(selected),
      objects: _list(json['objects'])
          .map((item) => ManagerReportObjectOption.fromJson(_map(item)))
          .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
          .toList(),
      metrics: _map(json['metrics']),
      trend: _map(json['trend']),
      details: parsedDetails,
      dispatcherRuns: _list(json['dispatcher_runs'])
          .map((item) => DispatcherSummaryRun.fromJson(_map(item)))
          .toList(),
    );
  }

  Map<String, dynamic> section(String key) => _map(metrics[key]);

  int metric(String sectionKey, String valueKey) {
    return _asInt(section(sectionKey)[valueKey]);
  }

  double decimalMetric(String sectionKey, String valueKey) {
    return _asDouble(section(sectionKey)[valueKey]);
  }

  int get criticalCount => _asInt(metrics['critical_count']);

  double trendValue(String key) => _asDouble(trend[key]);

  int trendInt(String key) => _asInt(trend[key]);

  List<ManagerReportDetailItem> detailItems(String key) {
    return details[key] ?? const <ManagerReportDetailItem>[];
  }
}

class ManagerReportsRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<ManagerReportsCenter> fetch({
    String? objectId,
    required DateTime reportDate,
  }) async {
    final result = await _client.rpc<dynamic>(
      'get_manager_reports_center',
      params: <String, dynamic>{
        'p_object_id': objectId?.trim().isEmpty == true ? null : objectId,
        'p_report_date': _date(reportDate),
      },
    );
    return ManagerReportsCenter.fromJson(_map(result));
  }

  static String _date(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

List<dynamic> _list(dynamic value) {
  if (value is List) return value;
  return const <dynamic>[];
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
