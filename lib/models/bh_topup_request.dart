class BhTopUpRequest {
  final String id;
  final double requestedAmount;
  final String status; // 'pending', 'approved', 'rejected'
  final String? rejectionReason;
  final DateTime requestedAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final String? approvedBy; // Admin who approved

  BhTopUpRequest({
    required this.id,
    required this.requestedAmount,
    required this.status,
    this.rejectionReason,
    required this.requestedAt,
    this.approvedAt,
    this.rejectedAt,
    this.approvedBy,
  });

  factory BhTopUpRequest.fromJson(Map<String, dynamic> json) {
    return BhTopUpRequest(
      id: json['id'] ?? '',
      requestedAmount: (json['requested_amount'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
      rejectionReason: json['rejection_reason'],
      requestedAt: DateTime.parse(json['requested_at'] ?? DateTime.now().toIso8601String()),
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'])
          : null,
      rejectedAt: json['rejected_at'] != null
          ? DateTime.parse(json['rejected_at'])
          : null,
      approvedBy: json['approved_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requested_amount': requestedAmount,
      'status': status,
      'rejection_reason': rejectionReason,
      'requested_at': requestedAt.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
      'rejected_at': rejectedAt?.toIso8601String(),
      'approved_by': approvedBy,
    };
  }
}

