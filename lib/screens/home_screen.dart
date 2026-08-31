import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_adaptive_palette.dart';
import '../data/app_cache_coordinator.dart';
import '../data/app_data_sync.dart';
import '../data/app_state.dart';
import '../data/attendance_repository.dart';
import '../data/employee_repository.dart';
import '../data/finance_summary_repository.dart';
import '../data/object_repository.dart';
import '../data/task_repository.dart';
import '../features/milestones/presentation/milestone_home_overlay.dart';
import '../models/app_user_profile.dart';
import '../models/employee.dart';
import '../models/task_item_data.dart';
import '../widgets/notification_bell.dart';
import '../widgets/premium_ui.dart';

part 'home/home_actions.dart';
part 'home/home_loading.dart';
part 'home/home_object_actions.dart';
part 'home/home_sections.dart';
part 'home/home_view.dart';
part 'home/home_widgets.dart';

Color get _card => AppAdaptivePalette.surface;
Color get _softCard => AppAdaptivePalette.surfaceSoft;
Color get _line => AppAdaptivePalette.border;
Color get _text => AppAdaptivePalette.textPrimary;
Color get _muted => AppAdaptivePalette.textMuted;
Color get _accent => AppAdaptivePalette.accent;
Color get _success => AppAdaptivePalette.success;

class HomeScreen extends StatefulWidget {
  final AppUserProfile profile;
  final String? selectedObjectName;
  final ValueChanged<String?> onObjectChanged;

  const HomeScreen({
    super.key,
    required this.profile,
    required this.selectedObjectName,
    required this.onObjectChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String _allObjectsValue = '__all__';
  final String _addObjectValue = '__add_object__';
  final String _archiveListValue = '__archive_list__';
  final String _editObjectPrefix = '__edit_object__::';
  final String _archiveObjectPrefix = '__archive_object__::';

  Future<_HomeDashboardData>? dashboardFuture;
  Future<List<String>>? objectNamesFuture;
  FinancePeriod financePeriod = FinancePeriod.current(AppState.today);
  StreamSubscription<AppDataChange>? dataChangeSubscription;
  bool _tabActive = true;
  bool _refreshPending = false;
  bool _objectsRefreshPending = false;

  @override
  void initState() {
    super.initState();
    dashboardFuture = loadDashboardData();
    objectNamesFuture = EmployeeRepository.fetchObjectNames();
    dataChangeSubscription = AppDataSync.changes.listen(handleDataChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.of(context);
    if (_tabActive == active) return;
    _tabActive = active;
    if (_tabActive) flushDeferredDataChanges();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedObjectName != widget.selectedObjectName) {
      dashboardFuture = loadDashboardData();
    }
  }

  @override
  void dispose() {
    dataChangeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => buildHomeView();
}
