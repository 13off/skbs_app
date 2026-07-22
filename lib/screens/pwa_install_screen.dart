import 'package:flutter/material.dart';

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

  Future<void> install() async {
    if (isInstalling) return;
    setState(() {
      isInstalling = true;
      message = null;
    });

    final result = await PwaInstallService.install();
    if (!mounted) return;

    setState(() {
      isInstalling = false;
      switch (result) {
        case 'accepted':
          message =
              'Установка подтверждена. AppСтрой появится среди приложений.';
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

  @override
  Widget build(BuildContext context) {
    final installed = PwaInstallService.isInstalled;
    final canPrompt = PwaInstallService.canPrompt;

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
            'Установите веб-версию на ${PwaInstallService.platformName}: отдельное окно, иконка и быстрый запуск без адресной строки.',
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
                    child: const Icon(
                      Icons.install_desktop_rounded,
                      size: 30,
                      color: AppAdaptivePalette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    installed
                        ? 'Приложение уже установлено'
                        : 'Установить AppСтрой',
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
                        ? 'Браузер готов показать системное окно установки.'
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
                      onPressed: installed || isInstalling ? null : install,
                      icon: isInstalling
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              canPrompt
                                  ? Icons.download_rounded
                                  : Icons.help_outline_rounded,
                            ),
                      label: Text(
                        installed
                            ? 'Уже установлено'
                            : canPrompt
                            ? 'Установить приложение'
                            : 'Как установить',
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
