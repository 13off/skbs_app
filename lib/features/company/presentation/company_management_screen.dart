import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../navigation/app_page_route.dart';
import 'company_branding_settings_screen.dart';
import 'desktop_company_management_screen.dart';
import 'mobile_company_management_screen.dart' as mobile;

export 'mobile_company_management_screen.dart' show CompanyMemberEditorScreen;

class CompanyManagementScreen extends StatelessWidget {
  static const double desktopBreakpoint = 1050;

  final String companyId;

  const CompanyManagementScreen({super.key, required this.companyId});

  void _openBranding(BuildContext context) {
    Navigator.of(context).push<void>(
      AppPageRoute<void>(
        builder: (_) => CompanyBrandingSettingsScreen(companyId: companyId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useDesktop = kIsWeb && constraints.maxWidth >= desktopBreakpoint;
        final content = useDesktop
            ? DesktopCompanyManagementScreen(companyId: companyId)
            : mobile.CompanyManagementScreen(companyId: companyId);

        return Stack(
          children: [
            Positioned.fill(child: content),
            Positioned(
              right: 18,
              bottom: 18,
              child: SafeArea(
                minimum: EdgeInsets.zero,
                child: useDesktop
                    ? FloatingActionButton.extended(
                        heroTag: 'company-branding-$companyId',
                        onPressed: () => _openBranding(context),
                        icon: const Icon(Icons.palette_outlined),
                        label: const Text('Оформление компании'),
                      )
                    : FloatingActionButton.small(
                        heroTag: 'company-branding-$companyId',
                        tooltip: 'Оформление компании',
                        onPressed: () => _openBranding(context),
                        child: const Icon(Icons.palette_outlined),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}
