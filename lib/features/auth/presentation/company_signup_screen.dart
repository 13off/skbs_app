import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/app_theme.dart';
import '../../../data/user_repository.dart';
import '../../../widgets/premium_ui.dart';

class CompanySignupScreen extends StatefulWidget {
  const CompanySignupScreen({super.key});

  @override
  State<CompanySignupScreen> createState() => _CompanySignupScreenState();
}

class _CompanySignupScreenState extends State<CompanySignupScreen> {
  final companyController = TextEditingController();
  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final passwordRepeatController = TextEditingController();

  bool isLoading = false;
  bool passwordVisible = false;
  String? errorText;

  @override
  void dispose() {
    companyController.dispose();
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    passwordRepeatController.dispose();
    super.dispose();
  }

  String friendlyError(Object error) {
    if (error is AuthException) {
      final text = error.message.toLowerCase();
      if (text.contains('already registered') || text.contains('already exists')) {
        return 'Пользователь с таким email уже зарегистрирован';
      }
      if (text.contains('password')) {
        return 'Пароль должен содержать не менее 8 символов';
      }
      if (text.contains('rate limit')) {
        return 'Слишком много попыток. Попробуйте немного позже';
      }
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> submit() async {
    if (isLoading) return;

    final company = companyController.text.trim();
    final fullName = fullNameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final repeatedPassword = passwordRepeatController.text;

    if (company.length < 2 || fullName.length < 2) {
      setState(() => errorText = 'Укажите название компании и ваше имя');
      return;
    }
    if (!email.contains('@')) {
      setState(() => errorText = 'Введите корректный email');
      return;
    }
    if (password.length < 8) {
      setState(() => errorText = 'Пароль должен содержать не менее 8 символов');
      return;
    }
    if (password != repeatedPassword) {
      setState(() => errorText = 'Пароли не совпадают');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      isLoading = true;
      errorText = null;
    });

    try {
      final signedIn = await UserRepository.signUpCompany(
        companyName: company,
        fullName: fullName,
        email: email,
        password: password,
      );
      if (!mounted) return;

      if (signedIn) {
        Navigator.pop(context, true);
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Подтвердите email'),
          content: const Text(
            'Мы отправили письмо. Перейдите по ссылке, затем AppСтрой завершит создание компании.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Понятно'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, false);
    } catch (error) {
      if (mounted) setState(() => errorText = friendlyError(error));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  InputDecoration decoration(String label, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.textMuted),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.90),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Создать компанию')),
      body: PremiumBackdrop(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.84),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 38,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: AutofillGroup(
                      child: Column(
                        children: [
                          const PremiumBrandMark(size: 68),
                          const SizedBox(height: 18),
                          Text(
                            'Рабочее пространство за минуту',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Вы станете владельцем компании и сможете создавать объекты и приглашать команду.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          const Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _SignupBenefit(
                                icon: Icons.schedule_rounded,
                                label: '14 дней',
                              ),
                              _SignupBenefit(
                                icon: Icons.credit_card_off_rounded,
                                label: 'Без карты',
                              ),
                              _SignupBenefit(
                                icon: Icons.groups_2_outlined,
                                label: 'Команда и объекты',
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            controller: companyController,
                            enabled: !isLoading,
                            textInputAction: TextInputAction.next,
                            decoration: decoration(
                              'Название компании',
                              Icons.apartment_rounded,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: fullNameController,
                            enabled: !isLoading,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.name],
                            decoration: decoration('Ваше имя', Icons.person_outline),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: emailController,
                            enabled: !isLoading,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: decoration('Email', Icons.alternate_email),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: passwordController,
                            enabled: !isLoading,
                            obscureText: !passwordVisible,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newPassword],
                            decoration: decoration(
                              'Пароль',
                              Icons.lock_outline,
                              suffix: IconButton(
                                tooltip: passwordVisible ? 'Скрыть пароль' : 'Показать пароль',
                                onPressed: () => setState(
                                  () => passwordVisible = !passwordVisible,
                                ),
                                icon: Icon(
                                  passwordVisible
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: passwordRepeatController,
                            enabled: !isLoading,
                            obscureText: !passwordVisible,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => submit(),
                            decoration: decoration(
                              'Повторите пароль',
                              Icons.lock_reset_outlined,
                            ),
                          ),
                          if (errorText != null) ...[
                            const SizedBox(height: 14),
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
                            label: 'Создать компанию',
                            icon: Icons.arrow_forward_rounded,
                            isLoading: isLoading,
                            onPressed: submit,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Первые 14 дней — пробный период. Банковская карта не требуется.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignupBenefit extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SignupBenefit({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2F3),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textPrimary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
