import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_adaptive_palette.dart';
import '../data/app_cache_coordinator.dart';
import '../data/employee_repository.dart';
import '../data/object_repository.dart';
import '../features/accounting/presentation/accounting_main_screen.dart';
import '../features/company/presentation/company_setup_nudge.dart';
import '../features/company_chat/presentation/company_chat_shell.dart';
import '../features/developer/presentation/developer_main_screen.dart';
import '../features/foreman/presentation/foreman_main_screen.dart';
import '../features/legal/presentation/legal_main_screen.dart';
import '../features/profile/data/personal_profile_controller.dart';
import '../features/recruitment/presentation/recruitment_main_screen.dart';
import '../features/reports/presentation/manager_main_screen.dart';
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
    PersonalProfileController.configure(widget.profile);
    // Репозитории используют статические кеши. Новый MainScreen может быть
    // создан после выхода, смены пользователя или компании без вызова
    // didUpdateWidget у прежнего экземпляра, поэтому очищаем их до прогрева.
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
      // Справочники имеют объединение одинаковых активных запросов. Задачи и
      // табель загружаются рабочими экранами: параллельный прогрев раньше
      // создавал повторные запросы в момент запуска приложения.
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
    if (profile.isAdmin) {
      return ManagerMainScreen(profile: profile);
    }
    if (profile.isForeman) {
      return ForemanMainScreen(profile: profile);
    }
    return premium.MainScreen(profile: profile);
  }

  Widget buildPlatform() {
    return ValueListenableBuilder(
      valueListenable: PersonalProfileController.state,
      builder: (context, _, __) {
        final liveBaseProfile = PersonalProfileController.merge(widget.profile);
        return ValueListenableBuilder<RolePreviewState>(
          valueListenable: RolePreviewController.state,
          builder: (context, preview, _) {
            final profile = effectiveProfile(liveBaseProfile, preview);
            final platform = KeyedSubtree(
              key: ValueKey<String>(
                'platform:${profile.role}:${profile.objectName}:${profile.activeCompanyId}',
              ),
              child: platformFor(profile),
            );

            final content = !profile.isRolePreview
                ? platform
                : _RolePreviewFrame(profile: profile, child: platform);
            return CompanyChatShell(
              key: ValueKey<String>(
                'chat:${profile.id}:${profile.fullName}:${profile.avatarPath}',
              ),
              profile: profile,
              child: CompanySetupNudge(profile: profile, child: content),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      'Режим: ${profile.roleTitle}$objectText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppAdaptivePalette.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: RolePreviewController.showAdmin,
                    style: TextButton.styleFrom(
                      foregroundColor: AppAdaptivePalette.accent,
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
