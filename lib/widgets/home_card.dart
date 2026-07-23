import 'package:flutter/material.dart';

import '../app/app_adaptive_palette.dart';
import '../app/app_ui_tokens.dart';
import 'premium_ui_v2.dart';

class HomeCard extends StatelessWidget {
  final String title;
  final String value;
  final String text;
  final List<String> details;
  final IconData icon;
  final VoidCallback onTap;

  const HomeCard({
    super.key,
    required this.title,
    required this.value,
    required this.text,
    required this.details,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textMuted = Theme.of(context).colorScheme.onSurfaceVariant;
    final accent = AppAdaptivePalette.accent;

    return PremiumPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppUi.cardRadius),
      child: PremiumWorkCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppUi.controlRadius),
              ),
              child: Icon(icon, color: accent, size: 26),
            ),
            const SizedBox(width: AppUi.gap16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppUi.gap8),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppUi.gap8,
                    runSpacing: AppUi.gap4,
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 30,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        text,
                        style: TextStyle(
                          color: textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: AppUi.gap12),
                    ...details.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: AppUi.gap4),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: AppUi.gap8),
                            Expanded(
                              child: Text(
                                item,
                                style: TextStyle(
                                  color: textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
