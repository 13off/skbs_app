import 'package:flutter/widgets.dart';

import '../features/auth/presentation/offline_first_auth_gate.dart';
import '../widgets/push_permission_prompt_host.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return const PushPermissionPromptHost(
      child: OfflineFirstAuthGate(),
    );
  }
}
