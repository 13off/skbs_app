import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/user_repository.dart';
import '../../../models/app_user_profile.dart';
import '../../employee/presentation/employee_main_screen.dart';
import 'premium_auth_gate_v2.dart' as management;

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  bool isPhoneOnlyEmployee(User? user) {
    if (user == null) return false;
    final phone = user.phone?.trim() ?? '';
    final email = user.email?.trim() ?? '';
    return phone.isNotEmpty && email.isEmpty;
  }

  AppUserProfile fallbackEmployeeProfile(User user) {
    final metadataName = user.userMetadata?['full_name']?.toString().trim() ?? '';
    return AppUserProfile(
      id: user.id,
      email: user.email?.trim() ?? '',
      fullName: metadataName.isEmpty ? 'Сотрудник' : metadataName,
      phone: user.phone?.trim() ?? '',
      role: 'employee',
      profession: '',
      objectName: '',
      activeCompanyId: '',
      isActive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, _) {
        final user = Supabase.instance.client.auth.currentUser;
        if (!isPhoneOnlyEmployee(user)) {
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

            final profile = snapshot.data ?? fallbackEmployeeProfile(user!);
            return EmployeeMainScreen(profile: profile);
          },
        );
      },
    );
  }
}
