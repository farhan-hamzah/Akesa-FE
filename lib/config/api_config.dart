import 'dart:io';

import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8080';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:8080';
    } else {
      return 'http://localhost:8080';
    }
  }

  static String get ktpOcrBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:9090';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:9090';
    } else {
      return 'http://localhost:9090';
    }
  }
}
