import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../data/user_repository.dart';
import '../../../widgets/premium_ui.dart';
import '../data/company_repository.dart';

class CompanySwitcherScreen extends StatefulWidget {
  final String activeCompanyId;

  const CompanySwitcherScreen({
    super.key,
    required this.activeCompanyId,
  });

  @override
  State<CompanySwitcherScreen> createState() => _CompanySwitcherScreenState();
}

class _CompanySwitcherScreenState extends State<CompanySwitcherScreen> {
  late Future<List<CompanySummary>> companiesFuture;
  String? switchingCompanyId;
  String? errorText;

  @override
  void initState() {
    super.initState();
    companiesFuture = CompanyRepository.fetchMyCompanies();
  }

  Future<void> refresh() async {
    final future = CompanyRepository.fetchMyCompanies();
    setState(() => companiesFuture = future);
    await future;
  }

  Future<void> selectCompany(CompanySummary company) async {
    if (switchingCompanyId != null || company.id == widget.activeCompanyId) {
      return;
    }
    setState(() {
      switchingCompanyId = company.id;
      errorText = null;
    });
    try {
      await UserRepository.setActiveCompany(company.id);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(
          () => errorText = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => switchingCompanyId = null);
    }
  }

  Widget errorState(BuildContext context, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 38),
                const SizedBox(height: 12),
                Text(
                  'Не удалось загрузить компании',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget companyTile(CompanySummary company) {
    final isCurrent = company.id == widget.activeCompanyId;
    final isSwitching = switchingCompanyId == company.id;

    return Card(
      elevation: 0,
      color: Colors.white.withValues(alpha: isCurrent ? 0.96 : 0.82),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isCurrent ? AppColors.textPrimary : Colors.white,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 9,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: Color(0xFFF0F1F3),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.apartment_rounded),
        ),
        title: Text(
          company.name,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(company.roleTitle),
        trailing: isSwitching
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                isCurrent
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
              ),
        onTap: isCurrent ? null : () => selectCompany(company),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Выбрать компанию')),
      body: PremiumBackdrop(
        child: FutureBuilder<List<CompanySummary>>(
          future: companiesFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData &&
                snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: PremiumDots(color: AppColors.textPrimary),
              );
            }
            if (snapshot.hasError) {
              return errorState(context, snapshot.error!);
            }

            final companies = snapshot.data ?? const <CompanySummary>[];
            return LayoutBuilder(
              builder: (context, constraints) {
                final horizontal = math.max(
                  16.0,
                  (constraints.maxWidth - 720) / 2,
                );
                return RefreshIndicator(
                  onRefresh: refresh,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      16,
                      horizontal,
                      40,
                    ),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.76),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              color: AppColors.textPrimary,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Данные, объекты и сотрудники каждой компании полностью изолированы.',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  height: 1.4,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF2F1),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: const Color(0xFFF0D2CF),
                            ),
                          ),
                          child: Text(
                            errorText!,
                            style: const TextStyle(
                              color: Color(0xFF874540),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      ...companies.map(companyTile),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

