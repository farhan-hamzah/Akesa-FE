class IdentityVerificationData {
  final String id;
  final String status;
  final String documentType;
  final String? failureReason;
  final String? verifiedAt;
  final String? expiresAt;

  const IdentityVerificationData({
    required this.id,
    required this.status,
    required this.documentType,
    this.failureReason,
    this.verifiedAt,
    this.expiresAt,
  });

  factory IdentityVerificationData.fromJson(Map<String, dynamic> json) {
    return IdentityVerificationData(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      documentType: json['documentType']?.toString() ?? 'KTP',
      failureReason: json['failureReason']?.toString(),
      verifiedAt: json['verifiedAt']?.toString(),
      expiresAt: json['expiresAt']?.toString(),
    );
  }
}
