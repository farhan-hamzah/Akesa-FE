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
        targetEmail: '${json['targetEmail'] ?? json['email'] ?? ''}',
        message: json['message']?.toString(),
      );
}

class AdminIdentityVerification {
  final String id;
  final String patientId;
  final String status;
  final String documentType;

  // Data dari profil pasien
  final String? patientCode;
  final String? fullName;
  final String? nik;
  final String? dateOfBirth;
  final String? gender;
  final String? phoneNumber;
  final String? address;

  // Data medis
  final String? bloodType;
  final String? drugAllergy;
  final String? medicalHistory;
  final String? insuranceNumber;

  // Kontak darurat
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  // Hasil pembacaan KTP/OCR dari backend
  final String? extractedFullName;
  final String? extractedNik;
  final String? extractedDateOfBirth;
  final String? extractedGender;

  final String? documentStatus;
  final String? livenessStatus;
  final String? faceMatchStatus;
  final String? failureReason;

  // Timestamp pengajuan
  final String? createdAt;

  const AdminIdentityVerification({
    required this.id,
    required this.patientId,
    required this.status,
    required this.documentType,
    this.patientCode,
    this.fullName,
    this.nik,
    this.dateOfBirth,
    this.gender,
    this.phoneNumber,
    this.address,
    this.bloodType,
    this.drugAllergy,
    this.medicalHistory,
    this.insuranceNumber,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.extractedFullName,
    this.extractedNik,
    this.extractedDateOfBirth,
    this.extractedGender,
    this.documentStatus,
    this.livenessStatus,
    this.faceMatchStatus,
    this.failureReason,
    this.createdAt,
  });

  factory AdminIdentityVerification.fromJson(Map<String, dynamic> json) {
    String? readString(dynamic value) {
      if (value == null) return null;
      final result = value.toString().trim();
      return result.isEmpty ? null : result;
    }

    final patient = json['patient'] is Map<String, dynamic>
        ? json['patient'] as Map<String, dynamic>
        : json;

    return AdminIdentityVerification(
      id: json['id']?.toString() ?? '',
      patientId:
          json['patientId']?.toString() ?? patient['id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'UNKNOWN',
      documentType: json['documentType']?.toString() ?? 'KTP',

      patientCode: readString(patient['patientCode']),
      fullName: readString(patient['fullName']),
      nik: readString(patient['nik']),
      dateOfBirth: readString(patient['dateOfBirth']),
      gender: readString(patient['gender']),
      phoneNumber: readString(patient['phoneNumber']),
      address: readString(patient['address']),

      bloodType: readString(patient['bloodType']),
      drugAllergy: readString(patient['drugAllergy']),
      medicalHistory: readString(patient['medicalHistory']),
      insuranceNumber: readString(patient['insuranceNumber']),

      emergencyContactName: readString(patient['emergencyContactName']),
      emergencyContactPhone: readString(patient['emergencyContactPhone']),

      extractedFullName: readString(json['extractedFullName']),
      extractedNik: readString(json['extractedNik']),
      extractedDateOfBirth: readString(json['extractedDateOfBirth']),
      extractedGender: readString(json['extractedGender']),

      documentStatus: readString(json['documentStatus']),
      livenessStatus: readString(json['livenessStatus']),
      faceMatchStatus: readString(json['faceMatchStatus']),
      failureReason: readString(json['failureReason']),
      createdAt: readString(json['createdAt']),
    );
  }
}
