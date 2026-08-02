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

  String get companyId => widget.profile.activeCompanyId;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<_PackageData> load() async {
    final values = await Future.wait<dynamic>([
      DocumentWorkflowRepository.fetchPackages(companyId),
      DocumentTemplateRepository.fetchTemplates(companyId: companyId),
    ]);
    return _PackageData(
      packages: values[0] as List<DocumentPackageRecord>,
      templates: values[1] as List<DocumentTemplateRecord>,
    );
  }

  Future<void> refresh() async {
    setState(() => future = load());
    await future;
  }

  Future<void> edit({
    DocumentPackageRecord? package,
    required List<DocumentTemplateRecord> templates,
  }) async {
    final title = TextEditingController(text: package?.title ?? '');
    final description = TextEditingController(text: package?.description ?? '');
    var onboardingType = package?.onboardingType ?? 'custom';
    final selected = <String>{};
    final required = <String>{};
    final result = await showDialog<_PackageDraft>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(package == null ? 'Новый пакет' : 'Редактирование пакета'),
          content: SizedBox(
            width: 620,
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
                      DropdownMenuItem(value: 'employment', child: Text('Трудовой договор')),
                      DropdownMenuItem(value: 'gph', child: Text('ГПХ / оказание услуг')),
                      DropdownMenuItem(value: 'transfer', child: Text('Перевод / изменение условий')),
                      DropdownMenuItem(value: 'termination', child: Text('Увольнение')),
                      DropdownMenuItem(value: 'custom', child: Text('Пользовательский')),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => onboardingType = value);
                    },
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Шаблоны пакета',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (templates.isEmpty)
                    const Text('Сначала создайте или подключите шаблоны документов.')
                  else
                    for (final template in templates)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: selected.contains(template.id),
                        title: Text(template.title),
                        subtitle: Text(
                          template.currentVersion == null
                              ? 'Нет активной версии'
                              : 'Версия ${template.currentVersion!.versionNo}',
                        ),
                        onChanged: template.currentVersion == null
                            ? null
                            : (value) {
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
              onPressed: () => Navigator.pop(
                context,
                _PackageDraft(
                  title: title.text,
                  description: description.text,
                  onboardingType: onboardingType,
                  templates: [
                    for (final id in selected)
                      (templateId: id, required: required.contains(id)),
                  ],
                ),
              ),
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
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_cleanError(error))),
      );
    }
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () => edit(templates: data.templates),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Создать пакет'),
                  ),
                ),
                const SizedBox(height: 16),
                if (data.packages.isEmpty)
                  const PremiumWorkCard(
                    radius: 24,
                    child: Text(
                      'Пакетов пока нет. Создайте набор документов или добавьте базовые пакеты на главной инструмента.',
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
                            '${_typeTitle(package.onboardingType)}\n${package.description}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.edit_outlined),
                          onTap: () => edit(
                            package: package,
                            templates: data.templates,
                          ),
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
  final List<DocumentPackageRecord> packages;
  final List<DocumentTemplateRecord> templates;

  const _PackageData({required this.packages, required this.templates});
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
