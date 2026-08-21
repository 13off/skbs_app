import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/app_user_profile.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/company_setup_repository.dart';
import 'company_setup_screen.dart';
import '../../../navigation/app_page_route.dart';

class CompanySetupRecommendationCard extends StatefulWidget {
  final AppUserProfile profile;

  const CompanySetupRecommendationCard({super.key, required this.profile});

  @override
  State<CompanySetupRecommendationCard> createState() =>
      _CompanySetupRecommendationCardState();
}

class _CompanySetupRecommendationCardState
    extends State<CompanySetupRecommendationCard> {
  Future<_CompanySetupRecommendationState>? stateFuture;
  int loadToken = 0;

  bool get isRealManager =>
      widget.profile.role == 'admin' &&
      widget.profile.actualRole == 'admin' &&
      !widget.profile.isRolePreview;

  String get dismissalKey =>
      'company_setup_recommendation_hidden:${widget.profile.id}:${widget.profile.activeCompanyId}';

  @override
  void initState() {
    super.initState();
    stateFuture = loadState();
  }

  @override
  void didUpdateWidget(covariant CompanySetupRecommendationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.id != widget.profile.id ||
        oldWidget.profile.activeCompanyId != widget.profile.activeCompanyId ||
        oldWidget.profile.role != widget.profile.role ||
        oldWidget.profile.actualRole != widget.profile.actualRole) {
      stateFuture = loadState();
    }
  }

  Future<_CompanySetupRecommendationState> loadState() async {
    final token = ++loadToken;
    if (!isRealManager || widget.profile.activeCompanyId.trim().isEmpty) {
      return const _CompanySetupRecommendationState.hidden();
    }

    final preferences = await SharedPreferences.getInstance();
    if (token != loadToken) {
      return const _CompanySetupRecommendationState.hidden();
    }
    if (preferences.getBool(dismissalKey) == true) {
      return const _CompanySetupRecommendationState.hidden();
    }

    try {
      final progress = await CompanySetupRepository.fetch(widget.profile);
      if (token != loadToken || progress.coreCompleted) {
        return const _CompanySetupRecommendationState.hidden();
      }
      return _CompanySetupRecommendationState.visible(progress);
    } catch (_) {
      // Рекомендация не должна мешать загрузке главной страницы.
      return const _CompanySetupRecommendationState.hidden();
    }
  }

  Future<void> refresh() async {
    if (!mounted) return;
    setState(() => stateFuture = loadState());
    await stateFuture;
  }

  Future<void> openDetails() async {
    await Navigator.of(context).push<void>(
      AppPageRoute<void>(
        builder: (_) => CompanySetupScreen(profile: widget.profile),
      ),
    );
    await refresh();
  }

  Future<void> dismiss() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Скрыть рекомендацию?'),
        content: const Text(
          'Чек-лист перестанет показываться на главной в этой компании. '
          'На работу приложения это не повлияет.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Больше не показывать'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(dismissalKey, true);
    if (!mounted) return;
    loadToken++;
    setState(() {
      stateFuture = Future<_CompanySetupRecommendationState>.value(
        const _CompanySetupRecommendationState.hidden(),
      );
    });
  }

  Widget buildCard(CompanySetupProgress progress) {
    final scheme = Theme.of(context).colorScheme;
    final percent = (progress.progress * 100).round();
    final nextTitle = progress.nextRequiredStep?.title ?? 'Проверить настройки';

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
        child: PremiumWorkCard(
          radius: 22,
          padding: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: openDetails,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(15, 13, 8, 13),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.rocket_launch_outlined, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Настройка компании',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Text(
                              '$percent%',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${progress.completedRequired} из ${progress.requiredSteps.length} шагов · Далее: $nextTitle',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 6,
                            value: progress.progress,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Больше не показывать',
                    onPressed: dismiss,
                    icon: const Icon(Icons.close_rounded),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final future = stateFuture;
    if (future == null) return const SizedBox.shrink();

    return FutureBuilder<_CompanySetupRecommendationState>(
      future: future,
      builder: (context, snapshot) {
        final value = snapshot.data;
        if (value == null || !value.visible || value.progress == null) {
          return const SizedBox.shrink();
        }
        return buildCard(value.progress!);
      },
    );
  }
}

class _CompanySetupRecommendationState {
  final bool visible;
  final CompanySetupProgress? progress;

  const _CompanySetupRecommendationState.hidden()
    : visible = false,
      progress = null;

  const _CompanySetupRecommendationState.visible(this.progress)
    : visible = true;
}
