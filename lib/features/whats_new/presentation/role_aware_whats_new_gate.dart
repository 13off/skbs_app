import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/app_user_profile.dart';
import '../../../navigation/app_modal_overlay_coordinator.dart';

part 'whats_new_release_data.dart';
part 'whats_new_dialog.dart';
part 'whats_new_preview_current_release.dart';

class WhatsNewGate extends StatefulWidget {
  final AppUserProfile profile;
  final Widget child;

  const WhatsNewGate({super.key, required this.profile, required this.child});

  @override
  State<WhatsNewGate> createState() => _WhatsNewGateState();
}

class _WhatsNewGateState extends State<WhatsNewGate> {
  static const String releaseId =
      'mobile-2026-09-26-1.3.10+24-v2';
  static const String _preferencePrefix = 'whats_new_seen_release';

  bool _checkStarted = false;
  final Object _overlayToken = Object();
  bool _overlayBlocked = false;

  String get _preferenceKey =>
      '$_preferencePrefix:${widget.profile.id}:${widget.profile.role}';

  @override
  void initState() {
    super.initState();
    if (!widget.profile.isRolePreview && _slidesFor(widget.profile).isNotEmpty) {
      AppModalOverlayCoordinator.begin(_overlayToken);
      _overlayBlocked = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _showIfNeeded());
  }

  void _releaseOverlayBlock() {
    if (!_overlayBlocked) return;
    _overlayBlocked = false;
    AppModalOverlayCoordinator.end(_overlayToken);
  }

  @override
  void dispose() {
    _releaseOverlayBlock();
    super.dispose();
  }

  Future<void> _showIfNeeded() async {
    if (_checkStarted || !mounted || widget.profile.isRolePreview) {
      _releaseOverlayBlock();
      return;
    }
    _checkStarted = true;

    SharedPreferences? preferences;
    String? seenRelease;
    try {
      preferences = await SharedPreferences.getInstance();
      seenRelease = preferences.getString(_preferenceKey);
    } catch (_) {
      // Ошибка локального хранилища не блокирует выпуск.
    }

    if (!mounted || seenRelease == releaseId) {
      _releaseOverlayBlock();
      return;
    }

    final slides = _slidesFor(widget.profile);
    if (slides.isEmpty) {
      _releaseOverlayBlock();
      return;
    }

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: const Color(0xD905070B),
        builder: (context) => _WhatsNewDialog(
          profile: widget.profile,
          slides: slides,
        ),
      );

      try {
        await preferences?.setString(_preferenceKey, releaseId);
      } catch (_) {
        // В текущем запуске выпуск уже просмотрен.
      }
    } finally {
      _releaseOverlayBlock();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
