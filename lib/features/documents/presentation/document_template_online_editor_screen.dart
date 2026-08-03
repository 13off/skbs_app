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
  late Future<DocumentTemplateOnlineDraft> future;
  final Map<String, TextEditingController> controllers = {};
  bool saving = false;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<DocumentTemplateOnlineDraft> load() async {
    final draft = await DocumentTemplateOnlineEditor.load(widget.version);
    for (final block in draft.blocks) {
      if (block.isProtected) continue;
      controllers[block.id] = TextEditingController(text: block.text);
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

  int changedCount(DocumentTemplateOnlineDraft draft) {
    return draft.blocks.where((block) {
      if (block.isProtected) return false;
      return (controllers[block.id]?.text.trim() ?? block.text) != block.text;
    }).length;
  }

  Future<void> save(DocumentTemplateOnlineDraft draft) async {
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
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Исходный DOCX не изменится. AppСтрой создаст отдельную версию с сохранением таблиц, стилей и защищённых системных полей.',
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
                          'Отключите, чтобы юрист или администратор сначала проверил версию.',
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
      final values = <String, String>{
        for (final entry in controllers.entries) entry.key: entry.value.text,
      };
      await DocumentTemplateOnlineEditor.saveVersion(
        template: widget.template,
        sourceVersion: widget.version,
        companyId: widget.companyId,
        draft: draft,
        values: values,
        approve: approve && widget.canApprove,
        notes: notes,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Bad state: ', '').replaceFirst('Exception: ', ''),
          ),
        ),
      );
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
              final message = snapshot.error
                  .toString()
                  .replaceFirst('Bad state: ', '')
                  .replaceFirst('Exception: ', '');
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

            final draft = snapshot.requireData;
            String? previousSection;
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
                        'Редактируйте текст прямо в AppСтрой. Системные поля, маркеры автозаполнения и служебные элементы Word защищены замком.',
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
                              valueBuilder: () => changedCount(draft),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      for (var index = 0; index < draft.blocks.length; index++) ...[
                        if (draft.blocks[index].sectionTitle != previousSection) ...[
                          Builder(
                            builder: (_) {
                              previousSection = draft.blocks[index].sectionTitle;
                              return Padding(
                                padding: const EdgeInsets.only(top: 10, bottom: 9),
                                child: Text(
                                  draft.blocks[index].sectionTitle,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                        _EditorBlock(
                          index: index + 1,
                          block: draft.blocks[index],
                          controller: controllers[draft.blocks[index].id],
                          onChanged: () => setState(() {}),
                        ),
                        const SizedBox(height: 10),
                      ],
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
                        onPressed: saving || changedCount(draft) == 0
                            ? null
                            : () => save(draft),
                        icon: saving
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          changedCount(draft) == 0
                              ? 'Измените текст, чтобы создать версию'
                              : 'Сохранить новую версию (${changedCount(draft)})',
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
  final int? value;
  final int Function()? valueBuilder;

  const _Counter({
    required this.icon,
    required this.label,
    this.value,
    this.valueBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final currentValue = valueBuilder?.call() ?? value ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 7),
        Text(
          '$label: $currentValue',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}