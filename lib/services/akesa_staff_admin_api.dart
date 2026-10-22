import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/access_request_data.dart';
import '../models/api_exception.dart';
import '../models/staff_admin_models.dart';
import 'akesa_api.dart';

/// Endpoint admin & petugas. Memakai extension supaya akesa_api.dart
/// tidak perlu diubah sama sekali.
extension StaffAdminApi on AkesaApi {
  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    bool auth = true,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (auth) {
      final token = await getSessionToken();
      if (token == null || token.isEmpty) {
        throw ApiException(401, 'Session token tidak tersedia.');
      }
      headers['Authorization'] = 'Bearer $token';
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    debugPrint('[AkesaStaffAdminApi] --> $method $uri');
    final request = http.Request(method, uri);
    request.headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);

    http.Response response;
    try {
      final streamed = await request.send().timeout(
        const Duration(seconds: 20),
      );
      response = await http.Response.fromStream(streamed);
      debugPrint('[AkesaStaffAdminApi] <-- ${response.statusCode} $path');
    } on TimeoutException {
      throw ApiException(408, 'Server tidak merespons. Coba lagi.');
    }

    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = response.body;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'Request gagal.';
      if (decoded is Map<String, dynamic>) {
        message =
            decoded['error']?.toString() ??
            decoded['message']?.toString() ??
            message;
      }
      throw ApiException(response.statusCode, message);
    }
    return decoded;
  }

  // ---------------------------------------------------------------- ROLE
  /// GET /api/v1/me -> role (mendukung `role` atau `user.role`).
  Future<String?> getMyRole() async {
    final me = await _send('GET', '/api/v1/me');
    if (me is Map<String, dynamic>) {
      final role =
          me['role'] ?? (me['user'] is Map ? me['user']['role'] : null);
      return role?.toString().toUpperCase();
    }
    return null;
  }

  // --------------------------------------------------------------- ADMIN HOSPITALS
  Future<List<AdminHospital>> adminGetHospitals() async {
    final json = await _send('GET', '/api/v1/admin/hospitals');
    if (json is! List) return [];
    return json
        .whereType<Map<String, dynamic>>()
        .map(AdminHospital.fromJson)
        .toList();
  }

  /// PATCH /api/v1/admin/hospitals/{id}/activate
  Future<AdminHospital> adminActivateHospital(String id) async {
    final json = await _send('PATCH', '/api/v1/admin/hospitals/$id/activate');
    return AdminHospital.fromJson(Map<String, dynamic>.from(json));
  }

  /// PATCH /api/v1/admin/hospitals/{id}/deactivate
  Future<AdminHospital> adminDeactivateHospital(String id) async {
    final json = await _send('PATCH', '/api/v1/admin/hospitals/$id/deactivate');
    return AdminHospital.fromJson(Map<String, dynamic>.from(json));
  }

  /// action: 'activate' | 'deactivate'
  Future<AdminHospital> adminSetHospitalStatus(String id, String action) async {
    if (action == 'activate') return adminActivateHospital(id);
    if (action == 'deactivate') return adminDeactivateHospital(id);
    final json = await _send('PATCH', '/api/v1/admin/hospitals/$id/$action');
    return AdminHospital.fromJson(Map<String, dynamic>.from(json));
  }

  // --------------------------------------------------- HOSPITAL APPLICATIONS
  Future<List<HospitalApplication>> adminGetHospitalApplications({
    String? status,
  }) async {
    final query = (status != null && status.isNotEmpty)
        ? '?status=$status'
        : '';
    final json = await _send(
      'GET',
      '/api/v1/admin/hospital-applications$query',
    );
    if (json is! List) return [];
    return json
        .whereType<Map<String, dynamic>>()
        .map(HospitalApplication.fromJson)
        .toList();
  }

  Future<HospitalApplication> adminGetHospitalApplicationDetail(
    String id,
  ) async {
    final json = await _send('GET', '/api/v1/admin/hospital-applications/$id');
    return HospitalApplication.fromJson(Map<String, dynamic>.from(json));
  }

  Future<dynamic> adminApproveHospitalApplication(String id) async {
    return await _send(
      'POST',
      '/api/v1/admin/hospital-applications/$id/approve',
    );
  }

  Future<dynamic> adminRequestRevisionHospitalApplication(
    String id, {
    required String notes,
  }) async {
    return await _send(
      'POST',
      '/api/v1/admin/hospital-applications/$id/request-revision',
      body: {'notes': notes},
    );
  }

  Future<dynamic> adminRejectHospitalApplication(
    String id, {
    required String notes,
  }) async {
    return await _send(
      'POST',
      '/api/v1/admin/hospital-applications/$id/reject',
      body: {'notes': notes},
    );
  }

  Future<void> adminAddStaff({
    required String hospitalId,
    required String userId,
    required String fullName,
    required String position,
  }) async {
    await _send(
      'POST',
      '/api/v1/admin/hospitals/$hospitalId/staff',
      body: {'userId': userId, 'fullName': fullName, 'position': position},
    );
  }

  Future<List<AdminIdentityVerification>>
  adminGetPendingIdentityVerifications() async {
    final json = await _send('GET', '/api/v1/admin/identity-verifications');

    if (json is! List) return [];

    return json
        .whereType<Map<String, dynamic>>()
        .map(AdminIdentityVerification.fromJson)
        .toList();
  }

  Future<Uint8List> adminGetIdentityDocument(
    String id, {
    required String type,
  }) async {
    final normalizedType = type.toLowerCase();

    if (normalizedType != 'ktp' && normalizedType != 'selfie') {
      throw ArgumentError('Tipe dokumen tidak valid.');
    }

    final token = await getSessionToken();

    if (token == null || token.isEmpty) {
      throw ApiException(401, 'Session token tidak tersedia.');
    }

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}'
      '/api/v1/admin/identity-verifications/'
      '$id/documents/$normalizedType',
    );

    final http.Response response;

    try {
      response = await http
          .get(
            uri,
            headers: {
              'Accept': 'image/jpeg, image/png',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw ApiException(408, 'Server tidak merespons. Coba lagi.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'Gagal mengambil dokumen identitas.';

      try {
        final decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic>) {
          message =
              decoded['error']?.toString() ??
              decoded['message']?.toString() ??
              message;
        }
      } catch (_) {}

      throw ApiException(response.statusCode, message);
    }

    final contentType = response.headers['content-type']
        ?.split(';')
        .first
        .trim()
        .toLowerCase();

    if (contentType != 'image/jpeg' && contentType != 'image/png') {
      throw ApiException(500, 'Format dokumen dari server tidak valid.');
    }

    if (response.bodyBytes.isEmpty) {
      throw ApiException(404, 'Dokumen identitas kosong.');
    }

    return response.bodyBytes;
  }

  Future<dynamic> adminApproveIdentity(String id) =>
      _send('POST', '/api/v1/admin/identity-verifications/$id/approve');

  Future<dynamic> adminRejectIdentity(String id, {String? reason}) => _send(
    'POST',
    '/api/v1/admin/identity-verifications/$id/reject',
    body: {if (reason != null && reason.isNotEmpty) 'reason': reason},
  );

  /// GET /api/v1/audit/verify-chain (publik, tanpa token)
  Future<ChainVerification> verifyAuditChain() async {
    final json = await _send('GET', '/api/v1/audit/verify-chain', auth: false);
    if (json is! Map<String, dynamic>) {
      throw ApiException(500, 'Format hasil verifikasi tidak valid.');
    }
    return ChainVerification.fromJson(json);
  }

  // --------------------------------------------------------------- STAFF
  Future<List<AccessRequestData>> staffGetAccessRequests() async {
    final json = await _send('GET', '/api/v1/hospital/access-requests');
    if (json is! List) return [];
    return json
        .whereType<Map<String, dynamic>>()
        .map(AccessRequestData.fromJson)
        .toList();
  }

  Future<AccessRequestData> staffCreateAccessRequest({
    required String patientCode,
    required String purpose,
    required List<String> categories,
  }) async {
    final json = await _send(
      'POST',
      '/api/v1/hospital/access-requests',
      body: {
        'patientCode': patientCode,
        'purpose': purpose,
        'categories': categories,
      },
    );
    return AccessRequestData.fromJson(Map<String, dynamic>.from(json));
  }

  Future<Map<String, dynamic>> staffFetchApprovedData(String requestId) async {
    final json = await _send(
      'GET',
      '/api/v1/hospital/access-requests/$requestId/data',
    );
    if (json is! Map<String, dynamic>) {
      throw ApiException(500, 'Format data pasien tidak valid.');
    }
    return json;
  }
}
