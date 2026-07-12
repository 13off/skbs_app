import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/app_theme.dart';
import '../../../data/user_repository.dart';
import '../../../widgets/premium_ui.dart';

class CompanyOnboardingScreen extends StatefulWidget {
  final Future<void> Function() onCompleted;

  const CompanyOnboardingScreen({
    super.key,
    required this.onCompleted,
  });

  @override
  State<CompanyOnboardingScreen> createState() => _CompanyOnboardingScreenState();
}

class _CompanyOnboardingScreenState extends State<CompanyOnboardingScreen> {
  late final TextEditingController companyController;
  late final TextEditingController fullNameController;

  bool isLoading = false;
  String? errorText;

  @override
  void initState() {
    super.initState();
    final metadata = Supabase.instance.client.auth.currentUser?.userMetadata;
    companyController = TextEditingController(
      text: metadata?['company_name']?.toString() ?? '',
    );
    fullNameController = TextEditingController(
      text: metadata?['full_name']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    companyController.dispose();
    fullNameController.dispose();
    super.dispose();
  }

  Future<void> complete() async {
    if (isLoading) return;
    if (companyController.text.trim().length < 2 ||
        fullNameController.text.trim().length < 2) {
      setState(() => errorText = 'Укажите компанию и ваше имя');
      return;
    }

    setState(() {
      isLoading = true;
      errorText = null;
    });
    try {
      await UserRepository.createCompanyProfile(
        companyName: companyController.text,
        fullName: fullNameController.text,
      );
      await widget.onCompleted();
    } catch (error) {
      if (mounted) {
        setState(
          () => errorText = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PremiumBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.86),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.09),
                        blurRadius: 42,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const PremiumBrandMark(size: 76),
                      const SizedBox(height: 20),
                      Text(
                        'Завершите настройку',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Создайте рабочее пространство компании. Вы получите права владельца.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F2F3),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              size: 17,
                              color: AppColors.textPrimary,
                            ),
                            SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                'Отдельные данные, команда и объекты',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        controller: companyController,
                        enabled: !isLoading,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Название компании',
                          prefixIcon: Icon(Icons.apartment_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: fullNameController,
                        enabled: !isLoading,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => complete(),
                        decoration: const InputDecoration(
                          labelText: 'Ваше имя',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
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
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 19,
                                color: Color(0xFFA64F49),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  errorText!,
                                  style: const TextStyle(
                                    color: Color(0xFF874540),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      PremiumActionButton(
                        label: 'Создать рабочее пространство',
                        icon: Icons.arrow_forward_rounded,
                        isLoading: isLoading,
                        onPressed: complete,
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: isLoading ? null : UserRepository.signOut,
                        child: const Text('Выйти'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
