import 'package:flutter/material.dart';

import '../features/payments/presentation/screens/payments_screen.dart' as feature;

class PaymentsScreen extends StatelessWidget {
  final String? selectedObjectName;

  const PaymentsScreen({super.key, this.selectedObjectName});

  @override
  Widget build(BuildContext context) {
    return feature.PaymentsScreen(selectedObjectName: selectedObjectName);
  }
}
