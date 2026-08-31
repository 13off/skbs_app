import 'package:flutter/material.dart';

import '../../../widgets/premium_ui.dart';
import 'company_branding_editor_card.dart';

class CompanyBrandingSettingsScreen extends StatelessWidget {
  final String companyId;
  final Future<void> Function()? onChanged;

  const CompanyBrandingSettingsScreen({
    super.key,
    required this.companyId,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Оформление компании'),
      ),
      body: PremiumBackdrop(
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: CompanyBrandingEditorCard(
                  companyId: companyId,
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
