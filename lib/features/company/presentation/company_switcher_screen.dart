import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../data/user_repository.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Выбрать компанию')),
      body: FutureBuilder<List<CompanySummary>>(
        future: companiesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Не удалось загрузить компании: ${snapshot.error}'),
            );
          }

          final companies = snapshot.data ?? const <CompanySummary>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Данные, объекты и сотрудники каждой компании полностью изолированы.',
                style: TextStyle(color: AppColors.textMuted, height: 1.4),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  errorText!,
                  style: const TextStyle(
                    color: Color(0xFF874540),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              ...companies.map((company) {
                final isCurrent = company.id == widget.activeCompanyId;
                final isSwitching = switchingCompanyId == company.id;
                return Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                      color: isCurrent
                          ? AppColors.textPrimary
                          : const Color(0xFFE3E5E7),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 7,
                    ),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFF0F1F3),
                      child: Icon(Icons.apartment_rounded),
                    ),
                    title: Text(
                      company.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
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
              }),
            ],
          );
        },
      ),
    );
  }
}

