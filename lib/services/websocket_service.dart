import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/api_config.dart';
import 'akesa_api.dart';
import 'notification_service.dart';

class WebSocketService {
  WebSocketService._();
  static final WebSocketService instance = WebSocketService._();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  AkesaApi? _api;

  final ValueNotifier<bool> isConnected = ValueNotifier<bool>(false);

  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of all raw WebSocket events received from backend
  Stream<Map<String, dynamic>> get onEvent => _eventController.stream;

  final StreamController<Map<String, dynamic>> _accessRequestUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream khusus ketika ada perubahan status permintaan akses
  /// (misal pasien approve / reject / revoke / request baru)
  Stream<Map<String, dynamic>> get onAccessRequestUpdated =>
      _accessRequestUpdateController.stream;

  bool _isDisposed = false;
  int _reconnectAttempts = 0;

  /// Memulai koneksi WebSocket dengan token autentikasi pengguna
  Future<void> connect(AkesaApi api) async {
    _api = api;
    _isDisposed = false;

    if (isConnected.value) {
      return;
    }

    try {
      final token = await api.getSessionToken();
      if (token == null || token.isEmpty) {
        debugPrint('[WebSocket] Token tidak tersedia, menunda koneksi.');
        return;
      }

      final wsUri = Uri.parse('${ApiConfig.wsUrl}?token=$token');
      debugPrint('[WebSocket] Menghubungkan ke $wsUri...');

      _channel = WebSocketChannel.connect(wsUri);

      // Tunggu hingga ready jika didukung
      await _channel?.ready.catchError((err) {
        debugPrint('[WebSocket] Gagal ready: $err');
      });

      _subscription?.cancel();
      _subscription = _channel?.stream.listen(
        _onMessageReceived,
        onDone: _onConnectionClosed,
        onError: _onConnectionError,
        cancelOnError: true,
      );

      isConnected.value = true;
      _reconnectAttempts = 0;
      debugPrint('[WebSocket] Berhasil terhubung ke Akesa Real-time Hub!');
    } catch (e) {
      debugPrint('[WebSocket] Gagal terhubung: $e');
      _scheduleReconnect();
    }
  }

  void _onMessageReceived(dynamic raw) {
    try {
      final decoded = jsonDecode(raw.toString());
      if (decoded is! Map<String, dynamic>) return;

      final event = decoded['event']?.toString() ?? '';
      final data = decoded['data'] is Map<String, dynamic>
          ? decoded['data'] as Map<String, dynamic>
          : <String, dynamic>{};

      debugPrint('[WebSocket] Pesan diterima: event=$event');

      // 1. Broadcast ke stream umum
      _eventController.add(decoded);

      // 2. Jika ada notifikasi baru, langsung perbarui badge lonceng
      if (event == 'notification') {
        if (_api != null) {
          NotificationService.instance.refreshUnreadCount(_api!);
        }

        final category = data['category']?.toString();
        final severity = data['severity']?.toString();
        final isSecurityAlert = (category?.toUpperCase() == 'SECURITY_ALERT') ||
            (severity?.toUpperCase() == 'CRITICAL') ||
            (data['title']?.toString().toLowerCase().contains('integritas') ?? false);

        // Tampilkan banner mengambang jika platform tidak memiliki push FCM native (misal Windows)
        // ATAU jika ini notifikasi keamanan kritis (peringatan integritas wajib selalu muncul di foreground)
        if (!NotificationService.instance.isPushNotificationSupported || isSecurityAlert) {
          final title = data['title']?.toString() ?? 'Pemberitahuan Baru';
          final message = data['message']?.toString() ?? '';
          NotificationService.instance.showInAppNotificationBanner(
            title: title,
            body: message,
            category: category,
            severity: severity,
          );
        }

        // Cek apakah notifikasi ini terkait permintaan akses (access request)
        final metadata = data['metadata'];
        if (category == 'ACCESS_REQUEST' || metadata is Map) {
          _accessRequestUpdateController.add(data);
        }
      }

      // 3. Jika event spesifik access_request_updated
      if (event == 'access_request_updated') {
        _accessRequestUpdateController.add(data);
      }
    } catch (e) {
      debugPrint('[WebSocket] Gagal memproses pesan masuk: $e');
    }
  }

  void _onConnectionClosed() {
    debugPrint('[WebSocket] Sambungan terputus.');
    isConnected.value = false;
    _scheduleReconnect();
  }

  void _onConnectionError(dynamic error) {
    debugPrint('[WebSocket] Terjadi error sambungan: $error');
    isConnected.value = false;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;
    isConnected.value = false;

    _reconnectTimer?.cancel();
    _reconnectAttempts++;

    // Exponential backoff: 2s, 4s, 8s, maks 30s
    final delaySeconds = (_reconnectAttempts * 2).clamp(2, 30);
    debugPrint('[WebSocket] Menjadwalkan reconnect dalam $delaySeconds detik...');

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_isDisposed && _api != null) {
        connect(_api!);
      }
    });
  }

  /// Menutup sambungan WebSocket (misal saat user logout)
  void disconnect() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _channel?.sink.close();
    _channel = null;
    isConnected.value = false;
    debugPrint('[WebSocket] Disconnected dan dibersihkan.');
  }
}
