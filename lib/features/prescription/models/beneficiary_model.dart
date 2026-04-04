class BeneficiaryModel {
  final String id;
  final String name;
  final String type; // self | family
  final String relation;

  const BeneficiaryModel({
    required this.id,
    required this.name,
    required this.type,
    required this.relation,
  });

  bool get isSelf => type == 'self';
}