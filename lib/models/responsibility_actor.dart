class ResponsibilityActor {
  final String? userId;
  final String fullName;
  final String? avatarPath;
  final DateTime? actedAt;

  const ResponsibilityActor({
    this.userId,
    required this.fullName,
    this.avatarPath,
    this.actedAt,
  });

  bool get hasIdentity => fullName.trim().isNotEmpty;

  static String? cleanText(Object? value) {
    final clean = value?.toString().trim();
    return clean == null || clean.isEmpty ? null : clean;
  }

  factory ResponsibilityActor.fromMap(
    Map<String, dynamic> row, {
    required String userIdKey,
    required String fullNameKey,
    required String avatarPathKey,
    required String actedAtKey,
  }) {
    final fullName = cleanText(row[fullNameKey]) ?? '';
    return ResponsibilityActor(
      userId: cleanText(row[userIdKey]),
      fullName: fullName,
      avatarPath: cleanText(row[avatarPathKey]),
      actedAt: DateTime.tryParse(row[actedAtKey]?.toString() ?? '')?.toLocal(),
    );
  }
}
