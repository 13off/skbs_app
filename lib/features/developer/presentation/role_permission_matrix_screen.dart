import 'package:flutter/material.dart';

import '../../../widgets/app_page.dart';
import '../../../widgets/premium_ui.dart';
import '../data/role_permission_repository.dart';
import '../models/role_permission_matrix.dart';

class RolePermissionMatrixScreen extends StatefulWidget {
  const RolePermissionMatrixScreen({super.key});

  @override
  State<RolePermissionMatrixScreen> createState() =>
      _RolePermissionMatrixScreenState();
}

class _RolePermissionMatrixScreenState
    extends State<RolePermissionMatrixScreen> {
  static const String companyScope = '__company__';

  RolePermissionCenter? center;
  bool loading = true;
  String? errorText;
  String? busyKey;
  String selectedScope = companyScope;
  String selectedMobileRole = 'foreman';

  String? get selectedObjectId =>
      selectedScope == companyScope ? null : selectedScope;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      errorText = null;
    });
    try {
      final value = await RolePermissionRepository.fetchCenter();
      if (!mounted) return;
      setState(() {
        center = value;
        loading = false;
        if (!value.roles.any((role) => role.code == selectedMobileRole)) {
          selectedMobileRole = value.roles
              .firstWhere(
                (role) => role.code != 'owner',
                orElse: () =>
                    const RolePermissionRole(code: 'foreman', title: 'Прораб'),
              )
              .code;
        }
        if (selectedScope != companyScope &&
            !value.objects.any((object) => object.id == selectedScope)) {
          selectedScope = companyScope;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorText = cleanError(error);
      });
    }
  }

  String cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  String keyFor(String roleCode, String permissionCode) {
    return '${selectedObjectId ?? 'company'}:$roleCode:$permissionCode';
  }

  Future<void> savePermission({
    required String roleCode,
    required String permissionCode,
    required bool isAllowed,
  }) async {
    final key = keyFor(roleCode, permissionCode);
    if (busyKey != null) return;
    setState(() {
      busyKey = key;
      errorText = null;
    });
    try {
      final value = await RolePermissionRepository.saveOverride(
        roleCode: roleCode,
        permissionCode: permissionCode,
        isAllowed: isAllowed,
        objectId: selectedObjectId,
      );
      if (!mounted) return;
      setState(() => center = value);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Право сохранено')));
    } catch (error) {
      if (mounted) setState(() => errorText = cleanError(error));
    } finally {
      if (mounted) setState(() => busyKey = null);
    }
  }

  Future<void> resetPermission({
    required String roleCode,
    required String permissionCode,
  }) async {
    final key = keyFor(roleCode, permissionCode);
    if (busyKey != null) return;
    setState(() {
      busyKey = key;
      errorText = null;
    });
    try {
      final value = await RolePermissionRepository.resetOverride(
        roleCode: roleCode,
        permissionCode: permissionCode,
        objectId: selectedObjectId,
      );
      if (!mounted) return;
      setState(() => center = value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            selectedObjectId == null
                ? 'Возвращено базовое право роли'
                : 'Объект снова наследует настройки компании',
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => errorText = cleanError(error));
    } finally {
      if (mounted) setState(() => busyKey = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Матрица ролей',
      subtitle: 'Права компании и отдельные исключения по объектам',
      showBackButton: true,
      headerTrailing: IconButton(
        tooltip: 'Обновить',
        onPressed: loading || busyKey != null ? null : load,
        icon: const Icon(Icons.refresh_rounded),
      ),
      child: loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          : center == null
          ? _ErrorState(message: errorText ?? 'Матрица недоступна', retry: load)
          : buildContent(),
    );
  }

  Widget buildContent() {
    final value = center!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 920;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildScopeCard(value),
            if (errorText != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  errorText!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (desktop)
              buildDesktopMatrix(value)
            else
              buildMobileMatrix(value),
            const SizedBox(height: 18),
            buildAudit(value),
          ],
        );
      },
    );
  }

  Widget buildScopeCard(RolePermissionCenter value) {
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_tree_outlined),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Область действия',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            selectedObjectId == null
                ? 'Изменения применяются ко всей компании. Объект может иметь собственное исключение.'
                : 'Показаны только права, которые можно переопределить для выбранного объекта.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: selectedScope,
            decoration: const InputDecoration(
              labelText: 'Компания или объект',
              prefixIcon: Icon(Icons.apartment_rounded),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: companyScope,
                child: Text('Вся компания'),
              ),
              ...value.objects.map(
                (object) => DropdownMenuItem<String>(
                  value: object.id,
                  child: Text(
                    object.isActive ? object.name : '${object.name} · архив',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: busyKey != null
                ? null
                : (next) {
                    if (next == null) return;
                    setState(() => selectedScope = next);
                  },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Синяя отметка означает явное исключение. Кнопка сброса возвращает наследование.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildDesktopMatrix(RolePermissionCenter value) {
    final groups = value.groupedPermissions(objectId: selectedObjectId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: groups.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: PremiumWorkCard(
            radius: 24,
            padding: const EdgeInsets.fromLTRB(14, 15, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 54,
                    dataRowMinHeight: 66,
                    dataRowMaxHeight: 82,
                    horizontalMargin: 10,
                    columnSpacing: 18,
                    columns: [
                      const DataColumn(
                        label: SizedBox(width: 270, child: Text('Право')),
                      ),
                      ...value.roles.map(
                        (role) => DataColumn(
                          label: SizedBox(
                            width: 112,
                            child: Text(
                              role.title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    rows: entry.value.map((permission) {
                      return DataRow(
                        cells: [
                          DataCell(
                            SizedBox(
                              width: 270,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    permission.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (permission.description.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      permission.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          ...value.roles.map(
                            (role) => DataCell(
                              SizedBox(
                                width: 112,
                                child: Center(
                                  child: buildPermissionControl(
                                    value,
                                    role: role,
                                    permission: permission,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget buildMobileMatrix(RolePermissionCenter value) {
    final groups = value.groupedPermissions(objectId: selectedObjectId);
    final role = value.roles.firstWhere(
      (item) => item.code == selectedMobileRole,
      orElse: () => value.roles.first,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PremiumWorkCard(
          radius: 22,
          padding: const EdgeInsets.all(14),
          child: DropdownButtonFormField<String>(
            value: role.code,
            decoration: const InputDecoration(
              labelText: 'Настраиваемая роль',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            items: value.roles
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item.code,
                    child: Text(item.title),
                  ),
                )
                .toList(),
            onChanged: busyKey != null
                ? null
                : (next) {
                    if (next != null) setState(() => selectedMobileRole = next);
                  },
          ),
        ),
        const SizedBox(height: 14),
        ...groups.entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: PremiumWorkCard(
              radius: 22,
              padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...entry.value.map(
                    (permission) => _MobilePermissionTile(
                      title: permission.title,
                      subtitle: permission.description,
                      control: buildPermissionControl(
                        value,
                        role: role,
                        permission: permission,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildPermissionControl(
    RolePermissionCenter value, {
    required RolePermissionRole role,
    required RolePermissionDefinition permission,
  }) {
    final allowed = value.allowed(
      roleCode: role.code,
      permissionCode: permission.code,
      objectId: selectedObjectId,
    );
    final overridden = value.hasOverride(
      roleCode: role.code,
      permissionCode: permission.code,
      objectId: selectedObjectId,
    );
    final key = keyFor(role.code, permission.code);
    final busy = busyKey == key;
    final editable = value.canEditRole(role.code) && !busy;

    if (role.code == 'owner') {
      return const Tooltip(
        message: 'Владелец всегда имеет полный доступ',
        child: Icon(Icons.verified_user_rounded),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (busy)
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          )
        else
          Switch.adaptive(
            value: allowed,
            onChanged: editable
                ? (next) => savePermission(
                    roleCode: role.code,
                    permissionCode: permission.code,
                    isAllowed: next,
                  )
                : null,
          ),
        if (overridden)
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: selectedObjectId == null
                ? 'Вернуть базовое право роли'
                : 'Вернуть настройки компании',
            onPressed: editable
                ? () => resetPermission(
                    roleCode: role.code,
                    permissionCode: permission.code,
                  )
                : null,
            icon: const Icon(Icons.settings_backup_restore_rounded, size: 19),
          )
        else
          const SizedBox(width: 40),
      ],
    );
  }

  Widget buildAudit(RolePermissionCenter value) {
    return PremiumWorkCard(
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.manage_history_rounded),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Последние изменения прав',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (value.audit.isEmpty)
            Text(
              'Матрица ещё не изменялась.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            ...value.audit.take(20).map((entry) {
              final permission = value.permissions.where(
                (item) => item.code == entry.permissionCode,
              );
              final permissionTitle = permission.isEmpty
                  ? entry.permissionCode
                  : permission.first.title;
              final scopeTitle = entry.scope == 'object'
                  ? value.objectTitle(entry.objectId)
                  : 'Вся компания';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: Icon(
                    entry.afterAllowed
                        ? Icons.check_rounded
                        : Icons.block_rounded,
                    size: 19,
                  ),
                ),
                title: Text(
                  '${value.roleTitle(entry.roleCode)} · $permissionTitle',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '$scopeTitle · ${entry.actorName.isEmpty ? 'Пользователь' : entry.actorName} · ${formatDate(entry.createdAt)}',
                ),
                trailing: Text(
                  entry.action == 'reset'
                      ? 'Наследование'
                      : entry.afterAllowed
                      ? 'Разрешено'
                      : 'Запрещено',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              );
            }),
        ],
      ),
    );
  }

  String formatDate(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class _MobilePermissionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget control;

  const _MobilePermissionTile({
    required this.title,
    required this.subtitle,
    required this.control,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          control,
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback retry;

  const _ErrorState({required this.message, required this.retry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 70),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, size: 44),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Повторить'),
          ),
        ],
      ),
    );
  }
}
