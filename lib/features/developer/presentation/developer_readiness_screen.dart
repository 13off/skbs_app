import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/documents/data/document_template_repository.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../../compliance/data/company_compliance_repository.dart';
import '../../compliance/models/company_compliance_models.dart';
import '../data/developer_policy_repository.dart';

class DeveloperReadinessScreen extends StatefulWidget {
  final AppUserProfile profile;

  const DeveloperReadinessScreen({super.key, required this.profile});

  @override
  State<DeveloperReadinessScreen> createState() =>
      _DeveloperReadinessScreenState();
}

class _DeveloperReadinessScreenState extends State<DeveloperReadinessScreen> {
  final SupabaseClient client = Supabase.instance.client;

  bool loading = true;
  List<_ReadinessCheck> checks = const <_ReadinessCheck>[];

  @override
  void initState() {
    super.initState();
    runChecks();
  }

  Future<_ReadinessCheck> check(
    String title,
    String description,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      return _ReadinessCheck(
        title: title,
        description: description,
        status: _ReadinessStatus.ok,
        result: 'Проверка пройдена',
      );
    } catch (error) {
      return _ReadinessCheck(
        title: title,
        description: description,
        status: _ReadinessStatus.failed,
        result: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  _ReadinessCheck complianceCheck(CompanyComplianceSnapshot? snapshot) {
    if (snapshot == null) {
      return const _ReadinessCheck(
        title: 'Реальные персональные документы',
        description:
            'Проверяет профиль работодателя, юридическое утверждение и восемь доказательств production gate.',
        status: _ReadinessStatus.failed,
        result: 'Не удалось прочитать compliance-настройки',
      );
    }
    if (snapshot.realDocumentsAllowed) {
      return const _ReadinessCheck(
        title: 'Реальные персональные документы',
        description:
            'Профиль работодателя утверждён, доказательства закрыты, серверный gate разрешает реальные документы.',
        status: _ReadinessStatus.ok,
        result: 'Production gate: OPEN',
      );
    }
    return _ReadinessCheck(
      title: 'Реальные персональные документы',
      description:
          'До открытия gate разрешены только тестовые или обезличенные записи. Сервер блокирует реальные ZIP, просмотр и загрузку подписанных экземпляров.',
      status: _ReadinessStatus.blocked,
      result:
          'Production gate: BLOCKED · '
          '${snapshot.gate.completedEvidenceCount}/8 доказательств · '
          'формы ${snapshot.employer.legalDocumentsApproved ? 'утверждены' : 'не утверждены'}',
    );
  }

  Future<void> runChecks() async {
    if (mounted) setState(() => loading = true);
    final companyId = widget.profile.activeCompanyId.trim();
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    CompanyComplianceSnapshot? compliance;
    try {
      if (companyId.isNotEmpty) {
        compliance = await CompanyComplianceRepository.fetchSnapshot(companyId);
      }
    } catch (_) {
      compliance = null;
    }

    final results = <_ReadinessCheck>[
      await check(
        'Сессия пользователя',
        'Проверяет действующий JWT текущего пользователя.',
        () async {
          final user = client.auth.currentUser;
          if (user == null) throw Exception('Нет активной Auth-сессии');
        },
      ),
      await check(
        'Активная компания',
        'Все системные проверки должны выполняться только внутри выбранной компании.',
        () async {
          if (companyId.isEmpty)
            throw Exception('Активная компания не выбрана');
        },
      ),
      await check(
        'RLS объектов',
        'Выполняет минимальный пользовательский запрос без service role.',
        () async {
          if (companyId.isEmpty)
            throw Exception('Активная компания не выбрана');
          await client
              .from('objects')
              .select('id')
              .eq('company_id', companyId)
              .limit(1);
        },
      ),
      await check(
        'Ограничения компании и объектов',
        'Проверяет загрузку действующих политик фото, задач и наследования.',
        () async {
          await DeveloperPolicyRepository.fetchCenter();
        },
      ),
      await check(
        'Шаблоны документов',
        'Проверяет доступ к каталогу шаблонов через текущую роль и RLS.',
        () async {
          if (companyId.isEmpty)
            throw Exception('Активная компания не выбрана');
          await DocumentTemplateRepository.fetchTemplates(companyId: companyId);
        },
      ),
      await check(
        'Edge Function и JWT',
        'Запрашивает только read-only черновик месячного табеля.',
        () async {
          if (companyId.isEmpty)
            throw Exception('Активная компания не выбрана');
          final response = await client.functions.invoke(
            'ai-operational-draft',
            body: <String, dynamic>{
              'mode': 'chat',
              'company_id': companyId,
              'object_name': widget.profile.objectName.trim(),
              'date':
                  '${now.year}-$month-${now.day.toString().padLeft(2, '0')}',
              'prompt': 'Открой месячный табель за $month.${now.year}',
            },
          );
          if (response.status < 200 || response.status >= 300) {
            throw Exception('Edge Function ответила HTTP ${response.status}');
          }
          final data = response.data;
          if (data is! Map || data['error'] != null) {
            throw Exception(
              data is Map
                  ? data['error'] ?? 'Некорректный ответ'
                  : 'Некорректный ответ',
            );
          }
        },
      ),
      complianceCheck(compliance),
      const _ReadinessCheck(
        title: 'Web/PWA после публикации',
        description:
            'GitHub Actions проверяет живой URL, commit-маркер, manifest, service worker, API-прокси и JWT-защиту.',
        status: _ReadinessStatus.external,
        result: 'Проверяется автоматически после каждого web-релиза',
      ),
      const _ReadinessCheck(
        title: 'Мобильный релиз',
        description:
            'APK/IPA не выпускаются вместе с обычными web/PWA-изменениями.',
        status: _ReadinessStatus.external,
        result: 'Требуется отдельное изменение mobile release marker',
      ),
    ];

    if (!mounted) return;
    setState(() {
      checks = results;
      loading = false;
    });
  }

  int count(_ReadinessStatus status) =>
      checks.where((item) => item.status == status).length;

  Widget summary() {
    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Готовность AppСтрой',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(
            'Компания: ${widget.profile.activeCompanyId.isEmpty ? 'не выбрана' : widget.profile.activeCompanyId}\n'
            'Роль: ${widget.profile.roleTitle}',
            style: const TextStyle(height: 1.4, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryBadge(label: 'Готово', value: count(_ReadinessStatus.ok)),
              _SummaryBadge(
                label: 'Ошибки',
                value: count(_ReadinessStatus.failed),
              ),
              _SummaryBadge(
                label: 'Заблокировано',
                value: count(_ReadinessStatus.blocked),
              ),
              _SummaryBadge(
                label: 'Внешние проверки',
                value: count(_ReadinessStatus.external),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget checkCard(_ReadinessCheck item) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (item.status) {
      _ReadinessStatus.ok => (
        Icons.check_circle_outline,
        const Color(0xFF2E7D52),
      ),
      _ReadinessStatus.failed => (Icons.error_outline, scheme.error),
      _ReadinessStatus.blocked => (Icons.lock_outline, const Color(0xFF9A6816)),
      _ReadinessStatus.external => (Icons.cloud_sync_outlined, scheme.primary),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumWorkCard(
        radius: 22,
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    item.result,
                    style: TextStyle(color: color, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Готовность и диагностика',
      showBackButton: true,
      subtitle: 'Безопасные read-only проверки production-контура',
      headerTrailing: IconButton(
        tooltip: 'Проверить снова',
        onPressed: loading ? null : runChecks,
        icon: const Icon(Icons.refresh_rounded),
      ),
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                summary(),
                const SizedBox(height: 16),
                ...checks.map(checkCard),
                const SizedBox(height: 12),
                const Text(
                  'Эта диагностика не создаёт и не изменяет рабочие записи. '
                  'Она проверяет доступ текущей роли, а серверные права по-прежнему определяются RLS, RPC и Edge Functions.',
                  style: TextStyle(height: 1.4, fontWeight: FontWeight.w700),
                ),
              ],
            ),
    );
  }
}

enum _ReadinessStatus { ok, failed, blocked, external }

class _ReadinessCheck {
  final String title;
  final String description;
  final _ReadinessStatus status;
  final String result;

  const _ReadinessCheck({
    required this.title,
    required this.description,
    required this.status,
    required this.result,
  });
}

class _SummaryBadge extends StatelessWidget {
  final String label;
  final int value;

  const _SummaryBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}
