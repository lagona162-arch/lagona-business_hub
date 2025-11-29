class BusinessHub {
  final String id;
  final String name;
  final String bhCode;
  final String? municipality;
  final double balance;
  final double bonusRate;
  final DateTime createdAt;

  BusinessHub({
    required this.id,
    required this.name,
    required this.bhCode,
    this.municipality,
    required this.balance,
    required this.bonusRate,
    required this.createdAt,
  });

  factory BusinessHub.fromJson(Map<String, dynamic> json) {
    return BusinessHub(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      bhCode: json['bh_code'] ?? '',
      municipality: json['municipality'],
      balance: double.tryParse(json['balance']?.toString() ?? '0') ?? 0.0,
      bonusRate: double.tryParse(json['bonus_rate']?.toString() ?? '0') ?? 0.0,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'bh_code': bhCode,
      'municipality': municipality,
      'balance': balance,
      'bonus_rate': bonusRate,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

