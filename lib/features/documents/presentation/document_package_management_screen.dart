import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/document_template_repository.dart';
import '../data/document_workflow_repository.dart';
import '../models/document_onboarding.dart';
import '../models/document_template.dart';

class DocumentPackageManagementScreen extends StatefulWidget {
  final AppUserProfile profile;

  const DocumentPackageManagementScreen({
    super.key,
    required this.profile,
  });

  @override
  State<DocumentPackageManagementScreen> createState() =>
      _DocumentPackageManagementScreenState();
}

class _DocumentPackageManagementScreenState
    extends State<DocumentPackageManagementScreen> {
  late Future<_PackageData> future;
  bool seeding = false;

  String get companyId => widget.profile.activeCompanyId;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<_PackageData> load() async {
    final values = await Future.wait<dynamic>(<Future<dynamic>>[
      DocumentWorkflowRepository.fetchAccess(),
      DocumentWorkflowRepository.fetchPackages(companyId),
      DocumentTemplateRepository.fetchTemplates(companyId: companyId),
      DocumentWorkflowRepository.fetchPackageTemplateLinks(
        companyId: companyId,
      ),
    ]);
    final access = values[0] as DocumentWorkflowAccess;
    if (!access.canView) {
      throw StateError('Нет доступа к пакетам документооборота');
    }
    final templates = (values[2] as List<DocumentTemplateRecord>)
        .where((item) => item.isActive && item.currentVersion != null)
        .toList(growable: false);
    return _PackageData(
      access: access,
      packages: values[1] as List<DocumentPackageRecord>,
      templates: templates,
      links: values[3] as List<DocumentPackageTemplateLink>,
    );
  }

  Future<void> refresh() async {
    setState(() => future = load());
    await future;
  }

  Future<void> seedDefaults() async {
    if (seeding) return;
    setState(() => seeding = true);
    try {
      await DocumentWorkflowRepository.seedDefaultPackages(companyId);
      await refresh();
      _message('Базовые пакеты обновлены');
    } catch (error) {
      _message(_cleanError(error));
    } finally {
      if (mounted) setState(() => seeding = false);
    }
  }

  Future<void> edit({
    DocumentPackageRecord? package,
    required _PackageData data,
  }) async {
    if (!data.access.canManagePackages) return;
    final title = TextEditingController(text: package?.title ?? '');
    final description = TextEditingController(text: package?.description ?? '');
    var onboardingType = package?.onboardingType ?? 'gph';
    final selected = <String>{};
    final required = <String>{};
    if (package != null) {
      for (final link in data.links) {
        if (link.packageId != package.id) continue;
        selected.add(link.templateId);
        if (link.isRequired) required.add(link.templateId);
      }
    }
    final result = await showDialog<_PackageDraft>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(package == null ? 'Новый пакет' : 'Редактирование пакета'),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(
                      labelText: 'Название пакета',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: description,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Описание',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: onboardingType,
                    decoration: const InputDecoration(
                      labelText: 'Сценарий оформления',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'employment',
                        child: Text('Трудовой договор'),
                      ),
                      DropdownMenuItem(
                        value: 'gph',
                        child: Text('ГПХ / оказание услуг'),
                      ),
                      DropdownMenuItem(
                        value: 'transfer',
                        child: Text('Перевод / изменение условий'),
                      ),
                      DropdownMenuItem(
                        value: 'termination',
                        child: Text('Увольнение'),
                      ),
                      DropdownMenuItem(
                        value: 'custom',
                        child: Text('Пользовательский'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => onboardingType = value);
                      }
                    },
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Утверждённые шаблоны пакета',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (data.templates.isEmpty)
                    const Text(
                      'Нет утверждённых шаблонов с активной версией. '
                      'Сначала опубликуйте шаблон.',
                    )
                  else
                    for (final template in data.templates)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: selected.contains(template.id),
                        title: Text(template.title),
                        subtitle: Text(
                          '${template.category} · '
                          'v${template.currentVersion!.versionNo}',
                        ),
                        onChanged: (value) {
                          setDialogState(() {
                            if (value == true) {
                              selected.add(template.id);
                              required.add(template.id);
                            } else {
                              selected.remove(template.id);
                              required.remove(template.id);
                            }
                          });
                        },
                        secondary: selected.contains(template.id)
                            ? IconButton(
                                tooltip: required.contains(template.id)
                                    ? 'Обязательный документ'
                                    : 'Необязательный документ',
                                onPressed: () {
                                  setDialogState(() {
                                    if (!required.add(template.id)) {
                                      required.remove(template.id);
                                    }
                                  });
                                },
                                icon: Icon(
                                  required.contains(template.id)
                                      ? Icons.lock_rounded
                                      : Icons.lock_open_rounded,
                                ),
                              )
                            : null,
                      ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final cleanTitle = title.text.trim();
                if (cleanTitle.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Введите название пакета')),
                  );
                  return;
                }
                Navigator.pop(
                  context,
                  _PackageDraft(
                    title: cleanTitle,
                    description: description.text.trim(),
                    onboardingType: onboardingType,
                    templates: <({String templateId, bool required})>[
                      for (final template in data.templates)
                        if (selected.contains(template.id))
                          (
                            templateId: template.id,
                            required: required.contains(template.id),
                          ),
                    ],
                  ),
                );
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    title.dispose();
    description.dispose();
    if (result == null || !mounted) return;
    try {
      final saved = await DocumentWorkflowRepository.savePackage(
        id: package?.id,
        companyId: companyId,
        title: result.title,
        description: result.description,
        onboardingType: result.onboardingType,
      );
      await DocumentWorkflowRepository.replacePackageTemplates(
        companyId: companyId,
        packageId: saved.id,
        templates: result.templates,
      );
      await refresh();
      _message('Пакет сохранён');
    } catch (error) {
      _message(_cleanError(error));
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Пакеты документов',
      subtitle: 'Готовые наборы для HR',
      child: FutureBuilder<_PackageData>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(_cleanError(snapshot.error)));
          }
          final data = snapshot.requireData;
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (data.access.canManagePackages)
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: () => edit(data: data),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Создать пакет'),
                      ),
                      OutlinedButton.icon(
                        onPressed: seeding ? null : seedDefaults,
                        icon: seeding
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_awesome_outlined),
                        label: const Text('Обновить базовые пакеты'),
                      ),
                    ],
                  )
                else
                  const PremiumWorkCard(
                    radius: 24,
                    child: Text(
                      'Доступен просмотр пакетов. Изменение требует разрешения '
                      '«Пакеты документов».',
                    ),
                  ),
                const SizedBox(height: 16),
                if (data.packages.isEmpty)
                  const PremiumWorkCard(
                    radius: 24,
                    child: Text(
                      'Пакетов пока нет. Пользователь с правом управления '
                      'может создать набор или добавить базовые пакеты.',
                    ),
                  )
                else
                  for (final package in data.packages)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: PremiumWorkCard(
                        radius: 23,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            child: Icon(Icons.inventory_2_outlined),
                          ),
                          title: Text(
                            package.title,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          subtitle: Text(
                            '${_typeTitle(package.onboardingType)} · '
                            '${_templateCount(data.links, package.id)} шабл.\n'
                            '${package.description}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: data.access.canManagePackages
                              ? const Icon(Icons.edit_outlined)
                              : const Icon(Icons.chevron_right_rounded),
                          onTap: data.access.canManagePackages
                              ? () => edit(package: package, data: data)
                              : null,
                        ),
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PackageData {
  final DocumentWorkflowAccess access;
  final List<DocumentPackageRecord> packages;
  final List<DocumentTemplateRecord> templates;
  final List<DocumentPackageTemplateLink> links;

  const _PackageData({
    required this.access,
    required this.packages,
    required this.templates,
    required this.links,
  });
}

class _PackageDraft {
  final String title;
  final String description;
  final String onboardingType;
  final List<({String templateId, bool required})> templates;

  const _PackageDraft({
    required this.title,
    required this.description,
    required this.onboardingType,
    required this.templates,
  });
}

int _templateCount(List<DocumentPackageTemplateLink> links, String packageId) {
  return links.where((item) => item.packageId == packageId).length;
}

String _typeTitle(String value) => switch (value) {
      'employment' => 'Трудовой договор',
      'gph' => 'ГПХ / оказание услуг',
      'transfer' => 'Перевод / изменение условий',
      'termination' => 'Увольнение',
      'custom' => 'Пользовательский пакет',
      _ => value,
    };

String _cleanError(Object? value) {
  final text = value?.toString() ?? 'Неизвестная ошибка';
  return text.replaceFirst('Exception: ', '').replaceFirst('Bad state: ', '');
}
