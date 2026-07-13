import 'package:flutter/material.dart';

import 'premium_ui_v2.dart';

const Color _appText = Color(0xFF1F2328);
const Color _appMuted = Color(0xFF6B7075);

class AppPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? headerTrailing;

  const AppPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.headerTrailing,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumWorkBackdrop(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppPageHeader(
                      title: title,
                      subtitle: subtitle,
                      trailing: headerTrailing,
                    ),
                    const SizedBox(height: 18),
                    child,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const AppPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  Widget buildIdentity() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PremiumBrandMark(size: 50, animate: false),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'APPСТРОЙ • РАБОЧИЙ РАЗДЕЛ',
                style: TextStyle(
                  color: _appMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.75,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _appText,
                  fontSize: 30,
                  height: 1.02,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              if (subtitle.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _appMuted,
                    fontSize: 15,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      radius: 30,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final action = trailing;
          if (action == null) return buildIdentity();

          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                buildIdentity(),
                const SizedBox(height: 16),
                Align(alignment: Alignment.centerRight, child: action),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: buildIdentity()),
              const SizedBox(width: 16),
              action,
            ],
          );
        },
      ),
    );
  }
}
