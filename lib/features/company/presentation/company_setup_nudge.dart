import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/app_user_profile.dart';
import '../data/company_setup_repository.dart';
import 'company_setup_screen.dart';

class CompanySetupNudge extends StatefulWidget {
  final AppUserProfile profile;
  final Widget child;

  const CompanySetupNudge({
    super.key,
    required this.profile,
    required this.child,
  });

  @override
  State<CompanySetupNudge> createState() => _CompanySetupNudgeState();
}

class _CompanySetupNudgeState extends State<CompanySetupNudge> {
  static const String revision = 'v1';
  bool checking = false;

  bool get enabled {
    final role = widget.profile.actualRole;
    return !widget.profile.isRolePreview &&
        (role == 'admin' || role == 'developer') &&
        widget.profile.activeCompanyId.trim().isNotEmpty;
  }

  String get storageKey =>
      'company_setup_nudge:$revision:${widget.profile.activeCompanyId}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => check());
  }

  @override
  void didUpdateWidget(covariant CompanySetupNudge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.activeCompanyId != widget.profile.activeCompanyId ||
        oldWidget.profile.actualRole != widget.profile.actualRole) {
      WidgetsBinding.instance.addPostFrameCallback((_) => check());
    }
  }

  Future<void> check() async {
    if (!enabled || checking || !mounted) return;
    checking = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      if (preferences.getBool(storageKey) == true) return;
      final progress = await CompanySetupRepository.fetch(widget.profile);
      if (!mounted || progress.coreCompleted) {
        await preferences.setBool(storageKey, true);
        return;
      }
      await preferences.setBool(storageKey, true);
      if (!mounted) return;
      final openSetup = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Завершите запуск компании'),
          content: Text(
            '${progress.completedRequired} из ${progress.requiredSteps.length} шагов готово.\n\n'
            'Следующий шаг: ${progress.nextRequiredStep?.title ?? 'проверить настройки'}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Позже'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.rocket_launch_outlined),
              label: const Text('Открыть запуск'),
            ),
          ],
        ),
      );
      if (openSetup == true && mounted) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => CompanySetupScreen(profile: widget.profile),
          ),
        );
      }
    } catch (_) {
      // Первый запуск не должен блокировать рабочую платформу.
    } finally {
      checking = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
