import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';

import '../../services/akesa_api.dart';
import '../../widgets/shared/account_tab.dart';
import '../../widgets/shared/ui_kit.dart';
import 'admin_audit_tab.dart';
import 'admin_hospitals_tab.dart';
import 'admin_identity_tab.dart';

class AdminHomePage extends StatefulWidget {
  final ClerkAuthState authState;
  const AdminHomePage({super.key, required this.authState});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  late final AkesaApi api = AkesaApi(authState: widget.authState);
  int index = 0;

  static const _items = [
    NavItem(Icons.local_hospital_outlined, Icons.local_hospital, 'Rumah Sakit'),
    NavItem(Icons.badge_outlined, Icons.badge, 'Verifikasi'),
    NavItem(Icons.shield_outlined, Icons.shield, 'Audit'),
    NavItem(Icons.person_outline, Icons.person, 'Akun'),
  ];

  @override
  Widget build(BuildContext context) {
    return AdaptiveShell(
      index: index,
      onSelect: (i) => setState(() => index = i),
      items: _items,
      body: IndexedStack(
        index: index,
        children: [
          AdminHospitalsTab(api: api),
          AdminIdentityTab(api: api),
          AdminAuditTab(api: api),
          AccountTab(
            authState: widget.authState,
            roleLabel: 'Administrator',
            icon: Icons.admin_panel_settings_outlined,
            description: 'Kelola rumah sakit, petugas, verifikasi identitas, dan integritas audit.',
          ),
        ],
      ),
    );
  }
}