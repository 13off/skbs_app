import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/attendance_repository.dart';
import '../data/employee_repository.dart';
import '../data/object_repository.dart';
import '../data/task_repository.dart';
import '../features/accounting/presentation/accounting_main_screen.dart';
import '../features/developer/presentation/developer_main_screen.dart';
import '../features/foreman/presentation/foreman_main_screen.dart';
import '../features/legal/presentation/legal_main_screen.dart';
import '../features/recruitment/presentation/recruitment_main_screen.dart';
import '../features/role_preview/role_preview_controller.dart';
import '../features/shell/presentation/premium_main_screen.dart' as premium;
import '../features/whats_new/presentation/whats_new_gate.dart';
import '../models/app_user_profile.dart';
import '../navigation/navigation_session.dart';

class MainScreen extends StatefulWidget {
  final AppUserProfile profile;

  const MainScreen({super.key, required this.profile});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const Duration _maximumWarmup = Duration(seconds: 7);
  int warmupToken = 0;
  late Future<void> navigationRestoreFuture;

  @override
  void initState() {
    super.initState();
    navigationRestoreFuture = restoreNavigation();
    if (widget.profile.isAdmin || widget.profile.isForeman) {
      unawaited(warmUpApplication());
    }
  }

  @override
  void didUpdateWidget(covariant MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id ||
        oldWidget.profile.activeCompanyId != widget.profile.activeCompanyId) {
      navigationRestoreFuture = restoreNavigation();
    }
  }

  @override
  void dispose() {
    warmupToken++;
    super.dispose();
  }

  Future<void> restoreNavigation() async {
    try {
      await NavigationSession.configure(
        userId: widget.profile.id,
        companyId: widget.profile.activeCompanyId,
      );
      await RolePreviewController.restore(
        canPreviewRoles: widget.profile.canPreviewRoles,
      );
    } catch (_) {
      RolePreviewController.reset(clearPersisted: false);
    }
  }

  String? get initialObjectName {
    if (widget.profile.isAdmin) return null;
    final value = widget.profile.objectName.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> warmUpApplication() async {
    final token = ++warmupToken;
    final today = AppState.today;
    final objectName = initialObjectName;
    try {
      await Future.wait<dynamic>([
        EmployeeRepository.fetchEmployees(
          objectName: objectName,
          includeFired: true,
        ),
        ObjectRepository.fetchObjects(),
        AttendanceRepository.fetchShiftValuesForDate(
          today,
          objectName: objectName,
        ),
        TaskRepository.fetchTasksForDate(today, objectName: objectName),
      ]).timeout(_maximumWarmup);
      if (!mounted || token != warmupToken) return;
    } catch (_) {
      // Остаток данных загрузится внутри экранов.
    }
  }

  AppUserProfile effectiveProfile(RolePreviewState preview) {
    if (!widget.profile.canPreviewRoles || preview.isAdminMode) {
      return widget.profile;
    }
    return widget.profile.previewAs(
      role: preview.role,
      objectName: preview.objectName,
    );
  }

  Widget platformFor(AppUserProfile profile) {
    if (profile.isDeveloper) {
      return DeveloperMainScreen(profile: profile);
    }
    if (profile.isLawyer) {
      return LegalMainScreen(profile: profile);
    }
    if (profile.isAccountant) {
      return AccountingMainScreen(profile: profile);
    }
    if (profile.isHr) {
      return RecruitmentMainScreen(profile: profile);
    }
    if (profile.isForeman) {
      return ForemanMainScreen(profile: profile);
    }
    return premium.MainScreen(profile: profile);
  }

  Widget buildPlatform() {
    return ValueListenableBuilder<RolePreviewState>(
      valueListenable: RolePreviewController.state,
      builder: (context, preview, _) {
        final profile = effectiveProfile(preview);
        final platform = KeyedSubtree(
          key: ValueKey<String>(
            'platform:${profile.role}:${profile.objectName}:${profile.activeCompanyId}',
          ),
          child: platformFor(profile),
        );

        if (!profile.isRolePreview) return platform;
        return _RolePreviewFrame(profile: profile, child: platform);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: navigationRestoreFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Material(
            color: Color(0xFFF8F7F3),
            child: Center(
              child: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ),
          );
        }
        return WhatsNewGate(child: buildPlatform());
      },
    );
  }
}

class _RolePreviewFrame extends StatelessWidget {
  final AppUserProfile profile;
  final Widget child;

  const _RolePreviewFrame({required this.profile, required this.child});

  @override
  Widget build(BuildContext context) {
    final objectText = profile.isForeman && profile.objectName.trim().isNotEmpty
        ? ' · ${profile.objectName.trim()}'
        : '';

    return Material(
      color: const Color(0xFFF8F7F3),
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
              decoration: const BoxDecoration(
                color: Color(0xFF1F2328),
                border: Border(bottom: BorderSide(color: Color(0xFF353A40))),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.visibility_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Режим: ${profile.roleTitle}$objectText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: RolePreviewController.showAdmin,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text(
                      'К руководителю',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
