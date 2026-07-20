part of '../timesheet_screen.dart';

extension _TimesheetSections on _TimesheetScreenState {
  Widget buildPageHeader() {
    return AppPageHeader(
      title: 'Табель',
      subtitle: 'Смены сотрудников за выбранную дату • $objectTitle',
      trailing: widget.profile.isAdmin
          ? FilledButton.tonalIcon(
              onPressed: () {
                Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (_) => _TimesheetReportRoute(
                      selectedObjectName: widget.selectedObjectName,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.analytics_outlined, size: 18),
              label: const Text('Отчет'),
            )
          : null,
    );
  }

  Widget buildDateArrow({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return PremiumPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F0EC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE4E2DC)),
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 24),
      ),
    );
  }

  Widget buildDatePanel() {
    final dateActionsEnabled = !isSaving && !isAttendanceLoading;
    return PremiumWorkCard(
      radius: 28,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          buildDateArrow(
            icon: Icons.chevron_left_rounded,
            onTap: dateActionsEnabled
                ? () {
                    changeDate(selectedDate.subtract(const Duration(days: 1)));
                  }
                : null,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: PremiumPressable(
              onTap: dateActionsEnabled ? pickDate : null,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F0EC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE4E2DC)),
                ),
                child: Column(
                  children: [
                    Text(
                      shortDate(selectedDate),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      weekDayName(selectedDate),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 11),
          buildDateArrow(
            icon: Icons.chevron_right_rounded,
            onTap: dateActionsEnabled
                ? () {
                    changeDate(selectedDate.add(const Duration(days: 1)));
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget buildWorkedSummaryPanel({required List<Employee> visibleEmployees}) {
    final visibleWorked = workedCountFor(visibleEmployees);
    final totalShifts = totalShiftsFor(visibleEmployees);
    return PremiumWorkCard(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: AppColors.accentSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.groups_outlined,
              size: 21,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Вышли сегодня',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$visibleWorked / ${visibleEmployees.length}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${formatShift(totalShifts)} смен',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildSearch() {
    return TextField(
      controller: searchController,
      decoration: InputDecoration(
        hintText: 'Поиск по ФИО или должности',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: searchController.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close),
              ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.86),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Colors.white),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(
            color: AppColors.textPrimary,
            width: 1.3,
          ),
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget buildQuickActions(List<Employee> visibleEmployees) {
    return PremiumWorkCard(
      radius: 22,
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Быстрый ввод',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.tonalIcon(
            onPressed:
                visibleEmployees.isEmpty || isSaving || isAttendanceLoading
                ? null
                : () {
                    setVisibleEmployeesShifts(
                      employees: visibleEmployees,
                      value: 1,
                    );
                  },
            icon: const Icon(Icons.done_all, size: 18),
            label: const Text('Всем 1'),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed:
                visibleEmployees.isEmpty || isSaving || isAttendanceLoading
                ? null
                : () {
                    setVisibleEmployeesShifts(
                      employees: visibleEmployees,
                      value: 0,
                    );
                  },
            icon: const Icon(Icons.remove_done, size: 18),
            label: const Text('Всем 0'),
          ),
        ],
      ),
    );
  }

  Widget buildEmployeeRow(Employee employee) {
    final shifts = shiftValueFor(employee);
    final hasWorked = shifts > 0;
    return PremiumWorkCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      radius: 22,
      tint: hasWorked
          ? const Color(0xFFEDEEEB)
          : Colors.white.withValues(alpha: 0.86),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      employee.position,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: AppMotion.regular,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: hasWorked
                      ? AppColors.textPrimary
                      : AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  formatShift(shifts),
                  style: TextStyle(
                    color: hasWorked ? Colors.white : AppColors.textMuted,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...quickShiftOptions.map((option) {
                final isSelected = shifts == option;
                return ChoiceChip(
                  label: Text(formatShift(option)),
                  selected: isSelected,
                  onSelected: isAttendanceLoading || isSaving
                      ? null
                      : (_) => setShiftValue(employee, option),
                );
              }),
              ActionChip(
                avatar: const Icon(Icons.tune, size: 18),
                label: const Text('Другое'),
                onPressed: isAttendanceLoading || isSaving
                    ? null
                    : () => showShiftPicker(employee),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
