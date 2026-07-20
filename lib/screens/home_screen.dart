import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_cache_coordinator.dart';
import '../data/app_data_sync.dart';
import '../data/app_state.dart';
import '../data/attendance_repository.dart';
import '../data/employee_repository.dart';
import '../data/finance_summary_repository.dart';
import '../data/object_repository.dart';
import '../data/task_repository.dart';
import '../features/ai/presentation/ai_assistant_screen.dart';
import '../features/milestones/presentation/milestone_home_overlay.dart';
import '../models/app_user_profile.dart';
import '../models/employee.dart';
import '../models/task_item_data.dart';
import '../navigation/app_page_route.dart';
import '../widgets/notification_bell.dart';
import '../widgets/premium_ui.dart';

part 'home/home_actions.dart';
part 'home/home_loading.dart';
part 'home/home_object_actions.dart';
part 'home/home_sections.dart';
part 'home/home_view.dart';
part 'home/home_widgets.dart';

const Color _card = Color(0xFFFFFFFF);
const Color _softCard = Color(0xFFF2F3F5);
const Color _line = Color(0xFFE6E8EB);
const Color _text = Color(0xFF1F2328);
const Color _muted = Color(0xFF6B7075);
const Color _accent = Color(0xFF8F9499);
const Color _success = Color(0xFF22C55E);

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
  static const String _allObjectsValue = '__all__';
  static const String _addObjectValue = '__add_object__';
  static const String _archiveListValue = '__archive_list__';
  static const String _editObjectPrefix = '__edit_object__::';
  static const String _archiveObjectPrefix = '__archive_object__::';

  Future<_HomeDashboardData>? dashboardFuture;
  Future<List<String>>? objectNamesFuture;
  FinancePeriod financePeriod = FinancePeriod.current(AppState.today);
  StreamSubscription<AppDataChange>? dataChangeSubscription;

  @override
  void initState() {
    super.initState();
    dashboardFuture = loadDashboardData();
    objectNamesFuture = EmployeeRepository.fetchObjectNames();
    dataChangeSubscription = AppDataSync.changes.listen(handleDataChange);
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
