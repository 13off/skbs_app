import 'package:flutter/material.dart';

import '../../../widgets/premium_ui.dart';

class ManagerReportTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? meta;
  final String? trailingLabel;
  final VoidCallback? onTap;
  final bool loading;
  final EdgeInsetsGeometry margin;

  const ManagerReportTile({
    super.key,
    required this.icon,
    required this.title,
    this.meta,
    this.trailingLabel,
    this.onTap,
    this.loading = false,
    this.margin = const EdgeInsets.only(bottom: 10),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cleanMeta = meta?.trim();

    return Padding(
      padding: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: loading ? null : onTap,
          child: PremiumWorkCard(
            radius: 24,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: scheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (cleanMeta != null && cleanMeta.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          cleanMeta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (loading)
                  const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                else ...[
                  if (trailingLabel != null && trailingLabel!.trim().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        trailingLabel!,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  if (onTap != null) ...[
                    const SizedBox(width: 9),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: scheme.onSurfaceVariant,
                      size: 17,
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
