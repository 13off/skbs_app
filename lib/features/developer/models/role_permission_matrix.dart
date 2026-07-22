class RolePermissionRole {
  final String code;
  final String title;

  const RolePermissionRole({required this.code, required this.title});

  factory RolePermissionRole.fromJson(Map<String, dynamic> json) {
    return RolePermissionRole(
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
    );
  }
}

class RolePermissionDefinition {
  final String code;
  final String category;
  final String title;
  final String description;
  final bool supportsObjectScope;
  final int sortOrder;

  const RolePermissionDefinition({
    required this.code,
    required this.category,
    required this.title,
    required this.description,
    required this.supportsObjectScope,
    required this.sortOrder,
  });

  factory RolePermissionDefinition.fromJson(Map<String, dynamic> json) {
    return RolePermissionDefinition(
      code: json['code']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Прочее',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      supportsObjectScope: json['supports_object_scope'] == true,
      sortOrder: int.tryParse(json['sort_order']?.toString() ?? '') ?? 0,
    );
  }
}

class RolePermissionObject {
  final String id;
  final String name;
  final bool isActive;

  const RolePermissionObject({
    required this.id,
    required this.name,
    required this.isActive,
  });

  factory RolePermissionObject.fromJson(Map<String, dynamic> json) {
    return RolePermissionObject(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      isActive: json['is_active'] == true,
    );
  }
}

class RolePermissionOverride {
  final String? objectId;
  final String roleCode;
  final String permissionCode;
  final bool isAllowed;
  final DateTime? updatedAt;

  const RolePermissionOverride({
    required this.objectId,
    required this.roleCode,
    required this.permissionCode,
    required this.isAllowed,
    required this.updatedAt,
  });

  factory RolePermissionOverride.fromJson(
    Map<String, dynamic> json, {
    String? objectId,
  }) {
    return RolePermissionOverride(
      objectId: objectId ?? json['object_id']?.toString(),
      roleCode: json['role_code']?.toString() ?? '',
      permissionCode: json['permission_code']?.toString() ?? '',
      isAllowed: json['is_allowed'] == true,
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    );
  }
}

class RolePermissionAuditEntry {
  final int id;
  final String? objectId;
  final String scope;
  final String roleCode;
  final String permissionCode;
  final String action;
  final bool? beforeAllowed;
  final bool afterAllowed;
  final String actorName;
  final DateTime? createdAt;

  const RolePermissionAuditEntry({
    required this.id,
    required this.objectId,
    required this.scope,
    required this.roleCode,
    required this.permissionCode,
    required this.action,
    required this.beforeAllowed,
    required this.afterAllowed,
    required this.actorName,
    required this.createdAt,
  });

  factory RolePermissionAuditEntry.fromJson(Map<String, dynamic> json) {
    return RolePermissionAuditEntry(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      objectId: json['object_id']?.toString(),
      scope: json['scope']?.toString() ?? 'company',
      roleCode: json['role_code']?.toString() ?? '',
      permissionCode: json['permission_code']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      beforeAllowed: json['before_allowed'] is bool
          ? json['before_allowed'] as bool
          : null,
      afterAllowed: json['after_allowed'] == true,
      actorName: json['actor_name']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

class RolePermissionCenter {
  final String actorRole;
  final List<RolePermissionRole> roles;
  final List<RolePermissionDefinition> permissions;
  final Set<String> defaults;
  final Map<String, bool> companyOverrides;
  final List<RolePermissionObject> objects;
  final Map<String, bool> objectOverrides;
  final List<RolePermissionAuditEntry> audit;

  const RolePermissionCenter({
    required this.actorRole,
    required this.roles,
    required this.permissions,
    required this.defaults,
    required this.companyOverrides,
    required this.objects,
    required this.objectOverrides,
    required this.audit,
  });

  factory RolePermissionCenter.fromJson(Map<String, dynamic> json) {
    final roles = _maps(json['roles'])
        .map(RolePermissionRole.fromJson)
        .where((item) => item.code.isNotEmpty)
        .toList();
    final permissions = _maps(json['permissions'])
        .map(RolePermissionDefinition.fromJson)
        .where((item) => item.code.isNotEmpty)
        .toList()
      ..sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        return order == 0 ? a.code.compareTo(b.code) : order;
      });

    final defaults = <String>{};
    for (final item in _maps(json['defaults'])) {
      final role = item['role_code']?.toString() ?? '';
      final permission = item['permission_code']?.toString() ?? '';
      if (role.isNotEmpty && permission.isNotEmpty) {
        defaults.add(_permissionKey(role, permission));
      }
    }

    final companyOverrides = <String, bool>{};
    for (final item in _maps(json['company_overrides'])) {
      final value = RolePermissionOverride.fromJson(item);
      if (value.roleCode.isNotEmpty && value.permissionCode.isNotEmpty) {
        companyOverrides[_permissionKey(
          value.roleCode,
          value.permissionCode,
        )] = value.isAllowed;
      }
    }

    final objectOverrides = <String, bool>{};
    for (final item in _maps(json['object_overrides'])) {
      final value = RolePermissionOverride.fromJson(item);
      final objectId = value.objectId?.trim() ?? '';
      if (objectId.isNotEmpty &&
          value.roleCode.isNotEmpty &&
          value.permissionCode.isNotEmpty) {
        objectOverrides[_objectPermissionKey(
          objectId,
          value.roleCode,
          value.permissionCode,
        )] = value.isAllowed;
      }
    }

    return RolePermissionCenter(
      actorRole: json['actor_role']?.toString() ?? '',
      roles: roles,
      permissions: permissions,
      defaults: defaults,
      companyOverrides: companyOverrides,
      objects: _maps(json['objects'])
          .map(RolePermissionObject.fromJson)
          .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
          .toList(),
      objectOverrides: objectOverrides,
      audit: _maps(json['audit'])
          .map(RolePermissionAuditEntry.fromJson)
          .toList(),
    );
  }

  bool allowed({
    required String roleCode,
    required String permissionCode,
    String? objectId,
  }) {
    if (roleCode == 'owner') return true;

    final normalizedObjectId = objectId?.trim() ?? '';
    if (normalizedObjectId.isNotEmpty) {
      final objectKey = _objectPermissionKey(
        normalizedObjectId,
        roleCode,
        permissionCode,
      );
      if (objectOverrides.containsKey(objectKey)) {
        return objectOverrides[objectKey] ?? false;
      }
    }

    final companyKey = _permissionKey(roleCode, permissionCode);
    if (companyOverrides.containsKey(companyKey)) {
      return companyOverrides[companyKey] ?? false;
    }
    return defaults.contains(companyKey);
  }

  bool hasOverride({
    required String roleCode,
    required String permissionCode,
    String? objectId,
  }) {
    final normalizedObjectId = objectId?.trim() ?? '';
    if (normalizedObjectId.isNotEmpty) {
      return objectOverrides.containsKey(
        _objectPermissionKey(
          normalizedObjectId,
          roleCode,
          permissionCode,
        ),
      );
    }
    return companyOverrides.containsKey(
      _permissionKey(roleCode, permissionCode),
    );
  }

  bool canEditRole(String roleCode) {
    if (roleCode == 'owner') return false;
    if (actorRole == 'admin') {
      return roleCode != 'admin' && roleCode != 'developer';
    }
    return actorRole == 'developer' || actorRole == 'owner';
  }

  String roleTitle(String roleCode) {
    for (final role in roles) {
      if (role.code == roleCode) return role.title;
    }
    return roleCode;
  }

  String objectTitle(String? objectId) {
    final id = objectId?.trim() ?? '';
    if (id.isEmpty) return 'Вся компания';
    for (final object in objects) {
      if (object.id == id) return object.name;
    }
    return 'Объект';
  }

  Map<String, List<RolePermissionDefinition>> groupedPermissions({
    String? objectId,
  }) {
    final result = <String, List<RolePermissionDefinition>>{};
    final isObjectScope = (objectId?.trim().isNotEmpty ?? false);
    for (final permission in permissions) {
      if (isObjectScope && !permission.supportsObjectScope) continue;
      result.putIfAbsent(permission.category, () => []).add(permission);
    }
    return result;
  }
}

List<Map<String, dynamic>> _maps(dynamic value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

String _permissionKey(String roleCode, String permissionCode) {
  return '$roleCode\u0000$permissionCode';
}

String _objectPermissionKey(
  String objectId,
  String roleCode,
  String permissionCode,
) {
  return '$objectId\u0000${_permissionKey(roleCode, permissionCode)}';
}
