import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AppDataDomain {
  attendance,
  payments,
  employees,
  tasks,
  objects,
  notifications,
  company,
  legal,
  recruitment,
}

class AppDataChange {
  final Set<AppDataDomain> domains;
  final bool isRemote;
  final Map<String, dynamic> context;
  final DateTime occurredAt;

  const AppDataChange({
    required this.domains,
    required this.isRemote,
    required this.context,
    required this.occurredAt,
  });

  bool affects(AppDataDomain domain) => domains.contains(domain);

  bool affectsAny(Iterable<AppDataDomain> values) {
    return values.any(domains.contains);
  }

  String? contextValue(String key) {
    final value = context[key]?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }
}

typedef AppDataCacheInvalidator = void Function(Set<AppDataDomain> domains);

class AppDataSync {
  AppDataSync._();

  static const Duration _coalesceDuration = Duration(milliseconds: 120);
  static final StreamController<AppDataChange> _changesController =
      StreamController<AppDataChange>.broadcast(sync: true);
  static final Set<AppDataDomain> _pendingDomains = <AppDataDomain>{};

  static RealtimeChannel? _channel;
  static String? _companyId;
  static AppDataCacheInvalidator? _cacheInvalidator;
  static Timer? _deliveryTimer;
  static bool _pendingHasRemote = false;
  static bool _hasSubscribedOnce = false;
  static Map<String, dynamic> _pendingContext = <String, dynamic>{};

  static Stream<AppDataChange> get changes => _changesController.stream;

  static void start({
    required String companyId,
    required AppDataCacheInvalidator invalidateCaches,
  }) {
    final cleanCompanyId = companyId.trim();
    _cacheInvalidator = invalidateCaches;

    if (cleanCompanyId.isEmpty) {
      _removeRealtimeChannel();
      _companyId = null;
      return;
    }

    if (_companyId == cleanCompanyId && _channel != null) return;

    _removeRealtimeChannel();
    _companyId = cleanCompanyId;
    _hasSubscribedOnce = false;

    final channel = Supabase.instance.client.channel(
      'company:$cleanCompanyId:data',
      opts: const RealtimeChannelConfig(private: true),
    );

    channel
        .onBroadcast(event: 'app_data_changed', callback: _handleRemotePayload)
        .subscribe((status, _) {
          if (status != RealtimeSubscribeStatus.subscribed) return;
          if (_hasSubscribedOnce) _refreshAfterReconnect();
          _hasSubscribedOnce = true;
        });

    _channel = channel;
  }

  static void stop({String? companyId}) {
    final cleanCompanyId = companyId?.trim();
    if (cleanCompanyId != null &&
        cleanCompanyId.isNotEmpty &&
        cleanCompanyId != _companyId) {
      return;
    }

    _removeRealtimeChannel();
    _companyId = null;
    _cacheInvalidator = null;
    _deliveryTimer?.cancel();
    _deliveryTimer = null;
    _pendingDomains.clear();
    _pendingContext = <String, dynamic>{};
    _pendingHasRemote = false;
  }

  static void notifyLocal(
    Set<AppDataDomain> domains, {
    Map<String, dynamic> context = const <String, dynamic>{},
  }) {
    _queueChange(domains: domains, context: context, isRemote: false);
  }

  static void refreshAll() {
    // В браузере и установленном PWA сворачивание/возврат часто создаёт
    // lifecycle resumed, хотя соединение и данные не менялись. Общий refresh
    // здесь заставлял активный табель полностью перезагружаться.
    if (kIsWeb) return;

    _queueFullRefresh(source: 'resume');
  }

  static void _refreshAfterReconnect() {
    // Настоящее повторное подключение realtime должно обновить кэши на всех
    // платформах, включая Web/PWA.
    _queueFullRefresh(source: 'reconnect');
  }

  static void _queueFullRefresh({required String source}) {
    _queueChange(
      domains: const <AppDataDomain>{
        AppDataDomain.attendance,
        AppDataDomain.payments,
        AppDataDomain.employees,
        AppDataDomain.tasks,
        AppDataDomain.objects,
        AppDataDomain.notifications,
        AppDataDomain.legal,
        AppDataDomain.recruitment,
      },
      context: <String, dynamic>{'source': source},
      isRemote: true,
    );
  }

  static void _handleRemotePayload(Map<String, dynamic> payload) {
    final nestedPayload = payload['payload'];
    final context = nestedPayload is Map
        ? Map<String, dynamic>.from(nestedPayload)
        : Map<String, dynamic>.from(payload);
    final table = context['table']?.toString().trim().toLowerCase() ?? '';
    final domains = _domainsForTable(table);
    if (domains.isEmpty) return;
    _queueChange(domains: domains, context: context, isRemote: true);
  }

  static Set<AppDataDomain> _domainsForTable(String table) {
    switch (table) {
      case 'attendance':
        return const <AppDataDomain>{AppDataDomain.attendance};
      case 'payments':
      case 'payment_receipts':
        return const <AppDataDomain>{AppDataDomain.payments};
      case 'employees':
      case 'employee_private_data':
      case 'employee_comments':
      case 'employee_documents':
        return const <AppDataDomain>{AppDataDomain.employees};
      case 'tasks':
      case 'task_assignees':
      case 'task_photos':
        return const <AppDataDomain>{AppDataDomain.tasks};
      case 'objects':
        return const <AppDataDomain>{
          AppDataDomain.objects,
          AppDataDomain.employees,
          AppDataDomain.attendance,
          AppDataDomain.payments,
          AppDataDomain.tasks,
          AppDataDomain.legal,
          AppDataDomain.recruitment,
        };
      case 'app_notifications':
        return const <AppDataDomain>{AppDataDomain.notifications};
      case 'companies':
      case 'company_memberships':
      case 'object_memberships':
        return const <AppDataDomain>{AppDataDomain.company};
      case 'legal_counterparties':
      case 'legal_documents':
      case 'legal_document_files':
      case 'legal_matters':
      case 'weekly_reports':
      case 'scheduled_reminders':
      case 'app_files':
      case 'audit_log':
        return const <AppDataDomain>{AppDataDomain.legal};
      case 'recruitment_applications':
        return const <AppDataDomain>{AppDataDomain.recruitment};
      default:
        return const <AppDataDomain>{};
    }
  }

  static void _queueChange({
    required Set<AppDataDomain> domains,
    required Map<String, dynamic> context,
    required bool isRemote,
  }) {
    if (domains.isEmpty) return;
    _pendingDomains.addAll(domains);
    _pendingHasRemote = _pendingHasRemote || isRemote;
    if (context.isNotEmpty) {
      _pendingContext = Map<String, dynamic>.from(context);
    }
    _deliveryTimer?.cancel();
    _deliveryTimer = Timer(_coalesceDuration, _deliverPendingChange);
  }

  static void _deliverPendingChange() {
    _deliveryTimer = null;
    if (_pendingDomains.isEmpty) return;

    final domains = Set<AppDataDomain>.unmodifiable(_pendingDomains);
    final context = Map<String, dynamic>.unmodifiable(_pendingContext);
    final isRemote = _pendingHasRemote;

    _pendingDomains.clear();
    _pendingContext = <String, dynamic>{};
    _pendingHasRemote = false;

    _cacheInvalidator?.call(domains);
    _changesController.add(
      AppDataChange(
        domains: domains,
        isRemote: isRemote,
        context: context,
        occurredAt: DateTime.now(),
      ),
    );
  }

  static void _removeRealtimeChannel() {
    final channel = _channel;
    _channel = null;
    _hasSubscribedOnce = false;
    if (channel == null) return;
    unawaited(_removeChannel(channel));
  }

  static Future<void> _removeChannel(RealtimeChannel channel) async {
    await Supabase.instance.client.removeChannel(channel);
  }
}
