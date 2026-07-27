part of '../home_screen.dart';

extension _HomeObjectActions on _HomeScreenState {
  Future<String?> showObjectNameSheet({String? currentName}) async {
    if (!widget.profile.isAdmin) return null;

    final isEdit = currentName != null;
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(text: currentName ?? '');
    var isSaving = false;
    String? errorText;

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> saveObject() async {
              final isValid = formKey.currentState?.validate() ?? false;
              if (!isValid || isSaving) return;

              setModalState(() {
                isSaving = true;
                errorText = null;
              });

              try {
                final savedName = isEdit
                    ? await ObjectRepository.renameObject(
                        oldName: currentName,
                        newName: controller.text,
                      )
                    : await ObjectRepository.addObject(name: controller.text);
                if (!sheetContext.mounted) return;
                Navigator.pop(sheetContext, savedName);
              } catch (error) {
                if (!sheetContext.mounted) return;
                setModalState(() {
                  isSaving = false;
                  errorText = error.toString();
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
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                isEdit ? 'Редактировать объект' : 'Новый объект',
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
                                  : () => Navigator.pop(sheetContext),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: controller,
                          enabled: !isSaving,
                          autofocus: true,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: 'Название объекта',
                            hintText: isEdit ? currentName : 'Например: Талнах',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.business_outlined),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) return 'Введите название объекта';
                            if (text.length < 2) return 'Название слишком короткое';
                            return null;
                          },
                          onFieldSubmitted: (_) => saveObject(),
                        ),
                        if (errorText != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            errorText!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: isSaving ? null : saveObject,
                            icon: isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    isEdit
                                        ? Icons.save_outlined
                                        : Icons.add_business_outlined,
                                  ),
                            label: Text(
                              isSaving
                                  ? 'Сохраняем...'
                                  : isEdit
                                  ? 'Сохранить'
                                  : 'Создать',
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

  Future<void> handleAddObject() async {
    final createdName = await showObjectNameSheet();
    if (createdName == null || createdName.trim().isEmpty) return;
    widget.onObjectChanged(createdName);
    refreshObjectsAndDashboard();
  }

  Future<void> handleRenameObject(String oldName) async {
    final newName = await showObjectNameSheet(currentName: oldName);
    if (newName == null || newName.trim().isEmpty) return;
    if (isSameObject(widget.selectedObjectName, oldName)) {
      widget.onObjectChanged(newName);
    }
    refreshObjectsAndDashboard();
  }

  Future<void> handleArchiveObject(String objectName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Архивировать объект?'),
          content: Text(
            'Объект "$objectName" исчезнет из рабочего списка. Табели, задачи, выплаты и документы сохранятся. Сотрудники на этом объекте будут отмечены как уволенные.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.archive_outlined),
              label: const Text('В архив'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    try {
      final wasSelected = isSameObject(widget.selectedObjectName, objectName);
      await ObjectRepository.archiveObject(name: objectName);
      if (wasSelected) widget.onObjectChanged(null);
      refreshObjectsAndDashboard();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Объект "$objectName" перемещён в архив')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> showArchivedObjectsSheet(BuildContext context) async {
    List<String> archivedObjects;
    try {
      archivedObjects = await ObjectRepository.fetchArchivedObjectNames(
        forceRefresh: true,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
      return;
    }

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(18),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
            ),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Архив объектов',
                        style: TextStyle(
                          color: _text,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (archivedObjects.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Column(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 42,
                          color: _muted,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Архив пуст',
                          style: TextStyle(
                            color: _muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: archivedObjects.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final objectName = archivedObjects[index];
                        return Container(
                          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                          decoration: BoxDecoration(
                            color: _softCard,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: _line),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.inventory_2_outlined),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  objectName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _text,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () async {
                                  try {
                                    await ObjectRepository.restoreObject(
                                      name: objectName,
                                    );
                                    if (!sheetContext.mounted) return;
                                    Navigator.pop(sheetContext);
                                    refreshObjectsAndDashboard();
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(this.context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Объект "$objectName" восстановлен',
                                        ),
                                      ),
                                    );
                                  } catch (error) {
                                    if (!sheetContext.mounted) return;
                                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                                      SnackBar(content: Text(error.toString())),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.restore, size: 18),
                                label: const Text('Вернуть'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> showObjectPicker(
    BuildContext context,
    List<String> objects,
  ) async {
    if (!widget.profile.isAdmin) return;
    final selectedValue = widget.selectedObjectName ?? _allObjectsValue;

    final pickedValue = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(18),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.82,
            ),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4CCC2),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Выберите объект',
                        style: TextStyle(
                          color: _text,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Архив объектов',
                      onPressed: () {
                        Navigator.pop(sheetContext, _archiveListValue);
                      },
                      icon: const Icon(Icons.inventory_2_outlined),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.pop(sheetContext, _addObjectValue);
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Объект'),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      _ObjectPickerTile(
                        title: 'Все объекты',
                        subtitle: 'Сводка по всем активным объектам',
                        icon: Icons.apartment_outlined,
                        isSelected: selectedValue == _allObjectsValue,
                        onTap: () {
                          Navigator.pop(sheetContext, _allObjectsValue);
                        },
                      ),
                      ...objects.map((objectName) {
                        return _ObjectPickerTile(
                          title: objectName,
                          subtitle: 'Данные только по этому объекту',
                          icon: Icons.business_outlined,
                          isSelected: objectName == selectedValue,
                          onTap: () => Navigator.pop(sheetContext, objectName),
                          onEdit: () {
                            Navigator.pop(
                              sheetContext,
                              '$_editObjectPrefix$objectName',
                            );
                          },
                          onArchive: () {
                            Navigator.pop(
                              sheetContext,
                              '$_archiveObjectPrefix$objectName',
                            );
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!context.mounted || pickedValue == null) return;
    if (pickedValue == _archiveListValue) {
      await showArchivedObjectsSheet(context);
      return;
    }
    if (pickedValue == _addObjectValue) {
      await handleAddObject();
      return;
    }
    if (pickedValue.startsWith(_editObjectPrefix)) {
      await handleRenameObject(
        pickedValue.substring(_editObjectPrefix.length),
      );
      return;
    }
    if (pickedValue.startsWith(_archiveObjectPrefix)) {
      await handleArchiveObject(
        pickedValue.substring(_archiveObjectPrefix.length),
      );
      return;
    }
    if (pickedValue == _allObjectsValue) {
      widget.onObjectChanged(null);
      return;
    }
    widget.onObjectChanged(pickedValue);
  }
}
