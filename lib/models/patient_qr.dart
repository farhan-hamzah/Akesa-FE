class PatientQr {
  final String displayCode;
  final String qrPayload;
  final bool isActive;

  const PatientQr({
    required this.displayCode,
    required this.qrPayload,
    required this.isActive,
  });

  factory PatientQr.fromJson(Map<String, dynamic> json) {
    return PatientQr(
      displayCode: json['displayCode']?.toString() ?? '',
      qrPayload: json['qrPayload']?.toString() ?? '',
      isActive: json['isActive'] == true,
    );
  }
}
