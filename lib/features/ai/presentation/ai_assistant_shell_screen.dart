import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import 'ai_action_history_screen.dart';
import 'ai_assistant_confirmed_screen.dart' as confirmed;
import 'ai_diagnostics_screen.dart';
import '../../../navigation/app_page_route.dart';

class AiAssistantScreen extends StatelessWidget {
  final AppUserProfile profile;
  final String? selectedObjectName;

  const AiAssistantScreen({
    super.key,
    required this.profile,
    required this.selectedObjectName,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        confirmed.AiAssistantScreen(
          profile: profile,
          selectedObjectName: selectedObjectName,
        ),
        Positioned(
          right: 12,
          top: MediaQuery.paddingOf(context).top + kToolbarHeight + 10,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            elevation: 3,
            borderRadius: BorderRadius.circular(999),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Диагностика ИИ',
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      AppPageRoute<void>(
                        builder: (_) => AiDiagnosticsScreen(
                          profile: profile,
                          selectedObjectName: selectedObjectName,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.health_and_safety_outlined),
                ),
                IconButton(
                  tooltip: 'Журнал действий ИИ',
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      AppPageRoute<void>(
                        builder: (_) => AiActionHistoryScreen(profile: profile),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
