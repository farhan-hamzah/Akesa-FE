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

class HospitalApplication {
  final String id;
  final String invitationId;
  final String applicantUserId;
  final String name;
  final String address;
  final String phone;
  final String email;
  final String registrationNumber;
  final String npwp;
  final String licenseDocumentUrl;
  final String picFullName;
  final String picPosition;
  final String status;
  final String? notes;
  final String? createdAt;
  final String? updatedAt;

  const HospitalApplication({
    required this.id,
    required this.invitationId,
    required this.applicantUserId,
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    required this.registrationNumber,
    required this.npwp,
    required this.licenseDocumentUrl,
    required this.picFullName,
    required this.picPosition,
    required this.status,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory HospitalApplication.fromJson(Map<String, dynamic> json) =>
      HospitalApplication(
        id: '${json['id'] ?? ''}',
        invitationId: '${json['invitationId'] ?? ''}',
        applicantUserId: '${json['applicantUserId'] ?? ''}',
        name: '${json['name'] ?? 'Rumah Sakit'}',
        address: '${json['address'] ?? ''}',
        phone: '${json['phone'] ?? ''}',
        email: '${json['email'] ?? ''}',
        registrationNumber: '${json['registrationNumber'] ?? ''}',
        npwp: '${json['npwp'] ?? ''}',
        licenseDocumentUrl: '${json['licenseDocumentUrl'] ?? ''}',
        picFullName: '${json['picFullName'] ?? ''}',
        picPosition: '${json['picPosition'] ?? ''}',
        status: '${json['status'] ?? 'PENDING_REVIEW'}'.toUpperCase(),
        notes: json['notes']?.toString(),
        createdAt: json['createdAt']?.toString(),
        updatedAt: json['updatedAt']?.toString(),
      );
}

class HospitalInvitationValidation {
  final bool valid;
  final String targetEmail;
  final String? message;

  const HospitalInvitationValidation({
    required this.valid,
    required this.targetEmail,
    this.message,
  });

  factory HospitalInvitationValidation.fromJson(Map<String, dynamic> json) =>
      HospitalInvitationValidation(
        valid: json['valid'] == true,
        targetEmail:
            '${json['targetEmail'] ?? json['email'] ?? ''}',
        message: json['message']?.toString(),
      );
}

