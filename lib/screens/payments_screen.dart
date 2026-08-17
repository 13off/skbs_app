import 'package:flutter/material.dart';

import '../app/app_adaptive_palette.dart';
import '../features/payments/presentation/screens/payments_screen.dart' as feature;

class PaymentsScreen extends StatelessWidget {
  final String? selectedObjectName;

  const PaymentsScreen({super.key, this.selectedObjectName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipTheme = theme.chipTheme.copyWith(
      backgroundColor: AppAdaptivePalette.surfaceElevated,
      selectedColor: AppAdaptivePalette.accentSoft,
      checkmarkColor: AppAdaptivePalette.accent,
      side: BorderSide(color: AppAdaptivePalette.border),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      labelStyle: TextStyle(
        color: AppAdaptivePalette.textPrimary,
        fontWeight: FontWeight.w800,
      ),
    );

    return Theme(
      data: theme.copyWith(chipTheme: chipTheme),
      child: feature.PaymentsScreen(selectedObjectName: selectedObjectName),
    );
  }
}
