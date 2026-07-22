import 'package:flutter/material.dart';

import '../app/app_theme.dart';
import '../features/documents/data/document_template_repository.dart';
import '../features/documents/models/document_template.dart';
import '../models/app_user_profile.dart';
import '../widgets/premium_ui.dart';

class TemplateDocumentsScreen extends StatefulWidget {
  final AppUserProfile profile;

  const TemplateDocumentsScreen({super.key, required this.profile});

  @override
  State<TemplateDocumentsScreen> createState() =>
      _TemplateDocumentsScreenState();
}

class _TemplateDocumentsScreenState extends State<TemplateDocumentsScreen> {
  final TextEditingController searchController = TextEditingController();
  List<DocumentTemplateRecord> templates = const <DocumentTemplateRecord>[];
  bool loading = true;
  String? errorText;
  String categoryFilter = 'all';

  bool get canManage =>
      widget.profile.isAdmin ||
      widget.profile.isHr ||
      widget.profile.isDeveloper;

  bool get canApprove => widget.profile.isAdmin || widget.profile.isDeveloper;

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
        errorText = error.toString().replaceFirst('Exception: ', '').trim();
      });
    }
  }

  List<DocumentTemplateRecord> get visibleTemplates {
    final query = searchController.text.trim().toLowerCase();
    return templates
        .where((template) {
          if (categoryFilter != 'all' && template.category != categoryFilter) {
            return false;
          }
          if (query.isEmpty) return true;
          return <String>[
            template.title,
            template.description,
            template.code,
            template.categoryTitle,
          ].join(' ').toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  Set<String> get categories =>
      templates.map((template) => template.category).toSet();

  String statusTitle(DocumentTemplateRecord template) {
    if (template.status == 'active') return 'Действующий';
    if (template.status == 'archived') return 'Архив';
    return 'Требует проверки';
  }

  Color statusColor(DocumentTemplateRecord template) {
    if (template.status == 'active') return const Color(0xFF28704E);
    if (template.status == 'archived') return AppColors.textMuted;
    return const Color(0xFF8A6120);
  }

  Future<void> download(DocumentTemplateVersion version) async {
    try {
      await DocumentTemplateRepository.downloadVersion(version);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть шаблон: $error')),
      );
    }
  }

  Future<void> uploadVersion(DocumentTemplateRecord template) async {
    if (!canManage) return;
    final notesController = TextEditingController();
    var approve = canApprove;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: EdgeInsets.fromLTRB(
                  18,
                  18,
                  18,
                  18 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Новая версия шаблона',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(template.title),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Комментарий к версии',
                        hintText: 'Что изменилось и кто утвердил форму',
                      ),
                    ),
                    if (canApprove) ...[
                      const SizedBox(height: 12),
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
                          'Форма должна быть проверена ответственным лицом.',
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(sheetContext, true),
                        icon: const Icon(Icons.upload_file_outlined),
                        label: const Text('Выбрать DOCX или ODT'),
                      ),
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
      return;
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
      if (!mounted || result == null) return;
      await load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve && canApprove
                ? 'Новая версия загружена и активирована'
                : 'Новая версия загружена на проверку',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки шаблона: $error')),
      );
    }
  }

  Future<void> showVersions(DocumentTemplateRecord template) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: .72,
          minChildSize: .42,
          maxChildSize: .92,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    template.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('История версий исходного файла'),
                  const SizedBox(height: 16),
                  if (template.versions.isEmpty)
                    const Text('Файл ещё не загружен')
                  else
                    ...template.versions.map((version) {
                      final isCurrent = version.id == template.currentVersionId;
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
                            'Версия ${version.versionNo}${isCurrent ? ' • текущая' : ''}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: Text(
                            '${version.fileName}\n${version.notes.isEmpty ? 'Без комментария' : version.notes}'
                            '${version.supportsAutoFill ? '\nПоля автозаполнения: ${version.contentControls.join(', ')}' : ''}',
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'download') {
                                await download(version);
                              } else if (value == 'activate') {
                                try {
                                  await DocumentTemplateRepository.setCurrentVersion(
                                    template: template,
                                    version: version,
                                    approve: true,
                                  );
                                  if (!mounted) return;
                                  Navigator.pop(sheetContext);
                                  await load();
                                } catch (error) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Ошибка активации: $error'),
                                    ),
                                  );
                                }
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'download',
                                child: Text('Скачать исходник'),
                              ),
                              if (canApprove &&
                                  !template.isGlobal &&
                                  !isCurrent)
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
              ),
            );
          },
        );
      },
    );
  }

  Widget buildTemplate(DocumentTemplateRecord template) {
    final version = template.currentVersion;
    final color = statusColor(template);
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
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.description_outlined, color: color),
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
                      '${statusTitle(template)} • ${template.isGlobal ? 'встроенный' : 'версия компании'}',
                      style: TextStyle(
                        color: color,
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
          if (version != null)
            Text(
              'Версия ${version.versionNo} • ${version.fileName}'
              '${version.supportsAutoFill ? ' • автозаполнение готово' : ''}',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            const Text(
              'Утверждённый исходный файл отсутствует',
              style: TextStyle(
                color: Color(0xFF874540),
                fontWeight: FontWeight.w800,
              ),
            ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (version != null)
                FilledButton.tonalIcon(
                  onPressed: () => download(version),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Скачать исходник'),
                ),
              OutlinedButton.icon(
                onPressed: () => showVersions(template),
                icon: const Icon(Icons.history),
                label: const Text('Версии'),
              ),
              if (canManage)
                OutlinedButton.icon(
                  onPressed: () => uploadVersion(template),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Новая версия'),
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
        title: const Text('Шаблоны документов'),
        actions: [
          IconButton(
            onPressed: loading ? null : load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: PremiumWorkBackdrop(
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
              children: [
                const Text(
                  'Исходные формы и версии',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Действующие формы скачиваются без изменения верстки. Новые DOCX/ODT проходят проверку и сохраняются отдельной версией.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Поиск шаблона',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: categoryFilter,
                  decoration: const InputDecoration(labelText: 'Раздел'),
                  items: [
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text('Все разделы'),
                    ),
                    ...categories.map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(
                          templates
                              .firstWhere((item) => item.category == category)
                              .categoryTitle,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => categoryFilter = value ?? 'all'),
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
                      'Не удалось загрузить каталог: $errorText',
                      style: const TextStyle(color: Color(0xFF874540)),
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
      ),
    );
  }
}
