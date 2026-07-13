import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/app_theme.dart';
import '../../../widgets/premium_ui.dart';
import '../data/company_repository.dart';

const Color _billingText = Color(0xFF1F2328);
const Color _billingMuted = Color(0xFF6B7075);
const Color _billingSoft = Color(0xFFF1F0EC);
const Color _billingLine = Color(0xFFE4E2DC);
const Color _billingAccent = Color(0xFF646A70);

class CompanyPlansScreen extends StatefulWidget {
  final CompanyDashboard dashboard;

  const CompanyPlansScreen({super.key, required this.dashboard});

  @override
  State<CompanyPlansScreen> createState() => _CompanyPlansScreenState();
}

class _CompanyPlansScreenState extends State<CompanyPlansScreen> {
  late Future<_CompanyPlansData> dataFuture;
  bool isSubmitting = false;
  String? submittingPlanCode;

  @override
  void initState() {
    super.initState();
    dataFuture = loadData();
  }

  Future<_CompanyPlansData> loadData() async {
    final values = await Future.wait<dynamic>([
      CompanyRepository.fetchBillingPlans(),
      CompanyRepository.fetchOpenPlanRequest(widget.dashboard.company.id),
    ]);

    return _CompanyPlansData(
      plans: values[0] as List<CompanyBillingPlan>,
      openRequest: values[1] as CompanyPlanRequest?,
    );
  }

  Future<void> refresh() async {
    final future = loadData();
    setState(() => dataFuture = future);
    await future;
  }

  String currentPlanTitle(CompanySummary company) {
    switch (company.planCode) {
      case 'internal':
        return 'Внутренний тариф';
      case 'starter':
        return 'Старт';
      case 'business':
        return 'Бизнес';
      case 'enterprise':
        return 'Корпоративный';
      default:
        return 'Пробный период';
    }
  }

  String billingStatusTitle(CompanySummary company) {
    if (company.planCode == 'internal' || company.billingStatus == 'internal') {
      return 'Без ограничений по сроку';
    }

    if (company.billingStatus == 'active') {
      return 'Тариф активен';
    }

    if (company.billingStatus == 'past_due') {
      return 'Нужно продлить оплату';
    }

    if (company.billingStatus == 'canceled') {
      return 'Подписка завершена';
    }

    final end = company.trialEndsAt;
    if (end == null) return 'Пробный период';

    final days = end.difference(DateTime.now()).inDays + 1;
    if (days <= 0) return 'Пробный период завершён';

    return 'Осталось дней: $days';
  }

  String formatPrice(int? value) {
    if (value == null) return 'По договору';

    final formatted = value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    );

    return '$formatted ₽ / мес';
  }

  String requestPlanName(
    CompanyPlanRequest request,
    List<CompanyBillingPlan> plans,
  ) {
    for (final plan in plans) {
      if (plan.code == request.planCode) return plan.name;
    }
    return request.planCode;
  }

  String currentContactName() {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    for (final member in widget.dashboard.members) {
      if (member.userId == userId) {
        return member.fullName.isEmpty ? member.email : member.fullName;
      }
    }

    return '';
  }

  Future<void> submitRequest(CompanyBillingPlan plan) async {
    if (isSubmitting) return;

    final email = Supabase.instance.client.auth.currentUser?.email?.trim() ?? '';
    if (!email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('В профиле не найден email для связи'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Запросить тариф «${plan.name}»?'),
          content: Text(
            'Заявка будет отправлена команде AppСтрой. '
            'Для связи используем $email. Оплата сейчас не списывается.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Отправить заявку'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      isSubmitting = true;
      submittingPlanCode = plan.code;
    });

    try {
      await CompanyRepository.requestPlan(
        companyId: widget.dashboard.company.id,
        planCode: plan.code,
        contactName: currentContactName(),
        contactEmail: email,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Заявка на тариф «${plan.name}» отправлена')),
      );
      await refresh();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
          submittingPlanCode = null;
        });
      }
    }
  }

  Widget buildCurrentPlanCard() {
    final company = widget.dashboard.company;
    final memberProgress = company.seatLimit <= 0
        ? 0.0
        : (widget.dashboard.members.length / company.seatLimit)
              .clamp(0.0, 1.0)
              .toDouble();
    final objectProgress = company.objectLimit <= 0
        ? 0.0
        : (widget.dashboard.objects.length / company.objectLimit)
              .clamp(0.0, 1.0)
              .toDouble();

    return PremiumWorkCard(
      radius: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _billingSoft,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: _billingLine),
                ),
                child: const Icon(
                  Icons.workspace_premium_outlined,
                  color: _billingText,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Текущий тариф',
                      style: TextStyle(
                        color: _billingMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      currentPlanTitle(company),
                      style: const TextStyle(
                        color: _billingText,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: _billingSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                billingStatusTitle(company),
                style: const TextStyle(
                  color: _billingMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _UsageLine(
            icon: Icons.groups_outlined,
            label: 'Пользователи',
            value: '${widget.dashboard.members.length} из ${company.seatLimit}',
            progress: memberProgress,
          ),
          const SizedBox(height: 14),
          _UsageLine(
            icon: Icons.apartment_outlined,
            label: 'Объекты',
            value: '${widget.dashboard.objects.length} из ${company.objectLimit}',
            progress: objectProgress,
          ),
        ],
      ),
    );
  }

  Widget buildRequestCard(
    CompanyPlanRequest request,
    List<CompanyBillingPlan> plans,
  ) {
    return PremiumWorkCard(
      radius: 24,
      tint: _billingSoft,
      child: Row(
        children: [
          const Icon(Icons.mark_email_read_outlined, color: _billingAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.statusTitle,
                  style: const TextStyle(
                    color: _billingText,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Тариф: ${requestPlanName(request, plans)}',
                  style: const TextStyle(
                    color: _billingMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPlanCard({
    required CompanyBillingPlan plan,
    required CompanyPlanRequest? openRequest,
  }) {
    final company = widget.dashboard.company;
    final isCurrent = company.planCode == plan.code;
    final isInternal = company.planCode == 'internal';
    final isRecommended = plan.code == 'business';
    final canRequest = !isInternal && !isCurrent && openRequest == null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PremiumWorkCard(
        radius: 28,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            plan.name,
                            style: const TextStyle(
                              color: _billingText,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (isRecommended)
                            const _PlanBadge(text: 'Рекомендуем'),
                          if (isCurrent)
                            const _PlanBadge(text: 'Текущий'),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        plan.description,
                        style: const TextStyle(
                          color: _billingMuted,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  formatPrice(plan.monthlyPriceRub),
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: _billingText,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _LimitChip(
                  icon: Icons.groups_outlined,
                  text: plan.code == 'enterprise'
                      ? 'Пользователи — индивидуально'
                      : 'До ${plan.seatLimit} пользователей',
                ),
                _LimitChip(
                  icon: Icons.apartment_outlined,
                  text: plan.code == 'enterprise'
                      ? 'Объекты — индивидуально'
                      : 'До ${plan.objectLimit} объектов',
                ),
              ],
            ),
            const SizedBox(height: 15),
            ...plan.features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: _billingAccent,
                      size: 19,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(
                          color: _billingText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            PremiumActionButton(
              label: isInternal
                  ? 'Внутренний доступ активен'
                  : isCurrent
                  ? 'Тариф уже подключён'
                  : openRequest != null
                  ? 'Заявка уже отправлена'
                  : 'Оставить заявку',
              icon: openRequest == null
                  ? Icons.arrow_forward_rounded
                  : Icons.mark_email_read_outlined,
              isLoading: isSubmitting && plan.code == submittingPlanCode,
              onPressed: canRequest && !isSubmitting
                  ? () => submitRequest(plan)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Тариф и лимиты'),
        backgroundColor: const Color(0xFFFAF9F6),
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: isSubmitting ? null : refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: PremiumBackdrop(
        child: FutureBuilder<_CompanyPlansData>(
          future: dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: PremiumDots(color: AppColors.textPrimary),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: PremiumWorkCard(
                    radius: 26,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 36),
                        const SizedBox(height: 10),
                        Text(
                          'Не удалось загрузить тарифы: ${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: refresh,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final data = snapshot.data!;

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 54),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        buildCurrentPlanCard(),
                        if (data.openRequest != null) ...[
                          const SizedBox(height: 14),
                          buildRequestCard(data.openRequest!, data.plans),
                        ],
                        const SizedBox(height: 24),
                        const Text(
                          'Тарифы для компаний',
                          style: TextStyle(
                            color: _billingText,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          'На всех тарифах доступны все функции AppСтрой. '
                          'Отличаются только лимиты и сопровождение.',
                          style: TextStyle(
                            color: _billingMuted,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...data.plans.map(
                          (plan) => buildPlanCard(
                            plan: plan,
                            openRequest: data.openRequest,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Заявка не списывает деньги. До подключения эквайринга '
                          'активация тарифа выполняется после согласования.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _billingMuted,
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CompanyPlansData {
  final List<CompanyBillingPlan> plans;
  final CompanyPlanRequest? openRequest;

  const _CompanyPlansData({
    required this.plans,
    required this.openRequest,
  });
}

class _UsageLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final double progress;

  const _UsageLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: _billingMuted, size: 20),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: _billingMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: _billingText,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 6,
            value: progress,
            backgroundColor: _billingSoft,
            valueColor: const AlwaysStoppedAnimation<Color>(_billingAccent),
          ),
        ),
      ],
    );
  }
}

class _LimitChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _LimitChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: _billingSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _billingLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _billingMuted, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: _billingText,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  final String text;

  const _PlanBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: _billingSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _billingLine),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _billingMuted,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
