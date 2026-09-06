import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../widgets/premium_ui.dart';
import '../data/developer_policy_repository.dart';
import '../models/task_policy.dart';

class TimesheetEditPolicyScreen extends StatefulWidget {
  const TimesheetEditPolicyScreen({super.key});

  @override
  State<TimesheetEditPolicyScreen> createState() =>
      _TimesheetEditPolicyScreenState();
}

class _TimesheetEditPolicyScreenState extends State<TimesheetEditPolicyScreen> {
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
    final value = center;
    if (id == null || value == null) return null;
    for (final object in value.objects) {
      if (object.id == id) return object;
    }
    return null;
  }

  String get mode {
    final days = editing.foremanTimesheetEditWindowDays;
    if (days == null) return 'unlimited';
    if (days == 0) return 'today';
    return 'days';
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
        selectedObjectId = null;
        selectedHasOverride = true;
        editing = value.companyPolicy;
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

  void selectCompany() {
    final value = center;
    if (value == null) return;
    setState(() {
      selectedObjectId = null;
      selectedHasOverride = true;
      editing = value.companyPolicy;
      errorText = null;
    });
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
      final objectId = selectedObjectId;
      setState(() {
        center = next;
        if (objectId == null) {
          editing = next.companyPolicy;
          selectedHasOverride = true;
        } else {
          final object = next.objects.firstWhere((item) => item.id == objectId);
          editing = object.policy;
          selectedHasOverride = object.hasOverride;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ограничение табеля сохранено')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(
        () => errorText = error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> resetOverride() async {
    final objectId = selectedObjectId;
    if (objectId == null || saving) return;
    setState(() {
      saving = true;
      errorText = null;
    });
    try {
      final next = await DeveloperPolicyRepository.resetObjectOverride(objectId);
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
      if (!mounted) return;
      setState(
        () => errorText = error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void setMode(String? value) {
    if (value == null || saving) return;
    setState(() {
      editing = switch (value) {
        'unlimited' => editing.copyWith(
            foremanTimesheetEditWindowDays: null,
          ),
        'days' => editing.copyWith(
            foremanTimesheetEditWindowDays:
                (editing.foremanTimesheetEditWindowDays ?? 0) <= 0
                ? 7
                : editing.foremanTimesheetEditWindowDays,
          ),
        _ => editing.copyWith(foremanTimesheetEditWindowDays: 0),
      };
    });
  }

  void changeDays(int delta) {
    final current = editing.foremanTimesheetEditWindowDays ?? 7;
    final next = (current + delta).clamp(1, 3650).toInt();
    if (next == current) return;
    setState(
      () => editing = editing.copyWith(foremanTimesheetEditWindowDays: next),
    );
  }

  Widget scopeTile({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: saving ? null : onTap,
        leading: Icon(
          selected ? Icons.check_circle_rounded : Icons.apartment_outlined,
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
      ),
    );
  }

  Widget buildSelector() {
    final value = center!;
    return PremiumWorkCard(
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Где действует правило',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Можно задать общее ограничение компании и отдельное исключение для объекта.',
          ),
          const SizedBox(height: 14),
          scopeTile(
            title: 'Вся компания',
            subtitle: 'Настройка по умолчанию',
            selected: companyMode,
            onTap: selectCompany,
          ),
          const SizedBox(height: 7),
          ...value.objects.map(
            (object) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: scopeTile(
                title: object.name,
                subtitle: object.hasOverride
                    ? 'Индивидуальная настройка'
                    : 'Наследует настройку компании',
                selected: selectedObjectId == object.id,
                onTap: () => selectObjectPolicy(object),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildEditor() {
    final object = selectedObject;
    final days = editing.foremanTimesheetEditWindowDays ?? 7;
    return PremiumWorkCard(
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
                          ? 'Редактирование табеля'
                          : 'Табель: ${object?.name ?? ''}',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Ограничение применяется к прорабу. Администратор и разработчик могут исправлять старые даты без ограничения.',
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
          DropdownButtonFormField<String>(
            initialValue: mode,
            decoration: const InputDecoration(
              labelText: 'Редактирование предыдущих дней',
            ),
            items: const [
              DropdownMenuItem(
                value: 'today',
                child: Text('Только текущий день'),
              ),
              DropdownMenuItem(
                value: 'days',
                child: Text('Разрешить несколько предыдущих дней'),
              ),
              DropdownMenuItem(
                value: 'unlimited',
                child: Text('Без ограничения'),
              ),
            ],
            onChanged: saving ? null : setMode,
          ),
          if (mode == 'days') ...[
            const SizedBox(height: 14),
            Card(
              elevation: 0,
              child: ListTile(
                title: const Text(
                  'Сколько предыдущих дней можно исправлять',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  'Прораб сможет изменить сегодняшний табель и ещё $days дн. назад.',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: saving || days <= 1 ? null : () => changeDays(-1),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    SizedBox(
                      width: 42,
                      child: Text(
                        '$days',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: saving || days >= 3650 ? null : () => changeDays(1),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppAdaptivePalette.surfaceSoft,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppAdaptivePalette.border),
            ),
            child: const Text(
              'Старые табели остаются доступными для просмотра. Ограничение блокирует только изменение и сохранение.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (errorText != null) ...[
            const SizedBox(height: 12),
            Text(
              errorText!,
              style: TextStyle(
                color: AppAdaptivePalette.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 18),
          PremiumActionButton(
            onPressed: saving ? null : save,
            icon: Icons.save_outlined,
            label: companyMode
                ? 'Сохранить для компании'
                : selectedHasOverride
                ? 'Сохранить для объекта'
                : 'Создать исключение для объекта',
            isLoading: saving,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Редактирование табеля'),
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
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    errorText ?? 'Настройки недоступны',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final desktop = constraints.maxWidth >= 1000;
                  final selector = buildSelector();
                  final editor = buildEditor();
                  if (desktop) {
                    return ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 330, child: selector),
                            const SizedBox(width: 16),
                            Expanded(child: editor),
                          ],
                        ),
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
}
