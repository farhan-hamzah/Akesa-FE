import 'package:flutter/material.dart';

import '../../models/staff_admin_models.dart';
import '../../services/akesa_api.dart';
import '../../theme/app_colors.dart';
import '../../widgets/shared/ui_kit.dart';

class AdminAuditTab extends StatefulWidget {
  final AkesaApi api;
  const AdminAuditTab({super.key, required this.api});

  @override
  State<AdminAuditTab> createState() => _AdminAuditTabState();
}

class _AdminAuditTabState extends State<AdminAuditTab> {
  bool loading = true;
  String? error;
  ChainVerification? result;
  DateTime? checkedAt;

  @override
  void initState() {
    super.initState();
    _verify();
  }

  Future<void> _verify() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final dynamic raw = await widget.api.verifyAuditChain();
      final ChainVerification r = raw is ChainVerification
          ? raw
          : ChainVerification.fromJson(Map<String, dynamic>.from(raw as Map));
      if (!mounted) return;
      setState(() {
        result = r;
        checkedAt = DateTime.now();
      });
    } catch (e) {
      if (mounted) setState(() => error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TabPage(
      title: 'Integritas Audit',
      subtitle: 'Pastikan catatan akses data tidak pernah diubah',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        children: [
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              ),
            )
          else if (error != null)
            InlineError(error!)
          else if (result != null)
            _resultCard(result!),
          const SizedBox(height: 14),
          GreenButton(
            label: 'Verifikasi Ulang',
            icon: Icons.refresh,
            loading: loading,
            onPressed: _verify,
          ),
          const SizedBox(height: 14),
          const AppCard(
            child: Text(
              'Setiap aktivitas (permintaan, persetujuan, pencabutan, dan akses data) dicatat dalam rantai '
              'hash SHA-256. Jika satu catatan diubah, seluruh rantai setelahnya tidak akan cocok.',
              style: TextStyle(color: kMuted, fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultCard(ChainVerification r) {
    final ok = r.valid;
    final color = ok ? AppColors.darkGreen : AppColors.errorText;
    return AppCard(
      color: ok ? AppColors.lightGreen : AppColors.errorBackground,
      borderColor: ok ? const Color(0xFFCFE5CB) : AppColors.errorBorder,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(
            ok ? Icons.verified_user : Icons.gpp_bad,
            size: 54,
            color: color,
          ),
          const SizedBox(height: 10),
          Text(
            ok ? 'Rantai Audit Utuh' : 'Terdeteksi Perubahan / Rantai Rusak',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Status: ${r.status}',
            style: TextStyle(color: color, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Text(
            '${r.totalBlocks}',
            style: TextStyle(
              color: color,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text('blok terperiksa', style: TextStyle(color: color, fontSize: 12)),
          if ((ok ? r.message : r.error) != null) ...[
            const SizedBox(height: 12),
            Text(
              ok ? r.message! : r.error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 12, height: 1.4),
            ),
          ],
          if (checkedAt != null) ...[
            const SizedBox(height: 10),
            Text(
              'Diperiksa ${formatDate(checkedAt!.toIso8601String())}',
              style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
