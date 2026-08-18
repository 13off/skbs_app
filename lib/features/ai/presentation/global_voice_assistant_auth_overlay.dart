import 'package:flutter/material.dart';

/// Kept as a compatibility wrapper for the application shell. The global
/// voice controls are disabled, so authenticated screens are returned without
/// mounting listeners, profile lookups or a floating microphone overlay.
class GlobalVoiceAssistantAuthOverlay extends StatelessWidget {
  final Widget child;

  const GlobalVoiceAssistantAuthOverlay({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => child;
}
