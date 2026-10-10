import 'dart:convert';

import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'role_gate_page.dart';

class ApiTestPage extends StatefulWidget {
  final ClerkAuthState authState;

  const ApiTestPage({super.key, required this.authState});

  @override
  State<ApiTestPage> createState() => _ApiTestPageState();
}

class _ApiTestPageState extends State<ApiTestPage> {
  String result = 'Belum ada request';
  bool loading = false;

  // ------------------------------------------------------------ HELPERS

  /// Mengambil JWT sesi Clerk. Melempar Exception bila belum login.
  Future<String> _getSessionToken() async {
    if (!widget.authState.isSignedIn) {
      throw Exception('User belum login ke Clerk.');
    }
    final sessionToken = await widget.authState.sessionToken();
    final jwt = sessionToken.jwt;
    if (jwt.isEmpty) {
      throw Exception('Session token tidak tersedia.');
    }
    return jwt;
  }

  Future<void> _run(
    String startMessage,
    Future<String> Function() action,
  ) async {
    if (loading) return;
    setState(() {
      loading = true;
      result = startMessage;
    });
    try {
      final text = await action();
      if (!mounted) return;
      setState(() => result = text);
    } catch (e, stackTrace) {
      debugPrint('API test error: $e');
      debugPrint('$stackTrace');
      if (!mounted) return;
      setState(() => result = 'ERROR:\n$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _formatResponse(http.Response response) {
    var body = response.body;
    try {
      body = const JsonEncoder.withIndent('  ').convert(jsonDecode(body));
    } catch (_) {
      // Response bukan JSON, tampilkan apa adanya.
    }
    return 'STATUS: ${response.statusCode}\n\n$body';
  }

  Future<String> _authedRequest(String method, String path) async {
    final token = await _getSessionToken();
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final response = method == 'POST'
        ? await http.post(uri, headers: headers)
        : await http.get(uri, headers: headers);
    return _formatResponse(response);
  }

  // -------------------------------------------------------------- TESTS

  Future<void> testHealth() => _run('Menghubungi backend...', () async {
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/health'));
    return _formatResponse(response);
  });

  Future<void> testMe() =>
      _run('Mengambil data akun...', () => _authedRequest('GET', '/api/v1/me'));

  Future<void> testSync() => _run(
    'Sinkronisasi akun...',
    () => _authedRequest('POST', '/api/v1/users/sync'),
  );

  Future<void> showSessionToken() =>
      _run('Mendapatkan session token...', () async {
        final token = await _getSessionToken();
        return 'CLERK SESSION TOKEN:\n\n$token';
      });

  Future<void> logout() => _run('Logging out...', () async {
    await widget.authState.signOut();
    debugPrint('Clerk logout berhasil.');
    return 'Logout berhasil.';
  });

  // ------------------------------------------------------ OPEN BY ROLE

  /// RoleGatePage melakukan sync user, membaca role dari /api/v1/me,
  /// lalu membuka beranda Pasien, Petugas, atau Admin.
  void _openHomeByRole() {
    if (loading) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RoleGatePage(authState: widget.authState),
      ),
    );
  }

  // -------------------------------------------------------------- BUILD

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Akesa API Test'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: loading ? null : logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Akesa Backend Test',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Flutter → Clerk → Go API → PostgreSQL'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: loading ? null : _openHomeByRole,
                icon: const Icon(Icons.dashboard_outlined, size: 19),
                label: const Text(
                  'Buka Beranda Akun',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4D8F00),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: loading ? null : testHealth,
              child: const Text('GET /health'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: loading ? null : showSessionToken,
              child: const Text('Get Clerk Session Token'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: loading ? null : testMe,
              child: const Text('GET /api/v1/me'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: loading ? null : testSync,
              child: const Text('POST /api/v1/users/sync'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Response',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                result,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
