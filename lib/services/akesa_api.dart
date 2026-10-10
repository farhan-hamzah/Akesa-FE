import 'dart:convert';

import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';

import '../config/api_config.dart';
import '../models/access_request_data.dart';
import '../models/api_exception.dart';
import '../models/audit_log_data.dart';
import '../models/hospital_data.dart';
import '../models/patient_profile_data.dart';
import '../models/patient_qr.dart';
import '../models/identity_verification_data.dart';

class AkesaApi {
  final ClerkAuthState authState;

  AkesaApi({required this.authState});

  Future<String?> getSessionToken() async {
    if (!authState.isSignedIn) {
      return null;
    }

    final sessionToken = await authState.sessionToken();
    return sessionToken.jwt;
  }

  dynamic _decodeResponse(http.Response response) {
    if (response.body.isEmpty) {
      return null;
    }

    try {
      return jsonDecode(response.body);
    } catch (_) {
      return response.body;
    }
  }

  dynamic _unwrapData(dynamic json) {
    if (json is Map<String, dynamic> && json.containsKey('data')) {
      return json['data'];
    }
    return json;
  }

  dynamic _handleResponse(http.Response response) {
    final body = _decodeResponse(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Request gagal.';

      if (body is Map<String, dynamic>) {
        message =
            body['error']?.toString() ?? body['message']?.toString() ?? message;
      }

      throw ApiException(response.statusCode, message);
    }

    return _unwrapData(body);
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await getSessionToken();

    if (token == null || token.isEmpty) {
      throw ApiException(401, 'Session token tidak tersedia.');
    }

    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  Future<dynamic> _get(String path) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: headers,
    );
    return _handleResponse(response);
  }

  Future<dynamic> _post(String path) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: headers,
    );
    return _handleResponse(response);
  }

  Future<dynamic> syncUser() => _post('/api/v1/users/sync');

  Future<dynamic> getMe() => _get('/api/v1/me');

  Future<PatientProfileData> getPatientProfile() async {
    final json = await _get('/api/v1/patient/profile');

    if (json is! Map<String, dynamic>) {
      throw ApiException(500, 'Format profile pasien tidak valid.');
    }

    return PatientProfileData.fromJson(json);
  }

  Future<PatientProfileData> updatePatientProfile({
    required String nik,
    required String fullName,
    required String dateOfBirth,
    required String gender,
    required String phoneNumber,
    required String address,
    String? bloodType,
    String? drugAllergy,
    String? medicalHistory,
    String? insuranceNumber,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) async {
    final headers = await _authHeaders();

    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/patient/profile'),
      headers: headers,
      body: jsonEncode({
        'nik': nik,
        'fullName': fullName,
        'dateOfBirth': dateOfBirth,
        'gender': gender,
        'phoneNumber': phoneNumber,
        'address': address,
        'bloodType': bloodType,
        'drugAllergy': drugAllergy,
        'medicalHistory': medicalHistory,
        'insuranceNumber': insuranceNumber,
        'emergencyContactName': emergencyContactName,
        'emergencyContactPhone': emergencyContactPhone,
      }),
    );

    final json = _handleResponse(response);

    if (json is! Map<String, dynamic>) {
      throw ApiException(500, 'Format profile pasien tidak valid.');
    }

    return PatientProfileData.fromJson(json);
  }

  Future<List<HospitalData>> getHospitals() async {
    final json = await _get('/api/v1/hospitals');

    if (json is! List) {
      return [];
    }

    return json
        .whereType<Map<String, dynamic>>()
        .map(HospitalData.fromJson)
        .toList();
  }

  Future<List<AccessRequestData>> getAccessRequests() async {
    final json = await _get('/api/v1/patient/access-requests');

    if (json is! List) {
      return [];
    }

    return json
        .whereType<Map<String, dynamic>>()
        .map(AccessRequestData.fromJson)
        .toList();
  }

  Future<AccessRequestData?> approveAccessRequest(String id) async {
    final json = await _post('/api/v1/patient/access-requests/$id/approve');
    return json is Map<String, dynamic>
        ? AccessRequestData.fromJson(json)
        : null;
  }

  Future<AccessRequestData?> rejectAccessRequest(String id) async {
    final json = await _post('/api/v1/patient/access-requests/$id/reject');
    return json is Map<String, dynamic>
        ? AccessRequestData.fromJson(json)
        : null;
  }

  Future<AccessRequestData?> revokeAccessRequest(String id) async {
    final json = await _post('/api/v1/patient/access-requests/$id/revoke');
    return json is Map<String, dynamic>
        ? AccessRequestData.fromJson(json)
        : null;
  }

  Future<List<AuditLogData>> getHistory() async {
    final json = await _get('/api/v1/patient/history');

    if (json is! List) {
      return [];
    }

    return json
        .whereType<Map<String, dynamic>>()
        .map(AuditLogData.fromJson)
        .toList();
  }

  Future<PatientQr> getPatientQr() async {
    final json = await _get('/api/v1/patient/qr');

    if (json is! Map<String, dynamic>) {
      throw ApiException(500, 'Format QR pasien tidak valid.');
    }

    return PatientQr.fromJson(json);
  }

  Future<PatientQr> rotatePatientQr() async {
    final json = await _post('/api/v1/patient/qr/rotate');

    if (json is! Map<String, dynamic>) {
      throw ApiException(500, 'Format QR pasien tidak valid.');
    }

    return PatientQr.fromJson(json);
  }

  Future<IdentityVerificationData> getIdentityVerification(
    String verificationId,
  ) async {
    final response = await _get(
      '/api/v1/patient/identity/verifications/$verificationId',
    );

    return IdentityVerificationData.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<IdentityVerificationData> createIdentityVerification() async {
    final response = await _post('/api/v1/patient/identity/verifications');

    return IdentityVerificationData.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  Future<IdentityVerificationData> uploadIdentityDocument({
    required String verificationId,
    required XFile file,
  }) async {
    final token = await getSessionToken();

    if (token == null || token.isEmpty) {
      throw ApiException(401, 'Session token tidak tersedia.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        '${ApiConfig.baseUrl}'
        '/api/v1/patient/identity/verifications/'
        '$verificationId/document',
      ),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';

    final extension = file.name.toLowerCase().split('.').last;

    MediaType contentType;

    switch (extension) {
      case 'png':
        contentType = MediaType('image', 'png');
        break;

      case 'jpg':
      case 'jpeg':
        contentType = MediaType('image', 'jpeg');
        break;

      default:
        throw ApiException(400, 'Format KTP harus JPG atau PNG.');
    }

    request.files.add(
      await http.MultipartFile.fromPath(
        'document',
        file.path,
        contentType: contentType,
      ),
    );

    final streamedResponse = await request.send();

    final response = await http.Response.fromStream(streamedResponse);

    final body = _handleResponse(response);

    return IdentityVerificationData.fromJson(Map<String, dynamic>.from(body));
  }

  Future<IdentityVerificationData> uploadIdentitySelfie({
    required String verificationId,
    required XFile file,
  }) async {
    final token = await getSessionToken();

    if (token == null || token.isEmpty) {
      throw ApiException(401, 'Session token tidak tersedia.');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        '${ApiConfig.baseUrl}'
        '/api/v1/patient/identity/verifications/'
        '$verificationId/selfie',
      ),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';

    final extension = file.name.toLowerCase().split('.').last;

    MediaType contentType;

    switch (extension) {
      case 'png':
        contentType = MediaType('image', 'png');
        break;

      case 'jpg':
      case 'jpeg':
        contentType = MediaType('image', 'jpeg');
        break;

      default:
        throw ApiException(400, 'Format selfie harus JPG atau PNG.');
    }

    request.files.add(
      await http.MultipartFile.fromPath(
        'selfie',
        file.path,
        contentType: contentType,
      ),
    );

    final streamedResponse = await request.send();

    final response = await http.Response.fromStream(streamedResponse);

    final body = _handleResponse(response);

    if (body is! Map<String, dynamic>) {
      throw ApiException(500, 'Format response verifikasi tidak valid.');
    }

    return IdentityVerificationData.fromJson(body);
  }

  Future<PatientProfileData> createPatientProfile({
    required String nik,
    required String fullName,
    required String dateOfBirth,
    required String gender,
    required String phoneNumber,
    required String address,
    String? bloodType,
    String? drugAllergy,
    String? medicalHistory,
    String? insuranceNumber,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) async {
    final headers = await _authHeaders();

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/patient/profile'),
      headers: headers,
      body: jsonEncode({
        'nik': nik,
        'fullName': fullName,
        'dateOfBirth': dateOfBirth,
        'gender': gender,
        'phoneNumber': phoneNumber,
        'address': address,
        'bloodType': bloodType,
        'drugAllergy': drugAllergy,
        'medicalHistory': medicalHistory,
        'insuranceNumber': insuranceNumber,
        'emergencyContactName': emergencyContactName,
        'emergencyContactPhone': emergencyContactPhone,
      }),
    );

    final json = _handleResponse(response);

    if (json is! Map<String, dynamic>) {
      throw ApiException(500, 'Format profile pasien tidak valid.');
    }

    return PatientProfileData.fromJson(json);
  }

  Future<IdentityVerificationData?> getLatestIdentityVerification() async {
    try {
      final response = await _get(
        '/api/v1/patient/identity/verifications/latest',
      );

      if (response is! Map<String, dynamic>) {
        throw ApiException(500, 'Format verifikasi identitas tidak valid.');
      }

      return IdentityVerificationData.fromJson(response);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        return null;
      }

      rethrow;
    }
  }

  Future<List<AccessRequestData>> getHospitalAccessRequests() async {
    final json = await _get('/api/v1/hospital/access-requests');

    if (json is! List) {
      return [];
    }

    return json
        .whereType<Map<String, dynamic>>()
        .map(AccessRequestData.fromJson)
        .toList();
  }

  Future<AccessRequestData?> createHospitalAccessRequest({
    required String patientCode,
    required String purpose,
    required List<String> categories,
  }) async {
    final headers = await _authHeaders();

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/v1/hospital/access-requests'),
      headers: headers,
      body: jsonEncode({
        'patientCode': patientCode,
        'purpose': purpose,
        'categories': categories,
      }),
    );

    final json = _handleResponse(response);

    if (json is! Map<String, dynamic>) {
      throw ApiException(500, 'Format permintaan akses tidak valid.');
    }

    return AccessRequestData.fromJson(json);
  }

  Future<Map<String, dynamic>> getApprovedPatientData(String requestId) async {
    try {
      final json = await _get(
        '/api/v1/hospital/access-requests/$requestId/data',
      );

      if (json is! Map<String, dynamic>) {
        throw ApiException(500, 'Format data pasien tidak valid.');
      }

      return json;
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        throw ApiException(
          409,
          'Data pasien tidak dapat ditampilkan karena '
          'integritas data tidak dapat diverifikasi.',
        );
      }

      rethrow;
    }
  }

  Future<Map<String, dynamic>> verifyAuditChain() async {
    final json = await _get('/api/v1/audit/verify-chain');

    if (json is! Map<String, dynamic>) {
      throw ApiException(500, 'Format hasil audit tidak valid.');
    }

    return json;
  }
}
