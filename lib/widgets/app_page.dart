import 'package:flutter/material.dart';

import 'premium_ui_v2.dart';

const Color _appText = Color(0xFF1F2328);

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
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 120),
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
                    const SizedBox(height: 14),
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

  @override
  Widget build(BuildContext context) {
    final action = trailing;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _appText,
              fontSize: 20,
              height: 1.1,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.25,
            ),
          ),
        ),
        if (action != null) ...[
          const SizedBox(width: 12),
          Flexible(fit: FlexFit.loose, child: action),
        ],
      ],
    );
  }
}
