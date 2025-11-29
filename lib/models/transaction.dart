class Transaction {
  final String id;
  final String type; // 'topup', 'commission', 'bonus'
  final double amount;
  final double bonusAmount;
  final String? fromEntityId; // Loading Station or Rider ID
  final String? fromEntityType; // 'loading_station' or 'rider'
  final String? fromEntityName;
  final String status;
  final DateTime createdAt;

  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    this.bonusAmount = 0,
    this.fromEntityId,
    this.fromEntityType,
    this.fromEntityName,
    required this.status,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] ?? '',
      type: json['type'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      bonusAmount: (json['bonus_amount'] ?? 0).toDouble(),
      fromEntityId: json['from_entity_id'],
      fromEntityType: json['from_entity_type'],
      fromEntityName: json['from_entity_name'],
      status: json['status'] ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'bonus_amount': bonusAmount,
      'from_entity_id': fromEntityId,
      'from_entity_type': fromEntityType,
      'from_entity_name': fromEntityName,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

