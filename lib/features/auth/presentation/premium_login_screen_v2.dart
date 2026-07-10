import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/app_theme.dart';
import '../../../data/user_repository.dart';
import '../../../widgets/premium_ui.dart';

class LoginScreen extends StatefulWidget {
  final Future<void> Function()? onSignedIn;

  const LoginScreen({super.key, this.onSignedIn});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final emailFocusNode = FocusNode();
  final passwordFocusNode = FocusNode();

  bool isLoading = false;
  bool isPasswordVisible = false;
  String? errorText;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    emailFocusNode.dispose();
    passwordFocusNode.dispose();
    super.dispose();
  }

  String friendlyError(Object error) {
    if (error is AuthException) {
      final text = error.message.toLowerCase();

      if (text.contains('invalid login credentials')) {
        return 'Неверный email или пароль';
      }
      if (text.contains('email not confirmed')) {
        return 'Email ещё не подтверждён';
      }
      if (text.contains('rate limit')) {
        return 'Слишком много попыток. Подожди немного и попробуй снова';
      }
    }

    return 'Не удалось войти. Проверь интернет и данные для входа';
  }

  Future<void> signIn() async {
    if (isLoading) return;

    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => errorText = 'Введите email и пароль');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      isLoading = true;
      errorText = null;
    });

    try {
      await UserRepository.signIn(email: email, password: password);

      if (UserRepository.currentSession == null ||
          UserRepository.currentUser == null) {
        throw const AuthException('Session was not created');
      }

      await widget.onSignedIn?.call();
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final minimumHeight = constraints.maxHeight > 48
                  ? constraints.maxHeight - 48
                  : 0.0;

              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minimumHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 448),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 720),
                        curve: AppMotion.enterCurve,
                        builder: (context, progress, child) {
                          return Opacity(
                            opacity: progress,
                            child: Transform.translate(
                              offset: Offset(0, 18 * (1 - progress)),
                              child: child,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(26, 28, 26, 24),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.80),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.92),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF17191C,
                                ).withValues(alpha: 0.12),
                                blurRadius: 52,
                                offset: const Offset(0, 24),
                              ),
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.72),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: AutofillGroup(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const PremiumBrandMark(size: 86),
                                const SizedBox(height: 24),
                                Text(
                                  'AppСтрой',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        color: AppColors.textPrimary,
                                        fontSize: 31,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -1.2,
                                      ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  'Управление строительным объектом',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AppColors.textMuted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 30),
                                TextField(
                                  controller: emailController,
                                  focusNode: emailFocusNode,
                                  enabled: !isLoading,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [
                                    AutofillHints.username,
                                    AutofillHints.email,
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    hintText: 'name@company.ru',
                                    prefixIcon: Icon(Icons.alternate_email_rounded),
                                  ),
                                  onSubmitted: (_) {
                                    passwordFocusNode.requestFocus();
                                  },
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: passwordController,
                                  focusNode: passwordFocusNode,
                                  enabled: !isLoading,
                                  obscureText: !isPasswordVisible,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [AutofillHints.password],
                                  decoration: InputDecoration(
                                    labelText: 'Пароль',
                                    prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                    ),
                                    suffixIcon: IconButton(
                                      tooltip: isPasswordVisible
                                          ? 'Скрыть пароль'
                                          : 'Показать пароль',
                                      onPressed: isLoading
                                          ? null
                                          : () {
                                              setState(() {
                                                isPasswordVisible =
                                                    !isPasswordVisible;
                                              });
                                            },
                                      icon: AnimatedSwitcher(
                                        duration: AppMotion.fast,
                                        child: Icon(
                                          isPasswordVisible
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          key: ValueKey(isPasswordVisible),
                                        ),
                                      ),
                                    ),
                                  ),
                                  onSubmitted: (_) => signIn(),
                                ),
                                AnimatedSize(
                                  duration: AppMotion.regular,
                                  curve: AppMotion.enterCurve,
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
                                              color: const Color(0xFFFFF2F1),
                                              borderRadius:
                                                  BorderRadius.circular(15),
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
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: const Color(
                                                            0xFF874540,
                                                          ),
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 20),
                                PremiumActionButton(
                                  label: 'Войти в систему',
                                  icon: Icons.arrow_forward_rounded,
                                  isLoading: isLoading,
                                  onPressed: signIn,
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF3A8B61),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Защищённый доступ СКБС',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.textMuted,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
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
            },
          ),
        ),
      ),
    );
  }
}
