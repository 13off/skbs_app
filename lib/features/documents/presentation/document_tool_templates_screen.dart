import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';
import '../../../app/app_theme.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/premium_ui.dart';
import '../data/document_template_repository.dart';
import '../models/document_template.dart';
import 'document_template_online_editor_screen.dart';
import '../../../navigation/app_page_route.dart';

class DocumentToolTemplatesScreen extends StatefulWidget {
  final AppUserProfile profile;

  const DocumentToolTemplatesScreen({super.key, required this.profile});

  @override
  State<DocumentToolTemplatesScreen> createState() =>
      _DocumentToolTemplatesScreenState();
}

class _DocumentToolTemplatesScreenState
    extends State<DocumentToolTemplatesScreen> {
  final TextEditingController searchController = TextEditingController();
  List<DocumentTemplateRecord> templates = const [];
  bool loading = true;
  String? errorText;

  bool get canManage =>
      widget.profile.isAdmin ||
      widget.profile.isDeveloper ||
      widget.profile.isLawyer ||
      widget.profile.isHr;

  bool get canApprove =>
      widget.profile.isAdmin ||
      widget.profile.isDeveloper ||
      widget.profile.isLawyer;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      errorText = null;
    });
    try {
      final result = await DocumentTemplateRepository.fetchTemplates(
        companyId: widget.profile.activeCompanyId,
      );
      if (!mounted) return;
      setState(() {
        templates = result;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorText = _cleanError(error);
      });
    }
  }

  List<DocumentTemplateRecord> get visibleTemplates {
    final query = searchController.text.trim().toLowerCase();
    if (query.isEmpty) return templates;
    return templates
        .where((template) {
          return <String>[
            template.title,
            template.description,
            template.code,
          ].join(' ').toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  bool canEditOnlineVersion(DocumentTemplateVersion version) {
    final isDocx =
        version.mimeType == DocumentTemplateRepository.docxMime ||
        version.fileName.toLowerCase().endsWith('.docx');
    return isDocx && (version.isAsset || version.isStorage);
  }

  Future<void> editOnline(
    DocumentTemplateRecord template,
    DocumentTemplateVersion version,
  ) async {
    if (!canEditOnlineVersion(version)) {
      await uploadVersion(template, openEditorAfterUpload: true);
      return;
    }
    final changed = await Navigator.of(context).push<bool>(
      AppPageRoute<bool>(
        builder: (_) => DocumentTemplateOnlineEditorScreen(
          template: template,
          version: version,
          companyId: widget.profile.activeCompanyId,
          canApprove: canApprove,
        ),
      ),
    );
    if (changed == true) {
      await load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Новая версия шаблона сохранена')),
      );
    }
  }

  Future<DocumentTemplateRecord?> uploadVersion(
    DocumentTemplateRecord template, {
    bool openEditorAfterUpload = false,
  }) async {
    if (!canManage) return null;
    final notesController = TextEditingController();
    var approve = canApprove;
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
                      'Загрузить DOCX в AppСтрой',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(template.title),
                    const SizedBox(height: 8),
                    Text(
                      'Внешнюю ссылку нельзя безопасно редактировать. '
                      'Выберите сам файл DOCX — он сохранится как новая версия '
                      'в закрытом хранилище компании.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: notesController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Комментарий к версии',
                      ),
                    ),
                    if (canApprove) ...[
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
                      ),
                    ],
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      icon: const Icon(Icons.upload_file_outlined),
                      label: const Text('Выбрать DOCX'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (confirmed != true) {
      notesController.dispose();
      return null;
    }
    final notes = notesController.text;
    notesController.dispose();
    try {
      final result = await DocumentTemplateRepository.uploadNewVersion(
        template: template,
        companyId: widget.profile.activeCompanyId,
        approve: approve && canApprove,
        notes: notes,
      );
      if (!mounted || result == null) return result;
      await load();
      final current = result.currentVersion;
      if (openEditorAfterUpload && current != null && mounted) {
        if (canEditOnlineVersion(current)) {
          await editOnline(result, current);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Файл сохранён, но онлайн-редактор поддерживает только DOCX',
              ),
            ),
          );
        }
      }
      return result;
    } catch (error) {
      if (!mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_cleanError(error))));
      return null;
    }
  }

  Future<void> download(DocumentTemplateVersion version) async {
    try {
      await DocumentTemplateRepository.downloadVersion(version);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_cleanError(error))));
    }
  }

  Future<void> showVersions(DocumentTemplateRecord template) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: .78,
          minChildSize: .45,
          maxChildSize: .94,
          builder: (context, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
              children: [
                Text(
                  template.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text('Каждое изменение сохраняется отдельной версией.'),
                const SizedBox(height: 16),
                if (template.versions.isEmpty)
                  const Text('Версий пока нет')
                else
                  ...template.versions.map((version) {
                    final current = version.id == template.currentVersionId;
                    final editable = canEditOnlineVersion(version);
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: Icon(
                          version.isApproved
                              ? Icons.verified_outlined
                              : Icons.pending_actions_outlined,
                        ),
                        title: Text(
                          'Версия ${version.versionNo}${current ? ' • текущая' : ''}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          '${version.fileName}\n${version.notes.isEmpty ? 'Без комментария' : version.notes}',
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'edit') {
                              Navigator.pop(sheetContext);
                              await editOnline(template, version);
                            } else if (value == 'import') {
                              Navigator.pop(sheetContext);
                              await uploadVersion(
                                template,
                                openEditorAfterUpload: true,
                              );
                            } else if (value == 'download') {
                              await download(version);
                            } else if (value == 'activate') {
                              await DocumentTemplateRepository.setCurrentVersion(
                                template: template,
                                version: version,
                                approve: true,
                              );
                              if (!sheetContext.mounted) return;
                              Navigator.pop(sheetContext);
                              await load();
                            }
                          },
                          itemBuilder: (_) => [
                            if (canManage && editable)
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Редактировать онлайн'),
                              )
                            else if (canManage)
                              const PopupMenuItem(
                                value: 'import',
                                child: Text('Загрузить DOCX в AppСтрой'),
                              ),
                            const PopupMenuItem(
                              value: 'download',
                              child: Text('Скачать'),
                            ),
                            if (canApprove && !template.isGlobal && !current)
                              const PopupMenuItem(
                                value: 'activate',
                                child: Text('Сделать действующей'),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        );
      },
    );
  }

  Widget buildTemplate(DocumentTemplateRecord template) {
    final version = template.currentVersion;
    final active = template.isActive;
    final editable = version != null && canEditOnlineVersion(version);
    final statusColor = active
        ? AppAdaptivePalette.success
        : AppAdaptivePalette.warning;
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.description_outlined, color: statusColor),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${active ? 'Действующий' : 'Требует проверки'} • ${template.isGlobal ? 'базовый' : 'версия компании'}',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (template.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(template.description),
          ],
          const SizedBox(height: 12),
          Text(
            version == null
                ? 'Исходный файл ещё не загружен'
                : editable
                ? 'Версия ${version.versionNo} • ${version.fileName}'
                : 'Подключена внешняя ссылка. Для редактора загрузите DOCX в AppСтрой',
            style: TextStyle(
              color: editable
                  ? AppColors.textMuted
                  : AppAdaptivePalette.warning,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (canManage && editable)
                FilledButton.icon(
                  onPressed: () => editOnline(template, version),
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('Редактировать онлайн'),
                )
              else if (canManage)
                FilledButton.icon(
                  onPressed: () =>
                      uploadVersion(template, openEditorAfterUpload: true),
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Загрузить DOCX в AppСтрой'),
                ),
              if (canManage && editable)
                OutlinedButton.icon(
                  onPressed: () => uploadVersion(template),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Новая версия'),
                ),
              OutlinedButton.icon(
                onPressed: () => showVersions(template),
                icon: const Icon(Icons.history_rounded),
                label: const Text('Версии'),
              ),
              if (version != null)
                IconButton.filledTonal(
                  tooltip: 'Скачать исходник',
                  onPressed: () => download(version),
                  icon: const Icon(Icons.download_outlined),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = visibleTemplates;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Шаблоны'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: loading ? null : load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: PremiumWorkBackdrop(
        child: RefreshIndicator(
          onRefresh: load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
            children: [
              const Text(
                'Шаблоны компании',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              const Text(
                'Онлайн-редактор работает с DOCX, который загружен в закрытое хранилище AppСтрой. Внешние ссылки сначала импортируются как новая версия.',
                style: TextStyle(height: 1.45),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Поиск шаблона',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 16),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(42),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (errorText != null)
                PremiumWorkCard(
                  radius: 22,
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    errorText!,
                    style: TextStyle(color: AppAdaptivePalette.danger),
                  ),
                )
              else if (visible.isEmpty)
                const PremiumWorkCard(
                  radius: 22,
                  padding: EdgeInsets.all(22),
                  child: Text('Шаблоны не найдены'),
                )
              else
                ...visible.map(
                  (template) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: buildTemplate(template),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _cleanError(Object error) {
  return error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '')
      .trim();
}
