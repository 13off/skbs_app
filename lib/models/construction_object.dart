class ConstructionObject {
  final String id;
  final String name;
  final String address;
  final String comment;
  final bool isActive;

  const ConstructionObject({
    required this.id,
    required this.name,
    required this.address,
    required this.comment,
    required this.isActive,
  });

  factory ConstructionObject.fromSupabase(Map<String, dynamic> json) {
    return ConstructionObject(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      comment: json['comment']?.toString() ?? '',
      isActive: json['is_active'] == true,
    );
  }
}
