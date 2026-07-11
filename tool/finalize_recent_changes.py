from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, text: str) -> None:
    (ROOT / path).write_text(text, encoding="utf-8")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise RuntimeError(f"Не найден блок: {label}")
    return text.replace(old, new, 1)


def patch_task_details() -> None:
    path = "lib/screens/task_details_screen.dart"
    text = read(path)

    old = """          TextField(
            controller: axesController,
            enabled: !isSaving,
            decoration: InputDecoration(
              labelText: 'Оси',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          const SizedBox(height: 14),

          TextField(
            controller: workController,
            enabled: !isSaving,
            minLines: 3,
            maxLines: 7,
            decoration: InputDecoration(
              labelText: 'Вид работ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
"""
    new = """          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Оси',
                style: TextStyle(
                  color: Color(0xFF6B7075),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          TextField(
            controller: axesController,
            enabled: !isSaving,
            decoration: InputDecoration(
              hintText: 'Укажите оси',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          const SizedBox(height: 14),

          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Вид работ',
                style: TextStyle(
                  color: Color(0xFF6B7075),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          TextField(
            controller: workController,
            enabled: !isSaving,
            minLines: 3,
            maxLines: 7,
            decoration: InputDecoration(
              hintText: 'Опишите выполненные работы',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
"""
    text = replace_once(text, old, new, "поля Оси и Вид работ")
    write(path, text)


def patch_employee_repository() -> None:
    path = "lib/data/employee_repository.dart"
    text = read(path)

    old_watch = """      final filteredRows = rows.where((row) {
        final isActive = row['is_active'] as bool? ?? true;

        if (!includeFired && !isActive) return false;
"""
    new_watch = """      final filteredRows = rows.where((row) {
        final isActive = row['is_active'] as bool? ?? true;
        final archivedAt = row['archived_at'];

        if (archivedAt != null) return false;
        if (!includeFired && !isActive) return false;
"""
    text = replace_once(text, old_watch, new_watch, "фильтр архива в stream сотрудников")

    start = text.index("  static Future<List<Employee>> _loadEmployees({")
    end = text.index("  static List<Employee> _employeesFromRows", start)
    current = text[start:end]
    if ".isFilter('archived_at', null)" not in current:
        replacement = """  static Future<List<Employee>> _loadEmployees({
    required String? objectName,
    required bool includeFired,
  }) async {
    const fields =
        'id, fio, position, phone, object_name, daily_rate, is_active, comment, archived_at';

    late final List<dynamic> rows;

    if (objectName == null && includeFired) {
      rows = await _client
          .from('employees')
          .select(fields)
          .isFilter('archived_at', null)
          .order('fio', ascending: true);
    } else if (objectName == null && !includeFired) {
      rows = await _client
          .from('employees')
          .select(fields)
          .isFilter('archived_at', null)
          .eq('is_active', true)
          .order('fio', ascending: true);
    } else if (objectName != null && includeFired) {
      rows = await _client
          .from('employees')
          .select(fields)
          .isFilter('archived_at', null)
          .eq('object_name', objectName)
          .order('fio', ascending: true);
    } else {
      rows = await _client
          .from('employees')
          .select(fields)
          .isFilter('archived_at', null)
          .eq('object_name', objectName!)
          .eq('is_active', true)
          .order('fio', ascending: true);
    }

    return _employeesFromRows(rows);
  }

"""
        text = text[:start] + replacement + text[end:]

    write(path, text)


def patch_employee_archive_repository() -> None:
    path = "lib/data/employee_archive_repository.dart"
    text = read(path)
    old = """        .update({
          'is_active': true,
          'archived_at': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
"""
    new = """        .update({
          'is_active': false,
          'archived_at': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
"""
    text = replace_once(text, old, new, "восстановление сотрудника из архива")
    write(path, text)


def patch_archive_screen() -> None:
    path = "lib/features/archive/presentation/archive_management_screen_v3.dart"
    text = read(path)
    text = text.replace(
        "Сотрудники снова появятся в рабочем списке как активные.",
        "Сотрудники вернутся в рабочий список в раздел «Уволенные».",
    )
    write(path, text)


def patch_employee_details() -> None:
    path = "lib/screens/employee_details_screen.dart"
    text = read(path)

    if "import '../data/employee_archive_repository.dart';" not in text:
        text = text.replace(
            "import '../data/employee_repository.dart';",
            "import '../data/employee_archive_repository.dart';\nimport '../data/employee_repository.dart';",
            1,
        )

    if "bool isArchivingEmployee = false;" not in text:
        text = text.replace(
            "  bool isCopyingEmployee = false;",
            "  bool isCopyingEmployee = false;\n  bool isArchivingEmployee = false;",
            1,
        )

    if "Future<void> archiveCurrentEmployee()" not in text:
        start = text.index("  Future<void> toggleFiredStatus() async {")
        end = text.index("  Widget buildActionTile({", start)
        replacement = """  Future<void> archiveCurrentEmployee() async {
    final employeeId = employee.id?.trim() ?? '';
    if (employeeId.isEmpty || isArchivingEmployee) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Архивировать сотрудника?'),
        content: Text(
          '${employee.name} исчезнет из рабочего списка. Табель, выплаты, документы и личные данные сохранятся.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.archive_outlined),
            label: const Text('В архив'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => isArchivingEmployee = true);
    try {
      await EmployeeArchiveRepository.archiveEmployee(employeeId);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка архивирования: $error')),
      );
    } finally {
      if (mounted) setState(() => isArchivingEmployee = false);
    }
  }

  Future<void> toggleFiredStatus() async {
    final employeeId = employee.id?.trim() ?? '';

    if (employeeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не найден ID сотрудника')),
      );
      return;
    }

    final willFire = employee.isActive;
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(willFire ? 'Уволить сотрудника?' : 'Вернуть сотрудника?'),
        content: Text(
          willFire
              ? '${employee.name} будет перенесён в раздел «Уволенные». При необходимости его можно сразу убрать в архив.'
              : '${employee.name} снова появится в активных сотрудниках.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          if (willFire && widget.profile.isAdmin)
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, 'archive'),
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Уволить и архивировать'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              willFire ? 'fire' : 'restore',
            ),
            child: Text(willFire ? 'Уволить' : 'Вернуть'),
          ),
        ],
      ),
    );

    if (action == null || !mounted) return;

    if (action == 'archive') {
      setState(() => isArchivingEmployee = true);
      try {
        await EmployeeArchiveRepository.archiveEmployee(employeeId);
        if (!mounted) return;
        Navigator.pop(context);
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка архивирования: $error')),
        );
      } finally {
        if (mounted) setState(() => isArchivingEmployee = false);
      }
      return;
    }

    setState(() => isChangingStatus = true);
    try {
      final restored = action == 'restore';
      await EmployeeRepository.setEmployeeActive(
        employeeId: employeeId,
        isActive: restored,
      );

      if (!mounted) return;
      setState(() {
        employee = Employee(
          employee.name,
          employee.position,
          employee.status,
          id: employee.id,
          phone: employee.phone,
          objectName: employee.objectName,
          dailyRate: employee.dailyRate,
          isActive: restored,
          comment: employee.comment,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            restored
                ? 'Сотрудник возвращён в активные'
                : 'Сотрудник отмечен как уволенный',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка изменения статуса: $error')),
      );
    } finally {
      if (mounted) setState(() => isChangingStatus = false);
    }
  }

"""
        text = text[:start] + replacement + text[end:]

    if "tooltip: 'Архивировать'" not in text:
        old = """            _roundHeaderButton(
              tooltip: isFired ? 'Вернуть в активные' : 'Уволить',
              icon: isFired ? Icons.undo : Icons.person_off_outlined,
              onPressed: isChangingStatus || isCopyingEmployee
                  ? null
                  : toggleFiredStatus,
              child: isChangingStatus
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
"""
        new = """            _roundHeaderButton(
              tooltip: isFired ? 'Вернуть в активные' : 'Уволить',
              icon: isFired ? Icons.undo : Icons.person_off_outlined,
              onPressed:
                  isChangingStatus || isCopyingEmployee || isArchivingEmployee
                  ? null
                  : toggleFiredStatus,
              child: isChangingStatus
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
            if (widget.profile.isAdmin && isFired)
              _roundHeaderButton(
                tooltip: 'Архивировать',
                icon: Icons.archive_outlined,
                onPressed:
                    isChangingStatus || isCopyingEmployee || isArchivingEmployee
                    ? null
                    : archiveCurrentEmployee,
                child: isArchivingEmployee
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
"""
        text = replace_once(text, old, new, "кнопки увольнения и архива")

    write(path, text)


def patch_employees_screen() -> None:
    path = "lib/screens/employees_screen.dart"
    text = read(path)

    if "package:flutter/cupertino.dart" not in text:
        text = text.replace(
            "import 'package:flutter/material.dart';",
            "import 'package:flutter/cupertino.dart' show CupertinoPageRoute;\nimport 'package:flutter/material.dart';",
            1,
        )

    text = text.replace("  Employee? openedEmployee;\n", "")
    text = text.replace("      openedEmployee = null;\n", "")

    old_open = """  void openEmployeeDetails(BuildContext context, Employee employee) {
    if (openedEmployee != null) return;

    setState(() {
      openedEmployee = employee;
    });
  }
"""
    new_open = """  Future<void> openEmployeeDetails(
    BuildContext context,
    Employee employee,
  ) async {
    await Navigator.push<void>(
      context,
      CupertinoPageRoute<void>(
        builder: (_) => EmployeeDetailsScreen(
          profile: widget.profile,
          employee: employee,
        ),
      ),
    );

    if (!mounted) return;
    loadEmployees();
  }
"""
    text = replace_once(text, old_open, new_open, "открытие карточки сотрудника")

    old_close = """  void closeEmployeeDetails() {
    if (!mounted || openedEmployee == null) return;

    setState(() {
      openedEmployee = null;
    });

    loadEmployees();
  }

"""
    text = text.replace(old_close, "")

    old_build = """  @override
  Widget build(BuildContext context) {
    final employee = openedEmployee;

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(child: buildEmployeeList()),
        if (employee != null)
          _EmployeeDetailsOverlay(
            key: ValueKey(employee.id ?? employee.name),
            profile: widget.profile,
            employee: employee,
            onClosed: closeEmployeeDetails,
          ),
      ],
    );
  }
}

"""
    new_build = """  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(child: buildEmployeeList());
  }
}

"""
    text = replace_once(text, old_build, new_build, "корневой экран сотрудников")

    if "class _EmployeeDetailsOverlay" in text:
        start = text.index("class _EmployeeDetailsOverlay")
        end = text.index("class _HeaderActionButton", start)
        text = text[:start] + text[end:]

    write(path, text)


def audit() -> None:
    checks = {
        "одна HTML-загрузка": read("web/index.html").count('id="app-loader"') == 1,
        "кирпичная анимация": "brick b1" in read("web/index.html"),
        "нет второй Flutter-загрузки": "PremiumLoadingScreen" not in read("lib/screens/main_screen.dart"),
        "карточка сотрудника как табель": "CupertinoPageRoute<void>" in read("lib/screens/employees_screen.dart"),
        "нет старой задержки карточки": "Duration(milliseconds: 235)" not in read("lib/screens/employees_screen.dart"),
        "архив отделён от увольнения": "archiveCurrentEmployee" in read("lib/screens/employee_details_screen.dart"),
        "обычные списки скрывают архив": ".isFilter('archived_at', null)" in read("lib/data/employee_repository.dart"),
        "архив без вкладки Активные": "SegmentedButton<bool>" not in read("lib/features/archive/presentation/archive_management_screen_v3.dart"),
        "исправлены подписи задачи": "hintText: 'Укажите оси'" in read("lib/screens/task_details_screen.dart"),
    }
    failed = [name for name, ok in checks.items() if not ok]
    for name, ok in checks.items():
        print(f"[{'OK' if ok else 'FAIL'}] {name}")
    if failed:
        raise RuntimeError("Не пройдены проверки: " + ", ".join(failed))


def cleanup_markers() -> None:
    for marker in (ROOT / "tool").glob("*.marker"):
        marker.unlink()


patch_task_details()
patch_employee_repository()
patch_employee_archive_repository()
patch_archive_screen()
patch_employee_details()
patch_employees_screen()
audit()
cleanup_markers()
print("FINALIZATION_OK")
