import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_adaptive_palette.dart';
import '../models/app_user_profile.dart';
import '../models/employee.dart';
import '../models/employee_private_data.dart';
import '../widgets/app_page.dart';
import '../widgets/premium_ui.dart';

Color get _text => AppAdaptivePalette.textPrimary;
Color get _muted => AppAdaptivePalette.textMuted;
Color get _line => AppAdaptivePalette.border;
Color get _soft => AppAdaptivePalette.surfaceSoft;
Color get _surface => AppAdaptivePalette.surface;
Color get _surfaceElevated => AppAdaptivePalette.surfaceElevated;
Color get _input => AppAdaptivePalette.inputSurface;
Color get _success => AppAdaptivePalette.success;
Color get _warning => AppAdaptivePalette.warning;
Color get _danger => AppAdaptivePalette.danger;

class DesktopEmployeesView extends StatefulWidget {
  final AppUserProfile profile;
  final String scopeTitle;
  final List<Employee> employees;
  final Map<String, EmployeePrivateData> privateDataByEmployeeId;
  final bool loading;
  final String? error;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final ValueChanged<Employee> onOpenEmployee;
  final VoidCallback onOpenPayments;
  final Future<void> Function() onDownloadSummary;
  final Future<void> Function() onAddEmployee;

  const DesktopEmployeesView({
    super.key,
    required this.profile,
    required this.scopeTitle,
    required this.employees,
    required this.privateDataByEmployeeId,
    required this.loading,
    required this.error,
    required this.scrollController,
    required this.onRefresh,
    required this.onOpenEmployee,
    required this.onOpenPayments,
    required this.onDownloadSummary,
    required this.onAddEmployee,
  });

  @override
  State<DesktopEmployeesView> createState() => _DesktopEmployeesViewState();
}

class _DesktopEmployeesViewState extends State<DesktopEmployeesView> {
  final searchController = TextEditingController();

  String selectedObject = '';
  String selectedPosition = '';
  String selectedEmployment = 'all';
  String selectedDocuments = 'all';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  String money(int value) {
    final formatted = value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    );
    return '$formatted ₽';
  }

  String clean(String value) => value.trim();

  List<String> objectOptions() {
    final result =
        widget.employees
            .expand(
              (employee) => employee.objectName
                  .split(',')
                  .map(clean)
                  .where((value) => value.isNotEmpty),
            )
            .toSet()
            .toList()
          ..sort();
    return result;
  }

  List<String> positionOptions() {
    final result =
        widget.employees
            .map((employee) => clean(employee.position))
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return result;
  }

  _DocumentState documentState(Employee employee) {
    final employeeId = employee.id?.trim();
    if (employeeId == null || employeeId.isEmpty) {
      return _DocumentState.missing;
    }

    final data = widget.privateDataByEmployeeId[employeeId];
    if (data == null) return _DocumentState.missing;

    final checks = <bool>[
      data.passportSeries.trim().isNotEmpty &&
          data.passportNumber.trim().isNotEmpty,
      data.snils.trim().isNotEmpty,
      data.inn.trim().isNotEmpty,
      data.bankCard.trim().isNotEmpty || data.bankAccount.trim().isNotEmpty,
      data.contractNumber.trim().isNotEmpty ||
          data.employmentStartDate.trim().isNotEmpty,
    ];
    final completed = checks.where((value) => value).length;

    if (completed == checks.length) return _DocumentState.ready;
    if (completed == 0) return _DocumentState.missing;
    return _DocumentState.partial;
  }

  bool matchesObject(Employee employee, String objectFilter) {
    if (objectFilter.isEmpty) return true;
    return employee.objectName.split(',').map(clean).contains(objectFilter);
  }

  List<Employee> filteredEmployees() {
    final query = searchController.text.trim().toLowerCase();
    final objects = objectOptions();
    final positions = positionOptions();
    final objectFilter = objects.contains(selectedObject) ? selectedObject : '';
    final positionFilter = positions.contains(selectedPosition)
        ? selectedPosition
        : '';

    final result = widget.employees.where((employee) {
      if (query.isNotEmpty) {
        final haystack = <String>[
          employee.name,
          employee.position,
          employee.phone,
          employee.objectName,
        ].join(' ').toLowerCase();
        if (!haystack.contains(query)) return false;
      }

      if (!matchesObject(employee, objectFilter)) return false;
      if (positionFilter.isNotEmpty &&
          employee.position.trim() != positionFilter) {
        return false;
      }

      if (selectedEmployment == 'active' && !employee.isActive) return false;
      if (selectedEmployment == 'fired' && employee.isActive) return false;

      final documents = documentState(employee);
      if (selectedDocuments == 'ready' && documents != _DocumentState.ready) {
        return false;
      }
      if (selectedDocuments == 'partial' &&
          documents != _DocumentState.partial) {
        return false;
      }
      if (selectedDocuments == 'missing' &&
          documents != _DocumentState.missing) {
        return false;
      }

      return true;
    }).toList();

    result.sort((first, second) {
      if (first.isActive != second.isActive) return first.isActive ? -1 : 1;
      return first.name.toLowerCase().compareTo(second.name.toLowerCase());
    });
    return result;
  }

  bool get hasFilters {
    return searchController.text.trim().isNotEmpty ||
        selectedObject.isNotEmpty ||
        selectedPosition.isNotEmpty ||
        selectedEmployment != 'all' ||
        selectedDocuments != 'all';
  }

  Future<void> clearFilters() async {
    searchController.clear();
    setState(() {
      selectedObject = '';
      selectedPosition = '';
      selectedEmployment = 'all';
      selectedDocuments = 'all';
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = filteredEmployees();
    final activeCount = widget.employees
        .where((employee) => employee.isActive)
        .length;
    final readyCount = widget.employees
        .where((employee) => documentState(employee) == _DocumentState.ready)
        .length;

    return RepaintBoundary(
      child: PremiumWorkBackdrop(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: ListView(
              key: PageStorageKey<String>(
                'desktop-employees-${widget.scopeTitle}',
              ),
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 120),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppPageHeader(
                          title: 'Сотрудники',
                          subtitle:
                              'Люди, ставки и документы • ${widget.scopeTitle}',
                          trailing: IconButton(
                            onPressed: widget.onRefresh,
                            tooltip: 'Обновить сотрудников',
                            icon: Icon(Icons.refresh_rounded),
                          ),
                        ),
                        SizedBox(height: 18),
                        _ActionBar(
                          totalCount: widget.employees.length,
                          activeCount: activeCount,
                          readyCount: readyCount,
                          canManage: widget.profile.isAdmin,
                          onOpenPayments: widget.onOpenPayments,
                          onDownloadSummary: widget.onDownloadSummary,
                          onAddEmployee: widget.onAddEmployee,
                        ),
                        SizedBox(height: 18),
                        _FiltersCard(
                          searchController: searchController,
                          objectOptions: objectOptions(),
                          positionOptions: positionOptions(),
                          selectedObject: selectedObject,
                          selectedPosition: selectedPosition,
                          selectedEmployment: selectedEmployment,
                          selectedDocuments: selectedDocuments,
                          hasFilters: hasFilters,
                          onSearchChanged: (_) => setState(() {}),
                          onObjectChanged: (value) {
                            setState(() => selectedObject = value ?? '');
                          },
                          onPositionChanged: (value) {
                            setState(() => selectedPosition = value ?? '');
                          },
                          onEmploymentChanged: (value) {
                            setState(() => selectedEmployment = value ?? 'all');
                          },
                          onDocumentsChanged: (value) {
                            setState(() => selectedDocuments = value ?? 'all');
                          },
                          onClear: clearFilters,
                        ),
                        SizedBox(height: 18),
                        if (widget.loading && widget.employees.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: LinearProgressIndicator(minHeight: 3),
                          ),
                        _buildContent(visible),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(List<Employee> visible) {
    if (widget.loading && widget.employees.isEmpty) {
      return _MessageCard(
        icon: Icons.groups_outlined,
        title: 'Загружаем сотрудников',
        loading: true,
      );
    }

    if (widget.error != null && widget.employees.isEmpty) {
      return _MessageCard(
        icon: Icons.cloud_off_outlined,
        title: 'Не удалось загрузить сотрудников',
        description: widget.error,
        actionLabel: 'Повторить',
        onAction: widget.onRefresh,
      );
    }

    if (widget.employees.isEmpty) {
      return _MessageCard(
        icon: Icons.person_add_alt_1_outlined,
        title: 'Сотрудников пока нет',
        description: 'Добавьте первого сотрудника, чтобы начать работу.',
      );
    }

    if (visible.isEmpty) {
      return _MessageCard(
        icon: Icons.search_off_rounded,
        title: 'Сотрудники не найдены',
        description: 'Измените поиск или сбросьте выбранные фильтры.',
        actionLabel: hasFilters ? 'Сбросить фильтры' : null,
        onAction: hasFilters ? clearFilters : null,
      );
    }

    return _EmployeesTable(
      employees: visible,
      documentState: documentState,
      money: money,
      onOpenEmployee: widget.onOpenEmployee,
    );
  }
}

class _ActionBar extends StatelessWidget {
  final int totalCount;
  final int activeCount;
  final int readyCount;
  final bool canManage;
  final VoidCallback onOpenPayments;
  final Future<void> Function() onDownloadSummary;
  final Future<void> Function() onAddEmployee;

  const _ActionBar({
    required this.totalCount,
    required this.activeCount,
    required this.readyCount,
    required this.canManage,
    required this.onOpenPayments,
    required this.onDownloadSummary,
    required this.onAddEmployee,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _SummaryChip(
                  icon: Icons.groups_2_outlined,
                  label: 'Всего',
                  value: '$totalCount',
                ),
                _SummaryChip(
                  icon: Icons.verified_user_outlined,
                  label: 'Активных',
                  value: '$activeCount',
                ),
                _SummaryChip(
                  icon: Icons.folder_copy_outlined,
                  label: 'Документы готовы',
                  value: '$readyCount',
                ),
              ],
            ),
          ),
          if (canManage) ...[
            SizedBox(width: 16),
            OutlinedButton.icon(
              onPressed: onOpenPayments,
              icon: Icon(Icons.payments_outlined),
              label: const Text('Выплаты'),
            ),
            SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: onDownloadSummary,
              icon: Icon(Icons.table_view_outlined),
              label: const Text('Сводка'),
            ),
            SizedBox(width: 10),
            FilledButton.icon(
              onPressed: onAddEmployee,
              icon: Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Добавить'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 19, color: _muted),
          SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(color: _muted, fontWeight: FontWeight.w700),
          ),
          Text(
            value,
            style: TextStyle(color: _text, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _FiltersCard extends StatelessWidget {
  final TextEditingController searchController;
  final List<String> objectOptions;
  final List<String> positionOptions;
  final String selectedObject;
  final String selectedPosition;
  final String selectedEmployment;
  final String selectedDocuments;
  final bool hasFilters;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onObjectChanged;
  final ValueChanged<String?> onPositionChanged;
  final ValueChanged<String?> onEmploymentChanged;
  final ValueChanged<String?> onDocumentsChanged;
  final VoidCallback onClear;

  const _FiltersCard({
    required this.searchController,
    required this.objectOptions,
    required this.positionOptions,
    required this.selectedObject,
    required this.selectedPosition,
    required this.selectedEmployment,
    required this.selectedDocuments,
    required this.hasFilters,
    required this.onSearchChanged,
    required this.onObjectChanged,
    required this.onPositionChanged,
    required this.onEmploymentChanged,
    required this.onDocumentsChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final objectValue = objectOptions.contains(selectedObject)
        ? selectedObject
        : '';
    final positionValue = positionOptions.contains(selectedPosition)
        ? selectedPosition
        : '';

    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Поиск по ФИО, должности, телефону или объекту',
              prefixIcon: Icon(Icons.search_rounded),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged('');
                      },
                      tooltip: 'Очистить поиск',
                      icon: Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: _input,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: _line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: _line),
              ),
            ),
          ),
          SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _FilterField(
                width: 220,
                label: 'Объект',
                value: objectValue,
                items: <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: '', child: Text('Все объекты')),
                  ...objectOptions.map(
                    (object) => DropdownMenuItem(
                      value: object,
                      child: Text(object, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: onObjectChanged,
              ),
              _FilterField(
                width: 240,
                label: 'Должность',
                value: positionValue,
                items: <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: '', child: Text('Все должности')),
                  ...positionOptions.map(
                    (position) => DropdownMenuItem(
                      value: position,
                      child: Text(position, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: onPositionChanged,
              ),
              _FilterField(
                width: 205,
                label: 'Статус',
                value: selectedEmployment,
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'all', child: Text('Все сотрудники')),
                  DropdownMenuItem(value: 'active', child: Text('Активные')),
                  DropdownMenuItem(value: 'fired', child: Text('Уволенные')),
                ],
                onChanged: onEmploymentChanged,
              ),
              _FilterField(
                width: 220,
                label: 'Документы',
                value: selectedDocuments,
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'all', child: Text('Любой статус')),
                  DropdownMenuItem(value: 'ready', child: Text('Готово')),
                  DropdownMenuItem(value: 'partial', child: Text('Частично')),
                  DropdownMenuItem(value: 'missing', child: Text('Нет данных')),
                ],
                onChanged: onDocumentsChanged,
              ),
              if (hasFilters)
                TextButton.icon(
                  onPressed: onClear,
                  icon: Icon(Icons.filter_alt_off_outlined),
                  label: const Text('Сбросить'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterField extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  const _FilterField({
    required this.width,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        dropdownColor: _surfaceElevated,
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: _input,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _line),
          ),
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}

class _EmployeesTable extends StatelessWidget {
  final List<Employee> employees;
  final _DocumentState Function(Employee employee) documentState;
  final String Function(int value) money;
  final ValueChanged<Employee> onOpenEmployee;

  const _EmployeesTable({
    required this.employees,
    required this.documentState,
    required this.money,
    required this.onOpenEmployee,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      radius: 26,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tableWidth = math.max(constraints.maxWidth, 1180.0);

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: Column(
                  children: [
                    const _TableHeader(),
                    ...employees.indexed.map(
                      (entry) => _EmployeeRow(
                        employee: entry.$2,
                        documentState: documentState(entry.$2),
                        money: money,
                        onTap: () => onOpenEmployee(entry.$2),
                        shaded: entry.$1.isOdd,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: _soft,
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          _HeaderCell(flex: 4, text: 'Сотрудник'),
          _HeaderCell(flex: 2, text: 'Должность'),
          _HeaderCell(flex: 2, text: 'Объект'),
          _HeaderCell(flex: 2, text: 'Телефон'),
          _HeaderCell(flex: 2, text: 'Ставка'),
          _HeaderCell(flex: 2, text: 'Документы'),
          _HeaderCell(flex: 2, text: 'Статус'),
          SizedBox(width: 34),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final int flex;
  final String text;

  const _HeaderCell({required this.flex, required this.text});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: _muted,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmployeeRow extends StatelessWidget {
  final Employee employee;
  final _DocumentState documentState;
  final String Function(int value) money;
  final VoidCallback onTap;
  final bool shaded;

  const _EmployeeRow({
    required this.employee,
    required this.documentState,
    required this.money,
    required this.onTap,
    required this.shaded,
  });

  @override
  Widget build(BuildContext context) {
    final mutedRow = !employee.isActive;

    return PremiumPressable(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: mutedRow
              ? AppAdaptivePalette.disabledSurface
              : shaded
              ? _surfaceElevated
              : _surface,
          border: Border(bottom: BorderSide(color: _line)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: mutedRow
                        ? AppAdaptivePalette.disabledSurface
                        : _soft,
                    foregroundColor: _text,
                    child: Text(
                      employee.name.trim().isEmpty
                          ? '?'
                          : employee.name.trim().characters.first,
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      employee.name.trim().isEmpty
                          ? 'Без имени'
                          : employee.name.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: mutedRow ? _muted : _text,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _TextCell(flex: 2, text: employee.position),
            _TextCell(flex: 2, text: employee.objectName),
            _TextCell(flex: 2, text: employee.phone),
            _TextCell(flex: 2, text: money(employee.dailyRate)),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _DocumentBadge(state: documentState),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _EmploymentBadge(active: employee.isActive),
              ),
            ),
            SizedBox(
              width: 34,
              child: Icon(Icons.chevron_right_rounded, color: _muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextCell extends StatelessWidget {
  final int flex;
  final String text;

  const _TextCell({required this.flex, required this.text});

  @override
  Widget build(BuildContext context) {
    final value = text.trim().isEmpty ? '—' : text.trim();

    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _text,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DocumentBadge extends StatelessWidget {
  final _DocumentState state;

  const _DocumentBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _DocumentState.ready:
        return _Badge(
          label: 'Готово',
          icon: Icons.check_circle_outline_rounded,
          foreground: _success,
          background: AppAdaptivePalette.isDark
              ? _success.withValues(alpha: 0.16)
              : const Color(0xFFE8F5ED),
        );
      case _DocumentState.partial:
        return _Badge(
          label: 'Частично',
          icon: Icons.pending_actions_outlined,
          foreground: _warning,
          background: AppAdaptivePalette.isDark
              ? _warning.withValues(alpha: 0.16)
              : const Color(0xFFFFF4DC),
        );
      case _DocumentState.missing:
        return _Badge(
          label: 'Нет данных',
          icon: Icons.folder_off_outlined,
          foreground: _muted,
          background: _soft,
        );
    }
  }
}

class _EmploymentBadge extends StatelessWidget {
  final bool active;

  const _EmploymentBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    return _Badge(
      label: active ? 'Активен' : 'Уволен',
      icon: active ? Icons.person_outline_rounded : Icons.archive_outlined,
      foreground: active ? _success : _danger,
      background: active
          ? (AppAdaptivePalette.isDark
                ? _success.withValues(alpha: 0.16)
                : const Color(0xFFE8F5ED))
          : (AppAdaptivePalette.isDark
                ? _danger.withValues(alpha: 0.16)
                : const Color(0xFFF7E8E7)),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;

  _Badge({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foreground),
          SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final bool loading;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  _MessageCard({
    required this.icon,
    required this.title,
    this.description,
    this.loading = false,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumWorkCard(
      radius: 26,
      padding: const EdgeInsets.all(34),
      child: Column(
        children: [
          if (loading)
            const CircularProgressIndicator()
          else
            Icon(icon, size: 42, color: _muted),
          SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (description != null) ...[
            SizedBox(height: 8),
            Text(
              description!,
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: 18),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

enum _DocumentState { ready, partial, missing }
