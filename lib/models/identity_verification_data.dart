class IdentityVerificationData {
  final String id;
  final String status;
  final String documentType;

  final bool documentUploaded;
  final bool selfieUploaded;

  final String? documentStatus;
  final String? livenessStatus;
  final String? faceMatchStatus;
  final String? failureReason;
  final String? verifiedAt;
  final String? expiresAt;

  const IdentityVerificationData({
    required this.id,
    required this.status,
    required this.documentType,
    required this.documentUploaded,
    required this.selfieUploaded,
    this.documentStatus,
    this.livenessStatus,
    this.faceMatchStatus,
    this.failureReason,
    this.verifiedAt,
    this.expiresAt,
  });

  factory IdentityVerificationData.fromJson(Map<String, dynamic> json) {
    return IdentityVerificationData(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      documentType: json['documentType']?.toString() ?? 'KTP',

      documentUploaded: json['documentUploaded'] == true,

      selfieUploaded: json['selfieUploaded'] == true,

      documentStatus: json['documentStatus']?.toString(),

      livenessStatus: json['livenessStatus']?.toString(),

      faceMatchStatus: json['faceMatchStatus']?.toString(),

      failureReason: json['failureReason']?.toString(),

      verifiedAt: json['verifiedAt']?.toString(),

      expiresAt: json['expiresAt']?.toString(),
    );
  }
}
