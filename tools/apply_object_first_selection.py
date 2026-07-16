from pathlib import Path


def read(path: str) -> str:
    return Path(path).read_text(encoding="utf-8")


def write(path: str, text: str) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text, encoding="utf-8")


def replace(path: str, old: str, new: str, count: int = 1) -> None:
    text = read(path)
    found = text.count(old)
    if found < count:
        raise SystemExit(
            f"{path}: expected at least {count} occurrence(s), "
            f"found {found}: {old[:120]!r}"
        )
    write(path, text.replace(old, new, count))


def add_shared_scope() -> None:
    write(
        "lib/widgets/object_employee_scope.dart",
        """const String allObjectsScopeValue = '__all_objects__';

bool isAllObjectsScope(String? value) => value == allObjectsScopeValue;

String? selectedObjectNameFromScope(String? value) {
  final clean = value?.trim();
  if (clean == null || clean.isEmpty || isAllObjectsScope(clean)) return null;
  return clean;
}

List<T> filterEmployeesByObject<T>({
  required List<T> employees,
  required String? selectedObject,
  required String Function(T employee) objectNameOf,
}) {
  final cleanScope = selectedObject?.trim();
  if (cleanScope == null || cleanScope.isEmpty) return <T>[];
  if (isAllObjectsScope(cleanScope)) return List<T>.from(employees);

  final normalizedScope = cleanScope.toLowerCase();
  return employees.where((employee) {
    return objectNameOf(employee).trim().toLowerCase() == normalizedScope;
  }).toList();
}
""",
    )


def patch_add_payment() -> None:
    path = "lib/screens/add_payment_screen.dart"
    replace(
        path,
        "import '../models/employee.dart';\n",
        "import '../models/employee.dart';\n"
        "import '../widgets/object_employee_scope.dart';\n",
    )
    replace(
        path,
        "  final String? initialEmployeeId;\n",
        "  final String? initialEmployeeId;\n"
        "  final String? initialObjectName;\n",
    )
    replace(
        path,
        "    this.initialEmployeeId,\n",
        "    this.initialEmployeeId,\n"
        "    this.initialObjectName,\n",
    )
    replace(
        path,
        "    selectedEmployeeId = widget.initialEmployeeId;\n"
        "    loadEmployees();\n",
        "    final initialObject = widget.initialObjectName?.trim();\n"
        "    selectedObjectName = initialObject == null || initialObject.isEmpty\n"
        "        ? null\n"
        "        : initialObject;\n"
        "    selectedEmployeeId = widget.initialEmployeeId;\n"
        "    loadEmployees();\n",
    )
    replace(
        path,
        "  List<Employee> employeesForSelectedObject() {\n"
        "    final objectName = selectedObjectName?.trim();\n"
        "    if (objectName == null || objectName.isEmpty) return const <Employee>[];\n\n"
        "    final result = employees\n"
        "        .where((employee) => employee.objectName.trim() == objectName)\n"
        "        .toList();\n"
        "    result.sort((a, b) => a.name.compareTo(b.name));\n"
        "    return result;\n"
        "  }\n",
        "  List<Employee> employeesForSelectedObject() {\n"
        "    final result = filterEmployeesByObject<Employee>(\n"
        "      employees: employees,\n"
        "      selectedObject: selectedObjectName,\n"
        "      objectNameOf: (employee) => employee.objectName,\n"
        "    );\n"
        "    result.sort((a, b) => a.name.compareTo(b.name));\n"
        "    return result;\n"
        "  }\n",
    )
    replace(
        path,
        "            items: objectNames.map((objectName) {\n"
        "              return DropdownMenuItem<String>(\n"
        "                value: objectName,\n"
        "                child: Text(objectName),\n"
        "              );\n"
        "            }).toList(),\n",
        "            items: [\n"
        "              const DropdownMenuItem<String>(\n"
        "                value: allObjectsScopeValue,\n"
        "                child: Text('Все объекты'),\n"
        "              ),\n"
        "              ...objectNames.map((objectName) {\n"
        "                return DropdownMenuItem<String>(\n"
        "                  value: objectName,\n"
        "                  child: Text(objectName),\n"
        "                );\n"
        "              }),\n"
        "            ],\n",
    )
    replace(
        path,
        "                child: Text(employee.name),\n",
        "                child: Text(\n"
        "                  isAllObjectsScope(selectedObjectName) &&\n"
        "                          employee.objectName.trim().isNotEmpty\n"
        "                      ? '${employee.name} — ${employee.objectName.trim()}'\n"
        "                      : employee.name,\n"
        "                  overflow: TextOverflow.ellipsis,\n"
        "                ),\n",
    )


def patch_payment_exporter() -> None:
    path = "lib/features/payments/data/payment_report_exporter.dart"
    replace(
        path,
        "  final List<String> employeeIds;\n",
        "  final List<String> employeeIds;\n"
        "  final List<String> objectNames;\n",
    )
    replace(
        path,
        "    required this.employeeIds,\n"
        "  });\n",
        "    required this.employeeIds,\n"
        "    this.objectNames = const <String>[],\n"
        "  });\n",
    )
    replace(
        path,
        "  final String? employeeKey;\n\n"
        "  const PaymentReportRequest({required this.month, required this.employeeKey});\n",
        "  final String? employeeKey;\n"
        "  final String? objectName;\n\n"
        "  const PaymentReportRequest({\n"
        "    required this.month,\n"
        "    required this.employeeKey,\n"
        "    this.objectName,\n"
        "  });\n",
    )
    replace(
        path,
        "    final selectedEmployees = request.employeeKey == null\n"
        "        ? employees\n"
        "        : employees\n"
        "              .where((employee) => employee.key == request.employeeKey)\n"
        "              .toList();\n",
        "    final objectName = request.objectName?.trim().toLowerCase();\n"
        "    final objectEmployees = objectName == null || objectName.isEmpty\n"
        "        ? employees\n"
        "        : employees.where((employee) {\n"
        "            return employee.objectNames.any(\n"
        "              (value) => value.trim().toLowerCase() == objectName,\n"
        "            );\n"
        "          }).toList();\n"
        "    final selectedEmployees = request.employeeKey == null\n"
        "        ? objectEmployees\n"
        "        : objectEmployees\n"
        "              .where((employee) => employee.key == request.employeeKey)\n"
        "              .toList();\n",
    )


def patch_payment_report_sheet() -> None:
    path = "lib/features/payments/presentation/widgets/payment_report_sheet.dart"
    replace(
        path,
        "import '../../data/payment_report_exporter.dart';\n",
        "import '../../../../widgets/object_employee_scope.dart';\n"
        "import '../../data/payment_report_exporter.dart';\n",
    )
    replace(
        path,
        "  String selectedEmployeeKey = _allEmployeesKey;\n",
        "  String? selectedObjectKey;\n"
        "  String selectedEmployeeKey = _allEmployeesKey;\n",
    )
    replace(
        path,
        "  void submit() {\n",
        "  List<String> get objectNames {\n"
        "    final values = widget.employees\n"
        "        .expand((employee) => employee.objectNames)\n"
        "        .map((value) => value.trim())\n"
        "        .where((value) => value.isNotEmpty)\n"
        "        .toSet()\n"
        "        .toList()\n"
        "      ..sort();\n"
        "    return values;\n"
        "  }\n\n"
        "  List<PaymentReportEmployeeOption> get filteredEmployees {\n"
        "    final scope = selectedObjectKey;\n"
        "    if (scope == null) return const <PaymentReportEmployeeOption>[];\n"
        "    if (isAllObjectsScope(scope)) return widget.employees;\n"
        "    final normalized = scope.trim().toLowerCase();\n"
        "    return widget.employees.where((employee) {\n"
        "      return employee.objectNames.any(\n"
        "        (value) => value.trim().toLowerCase() == normalized,\n"
        "      );\n"
        "    }).toList();\n"
        "  }\n\n"
        "  void submit() {\n",
    )
    replace(
        path,
        "        employeeKey: selectedEmployeeKey == _allEmployeesKey\n"
        "            ? null\n"
        "            : selectedEmployeeKey,\n",
        "        employeeKey: selectedEmployeeKey == _allEmployeesKey\n"
        "            ? null\n"
        "            : selectedEmployeeKey,\n"
        "        objectName: isAllObjectsScope(selectedObjectKey)\n"
        "            ? null\n"
        "            : selectedObjectKey,\n",
    )
    replace(
        path,
        "                  'Выбери период и сотрудника. Таблица скачается одним XLSX-файлом.',\n",
        "                  'Сначала выбери объект или «Все объекты», затем период и сотрудника.',\n",
    )
    replace(
        path,
        "                    children: [\n"
        "                      DropdownButtonFormField<String>(\n"
        "                        initialValue: selectedPeriodKey,\n",
        "                    children: [\n"
        "                      DropdownButtonFormField<String>(\n"
        "                        initialValue: selectedObjectKey,\n"
        "                        isExpanded: true,\n"
        "                        decoration: const InputDecoration(\n"
        "                          labelText: 'Объект',\n"
        "                          hintText: 'Сначала выберите объект',\n"
        "                          prefixIcon: Icon(Icons.apartment_outlined),\n"
        "                          border: OutlineInputBorder(),\n"
        "                        ),\n"
        "                        items: [\n"
        "                          const DropdownMenuItem<String>(\n"
        "                            value: allObjectsScopeValue,\n"
        "                            child: Text('Все объекты'),\n"
        "                          ),\n"
        "                          ...objectNames.map((objectName) {\n"
        "                            return DropdownMenuItem<String>(\n"
        "                              value: objectName,\n"
        "                              child: Text(objectName),\n"
        "                            );\n"
        "                          }),\n"
        "                        ],\n"
        "                        onChanged: (value) {\n"
        "                          setState(() {\n"
        "                            selectedObjectKey = value;\n"
        "                            selectedEmployeeKey = _allEmployeesKey;\n"
        "                          });\n"
        "                        },\n"
        "                      ),\n"
        "                      const SizedBox(height: 14),\n"
        "                      DropdownButtonFormField<String>(\n"
        "                        initialValue: selectedPeriodKey,\n",
    )
    replace(
        path,
        "                          ...widget.employees.map((employee) {\n",
        "                          ...filteredEmployees.map((employee) {\n",
    )
    employee_block_old = """                      DropdownButtonFormField<String>(
                        initialValue: selectedEmployeeKey,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Сотрудник',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: _allEmployeesKey,
                            child: Text('Все сотрудники'),
                          ),
                          ...filteredEmployees.map((employee) {
                            final subtitle = employee.objectTitle.trim();
                            final label = subtitle.isEmpty
                                ? employee.name
                                : '${employee.name} — $subtitle';

                            return DropdownMenuItem<String>(
                              value: employee.key,
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          if (value == null) return;

                          setState(() {
                            selectedEmployeeKey = value;
                          });
                        },
                      ),
"""
    employee_block_new = """                      DropdownButtonFormField<String>(
                        key: ValueKey(
                          'payment-report-employee-${selectedObjectKey ?? 'none'}',
                        ),
                        initialValue: selectedEmployeeKey,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Сотрудник',
                          hintText: selectedObjectKey == null
                              ? 'Сначала выберите объект'
                              : 'Выберите сотрудника',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: _allEmployeesKey,
                            child: Text('Все сотрудники'),
                          ),
                          ...filteredEmployees.map((employee) {
                            final subtitle = employee.objectTitle.trim();
                            final label = subtitle.isEmpty
                                ? employee.name
                                : '${employee.name} — $subtitle';

                            return DropdownMenuItem<String>(
                              value: employee.key,
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],
                        onChanged: selectedObjectKey == null
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() {
                                  selectedEmployeeKey = value;
                                });
                              },
                      ),
"""
    replace(path, employee_block_old, employee_block_new)
    replace(
        path,
        "                    onPressed: submit,\n",
        "                    onPressed: selectedObjectKey == null ? null : submit,\n",
    )


def patch_payments_screen() -> None:
    path = "lib/features/payments/presentation/screens/payments_screen.dart"
    replace(
        path,
        "class PaymentsScreen extends StatefulWidget {\n"
        "  const PaymentsScreen({super.key});\n",
        "class PaymentsScreen extends StatefulWidget {\n"
        "  final String? selectedObjectName;\n\n"
        "  const PaymentsScreen({super.key, this.selectedObjectName});\n",
    )
    replace(
        path,
        "        month: targetMonth.month,\n"
        "        forceRefresh: forceRefresh,\n",
        "        month: targetMonth.month,\n"
        "        objectName: widget.selectedObjectName,\n"
        "        includeFired: true,\n"
        "        forceRefresh: forceRefresh,\n",
    )
    replace(
        path,
        "          initialEmployeeId: employeeId,\n",
        "          initialEmployeeId: employeeId,\n"
        "          initialObjectName: widget.selectedObjectName,\n",
    )
    replace(
        path,
        "        objectTitle: row.objectTitle,\n"
        "        employeeIds: List<String>.from(row.employeeIds),\n",
        "        objectTitle: row.objectTitle,\n"
        "        employeeIds: List<String>.from(row.employeeIds),\n"
        "        objectNames: List<String>.from(row.objectNames),\n",
    )
    replace(
        path,
        "  final List<String> employeeIds;\n"
        "  final double accrued;\n",
        "  final List<String> employeeIds;\n"
        "  final List<String> objectNames;\n"
        "  final double accrued;\n",
    )
    replace(
        path,
        "    required this.employeeIds,\n"
        "    required this.accrued,\n",
        "    required this.employeeIds,\n"
        "    required this.objectNames,\n"
        "    required this.accrued,\n",
    )
    replace(
        path,
        "      employeeIds: employeeIds.toList(),\n"
        "      accrued: accrued,\n",
        "      employeeIds: employeeIds.toList(),\n"
        "      objectNames: objectNames.toList()..sort(),\n"
        "      accrued: accrued,\n",
    )

    employees_path = "lib/screens/employees_screen.dart"
    replace(
        employees_path,
        "      AppPageRoute(builder: (_) => const PaymentsScreen()),\n",
        "      AppPageRoute(\n"
        "        builder: (_) => PaymentsScreen(\n"
        "          selectedObjectName: widget.selectedObjectName,\n"
        "        ),\n"
        "      ),\n",
    )


def patch_accounting() -> None:
    repository = "lib/features/accounting/data/accounting_repository.dart"
    method_start = """  static Future<List<AccountingPaymentRegisterRow>> fetchPaymentRegister({
    required DateTime startDate,
    required DateTime endDate,
    bool forceRefresh = false,
  }) async {
    final employees = await EmployeeRepository.fetchEmployees(
      includeFired: true,
      forceRefresh: forceRefresh,
    );
"""
    method_new = """  static Future<List<AccountingPaymentRegisterRow>> fetchPaymentRegister({
    required DateTime startDate,
    required DateTime endDate,
    String? objectName,
    bool forceRefresh = false,
  }) async {
    final employees = await EmployeeRepository.fetchEmployees(
      objectName: objectName,
      includeFired: true,
      forceRefresh: forceRefresh,
    );
"""
    replace(repository, method_start, method_new)

    path = "lib/features/accounting/presentation/accounting_reports_screen.dart"
    replace(
        path,
        "import '../../../data/employee_repository.dart';\n",
        "import '../../../data/employee_repository.dart';\n"
        "import '../../../data/object_repository.dart';\n",
    )
    replace(
        path,
        "import '../../../widgets/app_page.dart';\n",
        "import '../../../widgets/app_page.dart';\n"
        "import '../../../widgets/object_employee_scope.dart';\n",
    )
    replace(
        path,
        "  bool isExporting = false;\n",
        "  bool isExporting = false;\n"
        "  List<String> objectNames = const <String>[];\n"
        "  String? selectedObjectScope;\n",
    )
    replace(
        path,
        "    registerFuture = loadRegister();\n",
        "    registerFuture = Future.value(\n"
        "      const <AccountingPaymentRegisterRow>[],\n"
        "    );\n"
        "    loadObjects();\n",
    )
    replace(
        path,
        "  DateTime get firstDay => DateTime(selectedMonth.year, selectedMonth.month, 1);\n"
        "  DateTime get lastDay => DateTime(selectedMonth.year, selectedMonth.month + 1, 0);\n",
        "  DateTime get firstDay => DateTime(selectedMonth.year, selectedMonth.month, 1);\n"
        "  DateTime get lastDay => DateTime(selectedMonth.year, selectedMonth.month + 1, 0);\n"
        "  String? get selectedObjectName =>\n"
        "      selectedObjectNameFromScope(selectedObjectScope);\n\n"
        "  Future<void> loadObjects() async {\n"
        "    final names = await ObjectRepository.fetchObjectNames();\n"
        "    if (!mounted) return;\n"
        "    setState(() => objectNames = names);\n"
        "  }\n",
    )
    replace(
        path,
        "    return AccountingRepository.fetchPaymentRegister(\n"
        "      startDate: firstDay,\n"
        "      endDate: lastDay,\n"
        "      forceRefresh: forceRefresh,\n"
        "    );\n",
        "    if (selectedObjectScope == null) {\n"
        "      return Future.value(const <AccountingPaymentRegisterRow>[]);\n"
        "    }\n"
        "    return AccountingRepository.fetchPaymentRegister(\n"
        "      startDate: firstDay,\n"
        "      endDate: lastDay,\n"
        "      objectName: selectedObjectName,\n"
        "      forceRefresh: forceRefresh,\n"
        "    );\n",
    )
    replace(
        path,
        "    final employees = await EmployeeRepository.fetchEmployees(includeFired: true);\n",
        "    final employees = await EmployeeRepository.fetchEmployees(\n"
        "      objectName: selectedObjectName,\n"
        "      includeFired: true,\n"
        "    );\n",
    )
    replace(
        path,
        "        employeeIds: draft.employeeIds.toList(),\n",
        "        employeeIds: draft.employeeIds.toList(),\n"
        "        objectNames: objects,\n",
    )
    replace(
        path,
        "  Future<void> downloadPayments() async {\n"
        "    if (isExporting) return;\n",
        "  Future<void> downloadPayments() async {\n"
        "    if (isExporting || selectedObjectScope == null) return;\n",
    )
    replace(
        path,
        "        request: PaymentReportRequest(month: selectedMonth, employeeKey: null),\n",
        "        request: PaymentReportRequest(\n"
        "          month: selectedMonth,\n"
        "          employeeKey: null,\n"
        "          objectName: selectedObjectName,\n"
        "        ),\n",
    )
    replace(
        path,
        "  void openTimesheet() {\n"
        "    Navigator.push<void>(\n",
        "  void openTimesheet() {\n"
        "    if (selectedObjectScope == null) return;\n"
        "    Navigator.push<void>(\n",
    )
    replace(
        path,
        "        builder: (_) => const PeriodTimesheetScreen(selectedObjectName: null),\n",
        "        builder: (_) => PeriodTimesheetScreen(\n"
        "          selectedObjectName: selectedObjectName,\n"
        "        ),\n",
    )
    object_panel = """  Widget objectPanel() {
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(14),
      child: DropdownButtonFormField<String>(
        initialValue: selectedObjectScope,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Объект',
          hintText: 'Сначала выберите объект',
          prefixIcon: Icon(Icons.apartment_outlined),
          border: OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem<String>(
            value: allObjectsScopeValue,
            child: Text('Все объекты'),
          ),
          ...objectNames.map(
            (name) => DropdownMenuItem<String>(value: name, child: Text(name)),
          ),
        ],
        onChanged: (value) {
          setState(() {
            selectedObjectScope = value;
            registerFuture = loadRegister(forceRefresh: true);
          });
        },
      ),
    );
  }

"""
    replace(path, "  Widget monthPanel() {\n", object_panel + "  Widget monthPanel() {\n")
    replace(
        path,
        "        children: [\n"
        "          monthPanel(),\n",
        "        children: [\n"
        "          objectPanel(),\n"
        "          const SizedBox(height: 14),\n"
        "          monthPanel(),\n",
    )
    replace(
        path,
        "            onTap: isExporting ? null : downloadPayments,\n",
        "            onTap: isExporting || selectedObjectScope == null\n"
        "                ? null\n"
        "                : downloadPayments,\n",
    )
    replace(
        path,
        "            onTap: openTimesheet,\n",
        "            onTap: selectedObjectScope == null ? null : openTimesheet,\n",
    )
    replace(
        path,
        "              return register(snapshot.data ?? const []);\n",
        "              if (selectedObjectScope == null) {\n"
        "                return const PremiumWorkCard(\n"
        "                  child: Padding(\n"
        "                    padding: EdgeInsets.all(22),\n"
        "                    child: Text(\n"
        "                      'Сначала выберите объект или «Все объекты».',\n"
        "                      textAlign: TextAlign.center,\n"
        "                    ),\n"
        "                  ),\n"
        "                );\n"
        "              }\n"
        "              return register(snapshot.data ?? const []);\n",
    )


def patch_legal_directory() -> None:
    models = "lib/features/legal/models/legal_models.dart"
    replace(
        models,
        "  final String subtitle;\n",
        "  final String subtitle;\n"
        "  final String objectName;\n",
        count=1,
    )
    replace(
        models,
        "    this.subtitle = '',\n"
        "  });\n",
        "    this.subtitle = '',\n"
        "    this.objectName = '',\n"
        "  });\n",
        count=1,
    )
    repository = "lib/features/legal/data/legal_directory_repository_part.dart"
    replace(
        repository,
        "        subtitle: subtitle,\n"
        "      );\n",
        "        subtitle: subtitle,\n"
        "        objectName: object,\n"
        "      );\n",
        count=1,
    )
    for parent in (
        "lib/features/legal/presentation/legal_documents_screen.dart",
        "lib/features/legal/presentation/legal_matters_screen.dart",
    ):
        replace(
            parent,
            "import '../../../widgets/app_page.dart';\n",
            "import '../../../widgets/app_page.dart';\n"
            "import '../../../widgets/object_employee_scope.dart';\n",
        )


def legal_helpers(directory_type: str) -> str:
    return f"""  List<LegalDirectoryItem> employeesForObject({directory_type} data) {{
    if (objectId == null) return const <LegalDirectoryItem>[];
    if (isAllObjectsScope(objectId)) {{
      return List<LegalDirectoryItem>.from(data.employees);
    }}
    String? selectedObject;
    for (final item in data.objects) {{
      if (item.id == objectId) {{
        selectedObject = item.title.trim().toLowerCase();
        break;
      }}
    }}
    if (selectedObject == null) return const <LegalDirectoryItem>[];
    return data.employees.where((employee) {{
      return employee.objectName.trim().toLowerCase() == selectedObject;
    }}).toList();
  }}

  String employeeTitle(LegalDirectoryItem item) {{
    if (isAllObjectsScope(objectId) && item.objectName.trim().isNotEmpty) {{
      return '${{item.title}} — ${{item.objectName.trim()}}';
    }}
    return item.subtitle.isEmpty
        ? item.title
        : '${{item.title}} • ${{item.subtitle}}';
  }}

"""


def legal_link_block(prefix: str) -> str:
    return f"""                      DropdownButtonFormField<String>(
                        initialValue: objectFieldValue,
                        decoration: const InputDecoration(
                          labelText: 'Объект',
                          hintText: 'Сначала выберите объект',
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: allObjectsScopeValue,
                            child: Text('Все объекты'),
                          ),
                          ...data.objects.map(directoryItem),
                        ],
                        onChanged: saving
                            ? null
                            : (value) => setState(() {{
                                  objectId = value;
                                  employeeId = null;
                                }}),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey('{prefix}-employee-${{objectId ?? 'none'}}'),
                        initialValue: employeeFieldValue,
                        decoration: InputDecoration(
                          labelText: 'Сотрудник',
                          hintText: objectId == null
                              ? 'Сначала выберите объект'
                              : availableEmployees.isEmpty
                                  ? 'На выбранном объекте нет сотрудников'
                                  : 'Выберите сотрудника',
                        ),
                        items: availableEmployees
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item.id,
                                child: Text(
                                  employeeTitle(item),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: saving || objectId == null
                            ? null
                            : (value) => setState(() => employeeId = value),
                      ),
"""


def patch_legal_document() -> None:
    path = "lib/features/legal/presentation/legal_document_editor_part.dart"
    replace(
        path,
        "      objectId = item.objectId.isEmpty ? null : item.objectId;\n",
        "      objectId = item.objectId.isEmpty\n"
        "          ? allObjectsScopeValue\n"
        "          : item.objectId;\n",
    )
    replace(
        path,
        "        objectId: objectId,\n",
        "        objectId: isAllObjectsScope(objectId) ? null : objectId,\n",
    )
    replace(
        path,
        "  @override\n"
        "  Widget build(BuildContext context) {\n",
        legal_helpers("_DocumentDirectories")
        + "  @override\n"
        + "  Widget build(BuildContext context) {\n",
    )
    replace(
        path,
        "            final data = snapshot.data!;\n"
        "            return Column(\n",
        "            final data = snapshot.data!;\n"
        "            final availableEmployees = employeesForObject(data);\n"
        "            final objectFieldValue = isAllObjectsScope(objectId) ||\n"
        "                    data.objects.any((item) => item.id == objectId)\n"
        "                ? objectId\n"
        "                : null;\n"
        "            final employeeFieldValue = availableEmployees\n"
        "                    .any((item) => item.id == employeeId)\n"
        "                ? employeeId\n"
        "                : null;\n"
        "            return Column(\n",
    )
    old = """                      DropdownButtonFormField<String>(
                        initialValue: data.employees.any((item) => item.id == employeeId) ? employeeId : null,
                        decoration: const InputDecoration(labelText: 'Сотрудник'),
                        items: data.employees.map(directoryItem).toList(),
                        onChanged: saving ? null : (value) => setState(() => employeeId = value),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: data.objects.any((item) => item.id == objectId) ? objectId : null,
                        decoration: const InputDecoration(labelText: 'Объект'),
                        items: data.objects.map(directoryItem).toList(),
                        onChanged: saving ? null : (value) => setState(() => objectId = value),
                      ),
"""
    replace(path, old, legal_link_block("legal-document"))


def patch_legal_matter() -> None:
    path = "lib/features/legal/presentation/legal_matter_editor_part.dart"
    replace(
        path,
        "      objectId = item.objectId.isEmpty ? null : item.objectId;\n",
        "      objectId = item.objectId.isEmpty\n"
        "          ? allObjectsScopeValue\n"
        "          : item.objectId;\n",
    )
    replace(
        path,
        "        objectId: objectId,\n",
        "        objectId: isAllObjectsScope(objectId) ? null : objectId,\n",
    )
    replace(
        path,
        "  @override\n"
        "  Widget build(BuildContext context) {\n",
        legal_helpers("_MatterDirectories")
        + "  @override\n"
        + "  Widget build(BuildContext context) {\n",
    )
    replace(
        path,
        "            final data = snapshot.data!;\n"
        "            return Column(\n",
        "            final data = snapshot.data!;\n"
        "            final availableEmployees = employeesForObject(data);\n"
        "            final objectFieldValue = isAllObjectsScope(objectId) ||\n"
        "                    data.objects.any((item) => item.id == objectId)\n"
        "                ? objectId\n"
        "                : null;\n"
        "            final employeeFieldValue = availableEmployees\n"
        "                    .any((item) => item.id == employeeId)\n"
        "                ? employeeId\n"
        "                : null;\n"
        "            return Column(\n",
    )
    old = """                      DropdownButtonFormField<String>(
                        initialValue: data.employees.any((item) => item.id == employeeId) ? employeeId : null,
                        decoration: const InputDecoration(labelText: 'Сотрудник'),
                        items: data.employees.map(directoryItem).toList(),
                        onChanged: saving ? null : (value) => setState(() => employeeId = value),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: data.objects.any((item) => item.id == objectId) ? objectId : null,
                        decoration: const InputDecoration(labelText: 'Объект'),
                        items: data.objects.map(directoryItem).toList(),
                        onChanged: saving ? null : (value) => setState(() => objectId = value),
                      ),
"""
    replace(path, old, legal_link_block("legal-matter"))


def add_contract_test() -> None:
    write(
        "test/object_first_employee_selection_contract_test.dart",
        """import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('выплата требует объект или все объекты до сотрудника', () {
    final text = source('lib/screens/add_payment_screen.dart');
    expect(text, contains('value: allObjectsScopeValue'));
    expect(
      text.indexOf("labelText: 'Объект'"),
      lessThan(text.indexOf("labelText: 'Сотрудник'")),
    );
    expect(text, contains('filterEmployeesByObject<Employee>'));
    expect(text, contains("'Все объекты'"));
  });

  test('отчёт по выплатам фильтрует сотрудников после объекта', () {
    final sheet = source(
      'lib/features/payments/presentation/widgets/payment_report_sheet.dart',
    );
    final exporter = source(
      'lib/features/payments/data/payment_report_exporter.dart',
    );
    expect(
      sheet.indexOf("labelText: 'Объект'"),
      lessThan(sheet.indexOf("labelText: 'Сотрудник'")),
    );
    expect(sheet, contains('selectedObjectKey == null ? null : submit'));
    expect(sheet, contains('filteredEmployees'));
    expect(exporter, contains('final String? objectName;'));
    expect(exporter, contains('employee.objectNames.any'));
  });

  test('юридические документы и вопросы используют объектный фильтр', () {
    for (final path in <String>[
      'lib/features/legal/presentation/legal_document_editor_part.dart',
      'lib/features/legal/presentation/legal_matter_editor_part.dart',
    ]) {
      final text = source(path);
      expect(
        text.indexOf("labelText: 'Объект'"),
        lessThan(text.indexOf("labelText: 'Сотрудник'")),
      );
      expect(text, contains('value: allObjectsScopeValue'));
      expect(text, contains('employeesForObject'));
      expect(text, contains('employee.objectName'));
    }
  });

  test('бухгалтерские отчёты сначала выбирают объект', () {
    final text = source(
      'lib/features/accounting/presentation/accounting_reports_screen.dart',
    );
    expect(text, contains('Widget objectPanel()'));
    expect(text, contains("child: Text('Все объекты')"));
    expect(text, contains('selectedObjectName: selectedObjectName'));
    expect(text, contains('objectName: selectedObjectName'));
  });
}
""",
    )


def main() -> None:
    add_shared_scope()
    patch_add_payment()
    patch_payment_exporter()
    patch_payment_report_sheet()
    patch_payments_screen()
    patch_accounting()
    patch_legal_directory()
    patch_legal_document()
    patch_legal_matter()
    add_contract_test()


if __name__ == "__main__":
    main()
