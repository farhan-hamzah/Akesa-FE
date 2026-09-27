class AccessRequestData {
  final String id;
  final String hospitalId;
  final String patientId;
  final String requestedBy;
  final String purpose;
  final List<String> categories;
  final String status;
  final String? decidedAt;
  final String? createdAt;
  final String? updatedAt;

  AccessRequestData({
    required this.id,
    required this.hospitalId,
    required this.patientId,
    required this.requestedBy,
    required this.purpose,
    required this.categories,
    required this.status,
    this.decidedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory AccessRequestData.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['categories'];

    List<String> parsedCategories = [];

    if (rawCategories is List) {
      parsedCategories = rawCategories.map((item) => item.toString()).toList();
    }

    return AccessRequestData(
      id: '${json['id'] ?? ''}',
      hospitalId: '${json['hospitalId'] ?? ''}',
      patientId: '${json['patientId'] ?? ''}',
      requestedBy: '${json['requestedBy'] ?? ''}',
      purpose: '${json['purpose'] ?? ''}',
      categories: parsedCategories,
      status: '${json['status'] ?? ''}',
      decidedAt: json['decidedAt']?.toString(),
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
    );
  }
}
