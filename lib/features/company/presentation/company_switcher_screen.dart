import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
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
              color: AppAdaptivePalette.surfaceElevated,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppAdaptivePalette.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 38,
                  color: AppAdaptivePalette.textPrimary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Не удалось загрузить компании',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppAdaptivePalette.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppAdaptivePalette.textMuted),
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
      color: isCurrent
          ? AppAdaptivePalette.selectedSurface
          : AppAdaptivePalette.surfaceElevated,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isCurrent
              ? AppAdaptivePalette.accent
              : AppAdaptivePalette.border,
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
          decoration: BoxDecoration(
            color: AppAdaptivePalette.surfaceSoft,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.apartment_rounded,
            color: AppAdaptivePalette.textPrimary,
          ),
        ),
        title: Text(
          company.name,
          style: TextStyle(
            color: AppAdaptivePalette.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          company.roleTitle,
          style: TextStyle(color: AppAdaptivePalette.textMuted),
        ),
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
                color: isCurrent
                    ? AppAdaptivePalette.accent
                    : AppAdaptivePalette.textMuted,
              ),
        onTap: isCurrent ? null : () => selectCompany(company),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Выбрать компанию'),
      ),
      body: PremiumBackdrop(
        child: FutureBuilder<List<CompanySummary>>(
          future: companiesFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData &&
                snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: PremiumDots(color: AppAdaptivePalette.textPrimary),
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
                          color: AppAdaptivePalette.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppAdaptivePalette.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              color: AppAdaptivePalette.textPrimary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Данные, объекты и сотрудники каждой компании полностью изолированы.',
                                style: TextStyle(
                                  color: AppAdaptivePalette.textMuted,
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
                            color: AppAdaptivePalette.danger.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: AppAdaptivePalette.danger.withValues(
                                alpha: 0.32,
                              ),
                            ),
                          ),
                          child: Text(
                            errorText!,
                            style: TextStyle(
                              color: AppAdaptivePalette.danger,
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
