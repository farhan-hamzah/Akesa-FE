import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../services/akesa_api.dart';
import '../../services/akesa_staff_admin_api.dart';
import '../../theme/app_colors.dart';
import '../../widgets/shared/ui_kit.dart';
import '../../models/staff_admin_models.dart';

class AdminIdentityTab extends StatefulWidget {
  final AkesaApi api;

  const AdminIdentityTab({super.key, required this.api});

  @override
  State<AdminIdentityTab> createState() => _AdminIdentityTabState();
}

class _AdminIdentityTabState extends State<AdminIdentityTab> {
  List<AdminIdentityVerification> verifications = [];

  bool loading = false;
  String? error;
  String? busyId;

  String _valueOrFallback(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty
        ? 'Belum tersedia'
        : normalized;
  }

  String _statusLabel(String? value) {
    switch (value?.toUpperCase()) {
      case 'VERIFIED':
        return 'Terverifikasi';
      case 'MANUAL_REVIEW':
        return 'Menunggu pemeriksaan manual';
      case 'PENDING':
        return 'Menunggu proses';
      case 'PROCESSING':
        return 'Sedang diproses';
      case 'FAILED':
        return 'Pemeriksaan gagal';
      case 'PASSED':
        return 'Lolos pemeriksaan';
      case 'REJECTED':
        return 'Ditolak';
      default:
        return 'Belum tersedia';
    }
  }

  String _formatDateTime(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Belum tersedia';
    }

    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return 'Format waktu tidak valid';
    }

    final date = parsed.toLocal();

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];

    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day $month $year, $hour.$minute';
  }

  final Map<String, String> documentErrors = {};

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  Future<void> _loadQueue() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result = await widget.api.adminGetPendingIdentityVerifications();

      if (!mounted) return;

      setState(() {
        verifications = result;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = apiErrorMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<String?> _askReason() async {
    final formKey = GlobalKey<FormState>();
    String reason = '';

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tolak verifikasi'),
        content: Form(
          key: formKey,
          child: TextFormField(
            autofocus: true,
            maxLines: 3,
            onChanged: (value) {
              reason = value;
            },
            decoration: const InputDecoration(
              labelText: 'Alasan penolakan',
              hintText: 'Contoh: Foto KTP tidak terbaca.',
              alignLabelWithHint: true,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Alasan penolakan wajib diisi.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, reason.trim());
              }
            },
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmApprove() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Setujui verifikasi?'),
            content: const Text(
              'Pastikan foto KTP dan selfie telah diperiksa '
              'serta sesuai dengan data pasien.',
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
        ) ??
        false;
  }

  Future<void> _run(
    AdminIdentityVerification item, {
    required bool approve,
  }) async {
    if (busyId != null) return;

    String? reason;

    if (approve) {
      if (!await _confirmApprove()) return;
    } else {
      reason = await _askReason();
      if (reason == null) return;
    }

    setState(() {
      busyId = item.id;
      error = null;
    });

    try {
      if (approve) {
        await widget.api.adminApproveIdentity(item.id);
      } else {
        await widget.api.adminRejectIdentity(item.id, reason: reason);
      }

      if (!mounted) return;

      showSnack(
        context,
        approve
            ? 'Verifikasi berhasil disetujui.'
            : 'Verifikasi berhasil ditolak.',
      );

      await _loadQueue();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = apiErrorMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() => busyId = null);
      }
    }
  }

  Future<void> _showDocument(
    AdminIdentityVerification item, {
    required String type,
    required String title,
  }) async {
    if (busyId != null) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: FutureBuilder<Uint8List>(
              future: widget.api.adminGetIdentityDocument(item.id, type: type),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 220,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    snapshot.data!.isEmpty) {
                  return const SizedBox(
                    height: 160,
                    child: Center(
                      child: Text(
                        'Dokumen tidak dapat dimuat. '
                        'Coba lagi atau hubungi administrator.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: Image.memory(
                    snapshot.data!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, error, stackTrace) {
                      return const Text('Format gambar tidak valid.');
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  Widget _patientInformation(AdminIdentityVerification item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Informasi pasien',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        InfoRow(
          Icons.badge_outlined,
          'Kode pasien: ${_valueOrFallback(item.patientCode)}',
        ),
        InfoRow(
          Icons.person_outline,
          'Nama lengkap: ${_valueOrFallback(item.fullName)}',
        ),
        // InfoRow(
        //   Icons.credit_card_outlined,
        //   'NIK: ${_valueOrFallback(item.nik)}',
        // ),
        InfoRow(
          Icons.cake_outlined,
          'Tanggal lahir: ${_valueOrFallback(item.dateOfBirth)}',
        ),
        InfoRow(
          Icons.wc_outlined,
          'Jenis kelamin: ${_valueOrFallback(item.gender)}',
        ),
      ],
    );
  }

  Widget _verificationCard(AdminIdentityVerification item) {
    final isBusy = busyId == item.id;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.verified_user_outlined,
                color: AppColors.primaryGreen,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pengajuan verifikasi identitas',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.textGreen,
                      ),
                    ),
                    const SizedBox(height: 5),
                    _patientInformation(item),
                    const SizedBox(height: 12),
                    Text(
                      'Status: ${item.status}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),

                    if (item.createdAt != null &&
                        item.createdAt!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.schedule_outlined,
                            size: 16,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Diajukan pada ${_formatDateTime(item.createdAt)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () =>
                    _showDocument(item, type: 'ktp', title: 'Dokumen KTP'),
                icon: const Icon(Icons.badge_outlined),
                label: const Text('Lihat KTP'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _showDocument(item, type: 'selfie', title: 'Foto selfie'),
                icon: const Icon(Icons.face_outlined),
                label: const Text('Lihat selfie'),
              ),
            ],
          ),

          if (item.documentStatus != null ||
              item.livenessStatus != null ||
              item.faceMatchStatus != null) ...[
            const SizedBox(height: 14),
            const Text(
              'Informasi pemeriksaan',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),

            if (item.documentStatus != null)
              InfoRow(
                Icons.badge_outlined,
                'Pemeriksaan dokumen: '
                '${_statusLabel(item.documentStatus)}',
              ),

            if (item.livenessStatus != null)
              InfoRow(
                Icons.face_outlined,
                'Pemeriksaan keaktifan: '
                '${_statusLabel(item.livenessStatus)}',
              ),

            if (item.faceMatchStatus != null)
              InfoRow(
                Icons.compare_outlined,
                'Pencocokan wajah: '
                '${_statusLabel(item.faceMatchStatus)}',
              ),
          ],

          if (item.failureReason != null && item.failureReason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            InfoRow(Icons.info_outline, 'Catatan: ${item.failureReason}'),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              GreenButton(
                label: 'Setujui',
                icon: Icons.check_circle_outline,
                expanded: false,
                loading: isBusy,
                onPressed: busyId != null
                    ? null
                    : () => _run(item, approve: true),
              ),
              GreenButton(
                label: 'Tolak',
                icon: Icons.cancel_outlined,
                expanded: false,
                danger: true,
                onPressed: busyId != null
                    ? null
                    : () => _run(item, approve: false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TabPage(
      title: 'Verifikasi Identitas',
      subtitle: 'Periksa KTP dan selfie pasien sebelum mengambil keputusan.',
      child: RefreshIndicator(
        onRefresh: _loadQueue,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                      'Periksa foto KTP dan selfie dengan teliti. '
                      'Setujui hanya jika data dapat diverifikasi. '
                      'Alasan penolakan wajib diisi.',
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Antrean (${verifications.length})',
                    style: const TextStyle(
                      color: AppColors.textGreen,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Muat ulang',
                  onPressed: loading ? null : _loadQueue,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              InlineError(error!),
            ],
            if (loading && verifications.isEmpty) ...[
              const SizedBox(height: 28),
              const Center(child: CircularProgressIndicator()),
            ] else if (verifications.isEmpty && error == null) ...[
              const SizedBox(height: 28),
              const Icon(Icons.inbox_outlined, size: 48, color: Colors.black38),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  'Belum ada pengajuan yang menunggu pemeriksaan.',
                  textAlign: TextAlign.center,
                ),
              ),
            ] else ...[
              for (final item in verifications) ...[
                const SizedBox(height: 10),
                _verificationCard(item),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
