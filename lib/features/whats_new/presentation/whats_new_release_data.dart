part of 'role_aware_whats_new_gate.dart';

enum _UpdatePreviewKind {
  managerTodos,
  fines,
  legal,
  glass,
  photos,
  stability,
}

class _UpdateSlide {
  final IconData icon;
  final String title;
  final String description;
  final List<String> points;
  final _UpdatePreviewKind preview;
  final Set<String> roles;
  final bool common;

  const _UpdateSlide({
    required this.icon,
    required this.title,
    required this.description,
    required this.points,
    required this.preview,
    this.roles = const <String>{},
    this.common = false,
  });
}

const List<_UpdateSlide> _allSlides = <_UpdateSlide>[
  _UpdateSlide(
    icon: Icons.assignment_turned_in_outlined,
    title: 'Дела руководителя',
    description:
        'На Главной появился лёгкий рабочий список дел, который сам подхватывает проблемы из ежедневных отчётов.',
    points: <String>[
      'Ручные дела с точной датой и временем напоминания.',
      'Автоматические дела по невыходам, незакрытым работам, чекам, срокам и рискам.',
      'Выполненные дела остаются в истории и при необходимости возвращаются в работу.',
    ],
    preview: _UpdatePreviewKind.managerTodos,
    roles: <String>{'admin'},
  ),
  _UpdateSlide(
    icon: Icons.gavel_rounded,
    title: 'Штрафы и невыходы под контролем',
    description:
        'Невыход теперь проходит понятный двухэтапный процесс: документы сначала, финансовое удержание — только после решения.',
    points: <String>[
      'Ожидающий штраф 10 000 ₽ не влияет на выплаты до подтверждения.',
      'Для подтверждения нужны объяснительная и подписанный акт.',
      'У руководителя появился отдельный экран «Штрафы» с подтверждением и отменой.',
    ],
    preview: _UpdatePreviewKind.fines,
    roles: <String>{'admin', 'lawyer'},
  ),
  _UpdateSlide(
    icon: Icons.balance_rounded,
    title: 'Полноценная платформа юриста',
    description:
        'Юридическая работа собрана в единый контур без десятков отдельных экранов: Сегодня, База, Документы и Дела.',
    points: <String>[
      'Полные досье сотрудников, объектов и контрагентов.',
      'Версии документов, сроки, история изменений и безопасный импорт архива.',
      'Суды и претензии получили процессуальную ленту, контроль сроков и автоматическую очередь «Сегодня».',
    ],
    preview: _UpdatePreviewKind.legal,
    roles: <String>{'lawyer'},
  ),
  _UpdateSlide(
    icon: Icons.auto_awesome_rounded,
    title: 'Единый стеклянный интерфейс',
    description:
        'Все рабочие кабинеты приведены к одному собранному стилю AppСтрой — плотнее, чище и визуально объёмнее.',
    points: <String>[
      'Единая глубина стекла и радиусы рабочих карточек.',
      'Убраны лишние поясняющие подзаголовки на основных экранах.',
      'Мобильные карточки расходов, выплат и действий сотрудников стали ровнее и компактнее.',
    ],
    preview: _UpdatePreviewKind.glass,
    common: true,
  ),
  _UpdateSlide(
    icon: Icons.photo_library_rounded,
    title: 'Новые фото «До» и «После»',
    description:
        'Фотографии в задачах теперь удобнее добавлять с телефона, включая iPhone.',
    points: <String>[
      'Можно выбрать сразу несколько фотографий отдельно для «До» и «После».',
      'HEIC/HEIF с iPhone автоматически подготавливаются к загрузке.',
      'Показывается реальный процент отправленных байтов, а зависший файл повторяется отдельно от всей пачки.',
    ],
    preview: _UpdatePreviewKind.photos,
    roles: <String>{'employee', 'foreman'},
  ),
  _UpdateSlide(
    icon: Icons.verified_user_rounded,
    title: 'Стабильнее и безопаснее',
    description:
        'За кулисами AppСтрой получил большой технический апгрейд, чтобы ежедневная работа меньше зависела от случайных сбоев.',
    points: <String>[
      'Усилена изоляция данных между пользователями и компаниями.',
      'Критические массовые операции стали атомарными и устойчивее к обрывам.',
      'Исправлены мобильные загрузки файлов, права доступа и множество мелких интерфейсных ошибок.',
    ],
    preview: _UpdatePreviewKind.stability,
    common: true,
  ),
];

List<_UpdateSlide> _slidesFor(AppUserProfile profile) {
  if (profile.role == 'admin' || profile.role == 'developer') {
    return List<_UpdateSlide>.unmodifiable(_allSlides);
  }

  return _allSlides
      .where((slide) => slide.common || slide.roles.contains(profile.role))
      .toList(growable: false);
}
