class TopUpRequest {
  final String id;
  final String loadingStationId;
  final String loadingStationName;
  final String loadingStationCode;
  final double amount;
  final String status; // 'pending', 'approved', 'rejected'
  final String? rejectionReason;
  final DateTime requestedAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;

  TopUpRequest({
    required this.id,
    required this.loadingStationId,
    required this.loadingStationName,
    required this.loadingStationCode,
    required this.amount,
    required this.status,
    this.rejectionReason,
    required this.requestedAt,
    this.approvedAt,
    this.rejectedAt,
  });

  factory TopUpRequest.fromJson(Map<String, dynamic> json) {
    return TopUpRequest(
      id: json['id'] ?? '',
      loadingStationId: json['loading_station_id'] ?? '',
      loadingStationName: json['loading_station_name'] ?? '',
      loadingStationCode: json['loading_station_code'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
      rejectionReason: json['rejection_reason'],
      requestedAt: DateTime.parse(json['requested_at'] ?? DateTime.now().toIso8601String()),
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'])
          : null,
      rejectedAt: json['rejected_at'] != null
          ? DateTime.parse(json['rejected_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'loading_station_id': loadingStationId,
      'loading_station_name': loadingStationName,
      'loading_station_code': loadingStationCode,
      'amount': amount,
      'status': status,
      'rejection_reason': rejectionReason,
      'requested_at': requestedAt.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
      'rejected_at': rejectedAt?.toIso8601String(),
    };
  }
}

