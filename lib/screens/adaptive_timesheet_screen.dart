import 'package:flutter/material.dart';

import '../models/app_user_profile.dart';
import 'desktop_timesheet_screen.dart';
import 'timesheet_download_sheet.dart';
import 'timesheet_screen.dart';

class AdaptiveTimesheetScreen extends StatelessWidget {
  static const double desktopBreakpoint = 1050;

  final AppUserProfile profile;
  final String? selectedObjectName;

  const AdaptiveTimesheetScreen({
    super.key,
    required this.profile,
    required this.selectedObjectName,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useDesktop = constraints.maxWidth >= desktopBreakpoint;
        final canDownload = profile.isAdmin || profile.isForeman;
        final contentProfile = profile.isAdmin
            ? profile.copyWith(role: 'foreman')
            : profile;
        final VoidCallback? downloadAction = canDownload
            ? () {
                TimesheetDownloadSheet.show(
                  context,
                  selectedObjectName: selectedObjectName,
                  initialDate: DateTime.now(),
                );
              }
            : null;

        if (useDesktop) {
          return DesktopTimesheetScreen(
            profile: contentProfile,
            selectedObjectName: selectedObjectName,
            onDownload: downloadAction,
          );
        }

        final content = TimesheetScreen(
          profile: contentProfile,
          selectedObjectName: selectedObjectName,
        );
        if (!canDownload) return content;
        return Stack(
          children: [
            content,
            Positioned(
              top: 18,
              right: 18,
              child: FilledButton.tonalIcon(
                onPressed: downloadAction,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Скачать табель'),
              ),
            ),
          ],
        );
      },
    );
  }
}
