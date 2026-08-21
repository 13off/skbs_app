import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_adaptive_palette.dart';
import '../data/app_cache_coordinator.dart';
import '../data/app_session_scope.dart';
import '../data/employee_repository.dart';
import '../data/object_repository.dart';
import '../features/accounting/presentation/accounting_main_screen.dart';
import '../features/company_chat/presentation/company_chat_shell.dart';
import '../features/developer/presentation/developer_main_screen.dart';
import '../features/employee/presentation/employee_platform_with_passport.dart';
import '../features/foreman/presentation/foreman_main_screen.dart';
import '../features/legal/presentation/legal_main_screen.dart';
import '../features/procurement/presentation/procurement_main_screen.dart';
import '../features/profile/data/personal_profile_controller.dart';
import '../features/recruitment/presentation/recruitment_main_screen.dart';
import '../features/reports/presentation/manager_main_screen.dart';
import '../features/role_preview/role_preview_controller.dart';
import '../features/shell/presentation/persistent_tab_shell.dart';
import '../features/shell/presentation/premium_main_screen.dart' as premium;
import '../features/whats_new/presentation/role_aware_whats_new_gate.dart';
import '../models/app_user_profile.dart';
import '../navigation/navigation_session.dart';
import '../widgets/premium_ui.dart';

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
    PersonalProfileController.configure(widget.profile);
    AppSessionScope.configure(
      userId: widget.profile.id,
      companyId: widget.profile.activeCompanyId,
    );
    AppCacheCoordinator.clearAll();
    navigationRestoreFuture = restoreNavigation();
    if (widget.profile.isAdmin || widget.profile.isForeman) {
      unawaited(warmUpApplication());
    }
  }

  @override
  void didUpdateWidget(covariant MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final identityChanged = oldWidget.profile.id != widget.profile.id;
    final companyChanged =
        oldWidget.profile.activeCompanyId != widget.profile.activeCompanyId;
    if (identityChanged) PersonalProfileController.configure(widget.profile);
    if (!identityChanged && !companyChanged) return;

    warmupToken++;
    AppSessionScope.configure(
      userId: widget.profile.id,
      companyId: widget.profile.activeCompanyId,
    );
    AppCacheCoordinator.clearAll();
    navigationRestoreFuture = restoreNavigation();
    if (widget.profile.isAdmin || widget.profile.isForeman) {
      unawaited(warmUpApplication());
    }
  }

  @override
  void dispose() {
    warmupToken++;
    super.dispose();
  }

  Future<void> restoreNavigation() async {
    try {
      await Future.wait<void>([
        NavigationSession.configure(
          userId: widget.profile.id,
          companyId: widget.profile.activeCompanyId,
        ),
        RolePreviewController.restore(
          canPreviewRoles: widget.profile.canPreviewRoles,
        ),
      ]);
    } catch (_) {
      RolePreviewController.reset(clearPersisted: false);
    }
  }

  String? initialObjectNameFor(AppUserProfile profile) {
    if (profile.isAdmin) return null;
    final value = profile.objectName.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> warmUpApplication() async {
    final token = ++warmupToken;
    final profile = PersonalProfileController.merge(widget.profile);
    final objectName = initialObjectNameFor(profile);
    try {
      await Future.wait<dynamic>([
        EmployeeRepository.fetchEmployees(
          objectName: objectName,
          includeFired: true,
        ),
        ObjectRepository.fetchObjects(),
      ]).timeout(_maximumWarmup);
      if (!mounted || token != warmupToken) return;
    } catch (_) {
      // Остаток данных загрузится внутри экранов.
    }
  }

  AppUserProfile effectiveProfile(
    AppUserProfile baseProfile,
    RolePreviewState preview,
  ) {
    if (!baseProfile.canPreviewRoles || preview.isAdminMode) {
      return baseProfile;
    }
    return baseProfile.previewAs(
      role: preview.role,
      objectName: preview.objectName,
    );
  }

  Widget platformFor(
    AppUserProfile profile, {
    String previewEmployeeId = '',
    String previewEmployeeName = '',
  }) {
    if (profile.role == 'employee') {
      return EmployeePlatformWithPassport(
        profile: profile,
        initialEmployeeId: previewEmployeeId,
        initialEmployeeName: previewEmployeeName,
      );
    }
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
    if (profile.isProcurement) {
      return ProcurementMainScreen(profile: profile);
    }
    if (profile.isAdmin) {
      return ManagerMainScreen(profile: profile);
    }
    if (profile.isForeman) {
      return ForemanMainScreen(profile: profile);
    }
    return premium.MainScreen(profile: profile);
  }

  Widget workVisualScope(Widget child) {
    return LiquidGlassStyleScope(
      depth: PersistentTabShell.workDepth,
      cardRadius: PersistentTabShell.workCardRadius,
      hidePageSubtitles: false,
      compactPageLayout: true,
      child: child,
    );
  }

  Widget buildPlatform() {
    return ValueListenableBuilder(
      valueListenable: PersonalProfileController.state,
      builder: (context, _, _) {
        final liveBaseProfile = PersonalProfileController.merge(widget.profile);
        return ValueListenableBuilder<RolePreviewState>(
          valueListenable: RolePreviewController.state,
          builder: (context, preview, _) {
            final profile = effectiveProfile(liveBaseProfile, preview);
            final platform = KeyedSubtree(
              key: ValueKey<String>(
                'platform:${profile.id}:${profile.role}:${profile.objectName}:${preview.employeeId}:${profile.activeCompanyId}',
              ),
              child: platformFor(
                profile,
                previewEmployeeId: preview.employeeId,
                previewEmployeeName: preview.employeeName,
              ),
            );

            final content = !profile.isRolePreview
                ? platform
                : _RolePreviewFrame(
                    profile: profile,
                    employeeName: preview.employeeName,
                    child: platform,
                  );

            if (profile.isEmployee) return workVisualScope(content);
            return workVisualScope(
              CompanyChatShell(
                key: ValueKey<String>(
                  'chat:${profile.id}:${profile.fullName}:${profile.avatarPath}',
                ),
                profile: profile,
                child: content,
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);

    return FutureBuilder<void>(
      future: navigationRestoreFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Material(
            color: AppAdaptivePalette.background,
            child: Center(
              child: SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppAdaptivePalette.accent,
                ),
              ),
            ),
          );
        }
        return WhatsNewGate(profile: widget.profile, child: buildPlatform());
      },
    );
  }
}

class _RolePreviewFrame extends StatelessWidget {
  final AppUserProfile profile;
  final String employeeName;
  final Widget child;

  const _RolePreviewFrame({
    required this.profile,
    required this.employeeName,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final objectText = profile.isForeman && profile.objectName.trim().isNotEmpty
        ? ' · ${profile.objectName.trim()}'
        : '';
    final employeeText = profile.isEmployee && employeeName.trim().isNotEmpty
        ? ' · ${employeeName.trim()}'
        : '';

    return Material(
      color: AppAdaptivePalette.background,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
              decoration: BoxDecoration(
                color: AppAdaptivePalette.surfaceElevated,
                border: Border(
                  bottom: BorderSide(color: AppAdaptivePalette.border),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    color: AppAdaptivePalette.textPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Режим: ${profile.roleTitle}$objectText$employeeText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppAdaptivePalette.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: RolePreviewController.showAdmin,
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    label: const Text('К руководителю'),
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
