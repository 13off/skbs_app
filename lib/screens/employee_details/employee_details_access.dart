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
      SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
    );
  }

  Future<void> copyMaxConnectionValue(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Данные подключения MAX скопированы')),
    );
  }

  Future<void> showMaxConnectionDialog(EmployeeAccessState state) async {
    if (!mounted) return;
    if (state.maxConnected) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('MAX подключён'),
          content: Text(
            state.maxUsername.isEmpty
                ? 'Коды входа AppСтрой будут приходить сотруднику в чат «СКБС Работа».'
                : 'Коды входа AppСтрой будут приходить в MAX-профиль @${state.maxUsername}.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Готово'),
            ),
          ],
        ),
      );
      return;
    }

    final connectionValue = state.maxConnectUrl.isNotEmpty
        ? state.maxConnectUrl
        : state.maxConnectCode;
    final expires = state.maxConnectExpiresAt?.toLocal();
    final expiresText = expires == null
        ? ''
        : '\n\nСсылка действует до ${formatDateTime(expires)}.';
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Подключить MAX'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Передайте сотруднику эти данные. Он откроет бота «СКБС Работа», подтвердит свой номер и после этого будет бесплатно получать коды входа в MAX.',
            ),
            const SizedBox(height: 16),
            SelectableText(
              connectionValue.isEmpty
                  ? 'Не удалось сформировать код подключения'
                  : connectionValue,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if (expiresText.isNotEmpty) Text(expiresText),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
          FilledButton.icon(
            onPressed: connectionValue.isEmpty
                ? null
                : () => copyMaxConnectionValue(connectionValue),
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Скопировать'),
          ),
        ],
      ),
    );
  }

  Future<void> prepareEmployeeMax() async {
    if (isChangingEmployeeAccess) return;
    final employeeId = employee.id?.trim() ?? '';
    if (employeeId.isEmpty) {
      showEmployeeAccessError(Exception('Не найден ID сотрудника'));
      return;
    }

    rebuildEmployeeDetails(() => isChangingEmployeeAccess = true);
    try {
      final next = await EmployeeAccessRepository.prepareMax(employeeId);
      if (!mounted) return;
      rebuildEmployeeDetails(() {
        employeeAccessFuture = Future<EmployeeAccessState>.value(next);
      });
      await showMaxConnectionDialog(next);
    } catch (error) {
      showEmployeeAccessError(error);
    } finally {
      rebuildEmployeeDetails(() => isChangingEmployeeAccess = false);
    }
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
              ? 'Для ${employee.name} будет создан личный кабинет по номеру ${phone.isEmpty ? 'из карточки сотрудника' : phone}. Коды входа будут приходить бесплатно через MAX. Сотрудник увидит только свои задачи, табель, выплаты и документы.'
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
                ? next.maxConnected
                      ? 'Доступ включён, MAX найден и подключён'
                      : 'Доступ включён. Осталось подключить MAX'
                : 'Доступ сотрудника отключён',
          ),
        ),
      );
      if (enable && !next.maxConnected) {
        await showMaxConnectionDialog(next);
      }
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
        final accessSubtitle = hasError
            ? 'Не удалось проверить доступ. Нажмите, чтобы повторить'
            : active
            ? 'Личный кабинет включён${state!.phone.isEmpty ? '' : ': ${state.phone}'}'
            : state?.connected == true
            ? 'Кабинет создан, но вход сотрудника отключён'
            : 'Создать личный кабинет сотрудника';
        final maxSubtitle = state?.maxConnected == true
            ? state!.maxUsername.isEmpty
                  ? 'Подключён — коды входа приходят в «СКБС Работа»'
                  : 'Подключён: @${state.maxUsername}'
            : 'Подключить для бесплатных кодов входа';

        return Card(
          elevation: 0,
          color: AppAdaptivePalette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              ListTile(
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
                subtitle: Text(accessSubtitle),
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
              if (active && !hasError) ...[
                const Divider(height: 1),
                ListTile(
                  minVerticalPadding: 12,
                  leading: Icon(
                    state?.maxConnected == true
                        ? Icons.mark_chat_read_rounded
                        : Icons.add_comment_rounded,
                  ),
                  title: const Text(
                    'MAX',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(maxSubtitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: loading
                      ? null
                      : state?.maxConnected == true
                      ? () => showMaxConnectionDialog(state!)
                      : prepareEmployeeMax,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
