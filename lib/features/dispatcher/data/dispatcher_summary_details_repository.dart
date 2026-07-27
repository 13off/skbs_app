import 'package:supabase_flutter/supabase_flutter.dart';

class DispatcherDetailItem {
  final String id;
  final String title;
  final String subtitle;
  final String note;

  const DispatcherDetailItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.note,
  });

  factory DispatcherDetailItem.fromJson(Map<String, dynamic> json) {
    return DispatcherDetailItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Запись',
      subtitle: json['subtitle']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
    );
  }
}

class DispatcherDetailGroup {
  final String key;
  final String title;
  final int count;
  final bool includedInTotal;
  final List<DispatcherDetailItem> items;

  const DispatcherDetailGroup({
    required this.key,
    required this.title,
    required this.count,
    required this.includedInTotal,
    required this.items,
  });

  factory DispatcherDetailGroup.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return DispatcherDetailGroup(
      key: json['key']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Отклонение',
      count: int.tryParse(json['count']?.toString() ?? '') ?? 0,
      includedInTotal: json['included_in_total'] == true,
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) => DispatcherDetailItem.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const <DispatcherDetailItem>[],
    );
  }
}

class DispatcherSummaryDetails {
  final String runId;
  final String objectName;
  final DateTime? summaryDate;
  final int originalCriticalCount;
  final int currentCriticalCount;
  final bool changedSinceSummary;
  final List<DispatcherDetailGroup> deviations;
  final List<DispatcherDetailGroup> contextGroups;

  const DispatcherSummaryDetails({
    required this.runId,
    required this.objectName,
    required this.summaryDate,
    required this.originalCriticalCount,
    required this.currentCriticalCount,
    required this.changedSinceSummary,
    required this.deviations,
    required this.contextGroups,
  });

  factory DispatcherSummaryDetails.fromJson(Map<String, dynamic> json) {
    return DispatcherSummaryDetails(
      runId: json['run_id']?.toString() ?? '',
      objectName: json['object_name']?.toString() ?? '',
      summaryDate: DateTime.tryParse(json['summary_date']?.toString() ?? ''),
      originalCriticalCount:
          int.tryParse(json['original_critical_count']?.toString() ?? '') ?? 0,
      currentCriticalCount:
          int.tryParse(json['current_critical_count']?.toString() ?? '') ?? 0,
      changedSinceSummary: json['changed_since_summary'] == true,
      deviations: _groups(json['deviations']),
      contextGroups: _groups(json['context_groups']),
    );
  }

  static List<DispatcherDetailGroup> _groups(dynamic value) {
    if (value is! List) return const <DispatcherDetailGroup>[];
    return value
        .whereType<Map>()
        .map(
          (item) => DispatcherDetailGroup.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .where((group) => group.count > 0)
        .toList();
  }
}

class DispatcherSummaryDetailsRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<DispatcherSummaryDetails> fetch(String runId) async {
    final result = await _client.rpc<dynamic>(
      'get_dispatcher_summary_details',
      params: <String, dynamic>{'p_run_id': runId},
    );
    final map = result is Map
        ? Map<String, dynamic>.from(result)
        : <String, dynamic>{};
    return DispatcherSummaryDetails.fromJson(map);
  }
}
