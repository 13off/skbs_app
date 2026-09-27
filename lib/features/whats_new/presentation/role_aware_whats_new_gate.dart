import 'dart:async';
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
      'mobile-2026-09-27-1.3.11+25-v3';
  static const String _preferencePrefix = 'whats_new_seen_release';

  bool _checkStarted = false;
  final Object _overlayToken = Object();
  bool _overlayBlocked = false;
  List<_UpdateSlide> _visibleSlides = const <_UpdateSlide>[];
  Completer<void>? _dismissCompleter;

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

    final completer = Completer<void>();
    _dismissCompleter = completer;
    setState(() => _visibleSlides = slides);

    try {
      await completer.future;
      try {
        await preferences?.setString(_preferenceKey, releaseId);
      } catch (_) {
        // В текущем запуске выпуск уже просмотрен.
      }
    } finally {
      _dismissCompleter = null;
      _releaseOverlayBlock();
    }
  }

  void _dismissWhatsNew() {
    if (_visibleSlides.isEmpty) return;
    setState(() => _visibleSlides = const <_UpdateSlide>[]);
    final completer = _dismissCompleter;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  @override
  Widget build(BuildContext context) {
    final slides = _visibleSlides;
    if (slides.isEmpty) return widget.child;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        widget.child,
        const Positioned.fill(
          child: ColoredBox(color: Color(0xD905070B)),
        ),
        Positioned.fill(
          child: Material(
            type: MaterialType.transparency,
            child: SafeArea(
              child: Center(
                child: _WhatsNewDialog(
                  profile: widget.profile,
                  slides: slides,
                  onClose: _dismissWhatsNew,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
