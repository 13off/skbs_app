import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../widgets/premium_ui.dart';
import '../data/developer_policy_repository.dart';
import '../models/task_policy.dart';

class DeveloperPanelScreen extends StatefulWidget {
  final AppUserProfile profile;

  const DeveloperPanelScreen({super.key, required this.profile});

  @override
  State<DeveloperPanelScreen> createState() => _DeveloperPanelScreenState();
}

class _DeveloperPanelScreenState extends State<DeveloperPanelScreen> {
  DeveloperTaskPolicyCenter? center;
  TaskPolicy editing = TaskPolicy.defaults;
  String? selectedObjectId;
  bool selectedHasOverride = false;
  bool loading = true;
  bool saving = false;
  String? errorText;

  bool get companyMode => selectedObjectId == null;

  DeveloperObjectPolicy? get selectedObject {
    final id = selectedObjectId;
    if (id == null || center == null) return null;
    for (final object in center!.objects) {
      if (object.id == id) return object;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      errorText = null;
    });
    try {
      final value = await DeveloperPolicyRepository.fetchCenter();
      if (!mounted) return;
      setState(() {
        center = value;
        selectCompanyPolicy(updateState: false);
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorText = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void selectCompanyPolicy({bool updateState = true}) {
    final value = center;
    if (value == null) return;
    void apply() {
      selectedObjectId = null;
      selectedHasOverride = true;
      editing = value.companyPolicy;
      errorText = null;
    }

    if (updateState) {
      setState(apply);
    } else {
      apply();
    }
  }

  void selectObjectPolicy(DeveloperObjectPolicy object) {
    setState(() {
      selectedObjectId = object.id;
      selectedHasOverride = object.hasOverride;
      editing = object.policy.copyWith(objectId: object.id);
      errorText = null;
    });
  }

  Future<void> save() async {
    if (saving) return;
    setState(() {
      saving = true;
      errorText = null;
    });
    try {
      final next = await DeveloperPolicyRepository.savePolicy(
        objectId: selectedObjectId,
        policy: editing,
      );
      if (!mounted) return;
      final currentObjectId = selectedObjectId;
      setState(() {
        center = next;
        if (currentObjectId == null) {
          editing = next.companyPolicy;
          selectedHasOverride = true;
        } else {
          final object = next.objects.firstWhere(
            (item) => item.id == currentObjectId,
          );
          editing = object.policy;
          selectedHasOverride = object.hasOverride;
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ограничения сохранены')));
    } catch (error) {
      if (mounted) {
        setState(
          () => errorText = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> resetOverride() async {
    final objectId = selectedObjectId;
    if (objectId == null || saving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Использовать настройки компании?'),
        content: const Text(
          'Индивидуальные ограничения объекта будут удалены. Объект сразу начнёт наследовать общие настройки компании.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      saving = true;
      errorText = null;
    });
    try {
      final next = await DeveloperPolicyRepository.resetObjectOverride(
        objectId,
      );
      if (!mounted) return;
      final object = next.objects.firstWhere((item) => item.id == objectId);
      setState(() {
        center = next;
        editing = object.policy;
        selectedHasOverride = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Объект наследует настройки компании')),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => errorText = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void update(TaskPolicy Function(TaskPolicy value) change) {
    setState(() => editing = change(editing));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Панель разработчика'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: loading || saving ? null : load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: PremiumBackdrop(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : center == null
            ? _ErrorState(
                message: errorText ?? 'Настройки недоступны',
                retry: load,
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final desktop = constraints.maxWidth >= 1000;
                  final selector = _buildSelector();
                  final editor = _buildEditor();
                  if (desktop) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 330, child: selector),
                        const SizedBox(width: 16),
                        Expanded(child: editor),
                      ],
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                    children: [selector, const SizedBox(height: 16), editor],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildSelector() {
    final value = center!;
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        PremiumWorkCard(
          radius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.developer_mode_rounded),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Область настроек',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Общие правила применяются ко всем объектам. Для любого объекта можно создать исключение.',
                style: TextStyle(height: 1.35),
              ),
              const SizedBox(height: 14),
              _ScopeTile(
                title: 'Вся компания',
                subtitle: 'Настройки по умолчанию',
                selected: companyMode,
                icon: Icons.apartment_rounded,
                onTap: selectCompanyPolicy,
              ),
              const SizedBox(height: 8),
              ...value.objects.map(
                (object) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ScopeTile(
                    title: object.name,
                    subtitle: object.hasOverride
                        ? 'Индивидуальные ограничения'
                        : 'Наследует настройки компании',
                    selected: selectedObjectId == object.id,
                    icon: object.hasOverride
                        ? Icons.tune_rounded
                        : Icons.account_tree_outlined,
                    onTap: () => selectObjectPolicy(object),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        PremiumWorkCard(
          radius: 24,
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Роль и профессия',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 7),
              Text(
                'Роль «Разработчик» управляет доступом. Профессия хранится отдельно и редактируется в разделе «Компания и пользователи».',
                style: TextStyle(height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditor() {
    final object = selectedObject;
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 0, 16, 40),
      children: [
        PremiumWorkCard(
          radius: 26,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          companyMode
                              ? 'Ограничения компании'
                              : 'Ограничения: ${object?.name ?? ''}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          companyMode
                              ? 'Базовое поведение всех объектов'
                              : selectedHasOverride
                              ? 'Для объекта действуют индивидуальные правила'
                              : 'Сейчас показаны унаследованные правила. Сохранение создаст исключение.',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  if (!companyMode && selectedHasOverride)
                    TextButton.icon(
                      onPressed: saving ? null : resetOverride,
                      icon: const Icon(Icons.account_tree_outlined),
                      label: const Text('Наследовать'),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _sectionTitle('Фотографии'),
              _switch(
                title: 'Обязательно фото «До»',
                subtitle: 'Без нужного количества снимков задача не создаётся',
                value: editing.requireBeforePhoto,
                onChanged: (value) => update(
                  (policy) => policy.copyWith(requireBeforePhoto: value),
                ),
              ),
              if (editing.requireBeforePhoto)
                _counter(
                  title: 'Минимум фото «До»',
                  value: editing.minBeforePhotos,
                  onChanged: (value) => update(
                    (policy) => policy.copyWith(minBeforePhotos: value),
                  ),
                ),
              _switch(
                title: 'Обязательно фото «После»',
                subtitle: 'Проверяется при переводе задачи в «Выполнено»',
                value: editing.requireAfterPhotoOnComplete,
                onChanged: (value) => update(
                  (policy) =>
                      policy.copyWith(requireAfterPhotoOnComplete: value),
                ),
              ),
              if (editing.requireAfterPhotoOnComplete)
                _counter(
                  title: 'Минимум фото «После»',
                  value: editing.minAfterPhotos,
                  onChanged: (value) => update(
                    (policy) => policy.copyWith(minAfterPhotos: value),
                  ),
                ),
              _switch(
                title: 'Разрешить удалять фото «До»',
                subtitle:
                    'Только прорабу; администратор и разработчик не ограничиваются',
                value: editing.foremanCanDeleteBeforePhotos,
                onChanged: (value) => update(
                  (policy) =>
                      policy.copyWith(foremanCanDeleteBeforePhotos: value),
                ),
              ),
              _switch(
                title: 'Разрешить удалять фото «После»',
                subtitle: 'Можно закрыть удаление результата после завершения',
                value: editing.foremanCanDeleteAfterPhotos,
                onChanged: (value) => update(
                  (policy) =>
                      policy.copyWith(foremanCanDeleteAfterPhotos: value),
                ),
              ),
              const SizedBox(height: 12),
              _sectionTitle('Создание и срок редактирования'),
              _switch(
                title: 'Создавать задачи на другие даты',
                subtitle:
                    'По умолчанию прораб создаёт задачи только на сегодня',
                value: editing.foremanCanCreateAnyDate,
                onChanged: (value) => update(
                  (policy) => policy.copyWith(foremanCanCreateAnyDate: value),
                ),
              ),
              _switch(
                title: 'Редактировать прошедшие задачи',
                subtitle:
                    'Разблокирует старые задачи в пределах выбранного срока',
                value: editing.foremanCanEditPastTasks,
                onChanged: (value) => update(
                  (policy) => policy.copyWith(foremanCanEditPastTasks: value),
                ),
              ),
              if (editing.foremanCanEditPastTasks) _editWindow(),
              const SizedBox(height: 12),
              _sectionTitle('Что разрешено менять прорабу'),
              _switch(
                title: 'Дата задачи',
                value: editing.foremanCanEditDate,
                onChanged: (value) => update(
                  (policy) => policy.copyWith(foremanCanEditDate: value),
                ),
              ),
              _switch(
                title: 'Оси и вид работ',
                value: editing.foremanCanEditAxesWork,
                onChanged: (value) => update(
                  (policy) => policy.copyWith(foremanCanEditAxesWork: value),
                ),
              ),
              _switch(
                title: 'Исполнители',
                value: editing.foremanCanEditAssignees,
                onChanged: (value) => update(
                  (policy) => policy.copyWith(foremanCanEditAssignees: value),
                ),
              ),
              _switch(
                title: 'Статус задачи',
                value: editing.foremanCanEditStatus,
                onChanged: (value) => update(
                  (policy) => policy.copyWith(foremanCanEditStatus: value),
                ),
              ),
              _switch(
                title: 'Удаление задачи',
                subtitle: 'Опасное действие с подтверждением',
                value: editing.foremanCanDeleteTask,
                onChanged: (value) => update(
                  (policy) => policy.copyWith(foremanCanDeleteTask: value),
                ),
              ),
              _switch(
                title: 'Обязательная причина невыполнения',
                subtitle: 'Для задач на сегодня и прошедшие даты',
                value: editing.requireNotDoneComment,
                onChanged: (value) => update(
                  (policy) => policy.copyWith(requireNotDoneComment: value),
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  errorText!,
                  style: const TextStyle(
                    color: Color(0xFF874540),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              PremiumActionButton(
                onPressed: saving ? null : save,
                icon: Icons.save_outlined,
                label: companyMode
                    ? 'Сохранить настройки компании'
                    : selectedHasOverride
                    ? 'Сохранить настройки объекта'
                    : 'Создать исключение для объекта',
                isLoading: saving,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildAudit(),
      ],
    );
  }

  Widget _buildAudit() {
    final entries = center!.audit;
    return PremiumWorkCard(
      radius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Журнал изменений',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            const Text('Настройки ещё не менялись')
          else
            ...entries.take(12).map((entry) {
              final date = entry.changedAt;
              final dateText = date == null
                  ? '—'
                  : '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} '
                        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
              final action = switch (entry.action) {
                'create' => 'создано исключение',
                'reset' => 'сброшено наследование',
                _ => 'изменены настройки',
              };
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  child: Icon(Icons.history_rounded, size: 19),
                ),
                title: Text(
                  entry.objectName.isEmpty
                      ? 'Компания: $action'
                      : '${entry.objectName}: $action',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${entry.changedByName.isEmpty ? 'Пользователь' : entry.changedByName} • $dateText',
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _sectionTitle(String value) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
      child: Text(
        value.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _switch({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: saving ? null : onChanged,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: subtitle == null ? null : Text(subtitle),
      ),
    );
  }

  Widget _counter({
    required String title,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: saving || value <= 0
                  ? null
                  : () => onChanged(value - 1),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            SizedBox(
              width: 34,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            IconButton(
              onPressed: saving || value >= 20
                  ? null
                  : () => onChanged(value + 1),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editWindow() {
    final mode = editing.editWindowDays == null
        ? 'unlimited'
        : editing.editWindowDays == 0
        ? 'today'
        : 'days';
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Срок редактирования',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: mode,
              items: const [
                DropdownMenuItem(value: 'today', child: Text('Только сегодня')),
                DropdownMenuItem(value: 'days', child: Text('Количество дней')),
                DropdownMenuItem(value: 'unlimited', child: Text('Без срока')),
              ],
              onChanged: saving
                  ? null
                  : (value) {
                      update((policy) {
                        return switch (value) {
                          'unlimited' => policy.copyWith(editWindowDays: null),
                          'days' => policy.copyWith(
                            editWindowDays:
                                policy.editWindowDays == null ||
                                    policy.editWindowDays == 0
                                ? 7
                                : policy.editWindowDays,
                          ),
                          _ => policy.copyWith(editWindowDays: 0),
                        };
                      });
                    },
            ),
            if (mode == 'days') ...[
              const SizedBox(height: 10),
              _counter(
                title: 'Дней после даты задачи',
                value: editing.editWindowDays ?? 7,
                onChanged: (value) =>
                    update((policy) => policy.copyWith(editWindowDays: value)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScopeTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  const _ScopeTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: onTap,
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: selected ? const Icon(Icons.check_circle_rounded) : null,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() retry;

  const _ErrorState({required this.message, required this.retry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 46),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton(onPressed: retry, child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }
}
