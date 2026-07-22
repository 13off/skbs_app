import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WhatsNewGate extends StatefulWidget {
  final Widget child;

  const WhatsNewGate({super.key, required this.child});

  @override
  State<WhatsNewGate> createState() => _WhatsNewGateState();
}

class _WhatsNewGateState extends State<WhatsNewGate> {
  static const String releaseId = 'mobile-2026-07-22-1.3.1+5';
  static const String _preferenceKey = 'whats_new_seen_release';

  bool _checkStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showIfNeeded());
  }

  Future<void> _showIfNeeded() async {
    if (_checkStarted || !mounted) return;
    _checkStarted = true;

    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
      if (preferences.getString(_preferenceKey) == releaseId) return;
    } catch (_) {
      // Окно всё равно можно показать; ошибка локального хранилища не блокирует вход.
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _WhatsNewDialog(),
    );

    try {
      await preferences?.setString(_preferenceKey, releaseId);
    } catch (_) {
      // Пользователь уже прочитал сводку в текущем запуске.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _WhatsNewDialog extends StatelessWidget {
  const _WhatsNewDialog();

  static const sections = <_WhatsNewSection>[
    _WhatsNewSection(
      icon: Icons.chat_bubble_outline_rounded,
      title: 'Читаемый ИИ-чат в тёмной теме',
      items: [
        'Исправлен почти чёрный текст ответа на тёмной карточке.',
        'Заголовки, сводка, статусы, предупреждения, ошибки и загрузка теперь используют цвета активной темы.',
        'Сообщения пользователя также корректно отображаются в светлом и тёмном режимах.',
      ],
    ),
    _WhatsNewSection(
      icon: Icons.keyboard_rounded,
      title: 'Быстрая отправка с клавиатуры',
      items: [
        'Enter отправляет сообщение в ИИ-чат.',
        'Shift+Enter добавляет новую строку без отправки.',
        'Поддерживается Enter на цифровой клавиатуре.',
      ],
    ),
    _WhatsNewSection(
      icon: Icons.dark_mode_outlined,
      title: 'Остальные экраны ИИ',
      items: [
        'Исправлена тёмная тема журнала действий и окна подробностей.',
        'Диагностика, статусы и пустые состояния получили адаптивные цвета.',
        'Исправлены предупреждения и ошибки в черновиках документов и напоминаний.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.new_releases_outlined,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Text(
                  'Что нового в AppСтрой',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Изменения после версии 1.3.0+4',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 560),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < sections.length; index++) ...[
                if (index > 0) const SizedBox(height: 18),
                _SectionView(section: sections[index]),
              ],
            ],
          ),
        ),
      ),
      actions: [
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Понятно'),
        ),
      ],
    );
  }
}

class _SectionView extends StatelessWidget {
  final _WhatsNewSection section;

  const _SectionView({required this.section});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(section.icon, size: 20, color: theme.colorScheme.onSurface),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                section.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final item in section.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    item,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _WhatsNewSection {
  final IconData icon;
  final String title;
  final List<String> items;

  const _WhatsNewSection({
    required this.icon,
    required this.title,
    required this.items,
  });
}
