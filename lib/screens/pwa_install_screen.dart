import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_adaptive_palette.dart';
import '../services/pwa_install_service.dart';
import '../widgets/app_page.dart';
import '../widgets/premium_ui_v2.dart';

class PwaInstallScreen extends StatefulWidget {
  const PwaInstallScreen({super.key});

  @override
  State<PwaInstallScreen> createState() => _PwaInstallScreenState();
}

class _PwaInstallScreenState extends State<PwaInstallScreen> {
  bool isInstalling = false;
  String? message;
  late Timer pollTimer;
  bool canPrompt = PwaInstallService.canPrompt;
  bool installed = PwaInstallService.isInstalled;

  @override
  void initState() {
    super.initState();
    pollTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (!mounted) return;
      final nextPrompt = PwaInstallService.canPrompt;
      final nextInstalled = PwaInstallService.isInstalled;
      if (nextPrompt != canPrompt || nextInstalled != installed) {
        setState(() {
          canPrompt = nextPrompt;
          installed = nextInstalled;
        });
      }
    });
  }

  @override
  void dispose() {
    pollTimer.cancel();
    super.dispose();
  }

  String get appUrl =>
      Uri.base.replace(queryParameters: const <String, String>{}).toString();

  Future<void> install() async {
    if (isInstalling || !canPrompt) return;
    setState(() {
      isInstalling = true;
      message = null;
    });

    final result = await PwaInstallService.install();
    if (!mounted) return;

    setState(() {
      isInstalling = false;
      installed = PwaInstallService.isInstalled;
      canPrompt = PwaInstallService.canPrompt;
      switch (result) {
        case 'accepted':
          message =
              'Установка подтверждена. Дождитесь появления AppСтрой среди приложений.';
          break;
        case 'installed':
          message = 'AppСтрой уже запущен как установленное приложение.';
          break;
        case 'dismissed':
          message = 'Установка отменена. Её можно запустить позже.';
          break;
        default:
          message = PwaInstallService.manualInstruction;
      }
    });
  }

  Future<void> copyAddress() async {
    await Clipboard.setData(ClipboardData(text: appUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Адрес AppСтрой скопирован')));
  }

  Future<void> openInEdge() async {
    final edgeUri = Uri.parse('microsoft-edge:$appUrl');
    final opened = await launchUrl(
      edgeUri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Не удалось открыть Edge. Скопируйте адрес и вставьте его вручную.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final yandex = PwaInstallService.isYandexBrowser;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Установка AppСтрой'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: AppPage(
        title: 'AppСтрой как приложение',
        subtitle:
            '${PwaInstallService.browserName} · ${PwaInstallService.platformName}. Системная кнопка показывается только тогда, когда браузер действительно готов установить PWA.',
        child: Column(
          children: [
            PremiumWorkCard(
              radius: 28,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: AppAdaptivePalette.surfaceSoft,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(
                      installed
                          ? Icons.check_circle_outline_rounded
                          : Icons.install_desktop_rounded,
                      size: 30,
                      color: AppAdaptivePalette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    installed
                        ? 'Приложение уже установлено'
                        : canPrompt
                        ? 'Браузер готов к установке'
                        : 'Системная установка сейчас недоступна',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppAdaptivePalette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    installed
                        ? 'Вы открыли AppСтрой в отдельном режиме приложения.'
                        : canPrompt
                        ? 'Нажмите кнопку ниже — появится настоящее системное окно браузера.'
                        : PwaInstallService.manualInstruction,
                    style: TextStyle(
                      color: AppAdaptivePalette.textMuted,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: installed || isInstalling || !canPrompt
                          ? null
                          : install,
                      icon: isInstalling
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_rounded),
                      label: Text(
                        installed
                            ? 'Уже установлено'
                            : canPrompt
                            ? 'Установить приложение'
                            : 'Браузер не дал разрешение на установку',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: copyAddress,
                        icon: const Icon(Icons.content_copy_rounded),
                        label: const Text('Скопировать адрес'),
                      ),
                      if (yandex)
                        OutlinedButton.icon(
                          onPressed: openInEdge,
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('Открыть в Edge'),
                        ),
                      OutlinedButton.icon(
                        onPressed: () => launchUrl(
                          Uri.parse(appUrl),
                          mode: LaunchMode.platformDefault,
                        ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Открыть веб-версию'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (yandex) ...[
              const SizedBox(height: 12),
              PremiumWorkCard(
                radius: 24,
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: AppAdaptivePalette.warning,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'В Яндекс.Браузере пункт «Открыть приложение» может ничего не сделать. Это действие браузера, а не кнопка AppСтрой. Для Windows надёжнее установить через Microsoft Edge.',
                        style: TextStyle(
                          color: AppAdaptivePalette.textMuted,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (message != null) ...[
              const SizedBox(height: 12),
              PremiumWorkCard(
                radius: 24,
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message!,
                        style: TextStyle(
                          color: AppAdaptivePalette.textMuted,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            const PremiumWorkCard(
              radius: 24,
              padding: EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BenefitRow(
                    icon: Icons.window_rounded,
                    text: 'Открывается в отдельном окне без адресной строки.',
                  ),
                  SizedBox(height: 12),
                  _BenefitRow(
                    icon: Icons.sync_rounded,
                    text: 'Обновляется вместе с веб-версией AppСтрой.',
                  ),
                  SizedBox(height: 12),
                  _BenefitRow(
                    icon: Icons.cloud_done_outlined,
                    text: 'Использует тот же аккаунт, компанию и данные.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BenefitRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 21, color: AppAdaptivePalette.textMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: AppAdaptivePalette.textMuted,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
