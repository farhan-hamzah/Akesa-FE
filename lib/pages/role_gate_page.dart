import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';

import '../services/akesa_api.dart';
import '../services/akesa_staff_admin_api.dart';
import '../services/notification_service.dart';
import '../services/websocket_service.dart';
import '../theme/app_colors.dart';
import '../widgets/shared/ui_kit.dart';
import 'admin/admin_home_page.dart';
import 'patient_home_page.dart';
import 'staff/staff_home_page.dart';

class RoleGatePage extends StatefulWidget {
  final ClerkAuthState authState;
  const RoleGatePage({super.key, required this.authState});

  @override
  State<RoleGatePage> createState() => _RoleGatePageState();
}

class _RoleGatePageState extends State<RoleGatePage> {
  late final AkesaApi api = AkesaApi(authState: widget.authState);
  bool loading = true;
  String? error;
  String? role;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await api.syncUser();
      final r = await api.getMyRole();
      await NotificationService.instance.refreshUnreadCount(api);
      await NotificationService.instance.initializeFirebase(api);
      NotificationService.instance.startPolling(api);
      WebSocketService.instance.connect(api);
      if (!mounted) return;
      setState(() => role = r);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );
    }
    if (error != null) {
      return Scaffold(
        body: SafeArea(
          child: ErrorState(
            message: error!,
            onRetry: _load,
            authState: widget.authState,
          ),
        ),
      );
    }
    switch (role) {
      case 'ADMIN':
        return AdminHomePage(authState: widget.authState);
      case 'HOSPITAL_STAFF':
        return StaffHomePage(authState: widget.authState);
      case 'PATIENT':
        return PatientHomePage(authState: widget.authState);
      default:
        return Scaffold(
          body: SafeArea(
            child: ErrorState(
              message:
                  'Peran akun tidak dikenali ("${role ?? '-'}"). Hubungi administrator.',
              onRetry: _load,
              authState: widget.authState,
            ),
          ),
        );
    }
  }
}
