import 'dart:async';
import 'package:flutter/material.dart';

import '../../models/access_request_data.dart';
import '../../services/akesa_api.dart';
import '../../services/akesa_staff_admin_api.dart';
import '../../services/notification_service.dart';
import '../../services/websocket_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/shared/notification_bell_button.dart';
import '../../widgets/shared/ui_kit.dart';
import 'staff_approved_data_page.dart';

class StaffRequestsTab extends StatefulWidget {
  final AkesaApi api;
  final ValueNotifier<int> refreshSignal;
  final VoidCallback onCreateNew;
  const StaffRequestsTab({
    super.key,
    required this.api,
    required this.refreshSignal,
    required this.onCreateNew,
  });

  @override
  State<StaffRequestsTab> createState() => _StaffRequestsTabState();
}

class _StaffRequestsTabState extends State<StaffRequestsTab> {
  bool loading = true;
  String? error;
  List<AccessRequestData> items = [];
  String? filter;
  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    widget.refreshSignal.addListener(_onSignal);
    _wsSubscription =
        WebSocketService.instance.onAccessRequestUpdated.listen((_) {
      debugPrint('[StaffRequestsTab] Menerima sinyal WebSocket -> memuat ulang otomatis');
      _load(silent: true);
    });
    _load();
  }

  @override
  void dispose() {
    widget.refreshSignal.removeListener(_onSignal);
    _wsSubscription?.cancel();
    super.dispose();
  }

  void _onSignal() => _load(silent: true);

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => loading = true);
    try {
      final r = await widget.api.staffGetAccessRequests();
      await NotificationService.instance.refreshUnreadCount(widget.api);
      if (!mounted) return;
      setState(() {
        items = r;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (silent) {
        showSnack(context, apiErrorMessage(e), error: true);
      } else {
        setState(() => error = apiErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  int _count(String? s) => s == null
      ? items.length
      : items.where((r) => r.status.toUpperCase() == s).length;

  @override
  Widget build(BuildContext context) {
    return TabPage(
      title: 'Permintaan Akses',
      subtitle: 'Pantau status izin data pasien rumah sakit Anda',
      trailing: NotificationBellButton(
        authState: widget.api.authState,
        onOpened: () => NotificationService.instance.refreshUnreadCount(widget.api),
      ),
      child: loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : error != null
          ? ErrorState(
              message: error!,
              onRetry: _load,
              authState: widget.api.authState,
            )
          : _buildList(),
    );
  }

  Widget _buildList() {
    final shown = filter == null
        ? items
        : items.where((r) => r.status.toUpperCase() == filter).toList();

    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('Semua', null),
                _chip('Menunggu', 'PENDING'),
                _chip('Disetujui', 'APPROVED'),
                _chip('Ditolak', 'REJECTED'),
                _chip('Dicabut', 'REVOKED'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty) ...[
            const EmptyState(
              icon: Icons.assignment_outlined,
              title: 'Belum ada permintaan akses',
              message:
                  'Ajukan permintaan akses data pasien dengan kode pasien.',
            ),
            GreenButton(
              label: 'Buat Permintaan',
              icon: Icons.add,
              onPressed: widget.onCreateNew,
            ),
          ] else if (shown.isEmpty)
            const EmptyState(
              icon: Icons.filter_alt_off_outlined,
              title: 'Tidak ada data',
              message: 'Tidak ada permintaan dengan status ini.',
            )
          else
            ...shown.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _card(r),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(String label, String? value) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text('$label (${_count(value)})'),
      selected: filter == value,
      onSelected: (_) => setState(() => filter = value),
      selectedColor: AppColors.lightGreen,
      labelStyle: TextStyle(
        color: filter == value ? AppColors.darkGreen : kMuted,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    ),
  );

  Widget _card(AccessRequestData r) {
    final status = r.status.toUpperCase();
    final shortId = r.patientId.length > 8
        ? '${r.patientId.substring(0, 8)}…'
        : r.patientId;
    String? hint;
    if (status == 'PENDING') hint = 'Menunggu keputusan pasien.';
    if (status == 'REJECTED') hint = 'Pasien menolak permintaan ini.';
    if (status == 'REVOKED') hint = 'Pasien telah mencabut izin akses ini.';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pasien $shortId',
                  style: const TextStyle(
                    color: kMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              StatusBadge(accessTone(status)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            r.purpose,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textGreen,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          CategoryChips(r.categories),
          InfoRow(Icons.schedule, 'Diajukan ${formatDate(r.createdAt)}'),
          if (r.decidedAt != null)
            InfoRow(
              Icons.event_available_outlined,
              'Diputuskan ${formatDate(r.decidedAt)}',
            ),
          const SizedBox(height: 12),
          if (status == 'APPROVED')
            GreenButton(
              label: 'Lihat Data Pasien',
              icon: Icons.folder_shared_outlined,
              compact: true,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      StaffApprovedDataPage(api: widget.api, request: r),
                ),
              ),
            )
          else if (hint != null)
            Text(hint, style: const TextStyle(color: kMuted, fontSize: 12)),
        ],
      ),
    );
  }
}
