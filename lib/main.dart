import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';

import 'config/clerk_config.dart';
import 'pages/auth_page.dart';

void main() {
  runApp(
    ClerkAuth(
      config: ClerkAuthConfig(publishableKey: ClerkConfig.publishableKey),
      child: const AkesaApp(),
    ),
  );
}

class AkesaApp extends StatelessWidget {
  const AkesaApp({super.key});

  static const Color akesaGreen = Color(0xFF4D8F00);
  static const Color akesaDarkGreen = Color(0xFF185C22);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Akesa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: akesaGreen),
        scaffoldBackgroundColor: Colors.white,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFB5C9B2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF8BAA87)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: akesaGreen, width: 1.5),
          ),
        ),
      ),
      home: const AuthPage(),
    );
  }
}
