import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/employee_cabinet_repository.dart';
import '../../../navigation/app_page_route.dart';

class EmployeeActionableHomeScreen extends StatelessWidget {
  final AppUserProfile profile;

  const EmployeeActionableHomeScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return _EmployeeCabinetLoader(
      profile: profile,
      builder: (context, data, refresh) {
        final words = data.fullName.trim().split(RegExp(r'\s+'));
        final firstName = words.isEmpty || words.first.isEmpty
            ? 'сотрудник'
            : words.first;
        final task = data.currentTask;
        final subtitle = data.currentObject.isEmpty
            ? 'Личный рабочий кабинет'
            : 'Объект: ${data.currentObject}';

        return AppPage(
          title: 'Главная',
          subtitle: subtitle,
          onRefresh: refresh,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PremiumWorkCard(
                child: Row(
                  children: [
                    const _IconTile(icon: Icons.engineering_rounded, size: 58),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Привет, $firstName',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data.profession.isEmpty
                                ? 'Сотрудник AppСтрой'
                                : data.profession,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              PremiumWorkCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const _IconTile(icon: Icons.construction_rounded),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Текущая задача',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                        if (task != null) _StatusBadge(text: task.status),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      task?.work.trim().isNotEmpty == true
                          ? task!.work
                          : 'Пока задача не назначена',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (task != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        <String>[
                          if (task.axes.isNotEmpty) task.axes,
                          if (task.objectName.isNotEmpty) task.objectName,
                          if (task.date != null) _formatDate(task.date!),
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (task.photos.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Фотографий: ${task.photos.length}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ] else ...[
                      const SizedBox(height: 6),
                      Text(
                        'После назначения здесь появятся описание, срок и фотографии.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    PremiumActionButton(
                      label: task == null
                          ? 'Нет активной задачи'
                          : 'Открыть задачу',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: task == null
                          ? null
                          : () => _openTask(context, task),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.calendar_month_rounded,
                      value: _formatDecimal(data.summary.shifts),
                      label: 'смен в месяце',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.verified_rounded,
                      value: '${data.summary.completedTasks}',
                      label: 'задач выполнено',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              PremiumWorkCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const _IconTile(
                          icon: Icons.account_balance_wallet_rounded,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Этот месяц',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _ValueLine(
                      title: 'Предварительно начислено',
                      value: _formatMoney(data.summary.estimatedAccrued),
                    ),
                    _ValueLine(
                      title: 'Выплаты и авансы',
                      value: _formatMoney(data.summary.paidCurrentMonth),
                    ),
                    _ValueLine(
                      title: 'Задач в работе',
                      value: '${data.summary.plannedTasks}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class EmployeeActionableTasksScreen extends StatefulWidget {
  final AppUserProfile profile;

  const EmployeeActionableTasksScreen({super.key, required this.profile});

  @override
  State<EmployeeActionableTasksScreen> createState() =>
      _EmployeeActionableTasksScreenState();
}

class _EmployeeActionableTasksScreenState
    extends State<EmployeeActionableTasksScreen> {
  bool showCompleted = false;

  @override
  Widget build(BuildContext context) {
    return _EmployeeCabinetLoader(
      profile: widget.profile,
      builder: (context, data, refresh) {
        final tasks = data.tasks
            .where((task) => task.isCompleted == showCompleted)
            .toList(growable: false);

        return AppPage(
          title: 'Задачи',
          subtitle:
              '${data.summary.plannedTasks} в работе · ${data.summary.completedTasks} выполнено',
          onRefresh: refresh,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    icon: Icon(Icons.pending_actions_rounded),
                    label: Text('В работе'),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    icon: Icon(Icons.task_alt_rounded),
                    label: Text('Выполнено'),
                  ),
                ],
                selected: <bool>{showCompleted},
                onSelectionChanged: (selection) {
                  setState(() => showCompleted = selection.first);
                },
              ),
              const SizedBox(height: 14),
              if (tasks.isEmpty)
                _EmptySection(
                  icon: showCompleted
                      ? Icons.task_alt_rounded
                      : Icons.assignment_outlined,
                  title: showCompleted
                      ? 'Выполненных задач пока нет'
                      : 'Задач в работе пока нет',
                  text: showCompleted
                      ? 'После завершения задачи появятся в этом разделе.'
                      : 'Назначенные мастером задачи появятся здесь автоматически.',
                )
              else
                for (var index = 0; index < tasks.length; index++) ...[
                  _TaskCard(
                    task: tasks[index],
                    onTap: () => _openTask(context, tasks[index]),
                  ),
                  if (index != tasks.length - 1) const SizedBox(height: 12),
                ],
            ],
          ),
        );
      },
    );
  }
}

class EmployeeTaskDetailsScreen extends StatelessWidget {
  final EmployeeCabinetTask task;

  const EmployeeTaskDetailsScreen({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Задача',
      subtitle: <String>[
        if (task.objectName.isNotEmpty) task.objectName,
        if (task.date != null) _formatDate(task.date!),
      ].join(' · '),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PremiumWorkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _IconTile(icon: Icons.assignment_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        task.work.isEmpty ? 'Рабочая задача' : task.work,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _StatusBadge(text: task.status),
                  ],
                ),
                const SizedBox(height: 16),
                if (task.axes.isNotEmpty)
                  _DetailLine(icon: Icons.grid_4x4_rounded, text: task.axes),
                if (task.objectName.isNotEmpty)
                  _DetailLine(
                    icon: Icons.apartment_rounded,
                    text: task.objectName,
                  ),
                if (task.date != null)
                  _DetailLine(
                    icon: Icons.calendar_today_outlined,
                    text: _formatDate(task.date!),
                  ),
                if (task.photoRequirementsEnforced)
                  const _DetailLine(
                    icon: Icons.photo_camera_outlined,
                    text: 'Для задачи предусмотрены фотографии «До» и «После»',
                  ),
              ],
            ),
          ),
          if (task.notDoneComment.isNotEmpty) ...[
            const SizedBox(height: 14),
            PremiumWorkCard(
              child: _DetailLine(
                icon: Icons.info_outline_rounded,
                text: task.notDoneComment,
              ),
            ),
          ],
          const SizedBox(height: 14),
          _PhotoSection(title: 'Фото до', photos: task.beforePhotos),
          const SizedBox(height: 14),
          _PhotoSection(title: 'Фото после', photos: task.afterPhotos),
        ],
      ),
    );
  }
}

class _EmployeeCabinetLoader extends StatefulWidget {
  final AppUserProfile profile;
  final Widget Function(
    BuildContext context,
    EmployeeCabinetData data,
    Future<void> Function() refresh,
  )
  builder;

  const _EmployeeCabinetLoader({required this.profile, required this.builder});

  @override
  State<_EmployeeCabinetLoader> createState() => _EmployeeCabinetLoaderState();
}

class _EmployeeCabinetLoaderState extends State<_EmployeeCabinetLoader> {
  late Future<EmployeeCabinetData> future;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<EmployeeCabinetData> load() {
    if (widget.profile.isRolePreview) {
      return Future<EmployeeCabinetData>.value(
        EmployeeCabinetData.preview(widget.profile),
      );
    }
    return EmployeeCabinetRepository.fetch();
  }

  Future<void> refresh() async {
    final next = load();
    setState(() => future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EmployeeCabinetData>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const PremiumLoadingScreen();
        }
        if (snapshot.hasError || snapshot.data == null) {
          final message =
              snapshot.error?.toString().replaceFirst('Exception: ', '') ??
              'Не удалось загрузить личный кабинет';
          return AppPage(
            title: 'Личный кабинет',
            subtitle: 'Ошибка загрузки',
            child: PremiumWorkCard(
              child: Column(
                children: [
                  const _IconTile(icon: Icons.cloud_off_rounded, size: 62),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          );
        }
        return widget.builder(context, snapshot.data!, refresh);
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  final EmployeeCabinetTask task;
  final VoidCallback onTap;

  const _TaskCard({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Открыть задачу ${task.work}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: onTap,
          child: PremiumWorkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _IconTile(icon: Icons.assignment_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        task.work.isEmpty ? 'Рабочая задача' : task.work,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _StatusBadge(text: task.status),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
                const SizedBox(height: 10),
                if (task.axes.isNotEmpty)
                  _DetailLine(icon: Icons.grid_4x4_rounded, text: task.axes),
                if (task.objectName.isNotEmpty)
                  _DetailLine(
                    icon: Icons.apartment_rounded,
                    text: task.objectName,
                  ),
                if (task.date != null)
                  _DetailLine(
                    icon: Icons.calendar_today_outlined,
                    text: _formatDate(task.date!),
                  ),
                if (task.photos.isNotEmpty)
                  _DetailLine(
                    icon: Icons.photo_library_outlined,
                    text: 'Фотографий: ${task.photos.length}',
                  )
                else if (task.photoRequirementsEnforced)
                  const _DetailLine(
                    icon: Icons.photo_camera_outlined,
                    text: 'Для задачи нужны фотографии',
                  ),
                if (task.notDoneComment.isNotEmpty)
                  _DetailLine(
                    icon: Icons.info_outline_rounded,
                    text: task.notDoneComment,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoSection extends StatelessWidget {
  final String title;
  final List<EmployeeCabinetTaskPhoto> photos;

  const _PhotoSection({required this.title, required this.photos});

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconTile(icon: Icons.photo_library_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${photos.length}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (photos.isEmpty)
            Text(
              'Фотографий пока нет',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 600 ? 4 : 3;
                final width =
                    (constraints.maxWidth - (columns - 1) * 8) / columns;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: photos
                      .map((photo) {
                        return SizedBox(
                          width: width,
                          height: width,
                          child: _PhotoTile(photo: photo),
                        );
                      })
                      .toList(growable: false),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final EmployeeCabinetTaskPhoto photo;

  const _PhotoTile({required this.photo});

  @override
  Widget build(BuildContext context) {
    final url = photo.signedUrl;
    return Material(
      color: AppAdaptivePalette.surfaceSoft,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: url.isEmpty ? null : () => _showPhoto(context, photo),
        child: url.isEmpty
            ? const Center(child: Icon(Icons.broken_image_outlined))
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const Center(child: Icon(Icons.broken_image_outlined)),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String text;

  const _StatusBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    final completed = text == 'Выполнено';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: completed
            ? AppAdaptivePalette.success.withValues(alpha: 0.13)
            : AppAdaptivePalette.accentSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text.isEmpty ? 'Запланировано' : text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: completed
              ? AppAdaptivePalette.success
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  final IconData icon;
  final double size;

  const _IconTile({required this.icon, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppAdaptivePalette.accentSoft,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: Theme.of(context).colorScheme.onSurface),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueLine extends StatelessWidget {
  final String title;
  final String value;

  const _ValueLine({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DetailLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _EmptySection({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      child: Column(
        children: [
          _IconTile(icon: icon, size: 62),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _openTask(BuildContext context, EmployeeCabinetTask task) async {
  await Navigator.of(context).push<void>(
    AppPageRoute<void>(builder: (_) => EmployeeTaskDetailsScreen(task: task)),
  );
}

Future<void> _showPhoto(
  BuildContext context,
  EmployeeCabinetTaskPhoto photo,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5,
                child: Image.network(
                  photo.signedUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white,
                      size: 56,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      );
    },
  );
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

String _formatDecimal(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(1).replaceAll('.', ',');
}

String _formatMoney(double value) {
  final rounded = value.round();
  final raw = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < raw.length; index++) {
    if (index > 0 && (raw.length - index) % 3 == 0) buffer.write(' ');
    buffer.write(raw[index]);
  }
  return '${rounded < 0 ? '−' : ''}${buffer.toString()} ₽';
}
