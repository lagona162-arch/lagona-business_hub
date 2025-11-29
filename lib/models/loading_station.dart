class LoadingStation {
  final String id;
  final String name;
  final String bhCode;
  final String lsCode;
  final double balance;
  final String status;
  final DateTime createdAt;

  LoadingStation({
    required this.id,
    required this.name,
    required this.bhCode,
    required this.lsCode,
    required this.balance,
    required this.status,
    required this.createdAt,
  });

  factory LoadingStation.fromJson(Map<String, dynamic> json) {
    return LoadingStation(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      bhCode: json['bh_code'] ?? '',
      lsCode: json['ls_code'] ?? '',
      balance: (json['balance'] ?? 0).toDouble(),
      status: json['status'] ?? 'active',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'bh_code': bhCode,
      'ls_code': lsCode,
      'balance': balance,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

