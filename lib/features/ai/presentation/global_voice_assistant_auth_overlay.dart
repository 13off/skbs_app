import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/user_repository.dart';
import '../../../models/app_user_profile.dart';
import '../../role_preview/role_preview_controller.dart';
import 'global_voice_assistant_layer_v2.dart';

/// Keeps the global voice control clear of the floating company-chat button
/// and the bottom navigation zone without moving or shrinking app content.
const _globalVoiceBottomClearance = 88.0;

/// Auth-aware host for the global voice layer.
///
/// It is intentionally mounted above the application shell so the microphone
/// remains available while navigating between professional platforms and
/// dialogs. Before authentication (and when the profile cannot be resolved)
/// the child is returned unchanged.
class GlobalVoiceAssistantAuthOverlay extends StatefulWidget {
  final Widget child;

  const GlobalVoiceAssistantAuthOverlay({
    super.key,
    required this.child,
  });

  @override
  State<GlobalVoiceAssistantAuthOverlay> createState() =>
      _GlobalVoiceAssistantAuthOverlayState();
}

class _GlobalVoiceAssistantAuthOverlayState
    extends State<GlobalVoiceAssistantAuthOverlay> {
  StreamSubscription<AuthState>? _subscription;
  AppUserProfile? _profile;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _profile = UserRepository.cachedProfile;
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      unawaited(_reload());
    });
    unawaited(_reload());
  }

  @override
  void dispose() {
    _loadToken += 1;
    final subscription = _subscription;
    if (subscription != null) unawaited(subscription.cancel());
    super.dispose();
  }

  Future<void> _reload() async {
    final token = ++_loadToken;
    if (Supabase.instance.client.auth.currentUser == null) {
      if (mounted && token == _loadToken && _profile != null) {
        setState(() => _profile = null);
      }
      return;
    }

    try {
      final profile = await UserRepository.fetchCurrentProfile();
      if (!mounted || token != _loadToken) return;
      if (profile == null || !profile.isActive) {
        if (_profile != null) setState(() => _profile = null);
        return;
      }
      setState(() => _profile = profile);
    } catch (_) {
      // Авторизационные экраны сами покажут ошибку профиля. Голосовой слой не
      // должен мешать входу, поэтому при ошибке просто остаётся скрытым.
    }
  }

  AppUserProfile _effectiveProfile(
    AppUserProfile base,
    RolePreviewState preview,
  ) {
    if (!base.canPreviewRoles || preview.isAdminMode) return base;
    return base.previewAs(
      role: preview.role,
      objectName: preview.objectName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    if (profile == null) return widget.child;

    return ValueListenableBuilder<RolePreviewState>(
      valueListenable: RolePreviewController.state,
      builder: (context, preview, _) {
        final effective = _effectiveProfile(profile, preview);
        return Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            Positioned.fill(
              bottom: _globalVoiceBottomClearance,
              child: GlobalVoiceAssistantLayerV2(
                key: ValueKey<String>(
                  'global-voice:${effective.id}:${effective.role}:${effective.activeCompanyId}',
                ),
                profile: effective,
                child: const SizedBox.expand(),
              ),
            ),
          ],
        );
      },
    );
  }
}
