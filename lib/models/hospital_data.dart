class HospitalData {
  final String id;
  final String name;
  final String address;
  final String status;
  final String? phone;
  final String? email;

  HospitalData({
    required this.id,
    required this.name,
    required this.address,
    required this.status,
    this.phone,
    this.email,
  });

  factory HospitalData.fromJson(Map<String, dynamic> json) {
    return HospitalData(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? 'Rumah Sakit'}',
      address: '${json['address'] ?? ''}',
      status: '${json['status'] ?? ''}',
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
    );
  }
}
