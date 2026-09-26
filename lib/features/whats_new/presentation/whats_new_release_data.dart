part of 'role_aware_whats_new_gate.dart';

enum _UpdatePreviewKind {
  taskMedia,
  decimalMoney,
  advanceThirty,
}

class _UpdateSlide {
  final IconData icon;
  final String title;
  final String description;
  final List<String> points;
  final _UpdatePreviewKind preview;
  final Set<String> roles;

  const _UpdateSlide({
    required this.icon,
    required this.title,
    required this.description,
    required this.points,
    required this.preview,
    required this.roles,
  });
}

const List<_UpdateSlide> _allSlides = <_UpdateSlide>[
  _UpdateSlide(
    icon: Icons.video_library_rounded,
    title: 'Фото и видео в задачах',
    description:
        'Фиксация «До» и «После» стала быстрее: теперь можно отправлять сразу несколько материалов и добавлять короткие видео.',
    points: <String>[
      'Выбирайте сразу несколько фотографий за один раз.',
      'К «До» и «После» теперь можно прикреплять видео длительностью до 1 минуты.',
      'Фото сжимаются перед загрузкой, а видео на Android и iPhone автоматически подготавливаются для экономии места.',
    ],
    preview: _UpdatePreviewKind.taskMedia,
    roles: <String>{'foreman', 'employee'},
  ),
  _UpdateSlide(
    icon: Icons.calculate_rounded,
    title: 'Копейки — через точку или запятую',
    description:
        'В денежных полях больше не нужно подстраиваться под один формат: копейки принимаются привычным способом.',
    points: <String>[
      'Можно вводить 12500.50 или 12500,50 — сумма сохранится одинаково.',
      'Точка больше не заменяется сама на запятую во время ввода.',
      'Правило применяется к основным денежным полям бухгалтерского контура.',
    ],
    preview: _UpdatePreviewKind.decimalMoney,
    roles: <String>{'accountant'},
  ),
  _UpdateSlide(
    icon: Icons.percent_rounded,
    title: 'Аванс 30% в «Оплате»',
    description:
        'В «Повелителе» появился быстрый режим аванса: одним нажатием весь список к выплате пересчитывается на 30%.',
    points: <String>[
      'Включите «30% аванс» — суммы по сотрудникам и общий итог пересчитаются сразу.',
      'Копирование по объектам и экспресс-сводка используют уже авансовые суммы.',
      'Нажмите кнопку ещё раз — расчёт вернётся к полному остатку.',
    ],
    preview: _UpdatePreviewKind.advanceThirty,
    roles: <String>{'executive'},
  ),
];

List<_UpdateSlide> _slidesFor(AppUserProfile profile) {
  return _allSlides
      .where((slide) => slide.roles.contains(profile.role))
      .toList(growable: false);
}
