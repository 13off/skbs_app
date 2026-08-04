import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../widgets/premium_ui.dart';
import '../data/document_template_online_editor.dart';
import '../models/document_template.dart';

class DocumentTemplateOnlineEditorScreen extends StatefulWidget {
  final DocumentTemplateRecord template;
  final DocumentTemplateVersion version;
  final String companyId;
  final bool canApprove;

  const DocumentTemplateOnlineEditorScreen({
    super.key,
    required this.template,
    required this.version,
    required this.companyId,
    required this.canApprove,
  });

  @override
  State<DocumentTemplateOnlineEditorScreen> createState() =>
      _DocumentTemplateOnlineEditorScreenState();
}

class _DocumentTemplateOnlineEditorScreenState
    extends State<DocumentTemplateOnlineEditorScreen> {
  late final Future<DocumentTemplateOnlineDraft> future;
  final Map<String, TextEditingController> controllers = {};
  bool saving = false;

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<DocumentTemplateOnlineDraft> _load() async {
    final draft = await DocumentTemplateOnlineEditor.load(widget.version);
    for (final block in draft.blocks) {
      if (!block.isProtected) {
        controllers[block.id] = TextEditingController(text: block.text);
      }
    }
    return draft;
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int _changedCount(DocumentTemplateOnlineDraft draft) {
    return draft.blocks.where((block) {
      if (block.isProtected) return false;
      final current = controllers[block.id]?.text.trim() ?? block.text;
      return current != block.text;
    }).length;
  }

  List<Widget> _documentBlocks(DocumentTemplateOnlineDraft draft) {
    final widgets = <Widget>[];
    String? activeSection;
    for (var index = 0; index < draft.blocks.length; index++) {
      final block = draft.blocks[index];
      if (block.sectionTitle != activeSection) {
        activeSection = block.sectionTitle;
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 9),
            child: Text(
              activeSection,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
        );
      }
      widgets.add(
        _EditorBlock(
          index: index + 1,
          block: block,
          controller: controllers[block.id],
          onChanged: () => setState(() {}),
        ),
      );
      widgets.add(const SizedBox(height: 10));
    }
    return widgets;
  }

  Future<void> _save(DocumentTemplateOnlineDraft draft) async {
    if (saving) return;
    final notesController = TextEditingController(
      text: 'Изменено в онлайн-редакторе AppСтрой',
    );
    var approve = widget.canApprove;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  4,
                  20,
                  20 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Сохранить новую версию',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Исходный DOCX не меняется. AppСтрой создаёт отдельную '
                      'версию и сохраняет таблицы, стили и защищённые поля.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Комментарий к версии',
                      ),
                    ),
                    if (widget.canApprove) ...[
                      const SizedBox(height: 10),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: approve,
                        onChanged: (value) =>
                            setSheetState(() => approve = value),
                        title: const Text(
                          'Сразу сделать действующей',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: const Text(
                          'Отключите, если версию сначала должен проверить юрист.',
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Создать новую версию'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    final notes = notesController.text;
    notesController.dispose();
    if (confirmed != true || !mounted) return;

    setState(() => saving = true);
    try {
      await DocumentTemplateOnlineEditor.saveVersion(
        template: widget.template,
        sourceVersion: widget.version,
        companyId: widget.companyId,
        draft: draft,
        values: {
          for (final entry in controllers.entries) entry.key: entry.value.text,
        },
        approve: approve && widget.canApprove,
        notes: notes,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_cleanError(error))));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Редактор шаблона'),
      ),
      body: PremiumWorkBackdrop(
        child: FutureBuilder<DocumentTemplateOnlineDraft>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _UnavailableEditor(message: _cleanError(snapshot.error));
            }

            final draft = snapshot.requireData;
            final changes = _changedCount(draft);
            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
                    children: [
                      Text(
                        widget.template.title,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Меняйте текст прямо в AppСтрой. Системные поля, '
                        'маркеры автозаполнения и служебные элементы Word '
                        'защищены замком.',
                        style: TextStyle(height: 1.45),
                      ),
                      const SizedBox(height: 14),
                      PremiumWorkCard(
                        radius: 22,
                        padding: const EdgeInsets.all(16),
                        child: Wrap(
                          spacing: 18,
                          runSpacing: 10,
                          children: [
                            _Counter(
                              icon: Icons.edit_note_outlined,
                              label: 'Можно редактировать',
                              value: draft.editableCount,
                            ),
                            _Counter(
                              icon: Icons.lock_outline_rounded,
                              label: 'Защищено',
                              value: draft.protectedCount,
                            ),
                            _Counter(
                              icon: Icons.change_circle_outlined,
                              label: 'Изменено',
                              value: changes,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      ..._documentBlocks(draft),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(
                        top: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: saving || changes == 0
                            ? null
                            : () => _save(draft),
                        icon: saving
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          changes == 0
                              ? 'Измените текст, чтобы создать версию'
                              : 'Сохранить новую версию ($changes)',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _UnavailableEditor extends StatelessWidget {
  final String message;

  const _UnavailableEditor({required this.message});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        PremiumWorkCard(
          radius: 24,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 50,
                color: AppAdaptivePalette.warning,
              ),
              const SizedBox(height: 14),
              const Text(
                'Этот исходник пока нельзя редактировать онлайн',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 9),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.45),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EditorBlock extends StatelessWidget {
  final int index;
  final DocumentTemplateEditableBlock block;
  final TextEditingController? controller;
  final VoidCallback onChanged;

  const _EditorBlock({
    required this.index,
    required this.block,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (block.isProtected) {
      return Tooltip(
        message: block.protectionReason,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: .72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_rounded, size: 20),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      block.text,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      block.protectionReason,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return TextField(
      controller: controller,
      minLines: block.text.length > 130 ? 3 : 1,
      maxLines: 8,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: 'Блок $index',
        alignLabelWithHint: true,
        prefixIcon: const Icon(Icons.edit_outlined),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;

  const _Counter({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 7),
        Text(
          '$label: $value',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

String _cleanError(Object? error) {
  return (error?.toString() ?? 'Неизвестная ошибка')
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '')
      .trim();
}
