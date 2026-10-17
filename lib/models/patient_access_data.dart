class PatientAccessData {
  final String patientId;
  final Map<String, dynamic> data;

  const PatientAccessData({required this.patientId, required this.data});

  factory PatientAccessData.fromJson(Map<String, dynamic> json) {
    return PatientAccessData(
      patientId: json['patientId']?.toString() ?? '',
      data: json,
    );
  }
}
