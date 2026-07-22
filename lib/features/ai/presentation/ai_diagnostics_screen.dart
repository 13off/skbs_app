import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/app_user_profile.dart';
import '../../../widgets/premium_ui.dart';
import '../../documents/data/document_template_repository.dart';
import '../data/ai_action_audit_repository.dart';
import '../data/ai_assistant_repository.dart';

class AiDiagnosticsScreen extends StatefulWidget {
  final AppUserProfile profile;
  final String? selectedObjectName;

  const AiDiagnosticsScreen({
    super.key,
    required this.profile,
    required this.selectedObjectName,
  });

  @override
  State<AiDiagnosticsScreen> createState() => _AiDiagnosticsScreenState();
}

class _AiDiagnosticsScreenState extends State<AiDiagnosticsScreen> {
  final List<_DiagnosticResult> results = <_DiagnosticResult>[];
  bool isRunning = false;

  String? get effectiveObjectName {
    final selected = widget.selectedObjectName?.trim() ?? '';
    if (selected.isNotEmpty) return selected;
    final assigned = widget.profile.objectName.trim();
    return assigned.isEmpty ? null : assigned;
  }

  Future<void> runDiagnostics() async {
    if (isRunning) return;
    setState(() {
      isRunning = true;
      results.clear();
    });

    await _run('Авторизованная сессия', () async {
      final session = Supabase.instance.client.auth.currentSession;
      final user = session?.user;
      if (session == null || user == null) {
        throw StateError('Нет активной пользовательской сессии');
      }
      return user.email?.trim().isNotEmpty == true
          ? user.email!.trim()
          : user.id;
    });

    await _run('Активная компания', () async {
      final companyId = widget.profile.activeCompanyId.trim();
      if (companyId.isEmpty) throw StateError('Активная компания не выбрана');
      return companyId;
    });

    await _run('Журнал действий ИИ', () async {
      final history = await AiActionAuditRepository.fetchHistory(
        companyId: widget.profile.activeCompanyId,
        limit: 1,
      );
      return history.isEmpty ? 'Доступ подтверждён, записей пока нет' : 'Доступ подтверждён';
    });

    await _run('Каталог шаблонов', () async {
      final templates = await DocumentTemplateRepository.fetchTemplates(
        companyId: widget.profile.activeCompanyId,
      );
      return 'Доступно шаблонов: ${templates.length}';
    });

    await _runProposal(
      title: 'Универсальный поиск',
      prompt: 'Покажи краткую справку по доступным рабочим данным',
      expectedActionType: null,
    );

    if (effectiveObjectName == null) {
      _append(
        const _DiagnosticResult.warning(
          title: 'Черновик задачи',
          details: 'Пропущено: для безопасной проверки нужен выбранный объект',
        ),
      );
    } else {
      await _runProposal(
        title: 'Черновик задачи',
        prompt: 'Поставь на завтра диагностическую задачу: проверка связи',
        expectedActionType: 'create_task_draft',
      );
    }

    await _runProposal(
      title: 'Черновик документа',
      prompt: 'Подготовь служебную записку: диагностика связи',
      expectedActionType: 'prepare_document',
    );

    await _runProposal(
      title: 'Операционное предложение',
      prompt: 'Открой месячный табель за июль 2026',
      expectedActionType: 'open_period_timesheet',
    );

    if (mounted) setState(() => isRunning = false);
  }

  Future<void> _runProposal({
    required String title,
    required String prompt,
    required String? expectedActionType,
  }) {
    return _run(title, () async {
      final response = await AiAssistantRepository.request(
        mode: 'chat',
        companyId: widget.profile.activeCompanyId,
        objectName: effectiveObjectName,
        prompt: prompt,
      );
      if (expectedActionType != null) {
        final actual = response.action?.type ?? '';
        if (actual != expectedActionType) {
          throw StateError(
            'Ожидалось действие $expectedActionType, получено ${actual.isEmpty ? 'без действия' : actual}',
          );
        }
      }
      return response.action == null
          ? 'Ответ получен без выполнения действий'
          : 'Предложение ${response.action!.type} получено, но не выполнено';
    });
  }

  Future<void> _run(
    String title,
    Future<String> Function() operation,
  ) async {
    try {
      final details = await operation();
      _append(_DiagnosticResult.success(title: title, details: details));
    } catch (error) {
      final details = error.toString().replaceFirst('Exception: ', '').trim();
      _append(
        _DiagnosticResult.failure(
          title: title,
          details: details.isEmpty ? 'Неизвестная ошибка' : details,
        ),
      );
    }
  }

  void _append(_DiagnosticResult result) {
    if (!mounted) return;
    setState(() => results.add(result));
  }

  @override
  Widget build(BuildContext context) {
    final passed = results.where((item) => item.state == _DiagnosticState.success).length;
    final failed = results.where((item) => item.state == _DiagnosticState.failure).length;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),title: const Text('Диагностика ИИ')),
      body: PremiumWorkBackdrop(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            PremiumWorkCard(
              radius: 24,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Безопасный smoke-тест',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Проверяются текущая JWT-сессия, RLS, журнал, шаблоны и получение предварительных ответов edge-функций. Диагностика не подтверждает, не сохраняет и не выполняет действия.',
                    style: TextStyle(height: 1.45, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 14),
                  Text('Область: ${effectiveObjectName ?? 'все доступные объекты'}'),
                  if (results.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Успешно: $passed • Ошибок: $failed'),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: isRunning ? null : runDiagnostics,
                      icon: isRunning
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.health_and_safety_outlined),
                      label: Text(isRunning ? 'Проверяем…' : 'Запустить диагностику'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            for (final result in results) ...[
              _DiagnosticCard(result: result),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

enum _DiagnosticState { success, warning, failure }

class _DiagnosticResult {
  final String title;
  final String details;
  final _DiagnosticState state;

  const _DiagnosticResult._({
    required this.title,
    required this.details,
    required this.state,
  });

  const _DiagnosticResult.success({required String title, required String details})
      : this._(title: title, details: details, state: _DiagnosticState.success);

  const _DiagnosticResult.warning({required String title, required String details})
      : this._(title: title, details: details, state: _DiagnosticState.warning);

  const _DiagnosticResult.failure({required String title, required String details})
      : this._(title: title, details: details, state: _DiagnosticState.failure);
}

class _DiagnosticCard extends StatelessWidget {
  final _DiagnosticResult result;

  const _DiagnosticCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final icon = switch (result.state) {
      _DiagnosticState.success => Icons.check_circle_outline,
      _DiagnosticState.warning => Icons.info_outline,
      _DiagnosticState.failure => Icons.error_outline,
    };
    final color = switch (result.state) {
      _DiagnosticState.success => const Color(0xFF236A45),
      _DiagnosticState.warning => const Color(0xFF8A6417),
      _DiagnosticState.failure => const Color(0xFF874540),
    };

    return PremiumWorkCard(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                SelectableText(result.details, style: const TextStyle(height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
