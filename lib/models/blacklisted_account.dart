class BlacklistedAccount {
  final String id;
  final String entityType; // 'loading_station' or 'rider'
  final String entityId;
  final String entityName;
  final String reason;
  final String status; // 'blacklisted', 'pending_reapplication', 'approved'
  final DateTime blacklistedAt;
  final DateTime? reapplicationRequestedAt;
  final DateTime? reapplicationApprovedAt;

  BlacklistedAccount({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.entityName,
    required this.reason,
    required this.status,
    required this.blacklistedAt,
    this.reapplicationRequestedAt,
    this.reapplicationApprovedAt,
  });

  factory BlacklistedAccount.fromJson(Map<String, dynamic> json) {
    return BlacklistedAccount(
      id: json['id'] ?? '',
      entityType: json['entity_type'] ?? '',
      entityId: json['entity_id'] ?? '',
      entityName: json['entity_name'] ?? '',
      reason: json['reason'] ?? '',
      status: json['status'] ?? 'blacklisted',
      blacklistedAt: DateTime.parse(json['blacklisted_at'] ?? DateTime.now().toIso8601String()),
      reapplicationRequestedAt: json['reapplication_requested_at'] != null
          ? DateTime.parse(json['reapplication_requested_at'])
          : null,
      reapplicationApprovedAt: json['reapplication_approved_at'] != null
          ? DateTime.parse(json['reapplication_approved_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entity_type': entityType,
      'entity_id': entityId,
      'entity_name': entityName,
      'reason': reason,
      'status': status,
      'blacklisted_at': blacklistedAt.toIso8601String(),
      'reapplication_requested_at': reapplicationRequestedAt?.toIso8601String(),
      'reapplication_approved_at': reapplicationApprovedAt?.toIso8601String(),
    };
  }
}

