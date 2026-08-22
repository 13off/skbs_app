import 'package:supabase_flutter/supabase_flutter.dart';

class FinancePeriod {
  final int? year;
  final int? month;

  const FinancePeriod.month({required int this.year, required int this.month});

  const FinancePeriod.allTime() : year = null, month = null;

  bool get isAllTime => year == null || month == null;

  String title() {
    if (isAllTime) return 'за всё время';

    final monthName = _monthNames[month! - 1];

    return 'за $monthName $year';
  }

  String pickerTitle() {
    if (isAllTime) return 'За всё время';

    final monthName = _monthNamesCapitalized[month! - 1];

    return '$monthName $year';
  }

  static FinancePeriod current(DateTime date) {
    return FinancePeriod.month(year: date.year, month: date.month);
  }

  static List<FinancePeriod> recentMonths(DateTime from, {int count = 12}) {
    final periods = <FinancePeriod>[];

    for (var i = 0; i < count; i++) {
      final date = DateTime(from.year, from.month - i, 1);

      periods.add(FinancePeriod.month(year: date.year, month: date.month));
    }

    return periods;
  }

  static const List<String> _monthNames = [
    'январь',
    'февраль',
    'март',
    'апрель',
    'май',
    'июнь',
    'июль',
    'август',
    'сентябрь',
    'октябрь',
    'ноябрь',
    'декабрь',
  ];

  static const List<String> _monthNamesCapitalized = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];
}

class FinanceSummaryData {
  final double accrued;
  final double paid;

  const FinanceSummaryData({required this.accrued, required this.paid});

  static const empty = FinanceSummaryData(accrued: 0, paid: 0);

  double get balance => accrued - paid;

  double get paidProgress {
    if (accrued <= 0) return 0.0;

    return (paid / accrued).clamp(0.0, 1.0).toDouble();
  }
}

class FinanceSummaryRepository {
  static final _client = Supabase.instance.client;

  /// Одновременные одинаковые запросы используют один Future.
  ///
  /// Постоянный кэш здесь намеренно не хранится, чтобы после изменения табеля
  /// или выплаты главная всегда показывала свежую сумму.
  static const Duration _cacheTtl = Duration(seconds: 20);
  static final Map<String, Future<FinanceSummaryData>> _inFlight = {};
  static final Map<String, _FinanceSummaryCacheEntry> _cache = {};
  static int _cacheGeneration = 0;

  static void clearCache() {
    _cacheGeneration++;
    _inFlight.clear();
    _cache.clear();
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();

    return double.tryParse(value.toString()) ?? 0;
  }

  static String? _cleanObjectName(String? objectName) {
    final clean = objectName?.trim();

    if (clean == null || clean.isEmpty) return null;

    return clean;
  }

  static String _requestKey({
    required FinancePeriod period,
    required String? objectName,
  }) {
    final periodPart = period.isAllTime
        ? 'all'
        : '${period.year}-${period.month}';
    final objectPart = _cleanObjectName(objectName) ?? '__all__';

    return '$periodPart::$objectPart';
  }

  static Future<FinanceSummaryData> fetchSummary({
    required FinancePeriod period,
    String? objectName,
    bool forceRefresh = false,
  }) {
    final key = _requestKey(period: period, objectName: objectName);
    final cached = _cache[key];
    if (!forceRefresh &&
        cached != null &&
        DateTime.now().difference(cached.createdAt) < _cacheTtl) {
      return Future<FinanceSummaryData>.value(cached.data);
    }

    final running = _inFlight[key];
    if (running != null) return running;

    final generation = _cacheGeneration;
    late final Future<FinanceSummaryData> future;
    future = _loadSummary(period: period, objectName: objectName)
        .then((data) {
          if (generation == _cacheGeneration) {
            _cache[key] = _FinanceSummaryCacheEntry(
              data: data,
              createdAt: DateTime.now(),
            );
          }
          return data;
        })
        .whenComplete(() {
          if (identical(_inFlight[key], future)) _inFlight.remove(key);
        });
    _inFlight[key] = future;
    return future;
  }

  static Future<FinanceSummaryData> _loadSummary({
    required FinancePeriod period,
    String? objectName,
  }) async {
    final response = await _client.rpc<dynamic>(
      'get_finance_summary_fast',
      params: <String, dynamic>{
        'p_year': period.year,
        'p_month': period.month,
        'p_object_name': _cleanObjectName(objectName),
      },
    );
    if (response is! List || response.isEmpty) {
      return FinanceSummaryData.empty;
    }

    final row = Map<String, dynamic>.from(response.first as Map);
    return FinanceSummaryData(
      accrued: _toDouble(row['accrued']),
      paid: _toDouble(row['paid']),
    );
  }
}

class _FinanceSummaryCacheEntry {
  final FinanceSummaryData data;
  final DateTime createdAt;

  const _FinanceSummaryCacheEntry({
    required this.data,
    required this.createdAt,
  });
}
