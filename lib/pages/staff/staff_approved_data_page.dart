import 'package:flutter/material.dart';

import '../../models/access_request_data.dart';
import '../../models/api_exception.dart';
import '../../services/akesa_api.dart';
import '../../services/akesa_staff_admin_api.dart';
import '../../theme/app_colors.dart';
import '../../widgets/shared/ui_kit.dart';

class StaffApprovedDataPage extends StatefulWidget {
  final AkesaApi api;
  final AccessRequestData request;
  const StaffApprovedDataPage({
    super.key,
    required this.api,
    required this.request,
  });

  @override
  State<StaffApprovedDataPage> createState() => _StaffApprovedDataPageState();
}

class _StaffApprovedDataPageState extends State<StaffApprovedDataPage> {
  bool loading = true;
  Object? error;
  Map<String, dynamic>? data;

  static const _labels = {
    'fullName': 'Nama Lengkap',
    'nik': 'NIK',
    'dateOfBirth': 'Tanggal Lahir',
    'gender': 'Jenis Kelamin',
    'phoneNumber': 'Nomor Telepon',
    'address': 'Alamat',
    'bloodType': 'Golongan Darah',
    'drugAllergy': 'Alergi Obat',
    'medicalHistory': 'Riwayat Medis',
    'insuranceNumber': 'Nomor Asuransi',
    'emergencyContactName': 'Nama Kontak Darurat',
    'emergencyContactPhone': 'Telepon Kontak Darurat',
    'patientCode': 'Kode Pasien',
  };

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
      final d = await widget.api.staffFetchApprovedData(widget.request.id);
      if (mounted) setState(() => data = d);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _label(String key) {
    if (_labels.containsKey(key)) return _labels[key]!;
    final spaced = key
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .replaceAll('_', ' ');
    return spaced.isEmpty ? key : spaced[0].toUpperCase() + spaced.substring(1);
  }

  String _text(dynamic v) {
    if (v == null) return '-';
    if (v is List) return v.isEmpty ? '-' : v.map(_text).join(', ');
    final s = v.toString().trim();
    return s.isEmpty ? '-' : s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkGreen,
        elevation: 0,
        title: const Text(
          'Data Pasien',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: CenteredBody(
          child: loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                  ),
                )
              : error != null
              ? _buildError()
              : _buildData(),
        ),
      ),
    );
  }

  Widget _buildError() {
    final e = error;
    if (e is ApiException && e.message == 'patient_data_integrity_violation') {
      return ListView(
        padding: const EdgeInsets.all(18),
        children: [
          AppCard(
            color: AppColors.errorBackground,
            borderColor: AppColors.errorBorder,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.gpp_bad, color: AppColors.errorText, size: 52),
                const SizedBox(height: 10),
                const Text(
                  'Akses Diblokir',
                  style: TextStyle(
                    color: AppColors.errorText,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  apiErrorMessage(e),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.errorText,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Kejadian ini telah dicatat. Hubungi administrator.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.errorText, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return ErrorState(message: apiErrorMessage(e!), onRetry: _load);
  }

  Widget _buildData() {
    final scalars = <MapEntry<String, dynamic>>[];
    final sections = <MapEntry<String, Map<String, dynamic>>>[];
    data!.forEach((k, v) {
      if (v is Map) {
        sections.add(MapEntry(k, Map<String, dynamic>.from(v)));
      } else {
        scalars.add(MapEntry(k, v));
      }
    });

    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          AppCard(
            color: AppColors.lightGreen,
            borderColor: AppColors.lightGreen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.lock_open_outlined,
                      color: AppColors.darkGreen,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Hanya data yang disetujui pasien',
                        style: TextStyle(
                          color: AppColors.darkGreen,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    StatusBadge(accessTone(widget.request.status)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.request.purpose,
                  style: const TextStyle(
                    color: AppColors.textGreen,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 8),
                CategoryChips(widget.request.categories),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (data!.isEmpty)
            const EmptyState(
              icon: Icons.folder_off_outlined,
              title: 'Tidak ada data',
              message:
                  'Pasien belum mengisi data pada kategori yang disetujui.',
            ),
          if (scalars.isNotEmpty) _section('Informasi Pasien', scalars),
          ...sections.map(
            (s) => _section(_label(s.key), s.value.entries.toList()),
          ),
          const SizedBox(height: 4),
          const Text(
            'Akses data ini dicatat dalam audit. Jangan membagikan atau menyalin data ke pihak yang tidak berwenang.',
            textAlign: TextAlign.center,
            style: TextStyle(color: kMuted, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<MapEntry<String, dynamic>> rows) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textGreen,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              ...rows.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _label(e.key),
                        style: const TextStyle(color: kMuted, fontSize: 11),
                      ),
                      const SizedBox(height: 2),
                      SelectableText(
                        _text(e.value),
                        style: const TextStyle(
                          color: AppColors.textGreen,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
