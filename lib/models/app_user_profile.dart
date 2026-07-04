class AppUserProfile {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String objectName;
  final bool isActive;

  const AppUserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.objectName,
    required this.isActive,
  });

  bool get isAdmin {
    return role == 'admin';
  }

  bool get isForeman {
    return role == 'foreman';
  }

  String get roleTitle {
    switch (role) {
      case 'admin':
        return 'Администратор';
      case 'foreman':
        return 'Прораб';
      default:
        return role;
    }
  }

  factory AppUserProfile.fromMap(Map<String, dynamic> map) {
    return AppUserProfile(
      id: map['id']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? '',
      role: map['role']?.toString() ?? 'foreman',
      objectName: map['object_name']?.toString() ?? '',
      isActive: map['is_active'] == true,
    );
  }
}
