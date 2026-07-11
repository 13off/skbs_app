import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../data/user_repository.dart';
import '../../../widgets/premium_ui.dart';

class SetInvitationPasswordScreen extends StatefulWidget {
  final Future<void> Function() onCompleted;

  const SetInvitationPasswordScreen({
    super.key,
    required this.onCompleted,
  });

  @override
  State<SetInvitationPasswordScreen> createState() =>
      _SetInvitationPasswordScreenState();
}

class _SetInvitationPasswordScreenState
    extends State<SetInvitationPasswordScreen> {
  final passwordController = TextEditingController();
  final repeatController = TextEditingController();

  bool isLoading = false;
  bool isVisible = false;
  String? errorText;

  @override
  void dispose() {
    passwordController.dispose();
    repeatController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (isLoading) return;
    final password = passwordController.text;
    if (password.length < 8) {
      setState(() => errorText = 'Пароль должен содержать не менее 8 символов');
      return;
    }
    if (password != repeatController.text) {
      setState(() => errorText = 'Пароли не совпадают');
      return;
    }

    setState(() {
      isLoading = true;
      errorText = null;
    });
    try {
      await UserRepository.setInvitationPassword(password);
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
                constraints: const BoxConstraints(maxWidth: 440),
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
                        'Придумайте пароль',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Приглашение принято. Пароль понадобится для следующих входов в AppСтрой.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        controller: passwordController,
                        enabled: !isLoading,
                        obscureText: !isVisible,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'Новый пароль',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: isVisible ? 'Скрыть пароль' : 'Показать пароль',
                            onPressed: () => setState(() => isVisible = !isVisible),
                            icon: Icon(
                              isVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: repeatController,
                        enabled: !isLoading,
                        obscureText: !isVisible,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => save(),
                        decoration: const InputDecoration(
                          labelText: 'Повторите пароль',
                          prefixIcon: Icon(Icons.lock_reset_outlined),
                        ),
                      ),
                      if (errorText != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorText!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF874540),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      PremiumActionButton(
                        label: 'Сохранить пароль',
                        icon: Icons.check_rounded,
                        isLoading: isLoading,
                        onPressed: save,
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

