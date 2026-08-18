import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';

/// Public shell contract kept for existing call sites, while the global
/// floating microphone and its action overlay are intentionally disabled.
class GlobalVoiceAssistantLayerV2 extends StatelessWidget {
  final AppUserProfile profile;
  final Widget child;

  const GlobalVoiceAssistantLayerV2({
    super.key,
    required this.profile,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => child;
}
