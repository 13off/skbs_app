import 'task_completion_report.dart';

class EstimatorVolumeSummary {
  final String objectName;
  final String work;
  final String unit;
  final double previousQuantity;
  final double periodQuantity;
  final double totalQuantity;
  final List<TaskCompletionReport> sources;

  const EstimatorVolumeSummary({
    required this.objectName,
    required this.work,
    required this.unit,
    required this.previousQuantity,
    required this.periodQuantity,
    required this.totalQuantity,
    required this.sources,
  });

  int get sourceCount => sources.length;

  String get previousTitle => TaskCompletionReport.formatQuantity(previousQuantity);
  String get periodTitle => TaskCompletionReport.formatQuantity(periodQuantity);
  String get totalTitle => TaskCompletionReport.formatQuantity(totalQuantity);

  static String normalizeUnit(String value) {
    final raw = value.trim().toLowerCase().replaceAll(' ', '');
    switch (raw) {
      case 'м3':
      case 'м^3':
      case 'м³':
        return 'м³';
      case 'м2':
      case 'м^2':
      case 'м²':
        return 'м²';
      case 'м.п':
      case 'м.п.':
      case 'мп':
      case 'п.м':
      case 'п.м.':
        return 'м.п.';
      case 'т':
      case 'тонн':
      case 'тонна':
      case 'тонны':
        return 'т';
      case 'кг':
      case 'килограмм':
      case 'килограммы':
        return 'кг';
      case 'шт':
      case 'шт.':
      case 'штук':
        return 'шт.';
      case 'компл':
      case 'компл.':
      case 'комплект':
        return 'компл.';
      default:
        return value.trim();
    }
  }

  static List<EstimatorVolumeSummary> build({
    required List<TaskCompletionReport> reports,
    required DateTime period,
    String objectFilter = '',
  }) {
    final periodStart = DateTime(period.year, period.month);
    final nextPeriodStart = DateTime(period.year, period.month + 1);
    final filter = objectFilter.trim().toLowerCase();
    final buckets = <String, _VolumeBucket>{};

    for (final report in reports) {
      if (!report.isApproved || report.approvedQuantity == null) continue;
      final objectName = report.objectName.trim().isEmpty
          ? 'Без объекта'
          : report.objectName.trim();
      if (filter.isNotEmpty && objectName.toLowerCase() != filter) continue;
      if (!report.taskDate.isBefore(nextPeriodStart)) continue;

      final work = report.work.trim().isEmpty
          ? 'Без наименования работы'
          : report.work.trim();
      final unit = normalizeUnit(report.unit).isEmpty
          ? '—'
          : normalizeUnit(report.unit);
      final key = '${objectName.toLowerCase()}|${work.toLowerCase()}|${unit.toLowerCase()}';
      final bucket = buckets.putIfAbsent(
        key,
        () => _VolumeBucket(objectName: objectName, work: work, unit: unit),
      );
      final quantity = report.approvedQuantity!;
      if (report.taskDate.isBefore(periodStart)) {
        bucket.previousQuantity += quantity;
      } else {
        bucket.periodQuantity += quantity;
      }
      bucket.sources.add(report);
    }

    final result = buckets.values
        .map(
          (bucket) => EstimatorVolumeSummary(
            objectName: bucket.objectName,
            work: bucket.work,
            unit: bucket.unit,
            previousQuantity: bucket.previousQuantity,
            periodQuantity: bucket.periodQuantity,
            totalQuantity: bucket.previousQuantity + bucket.periodQuantity,
            sources: List<TaskCompletionReport>.unmodifiable(bucket.sources),
          ),
        )
        .toList(growable: false);

    result.sort((a, b) {
      final objectCompare = a.objectName.toLowerCase().compareTo(
        b.objectName.toLowerCase(),
      );
      if (objectCompare != 0) return objectCompare;
      final workCompare = a.work.toLowerCase().compareTo(b.work.toLowerCase());
      if (workCompare != 0) return workCompare;
      return a.unit.toLowerCase().compareTo(b.unit.toLowerCase());
    });
    return result;
  }
}

class _VolumeBucket {
  final String objectName;
  final String work;
  final String unit;
  double previousQuantity = 0;
  double periodQuantity = 0;
  final List<TaskCompletionReport> sources = <TaskCompletionReport>[];

  _VolumeBucket({
    required this.objectName,
    required this.work,
    required this.unit,
  });
}
