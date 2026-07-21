import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';

import '../../../models/app_user_profile.dart';
import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui_v2.dart';
import '../data/employee_mobilization_repository.dart';
import '../models/employee_mobilization_models.dart';

class RecruitmentMobilizationScreen extends StatefulWidget {
  final AppUserProfile profile;

  const RecruitmentMobilizationScreen({super.key, required this.profile});

  @override
  State<RecruitmentMobilizationScreen> createState() =>
      _RecruitmentMobilizationScreenState();
}

class _RecruitmentMobilizationScreenState
    extends State<RecruitmentMobilizationScreen> {
  late Future<List<EmployeeMobilizationEntry>> future;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<List<EmployeeMobilizationEntry>> load() {
    return EmployeeMobilizationRepository.fetchEntries(
      companyId: widget.profile.activeCompanyId,
    );
  }

  void refresh() => setState(() => future = load());

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Выход на объект',
      subtitle: 'Билеты, проживание, допуски, экипировка и табель',
      headerTrailing: IconButton.filledTonal(
        tooltip: 'Обновить',
        onPressed: refresh,
        icon: const Icon(Icons.refresh_rounded),
      ),
      child: FutureBuilder<List<EmployeeMobilizationEntry>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _MobilizationMessage(
              icon: Icons.error_outline_rounded,
              text: 'Не удалось загрузить выходы: ${snapshot.error}',
            );
          }
          final entries = snapshot.data ?? const <EmployeeMobilizationEntry>[];
          if (entries.isEmpty) {
            return const _MobilizationMessage(
              icon: Icons.flight_takeoff_outlined,
              text:
                  'Нет сотрудников для выхода. Сначала создай и свяжи сотрудника во вкладке «Оформление».',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _MobilizationMessage(
                icon: Icons.info_outline_rounded,
                text:
                    'После закрытия всех пунктов сотрудник активируется на выбранном объекте, появляется в действующем списке табеля, а прораб и бухгалтер получают уведомления.',
              ),
              const SizedBox(height: 14),
              ...entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: PremiumPressable(
                    onTap: () async {
                      await Navigator.of(context).push<void>(
                        CupertinoPageRoute<void>(
                          builder: (_) => EmployeeMobilizationDetailScreen(
                            entry: entry,
                          ),
                        ),
                      );
                      refresh();
                    },
                    borderRadius: BorderRadius.circular(22),
                    child: PremiumWorkCard(
                      radius: 22,
                      padding: const EdgeInsets.all(15),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: entry.mobilization.isCompleted
                                  ? const Color(0xFFE7F4EC)
                                  : const Color(0xFFFFF3DE),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(
                              entry.mobilization.isCompleted
                                  ? Icons.verified_outlined
                                  : Icons.flight_takeoff_outlined,
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.candidate.fullName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${entry.candidate.positionTitle} · ${entry.candidate.objectName}',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '${entry.mobilization.statusTitle} · '
                                  '${entry.mobilization.completedSteps}/8 пунктов',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class EmployeeMobilizationDetailScreen extends StatefulWidget {
  final EmployeeMobilizationEntry entry;

  const EmployeeMobilizationDetailScreen({super.key, required this.entry});

  @override
  State<EmployeeMobilizationDetailScreen> createState() =>
      _EmployeeMobilizationDetailScreenState();
}

class _EmployeeMobilizationDetailScreenState
    extends State<EmployeeMobilizationDetailScreen> {
  late DateTime? plannedStartDate;
  late bool ticketBooked;
  late bool arrivalConfirmed;
  late bool accommodationConfirmed;
  late bool medicalCleared;
  late bool clothingIssued;
  late bool safetyInducted;
  late bool objectAssigned;
  late bool attendanceEnabled;
  late final TextEditingController notesController;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.entry.mobilization;
    plannedStartDate = item.plannedStartDate;
    ticketBooked = item.ticketBooked;
    arrivalConfirmed = item.arrivalConfirmed;
    accommodationConfirmed = item.accommodationConfirmed;
    medicalCleared = item.medicalCleared;
    clothingIssued = item.clothingIssued;
    safetyInducted = item.safetyInducted;
    objectAssigned = item.objectAssigned;
    attendanceEnabled = item.attendanceEnabled;
    notesController = TextEditingController(text: item.notes);
  }

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  int get completedSteps => <bool>[
        ticketBooked,
        arrivalConfirmed,
        accommodationConfirmed,
        medicalCleared,
        clothingIssued,
        safetyInducted,
        objectAssigned,
        attendanceEnabled,
      ].where((value) => value).length;

  String formatDate(DateTime? value) {
    if (value == null) return 'Не выбрана';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  Future<void> selectDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: plannedStartDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (selected != null && mounted) {
      setState(() => plannedStartDate = selected);
    }
  }

  void showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error.toString().replaceFirst('Bad state: ', '').replaceFirst('Exception: ', ''),
        ),
      ),
    );
  }

  Future<void> save() async {
    if (saving) return;
    setState(() => saving = true);
    try {
      final original = widget.entry.mobilization;
      final result = await EmployeeMobilizationRepository.save(
        candidate: widget.entry.candidate,
        mobilization: EmployeeMobilization(
          id: original.id,
          companyId: widget.entry.candidate.companyId,
          applicationId: widget.entry.candidate.applicationId,
          employeeId: widget.entry.candidate.employeeId,
          objectId: widget.entry.candidate.objectId,
          plannedStartDate: plannedStartDate,
          ticketBooked: ticketBooked,
          arrivalConfirmed: arrivalConfirmed,
          accommodationConfirmed: accommodationConfirmed,
          medicalCleared: medicalCleared,
          clothingIssued: clothingIssued,
          safetyInducted: safetyInducted,
          objectAssigned: objectAssigned,
          attendanceEnabled: attendanceEnabled,
          status: original.status,
          notes: notesController.text,
          completedAt: original.completedAt,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isCompleted
                ? 'Выход завершён. Прораб и бухгалтер уведомлены.'
                : 'Подготовка сотрудника сохранена.',
          ),
        ),
      );
      if (result.isCompleted) Navigator.of(context).pop();
    } catch (error) {
      showError(error);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget check(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final candidate = widget.entry.candidate;
    return AppPage(
      title: 'Выход сотрудника',
      subtitle: '${candidate.fullName} · ${candidate.objectName}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PremiumWorkCard(
            radius: 24,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  candidate.fullName,
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text('${candidate.positionTitle} · ${candidate.objectName}'),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: completedSteps / 8),
                const SizedBox(height: 6),
                Text(
                  'Закрыто $completedSteps из 8 пунктов',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: selectDate,
            icon: const Icon(Icons.event_outlined),
            label: Text('Дата выхода: ${formatDate(plannedStartDate)}'),
          ),
          const SizedBox(height: 8),
          PremiumWorkCard(
            radius: 24,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                check(
                  'Билеты оформлены',
                  'Маршрут и дата подтверждены.',
                  ticketBooked,
                  (value) => setState(() => ticketBooked = value),
                ),
                check(
                  'Прибытие подтверждено',
                  'Сотрудник фактически прибыл.',
                  arrivalConfirmed,
                  (value) => setState(() => arrivalConfirmed = value),
                ),
                check(
                  'Проживание подготовлено',
                  'Есть подтверждённое место проживания.',
                  accommodationConfirmed,
                  (value) => setState(() => accommodationConfirmed = value),
                ),
                check(
                  'Медицинский допуск получен',
                  'Медосмотр и обязательные допуски действуют.',
                  medicalCleared,
                  (value) => setState(() => medicalCleared = value),
                ),
                check(
                  'Спецодежда выдана',
                  'Размеры и комплект СИЗ закрыты.',
                  clothingIssued,
                  (value) => setState(() => clothingIssued = value),
                ),
                check(
                  'Инструктаж проведён',
                  'Охрана труда и объектовый инструктаж отмечены.',
                  safetyInducted,
                  (value) => setState(() => safetyInducted = value),
                ),
                check(
                  'Назначен на объект',
                  'Объект в карточке сотрудника подтверждён.',
                  objectAssigned,
                  (value) => setState(() => objectAssigned = value),
                ),
                check(
                  'Включён в табель',
                  'Сотрудник активируется в действующем списке объекта.',
                  attendanceEnabled,
                  (value) => setState(() => attendanceEnabled = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notesController,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Комментарий по выходу',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: saving ? null : save,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Сохранить подготовку'),
          ),
          const SizedBox(height: 10),
          const Text(
            'Завершение происходит только когда выбрана дата и закрыты все восемь пунктов. До этого сотрудник не переводится в готовый статус.',
            style: TextStyle(height: 1.4, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _MobilizationMessage extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MobilizationMessage({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      radius: 20,
      padding: const EdgeInsets.all(15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(height: 1.4, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
