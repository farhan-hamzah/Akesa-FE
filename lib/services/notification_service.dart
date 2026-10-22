import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../main.dart';
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

  /// Menampilkan banner notifikasi melayang di atas layar saat aplikasi sedang terbuka
  /// Menampilkan banner notifikasi melayang di atas layar saat aplikasi sedang terbuka
  void showInAppNotificationBanner({
    required String title,
    required String body,
    String? category,
    String? severity,
    VoidCallback? onTap,
  }) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;

    final isSecurityAlert = (category?.toUpperCase() == 'SECURITY_ALERT') ||
        (severity?.toUpperCase() == 'CRITICAL') ||
        title.toLowerCase().contains('integritas');

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isSecurityAlert
              ? const BorderSide(color: Color(0xFFEF4444), width: 1.5)
              : BorderSide.none,
        ),
        backgroundColor: isSecurityAlert
            ? const Color(0xFF1E0A0A) // Dark Crimson
            : const Color(0xFF0F172A), // Dark Slate
        elevation: isSecurityAlert ? 12 : 8,
        duration: Duration(seconds: isSecurityAlert ? 8 : 4),
        content: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon Container (Warning Sign untuk Security Alert)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSecurityAlert
                      ? const Color(0xFFEF4444).withValues(alpha: 0.18)
                      : const Color(0xFF4D8F00).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: isSecurityAlert
                      ? Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                          width: 1,
                        )
                      : null,
                ),
                child: Icon(
                  isSecurityAlert
                      ? Icons.warning_amber_rounded
                      : Icons.notifications_active_rounded,
                  color: isSecurityAlert
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF4D8F00),
                  size: isSecurityAlert ? 24 : 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isSecurityAlert) ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'PERINGATAN KEAMANAN',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'KRITIS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFFCA5A5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: TextStyle(
                        color: isSecurityAlert
                            ? const Color(0xFFE2E8F0)
                            : const Color(0xFF94A3B8),
                        fontSize: 12,
                        height: 1.3,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isSecurityAlert
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF94A3B8),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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

      // Aktifkan tampilan notifikasi banner saat aplikasi sedang dibuka
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
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
        final title = message.notification?.title ?? 'Notifikasi Baru';
        final body = message.notification?.body ??
            message.data['message']?.toString() ??
            '';
        final category = message.data['category']?.toString();
        final severity = message.data['severity']?.toString();
        debugPrint('[NotificationService] Notifikasi masuk (Foreground): $title');
        refreshUnreadCount(api);
        showInAppNotificationBanner(
          title: title,
          body: body,
          category: category,
          severity: severity,
        );
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

  /// Unregister device token from backend & FCM (e.g. upon user logout).
  Future<void> clearDeviceToken(AkesaApi api) async {

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
