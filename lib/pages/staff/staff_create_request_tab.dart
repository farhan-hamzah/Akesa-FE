import 'package:flutter/material.dart';

import '../../services/akesa_api.dart';
import '../../services/akesa_staff_admin_api.dart';
import '../../theme/app_colors.dart';
import '../../widgets/shared/ui_kit.dart';

class StaffCreateRequestTab extends StatefulWidget {
  final AkesaApi api;
  final VoidCallback onCreated;
  const StaffCreateRequestTab({
    super.key,
    required this.api,
    required this.onCreated,
  });

  @override
  State<StaffCreateRequestTab> createState() => _StaffCreateRequestTabState();
}

class _StaffCreateRequestTabState extends State<StaffCreateRequestTab> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _purpose = TextEditingController();
  final Set<String> selected = {};
  bool saving = false;
  String? error;
  bool categoryMissing = false;

  @override
  void dispose() {
    _code.dispose();
    _purpose.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _form.currentState!.validate();
    setState(() => categoryMissing = selected.isEmpty);
    if (!valid || selected.isEmpty) return;

    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.api.staffCreateAccessRequest(
        patientCode: _code.text.trim(),
        purpose: _purpose.text.trim(),
        categories: kCategoryIds.where(selected.contains).toList(),
      );
      if (!mounted) return;
      _code.clear();
      _purpose.clear();
      setState(() => selected.clear());
      showSnack(context, 'Permintaan terkirim. Menunggu persetujuan pasien.');
      widget.onCreated();
    } catch (e) {
      if (mounted) setState(() => error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TabPage(
      title: 'Buat Permintaan',
      subtitle: 'Minta izin pasien untuk mengakses data tertentu',
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _title('1. Kode pasien'),
                  TextFormField(
                    controller: _code,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Kode pasien wajib diisi'
                        : null,
                    decoration: const InputDecoration(
                      hintText: 'Masukkan kode dari pasien',
                      prefixIcon: Icon(Icons.qr_code_2),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _title('2. Tujuan permintaan'),
                  TextFormField(
                    controller: _purpose,
                    maxLines: 3,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Tujuan wajib diisi'
                        : null,
                    decoration: const InputDecoration(
                      hintText: 'Contoh: Pemeriksaan rawat jalan poli umum',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            AppCard(
              borderColor: categoryMissing ? AppColors.errorText : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _title('3. Data yang diminta'),
                  const Text(
                    'Pilih hanya data yang benar-benar dibutuhkan. Pasien dapat menyetujui atau menolak.',
                    style: TextStyle(color: kMuted, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  ...kCategoryIds.map(
                    (id) => CheckboxListTile(
                      value: selected.contains(id),
                      onChanged: (v) => setState(() {
                        v == true ? selected.add(id) : selected.remove(id);
                        categoryMissing = false;
                      }),
                      activeColor: AppColors.primaryGreen,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        kCategoryLabels[id]!,
                        style: const TextStyle(
                          color: AppColors.textGreen,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        kCategoryHints[id]!,
                        style: const TextStyle(fontSize: 11.5),
                      ),
                    ),
                  ),
                  if (categoryMissing)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Pilih minimal satu kategori data.',
                        style: TextStyle(
                          color: AppColors.errorText,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 14),
              InlineError(error!),
            ],
            const SizedBox(height: 16),
            GreenButton(
              label: 'Kirim Permintaan',
              icon: Icons.send_outlined,
              loading: saving,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _title(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t,
      style: const TextStyle(
        color: AppColors.textGreen,
        fontSize: 15,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
