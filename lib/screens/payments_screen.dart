import 'package:flutter/material.dart';

import '../features/payments/presentation/screens/payments_screen.dart' as feature;
import '../features/payments/presentation/widgets/pending_absence_fines_card.dart';

class PaymentsScreen extends StatelessWidget {
  final String? selectedObjectName;

  const PaymentsScreen({super.key, this.selectedObjectName});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + kToolbarHeight + 8;

    return Stack(
      children: [
        feature.PaymentsScreen(selectedObjectName: selectedObjectName),
        Positioned(
          top: top,
          left: 16,
          right: 16,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760, maxHeight: 420),
              child: SingleChildScrollView(
                child: PendingAbsenceFinesCard(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
