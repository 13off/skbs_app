part of '../employees_screen.dart';

extension _EmployeesSections on _EmployeesScreenState {
  Widget actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    final foreground = primary ? AppAdaptivePalette.onAccent : _text;
    final background = primary ? _accent : _soft;

    return PremiumPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: primary ? _accent : _line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 19, color: foreground),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: foreground, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget header() {
    final scopeTitle = objectName ?? 'Все объекты';
    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        actionButton(
          icon: Icons.payments_outlined,
          label: 'Выплаты',
          onTap: openPayments,
        ),
        actionButton(
          icon: Icons.table_view_outlined,
          label: 'Сводка',
          onTap: downloadSummary,
        ),
        actionButton(
          icon: Icons.person_add_alt_1,
          label: 'Добавить',
          onTap: addEmployee,
          primary: true,
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppPageHeader(
          title: 'Сотрудники',
          subtitle: 'Люди, ставки и документы • $scopeTitle',
        ),
        const SizedBox(height: 14),
        PremiumWorkCard(
          radius: 24,
          padding: const EdgeInsets.all(14),
          child: actions,
        ),
      ],
    );
  }

  Widget search() {
    return TextField(
      controller: searchController,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'Поиск по ФИО, должности, телефону...',
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
        fillColor: _card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: _line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: _line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: _accent, width: 1.4),
        ),
      ),
    );
  }

  Widget employeeCard(Employee employee) {
    final fired = !employee.isActive;
    final subtitle = <String>[
      employee.position,
      employee.phone,
      employee.objectName,
      'Ставка: ${money(employee.dailyRate)}',
    ].where((value) => value.trim().isNotEmpty).join('\n');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PremiumPressable(
        onTap: () => openEmployee(employee),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            color: fired
                ? AppAdaptivePalette.surfaceSoft
                : AppAdaptivePalette.surfaceElevated,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 18,
                spreadRadius: -8,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            leading: CircleAvatar(
              backgroundColor: _soft,
              foregroundColor: _text,
              child: Text(
                employee.name.trim().isEmpty
                    ? '?'
                    : employee.name.trim().characters.first,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    employee.name,
                    style: TextStyle(
                      color: fired ? AppAdaptivePalette.textMuted : _text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (fired)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppAdaptivePalette.surfaceSoft,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      'Уволен',
                      style: TextStyle(
                        color: AppAdaptivePalette.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                subtitle,
                style: TextStyle(
                  color: fired
                      ? AppAdaptivePalette.textFaint
                      : AppAdaptivePalette.textMuted,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: AppAdaptivePalette.textFaint,
            ),
          ),
        ),
      ),
    );
  }

  Widget section(String title, List<Employee> items, {bool fired = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (fired) Divider(height: 30, color: AppAdaptivePalette.border),
        Padding(
          padding: EdgeInsets.only(top: fired ? 22 : 0, bottom: 10),
          child: Row(
            children: [
              Icon(
                fired ? Icons.archive_outlined : Icons.groups_outlined,
                size: 20,
                color: fired ? AppAdaptivePalette.textMuted : _text,
              ),
              const SizedBox(width: 8),
              Text(
                '$title: ${items.length}',
                style: TextStyle(
                  color: fired ? AppAdaptivePalette.textMuted : _text,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              'Активных сотрудников нет',
              style: TextStyle(color: AppAdaptivePalette.textMuted),
            ),
          )
        else
          ...items.map(employeeCard),
      ],
    );
  }

  List<Widget> content() {
    final visible = visibleEmployees();
    final active = visible.where((employee) => employee.isActive).toList();
    final fired = visible.where((employee) => !employee.isActive).toList();
    final result = <Widget>[
      header(),
      const SizedBox(height: 14),
      search(),
      const SizedBox(height: 16),
    ];

    if (loading && employees.isEmpty) {
      result.addAll(const <Widget>[
        SizedBox(height: 60),
        Center(child: CircularProgressIndicator()),
      ]);
    } else if (error != null && employees.isEmpty) {
      result.add(
        Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Text(
            'Ошибка загрузки сотрудников: $error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    } else if (employees.isEmpty) {
      result.add(
        const Padding(
          padding: EdgeInsets.only(top: 40),
          child: Text('Сотрудников пока нет', textAlign: TextAlign.center),
        ),
      );
    } else if (visible.isEmpty) {
      result.add(
        const Padding(
          padding: EdgeInsets.only(top: 40),
          child: Text('Сотрудники не найдены', textAlign: TextAlign.center),
        ),
      );
    } else {
      result.add(section('Активные', active));
      if (fired.isNotEmpty) {
        result.add(section('Уволенные', fired, fired: true));
      }
    }
    return result;
  }
}
