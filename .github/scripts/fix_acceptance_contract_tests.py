from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    if old not in text:
        raise RuntimeError(f"Expected fragment is missing in {path}: {old!r}")
    if text.count(old) != 1:
        raise RuntimeError(f"Expected one fragment in {path}, found {text.count(old)}")
    file.write_text(text.replace(old, new, 1), encoding="utf-8")


def main() -> None:
    onboarding = "test/foreman_drafts_payments_onboarding_contract_test.dart"
    replace_once(
        onboarding,
        "    expect(guide, contains('coordinateBox.globalToLocal(globalTopLeft)'));",
        """    expect(
      guide,
      matches(
        RegExp(
          r'coordinateBox\\s*\\.\\s*globalToLocal\\s*\\(\\s*globalTopLeft\\s*,?\\s*\\)',
        ),
      ),
    );""",
    )
    replace_once(
        onboarding,
        "    expect(guide, contains('coordinateBox.globalToLocal(globalBottomRight)'));",
        """    expect(
      guide,
      matches(
        RegExp(
          r'coordinateBox\\s*\\.\\s*globalToLocal\\s*\\(\\s*globalBottomRight\\s*,?\\s*\\)',
        ),
      ),
    );""",
    )

    title_only = "test/title_only_action_controls_contract_test.dart"
    replace_once(
        title_only,
        "    expect(rolePreview, contains('badge: preview.isForemanMode'));",
        """    expect(
      rolePreview,
      matches(RegExp(r'badge:\\s*preview\\.isForemanMode')),
    );""",
    )
    replace_once(
        title_only,
        "    expect(rolePreview, contains('badge: preview.isEmployeeMode'));",
        """    expect(
      rolePreview,
      matches(RegExp(r'badge:\\s*preview\\.isEmployeeMode')),
    );""",
    )

    desktop_timesheet = "test/desktop_timesheet_contract_test.dart"
    replace_once(
        desktop_timesheet,
        """    expect(
      desktop,
      contains('BoxConstraints(maxWidth: double.infinity)'),
    );""",
        """    expect(
      desktop,
      matches(
        RegExp(
          r'BoxConstraints\\(\\s*maxWidth:\\s*double\\.infinity\\s*,?\\s*\\)',
        ),
      ),
    );""",
    )

    desktop_full_width = "test/desktop_full_width_contract_test.dart"
    replace_once(
        desktop_full_width,
        """        contains(
          'constraints: const BoxConstraints(maxWidth: double.infinity)',
        ),""",
        """        matches(
          RegExp(
            r'constraints:\\s*const\\s+BoxConstraints\\(\\s*maxWidth:\\s*double\\.infinity\\s*,?\\s*\\)',
          ),
        ),""",
    )

    notification = "test/notification_control_center_contract_test.dart"
    replace_once(
        notification,
        "String source(String path) => File(path).readAsStringSync();\n",
        """String source(String path) => File(path).readAsStringSync();

String notificationControlMigrationPath() {
  final matches = Directory('supabase/migrations')
      .listSync()
      .where(
        (entry) =>
            entry is File &&
            entry.path.endsWith('_notification_control_center.sql'),
      )
      .toList();
  expect(matches, hasLength(1));
  return matches.single.path;
}
""",
    )
    migration_path = (
        "'supabase/migrations/20260718150000_notification_control_center.sql'"
    )
    file = Path(notification)
    text = file.read_text(encoding="utf-8")
    count = text.count(migration_path)
    if count != 2:
        raise RuntimeError(
            f"Expected two notification migration references, found {count}"
        )
    file.write_text(
        text.replace(migration_path, "notificationControlMigrationPath()"),
        encoding="utf-8",
    )

    desktop_employees = "test/desktop_employees_contract_test.dart"
    replace_once(
        desktop_employees,
        """    expect(
      desktop,
      contains('BoxConstraints(maxWidth: double.infinity)'),
    );""",
        """    expect(
      desktop,
      matches(
        RegExp(
          r'BoxConstraints\\(\\s*maxWidth:\\s*double\\.infinity\\s*,?\\s*\\)',
        ),
      ),
    );""",
    )

    employee_shift = "test/employee_shift_geolocation_contract_test.dart"
    replace_once(
        employee_shift,
        "    expect(home, contains('active\\n                                ? finishDay'));",
        """    expect(
      home,
      matches(RegExp(r'active\\s*\\?\\s*finishDay')),
    );""",
    )

    replace_once(
        "test/exact_docx_service_test.dart",
        "    expect(screen, contains(\"ext: 'docx'\"));",
        "    expect(screen, contains(\"fileExtension: 'docx'\"));",
    )

    replace_once(
        "test/bottom_navigation_surface_consistency_contract_test.dart",
        "    expect(liquid, contains('final resolvedGradient = gradient ??'));",
        """    expect(
      liquid,
      matches(RegExp(r'final\\s+resolvedGradient\\s*=\\s*gradient\\s*\\?\\?')),
    );""",
    )


if __name__ == "__main__":
    main()
