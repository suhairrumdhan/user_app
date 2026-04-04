class MedicineModel {
  final String name;
  final String? dosage;
  final String? route;

  const MedicineModel({
    required this.name,
    this.dosage,
    this.route,
  });

  factory MedicineModel.fromJson(Map<String, dynamic> json) {
    String? cleaned(String key) {
      final value = json[key]?.toString().trim();
      if (value == null || value.isEmpty) return null;
      return value;
    }

    return MedicineModel(
      name: cleaned('name') ?? '',
      dosage: cleaned('dosage'),
      route: cleaned('route'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dosage': dosage,
      'route': route,
    };
  }

  MedicineModel copyWith({
    String? name,
    String? dosage,
    String? route,
  }) {
    return MedicineModel(
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      route: route ?? this.route,
    );
  }

  bool get hasDosage => dosage != null && dosage!.trim().isNotEmpty;
  bool get hasRoute => route != null && route!.trim().isNotEmpty;

  String get displayName {
    final parts = <String>[name];
    if (hasDosage) parts.add(dosage!);
    if (hasRoute) parts.add(route!);
    return parts.join(' - ');
  }
}