import 'package:flutter/material.dart';

import '../app/app_adaptive_palette.dart';

import '../data/attendance_repository.dart';
import '../data/employee_repository.dart';
import '../data/object_repository.dart';
import '../data/task_repository.dart';

Color get _bg => AppAdaptivePalette.background;
Color get _card => AppAdaptivePalette.surfaceElevated;
Color get _softCard => AppAdaptivePalette.surfaceSoft;
Color get _line => AppAdaptivePalette.border;
Color get _text => AppAdaptivePalette.textPrimary;
Color get _muted => AppAdaptivePalette.textMuted;
Color get _accent => AppAdaptivePalette.textFaint;

class ObjectManagementScreen extends StatefulWidget {
  final String? selectedObjectName;
  final ValueChanged<String?> onObjectChanged;

  const ObjectManagementScreen({
    super.key,
    required this.selectedObjectName,
    required this.onObjectChanged,
  });

  @override
  State<ObjectManagementScreen> createState() => _ObjectManagementScreenState();
}

class _ObjectManagementScreenState extends State<ObjectManagementScreen> {
  List<String> objectNames = [];
  bool isLoading = true;
  bool isMutating = false;
  String? errorText;
  int loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    loadObjects();
  }

  String? cleanObjectName(String? value) {
    final clean = value?.trim();

    if (clean == null || clean.isEmpty) return null;

    return clean;
  }

  String objectTitle(String? value) {
    return cleanObjectName(value) ?? 'Все объекты';
  }

  bool isSameObject(String? a, String? b) {
    return cleanObjectName(a) == cleanObjectName(b);
  }

  void clearAllCaches() {
    ObjectRepository.clearCache();
    EmployeeRepository.clearCache();
    AttendanceRepository.clearCache();
    TaskRepository.clearTaskListCache();
  }

  Future<void> loadObjects() async {
    final generation = ++loadGeneration;

    setState(() {
      isLoading = true;
      errorText = null;
    });

    try {
      final loadedObjects = await EmployeeRepository.fetchObjectNames(
        forceRefresh: true,
      );

      if (!mounted || generation != loadGeneration) return;

      setState(() {
        objectNames = loadedObjects;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted || generation != loadGeneration) return;

      setState(() {
        errorText = 'Ошибка загрузки объектов: $error';
        isLoading = false;
      });
    }
  }

  Future<String?> showObjectNameSheet({String? currentName}) async {
    final isEdit = currentName != null;
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(text: currentName ?? '');

    var isSaving = false;
    String? sheetErrorText;

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> save() async {
              final isValid = formKey.currentState?.validate() ?? false;

              if (!isValid || isSaving) return;

              setModalState(() {
                isSaving = true;
                sheetErrorText = null;
              });

              try {
                final savedName = isEdit
                    ? await ObjectRepository.renameObject(
                        oldName: currentName,
                        newName: controller.text,
                      )
                    : await ObjectRepository.addObject(name: controller.text);

                if (!context.mounted) return;

                Navigator.pop(context, savedName);
              } catch (error) {
                if (!context.mounted) return;

                setModalState(() {
                  isSaving = false;
                  sheetErrorText = error.toString();
                });
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 12,
                  bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: _line),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4CCC2),
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                        ),
                        SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                isEdit
                                    ? 'Редактировать объект'
                                    : 'Новый объект',
                                style: TextStyle(
                                  color: _text,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: isSaving
                                  ? null
                                  : () {
                                      Navigator.pop(context);
                                    },
                              icon: Icon(Icons.close),
                            ),
                          ],
                        ),
                        SizedBox(height: 14),
                        TextFormField(
                          controller: controller,
                          enabled: !isSaving,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: 'Название объекта',
                            hintText: isEdit ? currentName : 'Например: Талнах',
                            border: const OutlineInputBorder(),
                            prefixIcon: Icon(Icons.business_outlined),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';

                            if (text.isEmpty) {
                              return 'Введите название объекта';
                            }

                            if (text.length < 2) {
                              return 'Название слишком короткое';
                            }

                            return null;
                          },
                          onFieldSubmitted: (_) {
                            save();
                          },
                        ),
                        if (sheetErrorText != null) ...[
                          SizedBox(height: 12),
                          Text(
                            sheetErrorText!,
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton.icon(
                            onPressed: isSaving ? null : save,
                            icon: isSaving
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(isEdit ? Icons.save : Icons.add),
                            label: Text(
                              isSaving
                                  ? 'Сохраняем...'
                                  : isEdit
                                  ? 'Сохранить изменения'
                                  : 'Создать объект',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    controller.dispose();

    return result;
  }

  Future<void> addObject() async {
    final createdName = await showObjectNameSheet();

    if (createdName == null || createdName.trim().isEmpty) return;

    clearAllCaches();
    await loadObjects();

    widget.onObjectChanged(createdName);

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Объект "$createdName" создан')));
  }

  Future<void> renameObject(String oldName) async {
    final newName = await showObjectNameSheet(currentName: oldName);

    if (newName == null || newName.trim().isEmpty) return;

    clearAllCaches();
    await loadObjects();

    if (isSameObject(widget.selectedObjectName, oldName)) {
      widget.onObjectChanged(newName);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Объект переименован: $newName')));
  }

  Future<void> deleteObject(String objectName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Удалить объект?'),
          content: Text(
            'Объект "$objectName" будет скрыт из списка. Если к нему привязаны сотрудники, табель, задачи или пользователь — удаление будет запрещено.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || isMutating) return;

    setState(() {
      isMutating = true;
      errorText = null;
    });

    try {
      await ObjectRepository.deleteObject(name: objectName);

      clearAllCaches();

      if (isSameObject(widget.selectedObjectName, objectName)) {
        widget.onObjectChanged(null);
      }

      await loadObjects();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Объект "$objectName" удалён')));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          isMutating = false;
        });
      }
    }
  }

  Widget buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Объекты',
            style: TextStyle(
              color: _text,
              fontSize: 34,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Текущий выбор: ${objectTitle(widget.selectedObjectName)}',
            style: TextStyle(
              color: _muted,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: isLoading || isMutating ? null : addObject,
              icon: Icon(Icons.add_business_outlined),
              label: const Text('Добавить объект'),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildObjectCard(String objectName) {
    final isSelected = isSameObject(widget.selectedObjectName, objectName);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSelected ? _softCard : _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isSelected ? _accent : _line),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _softCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _line),
            ),
            child: Icon(
              isSelected ? Icons.check_circle : Icons.business_outlined,
              color: isSelected ? _accent : _text,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () {
                widget.onObjectChanged(objectName);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    objectName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _text,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    isSelected ? 'Выбран сейчас' : 'Нажми, чтобы выбрать',
                    style: TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Редактировать',
            onPressed: isLoading || isMutating
                ? null
                : () {
                    renameObject(objectName);
                  },
            icon: Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Удалить',
            onPressed: isLoading || isMutating
                ? null
                : () {
                    deleteObject(objectName);
                  },
            icon: Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Управление объектами'),
      ),
      body: RefreshIndicator(
        onRefresh: loadObjects,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            buildHeader(),
            SizedBox(height: 16),
            if (isLoading || isMutating)
              Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: LinearProgressIndicator(),
              ),
            if (errorText != null)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: Text(
                  errorText!,
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (!isLoading && objectNames.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _line),
                ),
                child: Text(
                  'Объекты пока не найдены',
                  style: TextStyle(color: _muted, fontWeight: FontWeight.w700),
                ),
              )
            else
              ...objectNames.map(buildObjectCard),
          ],
        ),
      ),
    );
  }
}
