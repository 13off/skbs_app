import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_adaptive_palette.dart';

import '../../../data/app_data_sync.dart';
import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/recruitment_repository.dart';
import '../models/recruitment_models.dart';

Color get _archiveText => AppAdaptivePalette.textPrimary;
Color get _archiveMuted => AppAdaptivePalette.textMuted;
Color get _archiveDanger => AppAdaptivePalette.danger;
Color get _archiveSoft => AppAdaptivePalette.surfaceSoft;

class RecruitmentArchiveScreen extends StatefulWidget {
  final AppUserProfile profile;

  const RecruitmentArchiveScreen({super.key, required this.profile});

  @override
  State<RecruitmentArchiveScreen> createState() =>
      _RecruitmentArchiveScreenState();
}

class _RecruitmentArchiveScreenState extends State<RecruitmentArchiveScreen> {
  final TextEditingController searchController = TextEditingController();
  late Future<List<RecruitmentApplication>> future;
  StreamSubscription<AppDataChange>? changesSubscription;
  final Set<String> busyIds = <String>{};

  @override
  void initState() {
    super.initState();
    future = load();
    searchController.addListener(handleSearchChanged);
    changesSubscription = AppDataSync.changes.listen((change) {
      if (change.affects(AppDataDomain.recruitment) && mounted) refresh();
    });
  }

  @override
  void dispose() {
    changesSubscription?.cancel();
    searchController
      ..removeListener(handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void handleSearchChanged() {
    if (mounted) setState(() {});
  }

  Future<List<RecruitmentApplication>> load() {
    return RecruitmentRepository.fetchApplications(
      companyId: widget.profile.activeCompanyId,
      archived: true,
    );
  }

  Future<void> refresh() async {
    final next = load();
    if (mounted) setState(() => future = next);
    await next;
  }

  List<RecruitmentApplication> visible(
    List<RecruitmentApplication> applications,
  ) {
    final query = searchController.text.trim().toLowerCase();
    if (query.isEmpty) return applications;
    return applications.where((application) {
      return <String>[
        application.fullName,
        application.phone,
        application.vacancy,
        application.objectName,
        application.citizenship,
        application.statusTitle,
        application.comment,
      ].join(' ').toLowerCase().contains(query);
    }).toList();
  }

  String formatDate(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day.$month.${local.year}';
  }

  Future<void> restore(RecruitmentApplication application) async {
    if (busyIds.contains(application.id)) return;
    setState(() => busyIds.add(application.id));
    try {
      await RecruitmentRepository.restoreApplication(
        companyId: widget.profile.activeCompanyId,
        applicationId: application.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${application.fullName} восстановлен из архива'),
        ),
      );
      await refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось восстановить заявку: $error')),
      );
    } finally {
      if (mounted) setState(() => busyIds.remove(application.id));
    }
  }

  Future<bool> confirmDelete(RecruitmentApplication application) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Удалить заявку навсегда?'),
            content: Text(
              'Заявка «${application.fullName}» будет удалена вместе с прикреплёнными документами и историей. Восстановить её будет невозможно.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _archiveDanger),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Удалить навсегда'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> deletePermanently(RecruitmentApplication application) async {
    if (busyIds.contains(application.id)) return;
    if (!await confirmDelete(application)) return;
    if (!mounted) return;

    setState(() => busyIds.add(application.id));
    try {
      await RecruitmentRepository.deleteApplication(
        companyId: widget.profile.activeCompanyId,
        applicationId: application.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Заявка ${application.fullName} удалена')),
      );
      await refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось удалить заявку: $error')),
      );
    } finally {
      if (mounted) setState(() => busyIds.remove(application.id));
    }
  }

  Widget infoPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _archiveSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _archiveMuted),
          SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: _archiveMuted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget applicationCard(RecruitmentApplication application) {
    final isBusy = busyIds.contains(application.id);
    final archivedAt = application.archivedAt;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumWorkCard(
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
                    color: _archiveSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: _archiveMuted,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        application.fullName,
                        style: TextStyle(
                          color: _archiveText,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        <String>[
                          if (application.vacancy.isNotEmpty)
                            application.vacancy,
                          if (application.objectName.isNotEmpty)
                            application.objectName,
                        ].join(' • '),
                        style: TextStyle(
                          color: _archiveMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                if (archivedAt != null)
                  Text(
                    formatDate(archivedAt),
                    style: TextStyle(
                      color: _archiveMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                infoPill(Icons.flag_outlined, application.statusTitle),
                infoPill(Icons.send_outlined, application.sourceTitle),
                if (application.phone.isNotEmpty)
                  infoPill(Icons.phone_outlined, application.phone),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : () => restore(application),
                    icon: Icon(Icons.restore_rounded),
                    label: const Text('Восстановить'),
                  ),
                ),
                SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: 'Удалить навсегда',
                  onPressed: isBusy
                      ? null
                      : () => deletePermanently(application),
                  icon: isBusy
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.delete_forever_outlined),
                  color: _archiveDanger,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Архив заявок',
      showBackButton: true,
      subtitle: '',
      headerTrailing: IconButton.filledTonal(
        tooltip: 'Назад к заявкам',
        onPressed: () => Navigator.pop(context),
        icon: Icon(Icons.close_rounded),
      ),
      child: FutureBuilder<List<RecruitmentApplication>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 90),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return PremiumWorkCard(
              radius: 24,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.error_outline_rounded, size: 40),
                  SizedBox(height: 10),
                  Text(
                    'Не удалось загрузить архив',
                    style: TextStyle(
                      color: _archiveText,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _archiveMuted),
                  ),
                  SizedBox(height: 14),
                  FilledButton(
                    onPressed: refresh,
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }

          final applications =
              snapshot.data ?? const <RecruitmentApplication>[];
          final filtered = visible(applications);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Найти заявку в архиве',
                  prefixIcon: Icon(Icons.search_rounded),
                  suffixIcon: searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: searchController.clear,
                          icon: Icon(Icons.close_rounded),
                        ),
                ),
              ),
              SizedBox(height: 16),
              if (filtered.isEmpty)
                PremiumWorkCard(
                  radius: 24,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 42,
                        color: _archiveMuted,
                      ),
                      SizedBox(height: 10),
                      Text(
                        applications.isEmpty
                            ? 'Архив пуст'
                            : 'Ничего не найдено',
                        style: TextStyle(
                          color: _archiveText,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        applications.isEmpty
                            ? 'Здесь появятся заявки, которые вы уберёте из рабочего списка.'
                            : 'Измените поисковый запрос.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _archiveMuted,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...filtered.map(applicationCard),
            ],
          );
        },
      ),
    );
  }
}
