class AdminHospital {
  final String id;
  final String name;
  final String address;
  final String phone;
  final String email;
  final String registrationNumber;
  final String status;
  final String? createdAt;

  const AdminHospital({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    required this.registrationNumber,
    required this.status,
    this.createdAt,
  });

  factory AdminHospital.fromJson(Map<String, dynamic> json) => AdminHospital(
    id: '${json['id'] ?? ''}',
    name: '${json['name'] ?? 'Rumah Sakit'}',
    address: '${json['address'] ?? ''}',
    phone: '${json['phone'] ?? ''}',
    email: '${json['email'] ?? ''}',
    registrationNumber: '${json['registrationNumber'] ?? ''}',
    status: '${json['status'] ?? ''}'.toUpperCase(),
    createdAt: json['createdAt']?.toString(),
  );
}

class ChainVerification {
  final bool valid;
  final int totalBlocks;
  final String status;
  final String? message;
  final String? error;

  const ChainVerification({
    required this.valid,
    required this.totalBlocks,
    required this.status,
    this.message,
    this.error,
  });

  factory ChainVerification.fromJson(Map<String, dynamic> json) =>
      ChainVerification(
        valid: json['valid'] == true,
        totalBlocks: (json['totalBlocks'] is num)
            ? (json['totalBlocks'] as num).toInt()
            : 0,
        status: '${json['status'] ?? ''}',
        message: json['message']?.toString(),
        error: json['error']?.toString(),
      );
}
