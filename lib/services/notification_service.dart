import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'akesa_api.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
  String? _registeredToken;
  bool _isFirebaseInitialized = false;

  /// Cek apakah platform mendukung FCM push notifications
  bool get isPushNotificationSupported {
    if (kIsWeb) return true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;
      default:
        return false;
    }
  }

  /// Inisialisasi Firebase Messaging, minta izin, dan daftarkan token ke backend.
  Future<void> initializeFirebase(AkesaApi api) async {
    if (_isFirebaseInitialized) return;

    if (!isPushNotificationSupported) {
      debugPrint(
        '[NotificationService] Platform Windows tidak mendukung push FCM native. Pusat notifikasi in-app tetap aktif penuh.',
      );
      _isFirebaseInitialized = true;
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;

      // 1. Minta izin notifikasi (wajib terutama di Android 13+ & iOS)
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('[NotificationService] Status izin notifikasi: ${settings.authorizationStatus}');

      // 2. Ambil token FCM awal dan daftarkan ke backend
      // ignore: deprecated_member_use
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        debugPrint('[NotificationService] FCM Token: $token');
        await syncDeviceToken(api, token: token);
      }

      // 3. Listen pembaharuan token
      // ignore: deprecated_member_use
      messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('[NotificationService] FCM Token diperbarui: $newToken');
        await syncDeviceToken(api, token: newToken);
      });

      // 4. Listen pesan saat aplikasi sedang dibuka (Foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[NotificationService] Notifikasi masuk (Foreground): ${message.notification?.title}');
        refreshUnreadCount(api);
      });

      // 5. Listen saat user klik notifikasi di system tray
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[NotificationService] Notifikasi diklik: ${message.data}');
        refreshUnreadCount(api);
      });

      _isFirebaseInitialized = true;
    } catch (e) {
      debugPrint('[NotificationService] Gagal inisialisasi Firebase Messaging: $e');
    }
  }

  /// Refresh unread notification count from the backend API.
  Future<int> refreshUnreadCount(AkesaApi api) async {
    try {
      final count = await api.getUnreadNotificationCount();
      unreadCount.value = count;
      return count;
    } catch (e) {
      debugPrint('[NotificationService] Gagal memuat unread count: $e');
      return unreadCount.value;
    }
  }

  /// Manually update unread count in local state.
  void setUnreadCount(int count) {
    unreadCount.value = count < 0 ? 0 : count;
  }

  /// Decrement unread count by 1 (e.g. after reading an item).
  void decrementUnreadCount() {
    if (unreadCount.value > 0) {
      unreadCount.value--;
    }
  }

  /// Register or sync device token with Akesa backend.
  Future<void> syncDeviceToken(
    AkesaApi api, {
    required String token,
    String platform = 'android',
  }) async {
    if (token.trim().isEmpty) return;
    try {
      await api.registerDeviceToken(token: token.trim(), platform: platform);
      _registeredToken = token.trim();
      debugPrint('[NotificationService] Device token registered in backend: $_registeredToken');
    } catch (e) {
      debugPrint('[NotificationService] Gagal mendaftarkan device token: $e');
    }
  }

  Timer? _pollingTimer;

  /// Memulai pengecekan otomatis secara berkala (misal setiap 5 detik)
  /// agar lonceng notifikasi langsung menyala sendiri secara real-time.
  void startPolling(AkesaApi api, {Duration interval = const Duration(seconds: 5)}) {
    _pollingTimer?.cancel();
    refreshUnreadCount(api);
    _pollingTimer = Timer.periodic(interval, (_) {
      refreshUnreadCount(api);
    });
  }

  /// Menghentikan pengecekan otomatis (misal saat logout).
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Unregister device token from backend & FCM (e.g. upon user logout).
  Future<void> clearDeviceToken(AkesaApi api) async {
    stopPolling();

    final token = _registeredToken;
    if (token != null && token.isNotEmpty) {
      try {
        await api.unregisterDeviceToken(token);
        debugPrint('[NotificationService] Device token unregistered from backend: $token');
        _registeredToken = null;
      } catch (e) {
        debugPrint('[NotificationService] Gagal menghapus device token: $e');
      }
    }

    if (isPushNotificationSupported) {
      try {
        // ignore: deprecated_member_use
        await FirebaseMessaging.instance.deleteToken();
        _isFirebaseInitialized = false;
      } catch (_) {}
    }
  }
}
