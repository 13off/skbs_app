import 'package:flutter/material.dart';

import '../../../widgets/premium_ui.dart';
import '../../shared/presentation/specialist_desktop_ui.dart';
import 'foreman_workspace_models.dart';

class ForemanAttendanceControl extends StatelessWidget {
  final ForemanDashboardData data;
  final VoidCallback onOpenTimesheet;

  const ForemanAttendanceControl({
    super.key,
    required this.data,
    required this.onOpenTimesheet,
  });

  @override
  Widget build(BuildContext context) {
    final absent = data.employees.where((employee) {
      final id = employee.id;
      return id == null || (data.shifts[id] ?? 0) <= 0;
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Контроль явки',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      'Сотрудники без отмеченной смены',
                      style: TextStyle(
                        color: specialistMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SpecialistStatusPill(
                label: absent.isEmpty ? 'Все отмечены' : 'Не отмечены: ${absent.length}',
                color: absent.isEmpty ? specialistSuccess : specialistWarning,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (data.employees.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('На объекте нет активных сотрудников')),
            )
          else if (absent.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      size: 38,
                      color: specialistSuccess,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Табель на сегодня заполнен',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            )
          else
            ...absent.take(8).map(
              (employee) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: specialistSoft,
                  child: Icon(Icons.person_outline, color: specialistText),
                ),
                title: Text(
                  employee.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  employee.position.trim().isEmpty
                      ? 'Должность не указана'
                      : employee.position,
                ),
                trailing: const SpecialistStatusPill(
                  label: '0 смен',
                  color: specialistWarning,
                ),
                onTap: onOpenTimesheet,
              ),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onOpenTimesheet,
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Открыть табель'),
          ),
        ],
      ),
    );
  }
}
