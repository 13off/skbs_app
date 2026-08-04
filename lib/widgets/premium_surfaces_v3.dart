import 'package:flutter/material.dart';

import 'app_page.dart';
import 'app_stroy_brand.dart';

class PremiumBackdrop extends StatelessWidget {
  final Widget child;

  const PremiumBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AppSurfaceBackdrop(child: child);
  }
}

class PremiumLoadingScreen extends StatelessWidget {
  final String message;

  const PremiumLoadingScreen({
    super.key,
    this.message = 'Загрузка',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppStroyBrandStage(
        showProgress: true,
        semanticsLabel: '$message. AppСтрой. планируй. строй. управляй.',
      ),
    );
  }
}
