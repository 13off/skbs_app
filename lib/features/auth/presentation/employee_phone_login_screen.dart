import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../app/app_theme.dart';
import '../../../data/user_repository.dart';
import '../../../widgets/premium_ui.dart';

class EmployeePhoneLoginScreen extends StatefulWidget {
  final Future<void> Function()? onSignedIn;

  const EmployeePhoneLoginScreen({super.key, this.onSignedIn});

  @override
  State<EmployeePhoneLoginScreen> createState() =>
      _EmployeePhoneLoginScreenState();
}

class _EmployeePhoneLoginScreenState
    extends State<EmployeePhoneLoginScreen> {
  final phoneController = TextEditingController(text: '+7 ');
  final codeController = TextEditingController();
  final phoneFocusNode = FocusNode();
  final codeFocusNode = FocusNode();

  bool isLoading = false;
  bool codeSent = false;
  String? errorText;

  @override
  void dispose() {
    phoneController.dispose();
    codeController.dispose();
    phoneFocusNode.dispose();
    codeFocusNode.dispose();
    super.dispose();
  }

  String friendlyError(Object error) {
    if (error is AuthException) {
      final text = error.message.toLowerCase();
      if (text.contains('rate limit')) {
        return 'Слишком много попыток. Подожди немного и попробуй снова';
      }
      if (text.contains('invalid') || text.contains('expired')) {
        return 'Код неверный или уже истёк';
      }
      if (text.contains('phone')) {
        return 'Проверь номер телефона';
      }
    }
    return 'Не получилось войти. Проверь интернет и попробуй ещё раз';
  }

  Future<void> requestCode() async {
    if (isLoading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      isLoading = true;
      errorText = null;
    });

    try {
      await UserRepository.requestEmployeeSmsCode(phoneController.text);
      if (!mounted) return;
      setState(() => codeSent = true);
      codeFocusNode.requestFocus();
    } catch (error) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => errorText = friendlyError(error));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> verifyCode() async {
    if (isLoading) return;
    final code = codeController.text.trim();
    if (code.length < 4) {
      setState(() => errorText = 'Введите код из СМС');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      isLoading = true;
      errorText = null;
    });

    try {
      await UserRepository.verifyEmployeeSmsCode(
        phone: phoneController.text,
        code: code,
      );
      await widget.onSignedIn?.call();
    } catch (error) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => errorText = friendlyError(error));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  InputDecoration fieldDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppAdaptivePalette.textMuted),
      filled: true,
      fillColor: AppAdaptivePalette.inputSurface,
    );
  }

  @override
  Widget build(BuildContext context) {
    final inputTextStyle = TextStyle(
      color: AppAdaptivePalette.textPrimary,
      fontSize: 17,
      fontWeight: FontWeight.w800,
    );

    return Scaffold(
      body: PremiumBackdrop(
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                left: 8,
                top: 6,
                child: IconButton(
                  tooltip: 'Назад',
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 72, 20, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 448),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 520),
                      curve: AppMotion.enterCurve,
                      builder: (context, progress, child) {
                        return Opacity(
                          opacity: progress,
                          child: Transform.translate(
                            offset: Offset(0, 16 * (1 - progress)),
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(26, 28, 26, 24),
                        decoration: BoxDecoration(
                          color: AppAdaptivePalette.surfaceElevated,
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: AppAdaptivePalette.border),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF17191C)
                                  .withValues(alpha: 0.12),
                              blurRadius: 52,
                              offset: const Offset(0, 24),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const PremiumBrandMark(size: 78),
                            const SizedBox(height: 22),
                            Text(
                              'Вход сотрудника',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: AppAdaptivePalette.textPrimary,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              codeSent
                                  ? 'Введи код, который пришёл на номер'
                                  : 'Введи номер телефона из карточки сотрудника',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppAdaptivePalette.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 26),
                            TextField(
                              controller: phoneController,
                              focusNode: phoneFocusNode,
                              enabled: !isLoading && !codeSent,
                              keyboardType: TextInputType.phone,
                              textInputAction: codeSent
                                  ? TextInputAction.next
                                  : TextInputAction.done,
                              autofillHints: const [AutofillHints.telephoneNumber],
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9+ ()-]'),
                                ),
                                LengthLimitingTextInputFormatter(20),
                              ],
                              style: inputTextStyle,
                              decoration: fieldDecoration(
                                label: 'Номер телефона',
                                hint: '+7 999 123-45-67',
                                icon: Icons.phone_iphone_rounded,
                              ),
                              onSubmitted: (_) {
                                if (!codeSent) requestCode();
                              },
                            ),
                            if (codeSent) ...[
                              const SizedBox(height: 14),
                              TextField(
                                controller: codeController,
                                focusNode: codeFocusNode,
                                enabled: !isLoading,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [
                                  AutofillHints.oneTimeCode,
                                ],
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(8),
                                ],
                                style: inputTextStyle.copyWith(
                                  letterSpacing: 4,
                                ),
                                textAlign: TextAlign.center,
                                decoration: fieldDecoration(
                                  label: 'Код из СМС',
                                  hint: '000000',
                                  icon: Icons.sms_outlined,
                                ),
                                onSubmitted: (_) => verifyCode(),
                              ),
                            ],
                            AnimatedSize(
                              duration: AppMotion.regular,
                              child: errorText == null
                                  ? const SizedBox.shrink()
                                  : Padding(
                                      padding: const EdgeInsets.only(top: 14),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppAdaptivePalette.danger
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(15),
                                        ),
                                        child: Text(
                                          errorText!,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: AppAdaptivePalette.danger,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 20),
                            PremiumActionButton(
                              label: codeSent ? 'Войти' : 'Получить код',
                              icon: codeSent
                                  ? Icons.login_rounded
                                  : Icons.sms_rounded,
                              isLoading: isLoading,
                              onPressed: codeSent ? verifyCode : requestCode,
                            ),
                            if (codeSent) ...[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: isLoading
                                    ? null
                                    : () {
                                        setState(() {
                                          codeSent = false;
                                          codeController.clear();
                                          errorText = null;
                                        });
                                        phoneFocusNode.requestFocus();
                                      },
                                child: const Text('Изменить номер'),
                              ),
                            ],
                          ],
                        ),
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
