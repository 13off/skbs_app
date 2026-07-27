part of '../employee_details_screen.dart';

extension _EmployeeDetailsAccess on _EmployeeDetailsScreenState {
  void refreshEmployeeAccess({bool rebuild = false}) {
    final employeeId = employee.id?.trim() ?? '';
    if (!widget.profile.isAdmin || employeeId.isEmpty) {
      employeeAccessFuture = null;
      return;
    }
    final next = EmployeeAccessRepository.fetchStatus(employeeId);
    if (rebuild && mounted) {
      rebuildEmployeeDetails(() => employeeAccessFuture = next);
    } else {
      employeeAccessFuture = next;
    }
  }

  void showEmployeeAccessError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString().replaceFirst('Exception: ', '')),
      ),
    );
  }

  Future<void> changeEmployeeAccess({required bool enable}) async {
    if (isChangingEmployeeAccess) return;
    final employeeId = employee.id?.trim() ?? '';
    if (employeeId.isEmpty) {
      showEmployeeAccessError(Exception('Не найден ID сотрудника'));
      return;
    }

    final phone = employee.phone.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(enable ? 'Открыть доступ?' : 'Отключить доступ?'),
        content: Text(
          enable
              ? 'Для ${employee.name} будет создан личный кабинет с входом по номеру ${phone.isEmpty ? 'из карточки сотрудника' : phone}. Сотрудник увидит только свои задачи, табель, выплаты и документы.'
              : '${employee.name} больше не сможет войти в личный кабинет. Рабочие данные и история сохранятся.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(enable ? 'Открыть доступ' : 'Отключить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    rebuildEmployeeDetails(() => isChangingEmployeeAccess = true);
    try {
      final next = enable
          ? await EmployeeAccessRepository.enable(employeeId)
          : await EmployeeAccessRepository.disable(employeeId);
      if (!mounted) return;
      rebuildEmployeeDetails(() {
        employeeAccessFuture = Future<EmployeeAccessState>.value(next);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enable
                ? 'Доступ сотрудника включён'
                : 'Доступ сотрудника отключён',
          ),
        ),
      );
    } catch (error) {
      showEmployeeAccessError(error);
    } finally {
      rebuildEmployeeDetails(() => isChangingEmployeeAccess = false);
    }
  }

  Widget buildEmployeeAccessTile() {
    final future = employeeAccessFuture;
    if (!widget.profile.isAdmin || future == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<EmployeeAccessState>(
      future: future,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final loading =
            snapshot.connectionState == ConnectionState.waiting ||
            isChangingEmployeeAccess;
        final active = state?.active == true;
        final hasError = snapshot.hasError;
        final subtitle = hasError
            ? 'Не удалось проверить доступ. Нажмите, чтобы повторить'
            : active
            ? 'Вход по СМС подключён${state!.phone.isEmpty ? '' : ': ${state.phone}'}'
            : state?.connected == true
            ? 'Кабинет создан, но вход сотрудника отключён'
            : 'Создать личный кабинет и разрешить вход по СМС';

        return Card(
          elevation: 0,
          color: AppAdaptivePalette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            minVerticalPadding: 14,
            leading: loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    active
                        ? Icons.phone_iphone_rounded
                        : Icons.phonelink_lock_rounded,
                  ),
            title: const Text(
              'Доступ в приложение',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(subtitle),
            trailing: hasError
                ? const Icon(Icons.refresh_rounded)
                : Switch.adaptive(
                    value: active,
                    onChanged: loading
                        ? null
                        : (value) => changeEmployeeAccess(enable: value),
                  ),
            onTap: loading
                ? null
                : hasError
                ? () => refreshEmployeeAccess(rebuild: true)
                : () => changeEmployeeAccess(enable: !active),
          ),
        );
      },
    );
  }
}
