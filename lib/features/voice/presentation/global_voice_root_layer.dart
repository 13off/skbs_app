import 'package:flutter/material.dart';

import '../app_voice_profile_controller.dart';
import 'global_voice_assistant_layer.dart';

class GlobalVoiceRootLayer extends StatelessWidget {
  final Widget child;

  const GlobalVoiceRootLayer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: AppVoiceProfileController.state,
      child: child,
      builder: (context, profile, navigator) {
        final content = navigator ?? const SizedBox.shrink();
        if (profile == null) return content;
        return GlobalVoiceAssistantLayer(
          key: ValueKey<String>(
            'global-voice-root:${profile.id}:${profile.role}:${profile.activeCompanyId}:${profile.objectName}',
          ),
          profile: profile,
          child: content,
        );
      },
    );
  }
}
