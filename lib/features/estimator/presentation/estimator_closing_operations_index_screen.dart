import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../navigation/app_page_route.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/estimator_closing_repository.dart';
import '../models/estimator_period_closing.dart';
import 'estimator_closing_operations_screen.dart';

class EstimatorClosingOperationsIndexScreen extends StatefulWidget {
  final AppUserProfile profile;

  const EstimatorClosingOperationsIndexScreen({super.key, required this.profile});

  @override
  State<EstimatorClosingOperationsIndexScreen> createState() => _EstimatorClosingOperationsIndexScreenState();
}

class _EstimatorClosingOperationsIndexScreenState extends State<EstimatorClosingOperationsIndexScreen> {
  late Future<List<EstimatorPeriodClosing>> future;

  @override
  void initState() {
    super.initState();
    future = EstimatorClosingRepository.fetchClosings();
  }

  Future<void> refresh() async {
    final next = EstimatorClosingRepository.fetchClosings();
    if (mounted) setState(() => future = next);
    await next;
  }

  Future<void> open(EstimatorPeriodClosing closing) async {
    await Navigator.of(context).push<void>(
      AppPageRoute<void>(
        builder: (_) => EstimatorClosingOperationsScreen(
          closing: closing,
          profile: widget.profile,
        ),
      ),
    );
    await refresh();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Пакеты закрытия',
      subtitle: 'Документы, проверка и связка внутренней выработки с фактическими выплатами.',
      onRefresh: refresh,
      child: FutureBuilder<List<EstimatorPeriodClosing>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasError) {
            return PremiumWorkCard(
              radius: 22,
              padding: const EdgeInsets.all(18),
              child: Text('Не удалось загрузить закрытия: ${snapshot.error}'),
            );
          }
          final closings = snapshot.data ?? const <EstimatorPeriodClosing>[];
          if (closings.isEmpty) {
            return const PremiumWorkCard(
              radius: 22,
              padding: EdgeInsets.all(18),
              child: Text('Закрытий пока нет.'),
            );
          }
          return Column(
            children: closings.map((closing) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => open(closing),
                child: PremiumWorkCard(
                  radius: 20,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.folder_copy_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${closing.objectName} · ${closing.periodTitle}', style: const TextStyle(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text('${closing.statusTitle} · ${closing.itemCount} позиций · вопросов расчёта ${closing.earningsIssueCount}'),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
            )).toList(growable: false),
          );
        },
      ),
    );
  }
}
