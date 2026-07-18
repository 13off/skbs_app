class AppUserProfile {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String actualRole;
  final String profession;
  final String objectName;
  final String activeCompanyId;
  final bool isActive;

  const AppUserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    String? actualRole,
    this.profession = '',
    required this.objectName,
    required this.activeCompanyId,
    required this.isActive,
  }) : actualRole = actualRole ?? role;

  bool get isAdmin => role == 'admin' || role == 'developer';
  bool get isDeveloper => role == 'developer';
  bool get isForeman => role == 'foreman';
  bool get isLawyer => role == 'lawyer';
  bool get isAccountant => role == 'accountant';
  bool get isHr => role == 'hr';

  bool get isRolePreview => role != actualRole;
  bool get canPreviewRoles =>
      actualRole == 'admin' || actualRole == 'developer';

  String get roleTitle => titleForRole(role);
  String get actualRoleTitle => titleForRole(actualRole);

  static String titleForRole(String role) {
    switch (role) {
      case 'admin':
        return 'Администратор';
      case 'developer':
        return 'Разработчик';
      case 'foreman':
        return 'Прораб';
      case 'lawyer':
        return 'Юрист';
      case 'accountant':
        return 'Бухгалтер';
      case 'hr':
        return 'HR-менеджер';
      default:
        return role;
    }
  }

  AppUserProfile previewAs({required String role, String objectName = ''}) {
    if (!canPreviewRoles) return this;
    return AppUserProfile(
      id: id,
      email: email,
      fullName: fullName,
      role: role,
      actualRole: actualRole,
      profession: profession,
      objectName: objectName,
      activeCompanyId: activeCompanyId,
      isActive: isActive,
    );
  }

  factory AppUserProfile.fromMap(Map<String, dynamic> map) {
    final role = map['role']?.toString() ?? 'foreman';
    return AppUserProfile(
      id: map['id']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? '',
      role: role,
      actualRole: role,
      profession: map['profession']?.toString() ?? '',
      objectName: map['object_name']?.toString() ?? '',
      activeCompanyId: map['active_company_id']?.toString() ?? '',
      isActive: map['is_active'] == true,
    );
  }
}
