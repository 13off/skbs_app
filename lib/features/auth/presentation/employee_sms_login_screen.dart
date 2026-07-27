import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../widgets/premium_ui.dart';
import '../data/employee_auth_repository.dart';

class EmployeeSmsLoginScreen extends StatefulWidget {
  final Future<void> Function()? onSignedIn;

  const EmployeeSmsLoginScreen({super.key, this.onSignedIn});

  @override
  State<EmployeeSmsLoginScreen> createState() => _EmployeeSmsLoginScreenState();
}

class _EmployeeSmsLoginScreenState extends State<EmployeeSmsLoginScreen> {
  final phoneController = TextEditingController(text: '+7 ');
  final codeController = TextEditingController();
  bool codeSent = false;
  bool isLoading = false;
  String? errorText;

  @override
  void dispose() {
    phoneController.dispose();
    codeController.dispose();
    super.dispose();
  }

  String friendlyError(Object error) {
    if (error is AuthException) {
      final message = error.message.trim();
      final text = message.toLowerCase();
      if (text.contains('rate limit')) {
        return 'Слишком много попыток. Подожди немного и попробуй снова';
      }
      if (text.contains('invalid') || text.contains('expired')) {
        return 'Код неверный или уже истёк';
      }
      if (text.contains('не подключ') ||
          text.contains('доступ сотрудника отключ') ||
          text.contains('signup') ||
          text.contains('sign up') ||
          text.contains('not found') ||
          text.contains('user not')) {
        return 'Этот номер не подключён к кабинету сотрудника. Обратись к руководителю';
      }
      if (text.contains('некорректный номер')) return message;
    }
    return 'Не получилось войти. Проверь номер и интернет';
  }

  Future<void> submit() async {
    if (isLoading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      isLoading = true;
      errorText = null;
    });

    try {
      if (!codeSent) {
        await EmployeeAuthRepository.requestCode(phoneController.text);
        if (!mounted) return;
        setState(() => codeSent = true);
      } else {
        if (codeController.text.trim().length < 4) {
          throw const AuthException('Invalid OTP');
        }
        await EmployeeAuthRepository.verifyCode(
          rawPhone: phoneController.text,
          code: codeController.text,
        );
        await widget.onSignedIn?.call();
      }
    } catch (error) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => errorText = friendlyError(error));
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
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: AppAdaptivePalette.surfaceElevated,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: AppAdaptivePalette.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          tooltip: 'Назад',
                          onPressed: isLoading
                              ? null
                              : () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      ),
                      const PremiumBrandMark(size: 76),
                      const SizedBox(height: 18),
                      Text(
                        'Вход сотрудника',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: AppAdaptivePalette.textPrimary,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        codeSent
                            ? 'Введи код из СМС'
                            : 'Введи номер из своей карточки сотрудника',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppAdaptivePalette.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: phoneController,
                        enabled: !isLoading && !codeSent,
                        keyboardType: TextInputType.phone,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9+ ()-]'),
                          ),
                          LengthLimitingTextInputFormatter(20),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Номер телефона',
                          hintText: '+7 999 123-45-67',
                          prefixIcon: Icon(Icons.phone_iphone_rounded),
                        ),
                        onSubmitted: (_) {
                          if (!codeSent) submit();
                        },
                      ),
                      if (codeSent) ...[
                        const SizedBox(height: 14),
                        TextField(
                          controller: codeController,
                          enabled: !isLoading,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(8),
                          ],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Код из СМС',
                            prefixIcon: Icon(Icons.sms_outlined),
                          ),
                          onSubmitted: (_) => submit(),
                        ),
                      ],
                      if (errorText != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorText!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppAdaptivePalette.danger,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      PremiumActionButton(
                        label: codeSent ? 'Войти' : 'Получить код',
                        icon: codeSent
                            ? Icons.login_rounded
                            : Icons.sms_rounded,
                        isLoading: isLoading,
                        onPressed: submit,
                      ),
                      if (codeSent)
                        TextButton(
                          onPressed: isLoading
                              ? null
                              : () {
                                  setState(() {
                                    codeSent = false;
                                    codeController.clear();
                                    errorText = null;
                                  });
                                },
                          child: const Text('Изменить номер'),
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
