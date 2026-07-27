import 'package:flutter/material.dart';

import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/legal_repository.dart';
import '../models/legal_models.dart';

class LegalWeeklyReportScreen extends StatefulWidget {
  const LegalWeeklyReportScreen({super.key});

  @override
  State<LegalWeeklyReportScreen> createState() =>
      _LegalWeeklyReportScreenState();
}

class _LegalWeeklyReportScreenState extends State<LegalWeeklyReportScreen> {
  final commentController = TextEditingController();
  final planController = TextEditingController();
  final decisionsController = TextEditingController();
  late Future<_ReportData> future;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  @override
  void dispose() {
    commentController.dispose();
    planController.dispose();
    decisionsController.dispose();
    super.dispose();
  }

  Future<_ReportData> load() async {
    final values = await Future.wait<dynamic>([
      LegalRepository.fetchDocuments(),
      LegalRepository.fetchMatters(),
      LegalRepository.fetchCurrentWeeklyReport(),
    ]);
    final report = values[2] as LegalWeeklyReport?;
    final weekStart = LegalRepository.currentWeekStart();
    final draft = LegalRepository.buildWeeklyDraft(
      documents: values[0] as List<LegalDocument>,
      matters: values[1] as List<LegalMatter>,
      weekStart: weekStart,
    );
    if (report != null) {
      commentController.text = report.authorComment;
      planController.text = report.nextWeekPlan;
      decisionsController.text = report.managerDecisions;
    }
    return _ReportData(report: report, draft: report?.autoDraft ?? draft);
  }

  Future<void> save(bool submit, Map<String, dynamic> draft) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await LegalRepository.saveWeeklyReport(
        autoDraft: draft,
        authorComment: commentController.text,
        nextWeekPlan: planController.text,
        managerDecisions: decisionsController.text,
        submit: submit,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            submit ? 'Отчёт отправлен руководителю' : 'Черновик сохранён',
          ),
        ),
      );
      setState(() => future = load());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось сохранить отчёт: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget draftMetric(String title, dynamic value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3F5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '${value ?? 0}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Недельный отчёт'),
      ),
      body: AppPage(
        title: 'Отчёт юриста',
        subtitle:
            'Автоматический черновик можно дополнить и отправить руководителю',
        child: FutureBuilder<_ReportData>(
          future: future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              if (snapshot.hasError) return Text('Ошибка: ${snapshot.error}');
              return const PremiumWorkCard(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            final data = snapshot.data!;
            final draft = data.draft;
            return Column(
              children: [
                PremiumWorkCard(
                  radius: 24,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      draftMetric(
                        'Подготовлено документов',
                        draft['prepared_documents'],
                      ),
                      const SizedBox(height: 8),
                      draftMetric(
                        'Подписано документов',
                        draft['signed_documents'],
                      ),
                      const SizedBox(height: 8),
                      draftMetric(
                        'Ожидают подписи',
                        draft['unsigned_documents'],
                      ),
                      const SizedBox(height: 8),
                      draftMetric(
                        'Приближаются сроки',
                        draft['approaching_deadlines'],
                      ),
                      const SizedBox(height: 8),
                      draftMetric('Высокие риски', draft['new_risks']),
                      const SizedBox(height: 8),
                      draftMetric('Решено вопросов', draft['resolved_matters']),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                PremiumWorkCard(
                  radius: 24,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      TextField(
                        controller: commentController,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Комментарий за неделю',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: planController,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'План на следующую неделю',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: decisionsController,
                        minLines: 2,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Какие решения нужны от руководителя',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: saving ? null : () => save(false, draft),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Сохранить черновик'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
                const SizedBox(height: 10),
                PremiumActionButton(
                  label: data.report?.status == 'submitted'
                      ? 'Отправить обновлённый отчёт'
                      : 'Отправить руководителю',
                  icon: Icons.send_outlined,
                  onPressed: saving ? null : () => save(true, draft),
                  isLoading: saving,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReportData {
  final LegalWeeklyReport? report;
  final Map<String, dynamic> draft;

  const _ReportData({required this.report, required this.draft});
}
