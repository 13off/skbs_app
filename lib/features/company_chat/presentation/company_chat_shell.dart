import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';

/// Shell contract kept for existing role screens, but the global floating chat
/// launcher is intentionally disabled. Chat data/screens remain available to
/// be wired explicitly later without placing a button over every application
/// screen.
class CompanyChatShell extends StatelessWidget {
  final AppUserProfile profile;
  final Widget child;

  const CompanyChatShell({
    super.key,
    required this.profile,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => child;
}
