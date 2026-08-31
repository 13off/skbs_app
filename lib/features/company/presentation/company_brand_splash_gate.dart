import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/app_adaptive_palette.dart';
import '../data/company_branding_repository.dart';
import 'company_branding_editor_card.dart';

class CompanyBrandSplashGate extends StatefulWidget {
  final String companyId;
  final Widget child;

  const CompanyBrandSplashGate({
    super.key,
    required this.companyId,
    required this.child,
  });

  @override
  State<CompanyBrandSplashGate> createState() => _CompanyBrandSplashGateState();
}

class _CompanyBrandSplashGateState extends State<CompanyBrandSplashGate> {
  static final Set<String> _shownForCompany = <String>{};
  static const Duration _minimumVisible = Duration(milliseconds: 1050);
  static const Duration _remoteTimeout = Duration(seconds: 2);

  CompanyBranding? _branding;
  bool _complete = false;
  DateTime? _visibleSince;
  Timer? _fallbackTimer;

  String get _cachePrefix => 'appstroy_company_brand_v1_${widget.companyId}';

  @override
  void initState() {
    super.initState();
    if (_shownForCompany.contains(widget.companyId)) {
      _complete = true;
    } else {
      unawaited(_load());
    }
  }

  @override
  void didUpdateWidget(covariant CompanyBrandSplashGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId == widget.companyId) return;
    _fallbackTimer?.cancel();
    _branding = null;
    _visibleSince = null;
    _complete = _shownForCompany.contains(widget.companyId);
    if (!_complete) unawaited(_load());
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final cached = await _readCache();
    if (!mounted) return;
    if (cached != null) {
      setState(() {
        _branding = cached;
        _visibleSince = DateTime.now();
      });
    }

    _fallbackTimer = Timer(const Duration(milliseconds: 2600), _finish);

    try {
      final remote = await CompanyBrandingRepository.fetch(
        widget.companyId,
      ).timeout(_remoteTimeout);
      await _writeCache(remote);
      if (!mounted) return;
      setState(() {
        _branding = remote;
        _visibleSince ??= DateTime.now();
      });
      await _finishAfterMinimum();
    } catch (_) {
      if (cached != null) {
        await _finishAfterMinimum();
      } else {
        _finish();
      }
    }
  }

  Future<void> _finishAfterMinimum() async {
    final start = _visibleSince ?? DateTime.now();
    final elapsed = DateTime.now().difference(start);
    final remaining = _minimumVisible - elapsed;
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);
    _finish();
  }

  void _finish() {
    if (!mounted || _complete) return;
    _fallbackTimer?.cancel();
    _shownForCompany.add(widget.companyId);
    setState(() => _complete = true);
  }

  Future<CompanyBranding?> _readCache() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final name = preferences.getString('${_cachePrefix}_name')?.trim() ?? '';
      if (name.isEmpty) return null;
      final logoPath = preferences.getString('${_cachePrefix}_logo')?.trim();
      final updatedRaw = preferences.getString('${_cachePrefix}_updated');
      return CompanyBranding(
        companyId: widget.companyId,
        name: name,
        logoPath: logoPath?.isEmpty == true ? null : logoPath,
        updatedAt: DateTime.tryParse(updatedRaw ?? ''),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(CompanyBranding branding) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('${_cachePrefix}_name', branding.name);
      final logoPath = branding.logoPath?.trim() ?? '';
      if (logoPath.isEmpty) {
        await preferences.remove('${_cachePrefix}_logo');
      } else {
        await preferences.setString('${_cachePrefix}_logo', logoPath);
      }
      final updatedAt = branding.updatedAt;
      if (updatedAt == null) {
        await preferences.remove('${_cachePrefix}_updated');
      } else {
        await preferences.setString(
          '${_cachePrefix}_updated',
          updatedAt.toIso8601String(),
        );
      }
    } catch (_) {
      // Кэш брендинга не должен влиять на запуск приложения.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_complete) return widget.child;

    final branding = _branding;
    return Scaffold(
      backgroundColor: AppAdaptivePalette.background,
      body: SafeArea(
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: branding == null
                ? const SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : Column(
                    key: ValueKey<String>(
                      '${branding.companyId}:${branding.updatedAt}',
                    ),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CompanyLogoView(branding: branding, size: 112),
                      const SizedBox(height: 22),
                      Text(
                        branding.name,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppAdaptivePalette.textPrimary,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Компания',
                        style: TextStyle(
                          color: AppAdaptivePalette.textMuted,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
