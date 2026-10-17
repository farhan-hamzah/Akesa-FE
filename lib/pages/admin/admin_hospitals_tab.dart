import 'package:flutter/material.dart';

import '../../models/staff_admin_models.dart';
import '../../services/akesa_api.dart';
import '../../services/akesa_staff_admin_api.dart';
import '../../theme/app_colors.dart';
import '../../widgets/shared/ui_kit.dart';
import 'admin_hospital_applications_page.dart';

class AdminHospitalsTab extends StatefulWidget {
  final AkesaApi api;
  const AdminHospitalsTab({super.key, required this.api});

  @override
  State<AdminHospitalsTab> createState() => _AdminHospitalsTabState();
}

class _AdminHospitalsTabState extends State<AdminHospitalsTab> {
  bool loading = true;
  String? error;
  List<AdminHospital> items = [];
  String query = '';
  String? filter; // null = semua
  String? busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => loading = true);
    try {
      final result = await widget.api.adminGetHospitals();
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

  Future<void> _activateHospital(AdminHospital h) async {
    if (busyId != null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aktifkan rumah sakit?'),
        content: Text('${h.name} akan diaktifkan dan dapat beroperasi di sistem.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primaryGreen),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aktifkan'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => busyId = h.id);
    try {
      // Hit endpoint PATCH /api/v1/admin/hospitals/{id}/activate
      final updated = await widget.api.adminActivateHospital(h.id);
      if (!mounted) return;
      setState(() {
        final idx = items.indexWhere((item) => item.id == h.id);
        if (idx != -1) items[idx] = updated;
      });
      await _load(silent: true);
      if (mounted) showSnack(context, '${h.name} berhasil diaktifkan.');
    } catch (e) {
      if (mounted) showSnack(context, apiErrorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  Future<void> _deactivateHospital(AdminHospital h) async {
    if (busyId != null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nonaktifkan rumah sakit?'),
        content: Text('${h.name} akan berstatus Nonaktif.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Nonaktifkan'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => busyId = h.id);
    try {
      // Hit endpoint PATCH /api/v1/admin/hospitals/{id}/deactivate
      final updated = await widget.api.adminDeactivateHospital(h.id);
      if (!mounted) return;
      setState(() {
        final idx = items.indexWhere((item) => item.id == h.id);
        if (idx != -1) items[idx] = updated;
      });
      await _load(silent: true);
      if (mounted) showSnack(context, '${h.name} dinonaktifkan.');
    } catch (e) {
      if (mounted) showSnack(context, apiErrorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  Future<void> _openApplications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminHospitalApplicationsPage(api: widget.api),
      ),
    );
    _load(silent: true);
  }

  Future<void> _addStaff(AdminHospital h) async {
    final added = await showAppSheet<bool>(
      context,
      'Tambah Petugas',
      _StaffFormSheet(api: widget.api, hospital: h),
    );
    if (added == true && mounted) {
      showSnack(context, 'Petugas berhasil ditambahkan.');
    }
  }

  int _count(String s) => items.where((h) => h.status == s).length;

  @override
  Widget build(BuildContext context) {
    return TabPage(
      title: 'Rumah Sakit',
      subtitle: 'Aktivasi dan kelola petugas rumah sakit terdaftar',
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
    final q = query.trim().toLowerCase();
    final shown = items.where((h) {
      if (filter != null && h.status != filter) return false;
      if (q.isEmpty) return true;
      return h.name.toLowerCase().contains(q) ||
          h.registrationNumber.toLowerCase().contains(q) ||
          h.email.toLowerCase().contains(q);
    }).toList();

    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        children: [
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: [
              _stat('Semua', items.length, null),
              _stat('Aktif', _count('ACTIVE'), 'ACTIVE'),
              _stat('Nonaktif', _count('INACTIVE'), 'INACTIVE'),
            ],
          ),
          const SizedBox(height: 14),
          GreenButton(
            label: 'Tinjau Pendaftaran RS',
            icon: Icons.assignment_turned_in_outlined,
            onPressed: _openApplications,
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(
              hintText: 'Cari nama, email, atau nomor registrasi',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('Semua', null),
                _chip('Aktif', 'ACTIVE'),
                _chip('Nonaktif', 'INACTIVE'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (shown.isEmpty)
            const EmptyState(
              icon: Icons.local_hospital_outlined,
              title: 'Tidak ada rumah sakit',
              message:
                  'Belum ada data yang cocok dengan pencarian atau filter.',
            )
          else
            ...shown.map(
              (h) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _card(h),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(String label, int n, String? status) {
    final tone = status == null
        ? const Tone('Semua', AppColors.darkGreen, AppColors.lightGreen)
        : hospitalTone(status);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => filter = filter == status ? null : status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: tone.bg,
          borderRadius: BorderRadius.circular(14),
          border: filter == status
              ? Border.all(color: tone.fg, width: 1.5)
              : null,
        ),
        child: Row(
          children: [
            Text(
              '$n',
              style: TextStyle(
                color: tone.fg,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tone.fg,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
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

  Widget _card(AdminHospital h) {
    final busy = busyId == h.id;
    final actions = <Widget>[];
    switch (h.status) {
      case 'ACTIVE':
        actions.add(
          SoftButton(
            label: 'Tambah Petugas',
            icon: Icons.person_add_alt,
            onPressed: busy ? null : () => _addStaff(h),
          ),
        );
        actions.add(
          SoftButton(
            label: 'Nonaktifkan',
            icon: Icons.block,
            color: AppColors.errorText,
            onPressed: busy ? null : () => _deactivateHospital(h),
          ),
        );
        break;
      case 'INACTIVE':
        actions.add(
          GreenButton(
            label: 'Aktifkan Kembali',
            icon: Icons.power_settings_new,
            compact: true,
            expanded: false,
            loading: busy,
            onPressed: () => _activateHospital(h),
          ),
        );
        break;
      default:
        actions.add(
          GreenButton(
            label: 'Aktifkan',
            icon: Icons.power_settings_new,
            compact: true,
            expanded: false,
            loading: busy,
            onPressed: () => _activateHospital(h),
          ),
        );
        break;
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  h.name,
                  style: const TextStyle(
                    color: AppColors.textGreen,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(hospitalTone(h.status)),
            ],
          ),
          const SizedBox(height: 4),
          InfoRow(
            Icons.confirmation_number_outlined,
            'No. Registrasi: ${h.registrationNumber}',
          ),
          InfoRow(Icons.location_on_outlined, h.address),
          InfoRow(Icons.phone_outlined, h.phone),
          InfoRow(Icons.email_outlined, h.email),
          InfoRow(Icons.schedule, 'Dibuat ${formatDate(h.createdAt)}'),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ FORMS
class _StaffFormSheet extends StatefulWidget {
  final AkesaApi api;
  final AdminHospital hospital;
  const _StaffFormSheet({required this.api, required this.hospital});

  @override
  State<_StaffFormSheet> createState() => _StaffFormSheetState();
}

class _StaffFormSheetState extends State<_StaffFormSheet> {
  final _form = GlobalKey<FormState>();
  final _userId = TextEditingController();
  final _name = TextEditingController();
  final _position = TextEditingController();
  bool saving = false;
  String? serverError;

  @override
  void dispose() {
    _userId.dispose();
    _name.dispose();
    _position.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      saving = true;
      serverError = null;
    });
    try {
      await widget.api.adminAddStaff(
        hospitalId: widget.hospital.id,
        userId: _userId.text.trim(),
        fullName: _name.text.trim(),
        position: _position.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => serverError = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    return Form(
      key: _form,
      child: Column(
        children: [
          AppCard(
            color: AppColors.lightGreen,
            borderColor: AppColors.lightGreen,
            child: Row(
              children: [
                const Icon(
                  Icons.local_hospital,
                  color: AppColors.darkGreen,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.hospital.name,
                    style: const TextStyle(
                      color: AppColors.darkGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          gap,
          TextFormField(
            controller: _userId,
            validator: (v) => kUuidRegex.hasMatch((v ?? '').trim())
                ? null
                : 'ID pengguna harus berupa UUID',
            decoration: const InputDecoration(
              labelText: 'ID pengguna (UUID)',
              helperText: 'Pengguna akan otomatis menjadi petugas rumah sakit',
              helperMaxLines: 2,
            ),
          ),
          gap,
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
            decoration: const InputDecoration(
              labelText: 'Nama lengkap petugas',
            ),
          ),
          gap,
          TextFormField(
            controller: _position,
            decoration: const InputDecoration(labelText: 'Jabatan (opsional)'),
          ),
          if (serverError != null) ...[gap, InlineError(serverError!)],
          const SizedBox(height: 16),
          GreenButton(
            label: 'Tambah Petugas',
            icon: Icons.person_add_alt,
            loading: saving,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
