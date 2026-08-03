import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../data/user_repository.dart';
import '../../../models/app_user_profile.dart';
import '../../employee/presentation/employee_platform_with_passport.dart';
import 'premium_auth_gate_v2.dart' as management;

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  bool isPhoneOnlySession(User? user) {
    if (user == null) return false;
    final phone = user.phone?.trim() ?? '';
    final email = user.email?.trim() ?? '';
    return phone.isNotEmpty && email.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, _) {
        final user = Supabase.instance.client.auth.currentUser;
        if (!isPhoneOnlySession(user)) {
          return const management.AuthGate();
        }

        return FutureBuilder<AppUserProfile?>(
          future: UserRepository.fetchCurrentProfile(forceRefresh: true),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final profile = snapshot.data;
            if (snapshot.hasError || profile == null || !profile.isEmployee) {
              return const _EmployeeAccessDeniedScreen();
            }

            if (!profile.isActive) {
              return const _EmployeeAccessDeniedScreen(
                title: 'Доступ отключён',
                message:
                    'Кабинет сотрудника отключён администратором компании.',
              );
            }

            return EmployeePlatformWithPassport(profile: profile);
          },
        );
      },
    );
  }
}

class _EmployeeAccessDeniedScreen extends StatefulWidget {
  final String title;
  final String message;

  const _EmployeeAccessDeniedScreen({
    this.title = 'Доступ сотрудника не подключён',
    this.message =
        'Этот номер не привязан к активному кабинету сотрудника. Руководителям, прорабам, HR, юристам и бухгалтерам нужно входить по email и паролю.',
  });

  @override
  State<_EmployeeAccessDeniedScreen> createState() =>
      _EmployeeAccessDeniedScreenState();
}

class _EmployeeAccessDeniedScreenState
    extends State<_EmployeeAccessDeniedScreen> {
  bool isLoading = false;

  Future<void> signOut() async {
    if (isLoading) return;
    setState(() => isLoading = true);
    try {
      await UserRepository.signOut();
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppAdaptivePalette.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: AppAdaptivePalette.surfaceElevated,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppAdaptivePalette.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.no_accounts_outlined,
                      size: 54,
                      color: AppAdaptivePalette.textPrimary,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppAdaptivePalette.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppAdaptivePalette.textMuted,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: isLoading ? null : signOut,
                        icon: isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.arrow_back_rounded),
                        label: const Text('Вернуться ко входу'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
