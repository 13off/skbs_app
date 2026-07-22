import 'package:flutter/material.dart';

import '../app/app_adaptive_palette.dart';

import '../data/object_repository.dart';
import '../widgets/premium_ui.dart';
import 'desktop_home_widgets.dart';

Color get _text => AppAdaptivePalette.textPrimary;
Color get _muted => AppAdaptivePalette.textMuted;
Color get _line => AppAdaptivePalette.border;
Color get _soft => AppAdaptivePalette.surfaceSoft;
Color get _danger => AppAdaptivePalette.danger;

class DesktopObjectManagementDialog extends StatefulWidget {
  final String? selectedObjectName;
  final ValueChanged<String?> onObjectChanged;
  final Future<void> Function() onDataChanged;

  const DesktopObjectManagementDialog({
    super.key,
    required this.selectedObjectName,
    required this.onObjectChanged,
    required this.onDataChanged,
  });

  @override
  State<DesktopObjectManagementDialog> createState() =>
      _DesktopObjectManagementDialogState();
}

class _DesktopObjectManagementDialogState
    extends State<DesktopObjectManagementDialog> {
  List<String> activeObjects = const <String>[];
  List<String> archivedObjects = const <String>[];
  bool loading = true;
  bool busy = false;
  String? errorText;
  String? selectedObjectName;

  String? clean(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  @override
  void initState() {
    super.initState();
    selectedObjectName = clean(widget.selectedObjectName);
    loadObjects();
  }

  Future<void> loadObjects() async {
    setState(() {
      loading = true;
      errorText = null;
    });

    try {
      final results = await Future.wait<List<String>>([
        ObjectRepository.fetchObjectNames(forceRefresh: true),
        ObjectRepository.fetchArchivedObjectNames(forceRefresh: true),
      ]);

      if (!mounted) return;
      setState(() {
        activeObjects = results[0];
        archivedObjects = results[1];
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorText = error.toString();
      });
    }
  }

  Future<String?> requestName({
    required String title,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Название объекта',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'Введите название объекта';
                if (text.length < 2) return 'Название слишком короткое';
                return null;
              },
              onFieldSubmitted: (_) {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(dialogContext, controller.text.trim());
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(dialogContext, controller.text.trim());
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return result;
  }

  Future<bool> confirmArchive(String objectName) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Архивировать объект?'),
              content: Text(
                'Объект «$objectName» исчезнет из рабочего списка. Данные сохранятся.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Архивировать'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> runAction(Future<void> Function() action) async {
    if (busy) return;

    setState(() {
      busy = true;
      errorText = null;
    });

    try {
      await action();
      await loadObjects();
      await widget.onDataChanged();
    } catch (error) {
      if (!mounted) return;
      setState(() => errorText = error.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> addObject() async {
    final name = await requestName(title: 'Новый объект');
    if (name == null) return;

    await runAction(() async {
      final savedName = await ObjectRepository.addObject(name: name);
      selectedObjectName = savedName;
      widget.onObjectChanged(savedName);
    });
  }

  Future<void> renameObject(String oldName) async {
    final newName = await requestName(
      title: 'Переименовать объект',
      initialValue: oldName,
    );
    if (newName == null || newName == oldName) return;

    await runAction(() async {
      final savedName = await ObjectRepository.renameObject(
        oldName: oldName,
        newName: newName,
      );
      if (selectedObjectName == oldName) {
        selectedObjectName = savedName;
        widget.onObjectChanged(savedName);
      }
    });
  }

  Future<void> archiveObject(String objectName) async {
    if (!await confirmArchive(objectName)) return;

    await runAction(() async {
      await ObjectRepository.archiveObject(name: objectName);
      if (selectedObjectName == objectName) {
        selectedObjectName = null;
        widget.onObjectChanged(null);
      }
    });
  }

  Future<void> restoreObject(String objectName) async {
    await runAction(() async {
      await ObjectRepository.restoreObject(name: objectName);
    });
  }

  void selectObject(String objectName) {
    setState(() => selectedObjectName = objectName);
    widget.onObjectChanged(objectName);
  }

  @override
  Widget build(BuildContext context) {
    final selected = selectedObjectName;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Управление объектами',
                          style: TextStyle(
                            color: _text,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Создание, переименование, архив и восстановление',
                          style: TextStyle(
                            color: _muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: busy ? null : addObject,
                    icon: Icon(Icons.add_business_outlined),
                    label: const Text('Добавить объект'),
                  ),
                  SizedBox(width: 8),
                  IconButton(
                    onPressed: busy ? null : () => Navigator.pop(context),
                    tooltip: 'Закрыть',
                    icon: Icon(Icons.close_rounded),
                  ),
                ],
              ),
              if (errorText != null) ...[
                SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    errorText!,
                    style: TextStyle(
                      color: _danger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              SizedBox(height: 16),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        children: [
                          ObjectSectionTitle(
                            title: 'Активные объекты',
                            count: activeObjects.length,
                          ),
                          SizedBox(height: 8),
                          if (activeObjects.isEmpty)
                            const DesktopEmptyState(
                              icon: Icons.business_outlined,
                              text: 'Активных объектов пока нет',
                            )
                          else
                            ...activeObjects.map(
                              (objectName) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected == objectName
                                        ? AppAdaptivePalette.selectedSurface
                                        : AppAdaptivePalette.surfaceElevated,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: selected == objectName
                                          ? _text
                                          : _line,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.business_outlined,
                                        color: _muted,
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          objectName,
                                          style: TextStyle(
                                            color: _text,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      if (selected == objectName)
                                        Padding(
                                          padding: EdgeInsets.only(right: 8),
                                          child: Text(
                                            'Выбран',
                                            style: TextStyle(
                                              color: _muted,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        )
                                      else
                                        TextButton(
                                          onPressed: busy
                                              ? null
                                              : () => selectObject(objectName),
                                          child: const Text('Выбрать'),
                                        ),
                                      IconButton(
                                        onPressed: busy
                                            ? null
                                            : () => renameObject(objectName),
                                        tooltip: 'Переименовать',
                                        icon: Icon(Icons.edit_outlined),
                                      ),
                                      IconButton(
                                        onPressed: busy
                                            ? null
                                            : () => archiveObject(objectName),
                                        tooltip: 'Архивировать',
                                        icon: Icon(Icons.archive_outlined),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          SizedBox(height: 18),
                          ObjectSectionTitle(
                            title: 'Архив',
                            count: archivedObjects.length,
                          ),
                          SizedBox(height: 8),
                          if (archivedObjects.isEmpty)
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: Text(
                                'Архив пуст',
                                style: TextStyle(
                                  color: _muted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          else
                            ...archivedObjects.map(
                              (objectName) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _soft,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: _line),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.inventory_2_outlined,
                                        color: _muted,
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          objectName,
                                          style: TextStyle(
                                            color: _text,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: busy
                                            ? null
                                            : () => restoreObject(objectName),
                                        icon: Icon(
                                          Icons.restore_rounded,
                                          size: 18,
                                        ),
                                        label: const Text('Восстановить'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
              if (busy) ...[
                SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ObjectSectionTitle extends StatelessWidget {
  final String title;
  final int count;

  const ObjectSectionTitle({
    super.key,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: _text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _soft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            style: TextStyle(color: _muted, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}
