import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'desktop_company_management_screen.dart';
import 'mobile_company_management_screen.dart' as mobile;

class CompanyManagementScreen extends StatelessWidget {
  static const double desktopBreakpoint = 1050;

  final String companyId;

  const CompanyManagementScreen({
    super.key,
    required this.companyId,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useDesktop =
            kIsWeb && constraints.maxWidth >= desktopBreakpoint;
        if (useDesktop) {
          return DesktopCompanyManagementScreen(companyId: companyId);
        }
        return mobile.CompanyManagementScreen(companyId: companyId);
      },
    );
  }
}
