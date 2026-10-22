import 'dart:io';

import 'package:flutter/foundation.dart';

enum AppEnvironment {
  local,
  vps,
}

class ApiConfig {
  /// =========================================================================
  /// PENGATURAN ENVIRONMENT (CUKUP UBAH INI UNTUK GANTI LOCAL <-> VPS)
  /// =========================================================================
  /// - AppEnvironment.vps   -> Menggunakan backend di VPS (https://api.akesa.cloud)
  /// - AppEnvironment.local -> Menggunakan backend lokal (10.0.2.2 / localhost)
  ///
  /// Anda juga bisa mengubahnya tanpa edit kode via command line:
  ///   flutter run --dart-define=ENV=vps
  ///   flutter run --dart-define=ENV=local
  /// =========================================================================
  static const AppEnvironment _defaultEnv = AppEnvironment.vps;

  /// Domain VPS Akesa
  static const String vpsUrl = 'https://api.akesa.cloud';

  /// Port OCR di lokal jika menjalankan docker/go local
  static const int localOcrPort = 9090;

  /// Deteksi environment aktif (prioritas dari --dart-define, fallback ke _defaultEnv)
  static AppEnvironment get environment {
    const fromEnv = String.fromEnvironment('ENV', defaultValue: '');
    if (fromEnv.toLowerCase() == 'local') return AppEnvironment.local;
    if (fromEnv.toLowerCase() == 'vps') return AppEnvironment.vps;
    return _defaultEnv;
  }

  /// Helper untuk mengecek apakah sedang mengarah ke VPS
  static bool get isVps => environment == AppEnvironment.vps;

  /// Memastikan string URL bersih dan tidak ada trailing slash '/' di ujung
  static String _sanitize(String url) =>
      url.trim().replaceAll(RegExp(r'/+$'), '');

  /// Base URL untuk Akesa Backend API
  static String get baseUrl {
    if (isVps) {
      return _sanitize(vpsUrl);
    }

    if (kIsWeb) {
      return 'http://localhost:8080';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:8080';
    } else {
      return 'http://localhost:8080';
    }
  }

  /// Base URL untuk KTP OCR Service
  /// - Di VPS: Caddy me-reverse proxy `/api/v1/ktp/*` langsung di domain yang sama (https://api.akesa.cloud).
  /// - Di Local: Menggunakan port terpisah (9090 / 8081).
  static String get ktpOcrBaseUrl {
    if (isVps) {
      return _sanitize(vpsUrl);
    }

    if (kIsWeb) {
      return 'http://localhost:$localOcrPort';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:$localOcrPort';
    } else {
      return 'http://localhost:$localOcrPort';
    }
  }

  /// WebSocket URL untuk Real-time Event (Access Request & Notifikasi)
  /// - VPS: wss://api.akesa.cloud/api/v1/ws
  /// - Local: ws://10.0.2.2:8080/api/v1/ws (Android) atau ws://localhost:8080/api/v1/ws
  static String get wsUrl {
    final httpUrl = baseUrl;
    if (httpUrl.startsWith('https://')) {
      return '${httpUrl.replaceFirst('https://', 'wss://')}/api/v1/ws';
    } else {
      return '${httpUrl.replaceFirst('http://', 'ws://')}/api/v1/ws';
    }
  }
}
