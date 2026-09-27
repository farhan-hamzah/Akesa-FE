class PatientProfileData {
  final String id;
  final String userId;
  final String patientCode;
  final String fullName;

  final String? nik;
  final String? dateOfBirth;
  final String? gender;

  final String? phoneNumber;
  final String? address;

  final String? bloodType;
  final String? drugAllergy;
  final String? medicalHistory;

  final String? insuranceNumber;

  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? emergencyContactRelation;

  final String identityVerificationStatus;
  final bool profileCompleted;

  PatientProfileData({
    required this.id,
    required this.userId,
    required this.patientCode,
    required this.fullName,
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
    this.emergencyContactRelation,
    this.identityVerificationStatus = 'NOT_VERIFIED',
    this.profileCompleted = false,
  });

  factory PatientProfileData.fromJson(Map<String, dynamic> json) {
    return PatientProfileData(
      id: '${json['id'] ?? ''}',
      userId: '${json['userId'] ?? ''}',
      patientCode: '${json['patientCode'] ?? ''}',
      fullName: '${json['fullName'] ?? 'Pasien'}',

      nik: json['nik']?.toString(),
      dateOfBirth: json['dateOfBirth']?.toString(),
      gender: json['gender']?.toString(),

      phoneNumber: json['phoneNumber']?.toString(),
      address: json['address']?.toString(),

      bloodType: json['bloodType']?.toString(),
      drugAllergy: json['drugAllergy']?.toString(),
      medicalHistory: json['medicalHistory']?.toString(),

      insuranceNumber: json['insuranceNumber']?.toString(),

      emergencyContactName: json['emergencyContactName']?.toString(),
      emergencyContactPhone: json['emergencyContactPhone']?.toString(),
      emergencyContactRelation: json['emergencyContactRelation']?.toString(),

      identityVerificationStatus:
          json['identityVerificationStatus']?.toString() ?? 'NOT_VERIFIED',

      profileCompleted: json['profileCompleted'] == true,
    );
  }
}
