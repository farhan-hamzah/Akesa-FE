import 'package:flutter/material.dart';

import '../../models/identity_verification_data.dart';
import '../../services/akesa_api.dart';
import '../../services/akesa_staff_admin_api.dart';
import '../../theme/app_colors.dart';
import '../../widgets/shared/ui_kit.dart';

class AdminIdentityTab extends StatefulWidget {
  final AkesaApi api;
  const AdminIdentityTab({super.key, required this.api});

  @override
  State<AdminIdentityTab> createState() => _AdminIdentityTabState();
}

class _AdminIdentityTabState extends State<AdminIdentityTab> {
  final _id = TextEditingController();
  bool busy = false;
  String? error;
  final List<String> log = [];
  IdentityVerificationData? last;

  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  Future<String?> _askReason() async {
    final ctl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tolak verifikasi'),
        content: TextField(
          controller: ctl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Alasan penolakan (opsional)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
    ctl.dispose();
    return result;
  }

  Future<bool> _confirmApprove() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Setujui verifikasi?'),
        content: const Text(
          'Pastikan foto KTP dan swafoto pasien sudah Anda periksa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Setujui'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _run(bool approve) async {
    final id = _id.text.trim();
    if (!kUuidRegex.hasMatch(id)) {
      setState(() => error = 'ID verifikasi harus berupa UUID yang valid.');
      return;
    }
    String? reason;
    if (approve) {
      if (!await _confirmApprove()) return;
    } else {
      reason = await _askReason();
      if (reason == null) return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final res = approve
          ? await widget.api.adminApproveIdentity(id)
          : await widget.api.adminRejectIdentity(id, reason: reason);
      if (!mounted) return;
      setState(() {
        last = res is Map<String, dynamic>
            ? IdentityVerificationData.fromJson(res)
            : null;
        log.insert(
          0,
          '${approve ? 'Disetujui' : 'Ditolak'} • ${id.substring(0, 8)}…',
        );
      });
      showSnack(
        context,
        approve ? 'Verifikasi disetujui.' : 'Verifikasi ditolak.',
      );
    } catch (e) {
      if (mounted) setState(() => error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TabPage(
      title: 'Verifikasi Identitas',
      subtitle: 'Setujui atau tolak verifikasi KTP pasien',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        children: [
          AppCard(
            color: const Color(0xFFFFF9E8),
            borderColor: const Color(0xFFF3E2A9),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Color(0xFF9A6700), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Backend belum menyediakan daftar antrean verifikasi. '
                    'Masukkan ID verifikasi (UUID) dari pasien yang berstatus "Menunggu verifikasi admin".',
                    style: TextStyle(
                      color: Color(0xFF7A5A00),
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _id,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'ID verifikasi (UUID)',
                    prefixIcon: Icon(Icons.fingerprint),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  InlineError(error!),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    GreenButton(
                      label: 'Setujui',
                      icon: Icons.check_circle_outline,
                      expanded: false,
                      loading: busy,
                      onPressed: () => _run(true),
                    ),
                    GreenButton(
                      label: 'Tolak',
                      icon: Icons.cancel_outlined,
                      expanded: false,
                      danger: true,
                      onPressed: busy ? null : () => _run(false),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (last != null) ...[
            const SizedBox(height: 14),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hasil terakhir',
                    style: TextStyle(
                      color: AppColors.textGreen,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  InfoRow(Icons.flag_outlined, 'Status: ${last!.status}'),
                  if (last!.failureReason != null)
                    InfoRow(Icons.report_outlined, last!.failureReason!),
                ],
              ),
            ),
          ],
          if (log.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Tindakan sesi ini',
              style: TextStyle(
                color: AppColors.textGreen,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            ...log.map(
              (l) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: AppCard(
                  padding: const EdgeInsets.all(11),
                  child: Text(l, style: const TextStyle(fontSize: 12.5)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
