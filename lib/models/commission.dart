class Commission {
  final String id;
  final String transactionId;
  final double commissionRate;
  final double commissionAmount;
  final double bonusAmount;
  final String sourceType; // 'topup' or 'rider_transaction'
  final DateTime createdAt;

  Commission({
    required this.id,
    required this.transactionId,
    required this.commissionRate,
    required this.commissionAmount,
    this.bonusAmount = 0,
    required this.sourceType,
    required this.createdAt,
  });

  factory Commission.fromJson(Map<String, dynamic> json) {
    return Commission(
      id: json['id'] ?? '',
      transactionId: json['transaction_id'] ?? '',
      commissionRate: (json['commission_rate'] ?? 0).toDouble(),
      commissionAmount: (json['commission_amount'] ?? 0).toDouble(),
      bonusAmount: (json['bonus_amount'] ?? 0).toDouble(),
      sourceType: json['source_type'] ?? '',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transaction_id': transactionId,
      'commission_rate': commissionRate,
      'commission_amount': commissionAmount,
      'bonus_amount': bonusAmount,
      'source_type': sourceType,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

