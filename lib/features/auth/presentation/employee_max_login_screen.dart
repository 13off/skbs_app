import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../widgets/premium_ui.dart';
import '../data/employee_auth_repository.dart';
import 'employee_sms_login_screen.dart';

class EmployeeMaxLoginScreen extends StatefulWidget {
  final Future<void> Function()? onSignedIn;

  const EmployeeMaxLoginScreen({super.key, this.onSignedIn});

  @override
  State<EmployeeMaxLoginScreen> createState() => _EmployeeMaxLoginScreenState();
}

class _EmployeeMaxLoginScreenState extends State<EmployeeMaxLoginScreen>
    with WidgetsBindingObserver {
  final phoneController = TextEditingController(text: '+7 ');
  Timer? pollTimer;
  String? attemptToken;
  String? maxUrl;
  String? errorText;
  String statusText = '';
  bool isLoading = false;
  bool isPolling = false;
  bool isWaiting = false;
  bool needsInitialLink = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && isWaiting) {
      unawaited(pollNow());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pollTimer?.cancel();
    phoneController.dispose();
    super.dispose();
  }

  String friendlyError(Object error) {
    if (error is AuthException) {
      final message = error.message.trim();
      final text = message.toLowerCase();
      if (text.contains('слишком много') || text.contains('rate limit')) {
        return 'Слишком много попыток. Подожди минуту и попробуй снова';
      }
      if (text.contains('несколько кабинетов')) return message;
      if (text.contains('некорректный номер')) return message;
      if (text.contains('не подключён') ||
          text.contains('доступ сотрудника отключ') ||
          text.contains('not found') ||
          text.contains('user not')) {
        return 'Этот номер не подключён к кабинету сотрудника. Обратись к руководителю';
      }
      if (message.isNotEmpty) return message;
    }
    return 'Не получилось войти через MAX. Проверь интернет и попробуй снова';
  }

  Future<void> startLogin() async {
    if (isLoading) return;
    FocusScope.of(context).unfocus();
    pollTimer?.cancel();
    setState(() {
      isLoading = true;
      errorText = null;
    });

    try {
      final result = await EmployeeAuthRepository.requestMaxLogin(
        phoneController.text,
      );
      if (!mounted) return;
      setState(() {
        attemptToken = result.attemptToken;
        maxUrl = result.maxUrl;
        needsInitialLink = result.needsInitialLink;
        isWaiting = true;
        statusText = result.needsInitialLink
            ? 'Открой MAX, запусти бота и отправь свой контакт. После привязки вход продолжится автоматически.'
            : 'В MAX уже отправлена кнопка подтверждения. Нажми её и вернись в AppСтрой.';
      });
      startPolling();
      await openMax();
    } catch (error) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => errorText = friendlyError(error));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void startPolling() {
    pollTimer?.cancel();
    unawaited(pollNow());
    pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(pollNow()),
    );
  }

  Future<void> pollNow() async {
    final token = attemptToken;
    if (!isWaiting || isPolling || token == null || token.isEmpty) return;
    isPolling = true;
    try {
      final result = await EmployeeAuthRepository.pollMaxLogin(token);
      if (!mounted) return;
      switch (result.status) {
        case 'link_required':
          setState(() {
            needsInitialLink = true;
            statusText =
                'В MAX нажми «Запустить» и отправь свой контакт. Номер должен совпадать с карточкой сотрудника.';
          });
          break;
        case 'waiting_max':
          setState(() {
            statusText =
                'Открой чат «СКБС Работа» в MAX. Кнопка подтверждения придёт автоматически.';
          });
          break;
        case 'waiting_confirmation':
          setState(() {
            needsInitialLink = false;
            statusText =
                'В MAX нажми «Подтвердить вход». Код вводить не требуется.';
          });
          break;
        case 'signed_in':
          pollTimer?.cancel();
          setState(() {
            isWaiting = false;
            statusText = 'Вход подтверждён';
          });
          HapticFeedback.mediumImpact();
          await widget.onSignedIn?.call();
          break;
        case 'expired':
          pollTimer?.cancel();
          setState(() {
            isWaiting = false;
            attemptToken = null;
            errorText = result.error?.isNotEmpty == true
                ? result.error
                : 'Время подтверждения истекло. Начни вход заново';
          });
          break;
        default:
          break;
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => errorText = friendlyError(error));
    } finally {
      isPolling = false;
    }
  }

  Future<void> openMax() async {
    final value = maxUrl;
    if (value == null || value.isEmpty) return;
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        setState(() {
          errorText =
              'Не удалось открыть MAX автоматически. Открой приложение MAX вручную';
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        errorText =
            'Не удалось открыть MAX автоматически. Открой приложение MAX вручную';
      });
    }
  }

  void resetLogin() {
    pollTimer?.cancel();
    setState(() {
      attemptToken = null;
      maxUrl = null;
      errorText = null;
      statusText = '';
      isWaiting = false;
      needsInitialLink = false;
    });
  }

  Future<void> openCodeFallback() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => EmployeeSmsLoginScreen(onSignedIn: widget.onSignedIn),
      ),
    );
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
                        'Вход через MAX',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: AppAdaptivePalette.textPrimary,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isWaiting
                            ? 'Подтверди вход одной кнопкой в MAX'
                            : 'Введи номер из карточки сотрудника. Код вручную вводить не придётся',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppAdaptivePalette.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: phoneController,
                        enabled: !isLoading && !isWaiting,
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
                          if (!isWaiting) startLogin();
                        },
                      ),
                      if (isWaiting) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppAdaptivePalette.accentSoft,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppAdaptivePalette.border,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                needsInitialLink
                                    ? Icons.link_rounded
                                    : Icons.verified_user_outlined,
                                color: AppAdaptivePalette.accentStrong,
                                size: 30,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                statusText,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppAdaptivePalette.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppAdaptivePalette.accentStrong,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Ждём подтверждение',
                                    style: TextStyle(
                                      color: AppAdaptivePalette.textMuted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
                        label: isWaiting ? 'Открыть MAX' : 'Войти через MAX',
                        icon: Icons.chat_rounded,
                        isLoading: isLoading,
                        onPressed: isWaiting ? openMax : startLogin,
                      ),
                      if (isWaiting)
                        TextButton(
                          onPressed: isLoading ? null : resetLogin,
                          child: const Text('Начать заново'),
                        )
                      else
                        TextButton(
                          onPressed: isLoading ? null : openCodeFallback,
                          child: const Text('Войти по коду из MAX'),
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
