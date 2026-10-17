import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';

import '../../services/akesa_api.dart';
import '../../widgets/shared/account_tab.dart';
import '../../widgets/shared/ui_kit.dart';
import 'staff_create_request_tab.dart';
import 'staff_requests_tab.dart';

class StaffHomePage extends StatefulWidget {
  final ClerkAuthState authState;
  const StaffHomePage({super.key, required this.authState});

  @override
  State<StaffHomePage> createState() => _StaffHomePageState();
}

class _StaffHomePageState extends State<StaffHomePage> {
  late final AkesaApi api = AkesaApi(authState: widget.authState);
  final refresh = ValueNotifier<int>(0);
  int index = 0;

  static const _items = [
    NavItem(Icons.assignment_outlined, Icons.assignment, 'Permintaan'),
    NavItem(Icons.add_circle_outline, Icons.add_circle, 'Buat Baru'),
    NavItem(Icons.person_outline, Icons.person, 'Akun'),
  ];

  @override
  void dispose() {
    refresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveShell(
      index: index,
      onSelect: (i) => setState(() => index = i),
      items: _items,
      body: IndexedStack(
        index: index,
        children: [
          StaffRequestsTab(
            api: api,
            refreshSignal: refresh,
            onCreateNew: () => setState(() => index = 1),
          ),
          StaffCreateRequestTab(
            api: api,
            onCreated: () {
              refresh.value++;
              setState(() => index = 0);
            },
          ),
          AccountTab(
            authState: widget.authState,
            roleLabel: 'Petugas Rumah Sakit',
            icon: Icons.medical_services_outlined,
            description: 'Ajukan izin akses data pasien dan lihat data yang sudah disetujui.',
          ),
        ],
      ),
    );
  }
}
