import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../widgets/premium_ui.dart';
import 'employee_max_login_screen.dart';
import 'premium_login_screen_v2.dart' as management;
import '../../../navigation/app_page_route.dart';

class LoginScreen extends StatelessWidget {
  final Future<void> Function()? onSignedIn;

  const LoginScreen({super.key, this.onSignedIn});

  Future<void> finishSignIn(BuildContext routeContext) async {
    await onSignedIn?.call();
    if (!routeContext.mounted) return;
    Navigator.of(routeContext).popUntil((route) => route.isFirst);
  }

  Future<void> openEmployeeLogin(BuildContext context) async {
    await Navigator.of(context).push<void>(
      AppPageRoute<void>(
        builder: (routeContext) => EmployeeMaxLoginScreen(
          onSignedIn: () => finishSignIn(routeContext),
        ),
      ),
    );
  }

  Future<void> openManagementLogin(BuildContext context) async {
    await Navigator.of(context).push<void>(
      AppPageRoute<void>(
        builder: (routeContext) => management.LoginScreen(
          onSignedIn: () => finishSignIn(routeContext),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PremiumBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 448),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(26, 30, 26, 24),
                  decoration: BoxDecoration(
                    color: AppAdaptivePalette.surfaceElevated,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: AppAdaptivePalette.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 48,
                        offset: const Offset(0, 22),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const PremiumBrandMark(size: 84),
                      const SizedBox(height: 22),
                      Text(
                        'AppСтрой',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: AppAdaptivePalette.textPrimary,
                              fontWeight: FontWeight.w300,
                              letterSpacing: -1,
                            ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'Выбери свой способ входа',
                        style: TextStyle(
                          color: AppAdaptivePalette.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 30),
                      _LoginChoice(
                        icon: Icons.engineering_rounded,
                        title: 'Я сотрудник',
                        subtitle: 'Подтвердить вход одной кнопкой в MAX',
                        onTap: () => openEmployeeLogin(context),
                        primary: true,
                      ),
                      const SizedBox(height: 12),
                      _LoginChoice(
                        icon: Icons.admin_panel_settings_rounded,
                        title: 'Руководитель или специалист',
                        subtitle: 'Войти по email и паролю',
                        onTap: () => openManagementLogin(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginChoice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool primary;

  const _LoginChoice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary
          ? AppAdaptivePalette.accentSoft
          : AppAdaptivePalette.inputSurface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppAdaptivePalette.surfaceElevated,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: AppAdaptivePalette.textPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppAdaptivePalette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppAdaptivePalette.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: AppAdaptivePalette.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
