import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';

import '../../models/api_exception.dart';
import '../../models/staff_admin_models.dart';
import '../../services/akesa_api.dart';
import '../../theme/app_colors.dart';
import '../role_gate_page.dart';
import 'hospital_registration_page.dart';

class HospitalApplicationStatusPage extends StatefulWidget {
  final ClerkAuthState authState;
  final HospitalApplication? initialApplication;

  const HospitalApplicationStatusPage({
    super.key,
    required this.authState,
    this.initialApplication,
  });

  @override
  State<HospitalApplicationStatusPage> createState() =>
      _HospitalApplicationStatusPageState();
}

class _HospitalApplicationStatusPageState
    extends State<HospitalApplicationStatusPage> {
  late final AkesaApi api;
  HospitalApplication? application;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    api = AkesaApi(authState: widget.authState);
    application = widget.initialApplication;
    if (application == null) {
      _loadApplication();
    } else {
      loading = false;
    }
  }

  Future<void> _loadApplication({bool silent = false}) async {
    if (!silent) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    try {
      final app = await api.getMyHospitalApplication();
      if (!mounted) return;
      setState(() {
        application = app;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      String msg = 'Gagal memuat status pengajuan.';
      if (e is ApiException) msg = e.message;
      setState(() => error = msg);
    } finally {
      if (mounted && !silent) setState(() => loading = false);
    }
  }

  void _navigateToRevision(HospitalApplication app) async {
    final result = await Navigator.of(context).push<HospitalApplication>(
      MaterialPageRoute(
        builder: (_) => HospitalRegistrationPage(
          authState: widget.authState,
          initialApplication: app,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() => application = result);
    } else {
      _loadApplication(silent: true);
    }
  }

  void _navigateToRoleGate() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => RoleGatePage(authState: widget.authState),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF7),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkGreen,
        centerTitle: false,
        title: const Text(
          'Status Pengajuan RS',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkGreen),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primaryGreen,
          onRefresh: () => _loadApplication(silent: true),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      );
    }

    if (error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          const Icon(Icons.error_outline, size: 48, color: AppColors.errorText),
          const SizedBox(height: 12),
          Center(
            child: Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.errorText),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: ElevatedButton.icon(
              onPressed: () => _loadApplication(),
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    final app = application;

    if (app == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5EDE3)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.local_hospital_outlined,
                  size: 56,
                  color: AppColors.primaryGreen,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Belum Ada Pengajuan Rumah Sakit',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkGreen,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Anda belum memiliki pengajuan pendaftaran fasilitas kesehatan yang sedang berjalan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => HospitalRegistrationPage(
                            authState: widget.authState,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_business_outlined),
                    label: const Text('Daftarkan Rumah Sakit Sekarang'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
      children: [
        _buildStatusCard(app),
        const SizedBox(height: 16),
        _buildHospitalDetailsCard(app),
        const SizedBox(height: 16),
        _buildPicDetailsCard(app),
      ],
    );
  }

  Widget _buildStatusCard(HospitalApplication app) {
    Color badgeBg;
    Color badgeText;
    Color badgeBorder;
    String statusTitle;
    String statusDescription;
    IconData statusIcon;

    switch (app.status) {
      case 'APPROVED':
        badgeBg = const Color(0xFFEAF5E8);
        badgeText = const Color(0xFF237804);
        badgeBorder = const Color(0xFFB5DAB2);
        statusTitle = 'Pengajuan Disetujui';
        statusDescription =
            'Selamat! Fasilitas kesehatan telah diverifikasi dan disetujui oleh Administrator Akesa. Akun Anda telah terhubung sebagai Petugas Rumah Sakit.';
        statusIcon = Icons.check_circle_outline;
        break;
      case 'REVISION_REQUIRED':
        badgeBg = const Color(0xFFFFF7E6);
        badgeText = const Color(0xFFD46B08);
        badgeBorder = const Color(0xFFFFD591);
        statusTitle = 'Perlu Revisi';
        statusDescription =
            'Administrator memerlukan perbaikan pada data atau dokumen legalitas faskes Anda sebelum pengajuan dapat diproses lebih lanjut.';
        statusIcon = Icons.edit_note_outlined;
        break;
      case 'REJECTED':
        badgeBg = const Color(0xFFFFF1F0);
        badgeText = const Color(0xFFCF1322);
        badgeBorder = const Color(0xFFFFA39E);
        statusTitle = 'Pengajuan Ditolak';
        statusDescription =
            'Mohon maaf, pengajuan pendaftaran faskes Anda tidak dapat disetujui oleh Administrator Akesa.';
        statusIcon = Icons.cancel_outlined;
        break;
      case 'PENDING_REVIEW':
      default:
        badgeBg = const Color(0xFFFFFBE6);
        badgeText = const Color(0xFFD48806);
        badgeBorder = const Color(0xFFFFE58F);
        statusTitle = 'Menunggu Peninjauan';
        statusDescription =
            'Pengajuan Anda telah diterima dan saat ini sedang ditinjau oleh tim Administrator Akesa. Verifikasi umumnya memakan waktu 1-3 hari kerja.';
        statusIcon = Icons.hourglass_top_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EDE3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(statusIcon, color: badgeText, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textGreen,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'No. Izin: ${app.registrationNumber}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: badgeBorder),
            ),
            child: Text(
              statusTitle.toUpperCase(),
              style: TextStyle(
                color: badgeText,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            statusDescription,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.45,
            ),
          ),

          // Catatan Admin (Notes)
          if (app.notes != null && app.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: app.status == 'REVISION_REQUIRED'
                    ? const Color(0xFFFFF9E6)
                    : const Color(0xFFF9F9F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: app.status == 'REVISION_REQUIRED'
                      ? const Color(0xFFFFD566)
                      : Colors.grey.shade300,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.comment_outlined,
                        size: 16,
                        color: app.status == 'REVISION_REQUIRED'
                            ? const Color(0xFFD48806)
                            : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        app.status == 'REVISION_REQUIRED'
                            ? 'Catatan Permintaan Revisi:'
                            : 'Catatan Administrator:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: app.status == 'REVISION_REQUIRED'
                              ? const Color(0xFF874D00)
                              : Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    app.notes!,
                    style: TextStyle(
                      fontSize: 13,
                      color: app.status == 'REVISION_REQUIRED'
                          ? const Color(0xFF613400)
                          : Colors.grey.shade800,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Tombol Aksi jika Revisi atau Disetujui
          if (app.status == 'REVISION_REQUIRED') ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _navigateToRevision(app),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text(
                  'Perbaiki & Ajukan Ulang Data',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD46B08),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],

          if (app.status == 'APPROVED') ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _navigateToRoleGate,
                icon: const Icon(Icons.dashboard_outlined, size: 18),
                label: const Text(
                  'Buka Portal Rumah Sakit',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHospitalDetailsCard(HospitalApplication app) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EDE3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.local_hospital_outlined, size: 18, color: AppColors.primaryGreen),
              SizedBox(width: 8),
              Text(
                'Data Rumah Sakit',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkGreen,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _buildInfoRow('Nama Rumah Sakit', app.name),
          _buildInfoRow('No. Registrasi Kemenkes', app.registrationNumber),
          _buildInfoRow('Email Resmi', app.email),
          _buildInfoRow('Nomor Telepon', app.phone),
          _buildInfoRow('Alamat', app.address),
          if (app.npwp.isNotEmpty) _buildInfoRow('NPWP', app.npwp),
          if (app.licenseDocumentUrl.isNotEmpty)
            _buildInfoRow('Tautan Berkas Legalitas', app.licenseDocumentUrl),
        ],
      ),
    );
  }

  Widget _buildPicDetailsCard(HospitalApplication app) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EDE3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person_outline, size: 18, color: AppColors.primaryGreen),
              SizedBox(width: 8),
              Text(
                'Data Penanggung Jawab (PIC)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkGreen,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _buildInfoRow('Nama Lengkap PIC', app.picFullName),
          _buildInfoRow('Jabatan / Posisi', app.picPosition),
          if (app.createdAt != null)
            _buildInfoRow('Waktu Pengajuan', _formatDateTime(app.createdAt!)),
          if (app.updatedAt != null)
            _buildInfoRow('Terakhir Diperbarui', _formatDateTime(app.updatedAt!)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 2),
          Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textGreen,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} WIB';
    } catch (_) {
      return raw;
    }
  }
}
