import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/employee_shift_runtime.dart';

class EmployeeLocationSettingsScreen extends StatefulWidget {
  const EmployeeLocationSettingsScreen({super.key});

  @override
  State<EmployeeLocationSettingsScreen> createState() =>
      _EmployeeLocationSettingsScreenState();
}

class _EmployeeLocationSettingsScreenState
    extends State<EmployeeLocationSettingsScreen> {
  final runtime = EmployeeShiftRuntime.instance;
  bool loading = true;
  bool serviceEnabled = false;
  LocationPermission permission = LocationPermission.denied;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() => loading = true);
    try {
      final nextService = await runtime.isLocationServiceEnabled();
      final nextPermission = await runtime.currentPermission();
      if (!mounted) return;
      setState(() {
        serviceEnabled = nextService;
        permission = nextPermission;
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  String get permissionTitle {
    if (kIsWeb) return 'Только при открытом приложении';
    return switch (permission) {
      LocationPermission.always => 'Разрешено всегда',
      LocationPermission.whileInUse => 'Только при использовании',
      LocationPermission.deniedForever => 'Запрещено в настройках',
      LocationPermission.denied => 'Не разрешено',
      LocationPermission.unableToDetermine => 'Не удалось определить',
    };
  }

  bool get permissionReady {
    if (kIsWeb) {
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    }
    return permission == LocationPermission.always;
  }

  Widget statusRow({
    required IconData icon,
    required String title,
    required String value,
    required bool ready,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: scheme.onSurfaceVariant, size: 21),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: ready ? scheme.primary : scheme.error,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Icon(
          ready ? Icons.check_circle_outline : Icons.error_outline_rounded,
          color: ready ? scheme.primary : scheme.error,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Геолокация рабочего дня',
      subtitle: 'Разрешения и состояние фоновой записи',
      showBackButton: true,
      onRefresh: refresh,
      child: ValueListenableBuilder<EmployeeWorkDaySnapshot>(
        valueListenable: runtime.state,
        builder: (context, snapshot, _) {
          final scheme = Theme.of(context).colorScheme;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (loading)
                const LinearProgressIndicator()
              else
                PremiumWorkCard(
                  radius: 24,
                  child: Column(
                    children: [
                      statusRow(
                        icon: Icons.location_on_outlined,
                        title: 'Геолокация телефона',
                        value: serviceEnabled ? 'Включена' : 'Выключена',
                        ready: serviceEnabled,
                      ),
                      const SizedBox(height: 14),
                      Divider(color: scheme.outlineVariant),
                      const SizedBox(height: 14),
                      statusRow(
                        icon: Icons.admin_panel_settings_outlined,
                        title: 'Доступ AppСтрой',
                        value: permissionTitle,
                        ready: permissionReady,
                      ),
                      const SizedBox(height: 14),
                      Divider(color: scheme.outlineVariant),
                      const SizedBox(height: 14),
                      statusRow(
                        icon: Icons.route_outlined,
                        title: 'Рабочий день',
                        value: snapshot.isActive
                            ? 'Маршрут записывается'
                            : 'Сейчас не начат',
                        ready:
                            !snapshot.isActive ||
                            (serviceEnabled && permissionReady),
                      ),
                      if (snapshot.isActive) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Локально ожидают отправки: '
                            '${snapshot.pendingPoints} точек',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              PremiumWorkCard(
                radius: 24,
                child: Text(
                  kIsWeb
                      ? 'Фоновая запись маршрута работает в установленном '
                            'Android-приложении. В браузере координаты поступают '
                            'только пока страница открыта.'
                      : 'Для надёжной записи выберите доступ «Разрешить всегда». '
                            'Во время рабочего дня Android показывает постоянное '
                            'уведомление AppСтрой. Не закрывайте приложение '
                            'принудительно и не ограничивайте его работу в фоне.',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!kIsWeb) ...[
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () async {
                    await runtime.openLocationSettings();
                    await refresh();
                  },
                  icon: const Icon(Icons.location_searching_rounded),
                  label: const Text('Настройки геолокации телефона'),
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    await runtime.openSettings();
                    await refresh();
                  },
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Настройки разрешений AppСтрой'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
