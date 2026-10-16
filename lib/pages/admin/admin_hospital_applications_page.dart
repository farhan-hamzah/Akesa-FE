import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/staff_admin_models.dart';
import '../../services/akesa_api.dart';
import '../../services/akesa_staff_admin_api.dart';
import '../../theme/app_colors.dart';
import '../../widgets/shared/ui_kit.dart';

class AdminHospitalApplicationsPage extends StatefulWidget {
  final AkesaApi api;
  const AdminHospitalApplicationsPage({super.key, required this.api});

  @override
  State<AdminHospitalApplicationsPage> createState() =>
      _AdminHospitalApplicationsPageState();
}

class _AdminHospitalApplicationsPageState
    extends State<AdminHospitalApplicationsPage> {
  bool loading = true;
  String? error;
  List<HospitalApplication> items = [];
  String query = '';
  String? filter; // null = semua, or PENDING_REVIEW, REVISION_REQUIRED, APPROVED, REJECTED
  String? busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => loading = true);
    try {
      final result = await widget.api.adminGetHospitalApplications();
      if (!mounted) return;
      setState(() {
        items = result;
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

  Future<void> _approve(HospitalApplication app) async {
    if (busyId != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Setujui Pendaftaran?'),
        content: Text(
          'Pendaftaran "${app.name}" akan disetujui dan rumah sakit akan terdaftar di sistem.',
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
            child: const Text('Ya, Setujui'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => busyId = app.id);
    try {
      await widget.api.adminApproveHospitalApplication(app.id);
      await _load(silent: true);
      if (mounted) {
        showSnack(context, 'Pendaftaran "${app.name}" berhasil disetujui.');
      }
    } catch (e) {
      if (mounted) showSnack(context, apiErrorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  Future<void> _requestRevision(HospitalApplication app) async {
    if (busyId != null) return;
    final notes = await _showNotesDialog(
      title: 'Minta Revisi Pendaftaran',
      hintText: 'Tuliskan bagian data atau dokumen yang perlu diperbaiki...',
      actionLabel: 'Kirim Permintaan Revisi',
      actionColor: const Color(0xFFC05621),
    );

    if (notes == null || notes.trim().isEmpty) return;

    setState(() => busyId = app.id);
    try {
      await widget.api.adminRequestRevisionHospitalApplication(
        app.id,
        notes: notes.trim(),
      );
      await _load(silent: true);
      if (mounted) {
        showSnack(
          context,
          'Permintaan revisi dikirim ke pemohon "${app.name}".',
        );
      }
    } catch (e) {
      if (mounted) showSnack(context, apiErrorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  Future<void> _reject(HospitalApplication app) async {
    if (busyId != null) return;
    final notes = await _showNotesDialog(
      title: 'Tolak Pendaftaran',
      hintText: 'Tuliskan alasan penolakan pendaftaran...',
      actionLabel: 'Tolak Pendaftaran',
      actionColor: Colors.redAccent,
    );

    if (notes == null || notes.trim().isEmpty) return;

    setState(() => busyId = app.id);
    try {
      await widget.api.adminRejectHospitalApplication(
        app.id,
        notes: notes.trim(),
      );
      await _load(silent: true);
      if (mounted) {
        showSnack(context, 'Pendaftaran "${app.name}" telah ditolak.');
      }
    } catch (e) {
      if (mounted) showSnack(context, apiErrorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  Future<String?> _showNotesDialog({
    required String title,
    required String hintText,
    required String actionLabel,
    required Color actionColor,
  }) async {
    final ctl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: hintText,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: actionColor),
            onPressed: () {
              if (ctl.text.trim().isEmpty) {
                showSnack(ctx, 'Catatan wajib diisi.', error: true);
                return;
              }
              Navigator.pop(ctx, ctl.text.trim());
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    ctl.dispose();
    return result;
  }

  int _count(String s) => items.where((h) => h.status == s).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('Pendaftaran Rumah Sakit'),
        backgroundColor: kBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : error != null
          ? ErrorState(
              message: error!,
              onRetry: _load,
              authState: widget.api.authState,
            )
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final q = query.trim().toLowerCase();
    final shown = items.where((h) {
      if (filter != null && h.status != filter) return false;
      if (q.isEmpty) return true;
      return h.name.toLowerCase().contains(q) ||
          h.registrationNumber.toLowerCase().contains(q) ||
          h.email.toLowerCase().contains(q) ||
          h.picFullName.toLowerCase().contains(q);
    }).toList();

    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        children: [
          Text(
            'Tinjau dan verifikasi pengajuan pendaftaran rumah sakit baru dari formulir registrasi.',
            style: TextStyle(color: kMuted, fontSize: 13),
          ),
          const SizedBox(height: 14),

          // Search bar
          TextField(
            onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(
              hintText: 'Cari nama RS, PIC, email, atau no. registrasi',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('Semua (${items.length})', null),
                _chip(
                  'Menunggu (${_count('PENDING_REVIEW')})',
                  'PENDING_REVIEW',
                ),
                _chip(
                  'Perlu Revisi (${_count('REVISION_REQUIRED')})',
                  'REVISION_REQUIRED',
                ),
                _chip('Disetujui (${_count('APPROVED')})', 'APPROVED'),
                _chip('Ditolak (${_count('REJECTED')})', 'REJECTED'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (shown.isEmpty)
            const EmptyState(
              icon: Icons.assignment_outlined,
              title: 'Tidak ada pengajuan',
              message:
                  'Belum ada pendaftaran rumah sakit yang cocok dengan filter.',
            )
          else
            ...shown.map((app) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _card(app),
                )),
        ],
      ),
    );
  }

  Widget _chip(String label, String? value) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
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

  Widget _card(HospitalApplication app) {
    final busy = busyId == app.id;
    final tone = hospitalApplicationTone(app.status);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name & Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.name,
                      style: const TextStyle(
                        color: AppColors.textGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (app.createdAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Diajukan: ${formatDate(app.createdAt)}',
                        style: TextStyle(color: kMuted, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(tone),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: kBorder),
          const SizedBox(height: 12),

          // Detail rows
          _infoRow(Icons.numbers_outlined, 'No. Registrasi', app.registrationNumber),
          const SizedBox(height: 6),
          _infoRow(Icons.receipt_long_outlined, 'NPWP', app.npwp),
          const SizedBox(height: 6),
          _infoRow(Icons.phone_outlined, 'Telepon', app.phone),
          const SizedBox(height: 6),
          _infoRow(Icons.mail_outline, 'Email', app.email),
          const SizedBox(height: 6),
          _infoRow(Icons.place_outlined, 'Alamat', app.address),
          const SizedBox(height: 8),

          // PIC Info
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F8F5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorder),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.person_pin_outlined,
                  size: 20,
                  color: AppColors.darkGreen,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Penanggung Jawab (PIC)',
                        style: TextStyle(
                          color: kMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${app.picFullName} (${app.picPosition})',
                        style: const TextStyle(
                          color: AppColors.textGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Document URL
          if (app.licenseDocumentUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD0E0FF)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.description_outlined,
                    size: 20,
                    color: Color(0xFF0B5CAD),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Dokumen Izin Operasional',
                      style: const TextStyle(
                        color: Color(0xFF0B5CAD),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(
                        ClipboardData(text: app.licenseDocumentUrl),
                      );
                      showSnack(
                        context,
                        'Tautan dokumen berhasil disalin ke clipboard.',
                      );
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.copy, size: 14, color: Color(0xFF0B5CAD)),
                          SizedBox(width: 4),
                          Text(
                            'Salin Link',
                            style: TextStyle(
                              color: Color(0xFF0B5CAD),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Notes / Catatan
          if (app.notes != null && app.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFEDD5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Color(0xFFC05621),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Catatan Tinjauan:',
                          style: TextStyle(
                            color: Color(0xFFC05621),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          app.notes!,
                          style: const TextStyle(
                            color: Color(0xFF7C2D12),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Action Buttons (Only for PENDING_REVIEW or REVISION_REQUIRED)
          if (app.status == 'PENDING_REVIEW' ||
              app.status == 'REVISION_REQUIRED') ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GreenButton(
                    label: 'Setujui',
                    icon: Icons.check_circle_outline,
                    compact: true,
                    expanded: false,
                    loading: busy,
                    onPressed: () => _approve(app),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SoftButton(
                    label: 'Minta Revisi',
                    icon: Icons.edit_note_outlined,
                    color: const Color(0xFFC05621),
                    onPressed: busy ? null : () => _requestRevision(app),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SoftButton(
                    label: 'Tolak',
                    icon: Icons.cancel_outlined,
                    color: Colors.redAccent,
                    onPressed: busy ? null : () => _reject(app),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: kMuted),
        const SizedBox(width: 6),
        SizedBox(
          width: 95,
          child: Text(
            label,
            style: TextStyle(color: kMuted, fontSize: 12),
          ),
        ),
        const Text(': ', style: TextStyle(color: kMuted, fontSize: 12)),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(
              color: AppColors.textGreen,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
