import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:8080';

  final Future<String?> Function() getSessionToken;

  ApiService({required this.getSessionToken});

  Future<Map<String, dynamic>> getPatientQr() async {
    final token = await getSessionToken();

    if (token == null || token.isEmpty) {
      throw Exception('Session token tidak tersedia.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/patient/qr'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    final body = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        body['error']?.toString() ?? 'Gagal mengambil QR pasien.',
      );
    }

    return Map<String, dynamic>.from(body);
  }

  Future<Map<String, dynamic>> rotatePatientQr() async {
    final token = await getSessionToken();

    if (token == null || token.isEmpty) {
      throw Exception('Session token tidak tersedia.');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/patient/qr/rotate'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    final body = jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['error']?.toString() ?? 'Gagal membuat QR baru.');
    }

    return Map<String, dynamic>.from(body);
  }
}
