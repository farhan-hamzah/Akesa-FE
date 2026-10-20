import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/api_exception.dart';
import '../../models/staff_admin_models.dart';
import '../../services/akesa_api.dart';
import '../../theme/app_colors.dart';
import 'hospital_application_status_page.dart';

class HospitalRegistrationPage extends StatefulWidget {
  final ClerkAuthState authState;
  final HospitalApplication? initialApplication; // Jika mode revisi
  final String? initialKeyCode;

  const HospitalRegistrationPage({
    super.key,
    required this.authState,
    this.initialApplication,
    this.initialKeyCode,
  });

  @override
  State<HospitalRegistrationPage> createState() =>
      _HospitalRegistrationPageState();
}

class _HospitalRegistrationPageState extends State<HospitalRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _keyGateFormKey = GlobalKey<FormState>();
  late final AkesaApi api;

  // Step: 0 = Input Kunci Registrasi (Gate), 1 = Formulir Data Faskes
  int _step = 0;

  // Controllers
  final _keyCodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _regNumberController = TextEditingController();
  final _npwpController = TextEditingController();
  final _licenseDocController = TextEditingController();
  final _picFullNameController = TextEditingController();
  final _picPositionController = TextEditingController();

  // State
  bool _isValidatingKey = false;
  HospitalInvitationValidation? _validatedKeyInfo;
  String? _keyValidationError;

  bool _isSubmitting = false;

  bool get _isRevisionMode => widget.initialApplication != null;

  @override
  void initState() {
    super.initState();
    api = AkesaApi(authState: widget.authState);

    if (_isRevisionMode) {
      // Pada mode revisi, langsung masuk ke formulir (kunci sudah pernah diklaim)
      _step = 1;
      final app = widget.initialApplication!;
      _nameController.text = app.name;
      _addressController.text = app.address;
      _phoneController.text = app.phone;
      _emailController.text = app.email;
      _regNumberController.text = app.registrationNumber;
      _npwpController.text = app.npwp;
      _licenseDocController.text = app.licenseDocumentUrl;
      _picFullNameController.text = app.picFullName;
      _picPositionController.text = app.picPosition;
    } else {
      _step = 0;
      // Pre-fill nama PIC dari sesi Clerk
      final clerkUser = widget.authState.user;
      final clerkName = clerkUser?.name ??
          [clerkUser?.firstName, clerkUser?.lastName]
              .whereType<String>()
              .where((s) => s.isNotEmpty)
              .join(' ');
      if (clerkName.trim().isNotEmpty) {
        _picFullNameController.text = clerkName.trim();
      }
      _picPositionController.text = 'Perwakilan / PIC';

      if (widget.initialKeyCode != null && widget.initialKeyCode!.isNotEmpty) {
        _keyCodeController.text = widget.initialKeyCode!.trim().toUpperCase();
      }
    }
  }

  @override
  void dispose() {
    _keyCodeController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _regNumberController.dispose();
    _npwpController.dispose();
    _licenseDocController.dispose();
    _picFullNameController.dispose();
    _picPositionController.dispose();
    super.dispose();
  }

  Future<void> _validateAndProceed() async {
    final code = _keyCodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() {
        _keyValidationError = 'Kunci registrasi wajib diisi';
        _validatedKeyInfo = null;
      });
      return;
    }

    setState(() {
      _isValidatingKey = true;
      _keyValidationError = null;
      _validatedKeyInfo = null;
    });

    try {
      final info = await api.validateHospitalInvitation(code);
      if (!mounted) return;

      setState(() {
        _validatedKeyInfo = info;
        _keyValidationError = null;
        // Jika email RS masih kosong dan info.targetEmail tersedia, pre-fill email
        if (_emailController.text.trim().isEmpty &&
            info.targetEmail.isNotEmpty &&
            info.targetEmail.contains('@')) {
          _emailController.text = info.targetEmail;
        }
        // Maju ke Step 1 (Formulir Pengisian Data Faskes)
        _step = 1;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Kunci berhasil diverifikasi untuk faskes (${info.targetEmail})',
          ),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      String msg = 'Kunci registrasi tidak valid.';
      if (e is ApiException) {
        if (e.statusCode == 404 || e.message == 'invitation_key_not_found') {
          msg = 'Kunci registrasi tidak ditemukan. Pastikan kode diketik dengan benar.';
        } else if (e.statusCode == 410 || e.message == 'invitation_key_expired') {
          msg = 'Kunci registrasi telah kedaluwarsa. Hubungi administrator untuk meminta kunci baru.';
        } else if (e.statusCode == 409 || e.message == 'invitation_key_already_used') {
          msg = 'Kunci registrasi ini sudah pernah digunakan untuk mendaftar faskes.';
        } else {
          msg = e.message;
        }
      }
      setState(() {
        _keyValidationError = msg;
        _validatedKeyInfo = null;
      });
    } finally {
      if (mounted) setState(() => _isValidatingKey = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Jika mode pendaftaran baru, pastikan kunci sudah divalidasi
    if (!_isRevisionMode && _validatedKeyInfo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan verifikasi kunci registrasi terlebih dahulu.'),
          backgroundColor: AppColors.errorText,
        ),
      );
      setState(() => _step = 0);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_isRevisionMode) {
        // Resubmit revisi via PUT /api/v1/hospitals/my-application
        final updatedApp = await api.resubmitHospitalApplication(
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          registrationNumber: _regNumberController.text.trim(),
          npwp: _npwpController.text.trim(),
          licenseDocumentUrl: _licenseDocController.text.trim(),
          picFullName: _picFullNameController.text.trim(),
          picPosition: _picPositionController.text.trim(),
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perbaikan data permohonan berhasil dikirim ulang!'),
            backgroundColor: AppColors.primaryGreen,
          ),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HospitalApplicationStatusPage(
              authState: widget.authState,
              initialApplication: updatedApp,
            ),
          ),
        );
      } else {
        // Pendaftaran baru via POST /api/v1/hospitals/register
        final createdApp = await api.registerHospitalWithKey(
          keyCode: _keyCodeController.text.trim().toUpperCase(),
          name: _nameController.text.trim(),
          address: _addressController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          registrationNumber: _regNumberController.text.trim(),
          npwp: _npwpController.text.trim(),
          licenseDocumentUrl: _licenseDocController.text.trim(),
          picFullName: _picFullNameController.text.trim(),
          picPosition: _picPositionController.text.trim(),
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pendaftaran faskes berhasil diajukan!'),
            backgroundColor: AppColors.primaryGreen,
          ),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HospitalApplicationStatusPage(
              authState: widget.authState,
              initialApplication: createdApp,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      String msg = 'Gagal menyimpan data pendaftaran.';
      if (e is ApiException) {
        if (e.message == 'email_already_registered') {
          msg = 'Email faskes sudah terdaftar pada sistem.';
        } else if (e.message == 'registration_number_already_registered') {
          msg = 'Nomor registrasi Kemenkes sudah terdaftar.';
        } else if (e.message == 'invitation_key_not_found') {
          msg = 'Kunci registrasi tidak ditemukan.';
        } else if (e.message == 'invitation_key_expired') {
          msg = 'Kunci registrasi telah kedaluwarsa.';
        } else if (e.message == 'invitation_key_already_used') {
          msg = 'Kunci registrasi sudah pernah digunakan.';
        } else {
          msg = e.message;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.errorText),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _handleBackNavigation() {
    if (_step == 1 && !_isRevisionMode) {
      // Kembali ke layar input kunci registrasi
      setState(() => _step = 0);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0 || _isRevisionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: AppColors.darkGreen,
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBackNavigation,
          ),
          title: Text(
            _isRevisionMode
                ? 'Perbaiki Pengajuan RS'
                : _step == 0
                    ? 'Kunci Registrasi RS'
                    : 'Formulir Pendaftaran RS',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.darkGreen,
            ),
          ),
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            child: _step == 0
                ? _buildKeyGateScreen()
                : _buildRegistrationFormScreen(),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // STEP 0: LAYAR MASUKKAN KUNCI REGISTRASI (KEY GATE)
  // =========================================================================
  Widget _buildKeyGateScreen() {
    return Form(
      key: _keyGateFormKey,
      child: SingleChildScrollView(
        key: const ValueKey('step_0_key_gate'),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 10),

            // Icon / Hero Visual
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.lightGreen,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFC7E2BE), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGreen.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.vpn_key_rounded,
                size: 40,
                color: AppColors.primaryGreen,
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Akses Registrasi Rumah Sakit',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.darkGreen,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Masukkan kunci undangan yang diterbitkan oleh Administrator Akesa untuk memverifikasi faskes Anda.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.45,
              ),
            ),

            const SizedBox(height: 28),

            // Input Kunci Registrasi
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE5EDE3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'KUNCI REGISTRASI FASKES',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: AppColors.textGreen,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _keyCodeController,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: AppColors.darkGreen,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
                      TextInputFormatter.withFunction((oldVal, newVal) {
                        return TextEditingValue(
                          text: newVal.text.toUpperCase(),
                          selection: newVal.selection,
                        );
                      }),
                    ],
                    decoration: InputDecoration(
                      hintText: 'AKESA-XXXX-YYYY',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 15,
                        letterSpacing: 1.5,
                      ),
                      prefixIcon: const Icon(
                        Icons.key_outlined,
                        color: AppColors.primaryGreen,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFFBFDFB),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.inputBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.inputBorderEnabled,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primaryGreen,
                          width: 1.8,
                        ),
                      ),
                    ),
                  ),

                  // Error Message
                  if (_keyValidationError != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.errorBackground,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.errorBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 16,
                            color: AppColors.errorText,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _keyValidationError!,
                              style: const TextStyle(
                                color: AppColors.errorText,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Tombol Verifikasi & Lanjut
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isValidatingKey ? null : _validateAndProceed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isValidatingKey
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Verifikasi Kunci & Lanjutkan',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, size: 18),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Informasi Bantuan
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FBF8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8EFE6)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.primaryGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Belum Memiliki Kunci Registrasi?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkGreen,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Kunci registrasi faskes diterbitkan khusus oleh Administrator Akesa. Hubungi administrator sistem jika Anda adalah perwakilan resmi faskes yang ingin bergabung.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // STEP 1: FORMULIR DATA RUMAH SAKIT & PIC
  // =========================================================================
  Widget _buildRegistrationFormScreen() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        key: const ValueKey('step_1_form'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Status Kunci / Banner Revisi
            if (_isRevisionMode && widget.initialApplication?.notes != null)
              _buildRevisionAlert(widget.initialApplication!.notes!)
            else
              _buildVerifiedKeyBadge(),

            const SizedBox(height: 20),

            // Bagian 1: Data Rumah Sakit
            _buildSectionHeader(
              icon: Icons.local_hospital_outlined,
              title: 'Informasi Rumah Sakit / Faskes',
              subtitle: 'Lengkapi profil legalitas dan kontak resmi fasilitas kesehatan.',
            ),
            const SizedBox(height: 14),

            _buildTextField(
              controller: _nameController,
              label: 'Nama Rumah Sakit *',
              hint: 'Contoh: RS Umum Daerah Dr. Soetomo',
              icon: Icons.business_outlined,
              maxLength: 120,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Nama rumah sakit wajib diisi';
                }
                return null;
              },
            ),

            _buildTextField(
              controller: _regNumberController,
              label: 'Nomor Registrasi Kemenkes *',
              hint: 'Contoh: RS-3578014',
              icon: Icons.badge_outlined,
              maxLength: 50,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Nomor registrasi Kemenkes wajib diisi';
                }
                return null;
              },
            ),

            _buildTextField(
              controller: _emailController,
              label: 'Email Resmi Rumah Sakit *',
              hint: 'Contoh: sekretariat@rsud-soetomo.id',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              maxLength: 100,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Email resmi wajib diisi';
                }
                if (!val.contains('@') || !val.contains('.')) {
                  return 'Format email tidak valid';
                }
                return null;
              },
            ),

            _buildTextField(
              controller: _phoneController,
              label: 'Nomor Telepon Rumah Sakit *',
              hint: 'Contoh: 0315501078',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              maxLength: 20,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Nomor telepon wajib diisi';
                }
                if (val.trim().length < 6) {
                  return 'Nomor telepon terlalu pendek';
                }
                return null;
              },
            ),

            _buildTextField(
              controller: _addressController,
              label: 'Alamat Lengkap Rumah Sakit *',
              hint: 'Jalan, nomor, kelurahan, kecamatan, kota/kabupaten',
              icon: Icons.location_on_outlined,
              maxLines: 3,
              maxLength: 300,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Alamat rumah sakit wajib diisi';
                }
                return null;
              },
            ),

            _buildTextField(
              controller: _npwpController,
              label: 'NPWP Rumah Sakit',
              hint: 'Opsional (Contoh: 01.234.567.8-012.000)',
              icon: Icons.receipt_long_outlined,
              maxLength: 35,
              showCounter: false,
            ),

            _buildTextField(
              controller: _licenseDocController,
              label: 'Tautan Berkas Izin Operasional / Legalitas',
              hint: 'Opsional (Contoh: https://storage.akesa.id/izin.pdf)',
              icon: Icons.link_outlined,
              keyboardType: TextInputType.url,
              maxLength: 255,
              showCounter: false,
            ),

            const SizedBox(height: 20),

            // Bagian 2: Identitas Penanggung Jawab (PIC)
            _buildSectionHeader(
              icon: Icons.person_outline,
              title: 'Data Penanggung Jawab (PIC)',
              subtitle: 'Akun Anda akan menjadi penanggung jawab dan pengelola akun faskes ini.',
            ),
            const SizedBox(height: 14),

            _buildTextField(
              controller: _picFullNameController,
              label: 'Nama Lengkap PIC *',
              hint: 'Contoh: Dr. dr. Budi Santoso, Sp.A',
              icon: Icons.person_outline,
              maxLength: 100,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Nama penanggung jawab wajib diisi';
                }
                return null;
              },
            ),

            _buildTextField(
              controller: _picPositionController,
              label: 'Jabatan / Posisi di Rumah Sakit *',
              hint: 'Contoh: Direktur Utama / Kasubag IT',
              icon: Icons.work_outline,
              maxLength: 80,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Jabatan penanggung jawab wajib diisi';
                }
                return null;
              },
            ),

            const SizedBox(height: 28),

            // Tombol Submit
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isRevisionMode
                                ? Icons.update_outlined
                                : Icons.send_outlined,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isRevisionMode
                                ? 'Ajukan Ulang Revisi'
                                : 'Kirim Pendaftaran RS',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 12),
            Center(
              child: Text(
                'Data bertanda * wajib diisi secara akurat',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifiedKeyBadge() {
    final code = _keyCodeController.text.trim().toUpperCase();
    final email = _validatedKeyInfo?.targetEmail ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFB5DAB2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: AppColors.primaryGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'KUNCI TERVERIFIKASI',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: AppColors.darkGreen,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      code,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Email Faskes: $email',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() => _step = 0);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.darkGreen,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(40, 32),
            ),
            child: const Text(
              'Ganti',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevisionAlert(String notes) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD566)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.feedback_outlined, color: Color(0xFFD48806), size: 22),
              SizedBox(width: 8),
              Text(
                'Permintaan Revisi dari Admin',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF874D00),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            notes,
            style: const TextStyle(
              color: Color(0xFF613400),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Silakan perbaiki data di bawah lalu klik tombol "Ajukan Ulang Revisi".',
            style: TextStyle(
              color: Color(0xFF874D00),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primaryGreen),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.darkGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    int? maxLength,
    bool showCounter = true,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textGreen,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            maxLines: maxLines,
            maxLength: maxLength,
            keyboardType: keyboardType,
            validator: validator,
            buildCounter: showCounter
                ? null
                : (context, {required currentLength, required isFocused, maxLength}) => null,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              prefixIcon: Icon(icon, color: AppColors.primaryGreen, size: 20),
              filled: true,
              fillColor: const Color(0xFFFBFDFB),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.inputBorderEnabled),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primaryGreen,
                  width: 1.8,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.errorText),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.errorText, width: 1.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
