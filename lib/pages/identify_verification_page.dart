import 'dart:io';

import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/api_exception.dart';
import '../models/identity_verification_data.dart';
import '../models/ktp_ocr_data.dart';
import '../services/akesa_api.dart';

class IdentityVerificationPage extends StatefulWidget {
  final ClerkAuthState authState;
  final String verificationId;
  final void Function(XFile file)? onKtpCaptured;

  const IdentityVerificationPage({
    super.key,
    required this.authState,
    required this.verificationId,
    this.onKtpCaptured,
  });

  @override
  State<IdentityVerificationPage> createState() =>
      _IdentityVerificationPageState();
}

class _IdentityVerificationPageState extends State<IdentityVerificationPage> {
  static const Color primaryGreen = Color(0xFF4D8F00);
  static const Color darkGreen = Color(0xFF185C22);
  static const Color textGreen = Color(0xFF294529);

  late final AkesaApi api;

  final ImagePicker _picker = ImagePicker();

  int currentStep = 0;

  XFile? ktpImage;
  XFile? selfieImage;

  bool ktpUploaded = false;
  bool selfieUploaded = false;

  bool uploadingKtp = false;
  bool uploadingSelfie = false;
  bool processingKtpOcr = false;

  bool loadingVerification = true;

  bool ktpConfirmed = false;
  bool ktpNeedsUpload = false;

  bool _hasKtpVerificationConsent = false;

  IdentityVerificationData? verification;
  KtpOcrData? ktpOcrResult;

  @override
  void initState() {
    super.initState();

    api = AkesaApi(authState: widget.authState);

    _loadVerification();
  }

  // ==========================================================
  // Load Verification
  // ==========================================================

  Future<void> _loadVerification() async {
    try {
      final result = await api.getIdentityVerification(widget.verificationId);

      ktpUploaded = result.documentUploaded;
      selfieUploaded = result.selfieUploaded;

      ktpConfirmed = result.documentUploaded;
      ktpNeedsUpload = false;

      currentStep = result.documentUploaded ? 1 : 0;
      loadingVerification = false;

      if (!mounted) return;

      setState(() {
        verification = result;

        ktpUploaded = result.documentUploaded;
        selfieUploaded = result.selfieUploaded;

        if (selfieUploaded) {
          currentStep = 1;
        } else {
          currentStep = 0;
        }

        loadingVerification = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loadingVerification = false;
      });

      _showError(_formatError(e));
    }
  }

  // ==========================================================
  // IMAGE PICKER
  // ==========================================================

  Future<void> _pickKtp(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (file == null) return;

      if (!mounted) return;

      setState(() {
        ktpImage = file;
        ktpConfirmed = false;
        ktpNeedsUpload = true;
      });
    } catch (e) {
      _showError('Gagal mengambil foto KTP.');
    }
  }

  Future<void> _showKtpSourcePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt_outlined,
                    color: primaryGreen,
                  ),
                  title: const Text('Ambil Foto KTP'),
                  subtitle: const Text(
                    'Gunakan kamera untuk mengambil foto KTP',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickKtp(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: primaryGreen,
                  ),
                  title: const Text('Upload dari Galeri'),
                  subtitle: const Text('Pilih foto KTP dari perangkat'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickKtp(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================================
  // UPLOAD KTP
  // ==========================================================

  Future<bool> _requestKtpVerificationConsent() async {
    if (_hasKtpVerificationConsent) return true;

    bool isChecked = false;

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.verified_user_outlined, color: primaryGreen),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Persetujuan Verifikasi Identitas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Sebelum melanjutkan, mohon baca dan setujui '
                        'penggunaan data untuk proses verifikasi identitas.',
                        style: TextStyle(height: 1.5),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'Data yang diproses',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '• Foto KTP untuk membaca dan memeriksa informasi '
                        'identitas Anda.\n'
                        '• Swafoto untuk mendukung proses pemeriksaan identitas.',
                        style: TextStyle(height: 1.5),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'Tujuan penggunaan',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Data digunakan untuk proses verifikasi identitas '
                        'Akesa. Pengiriman dokumen tidak berarti identitas '
                        'otomatis dinyatakan terverifikasi.',
                        style: TextStyle(height: 1.5),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'Perlindungan data',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Pastikan KTP dan swafoto yang diberikan adalah '
                        'milik Anda sendiri. Data akan diproses sesuai '
                        'mekanisme akses dan keamanan yang diterapkan Akesa.',
                        style: TextStyle(height: 1.5),
                      ),
                      const SizedBox(height: 12),

                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: primaryGreen,
                        value: isChecked,
                        onChanged: (value) {
                          setDialogState(() {
                            isChecked = value ?? false;
                          });
                        },
                        title: const Text(
                          'Saya telah membaca, memahami, dan menyetujui '
                          'pemrosesan data KTP dan swafoto untuk verifikasi '
                          'identitas.',
                          style: TextStyle(fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(false);
                  },
                  child: const Text(
                    'Batal',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                FilledButton(
                  onPressed: isChecked
                      ? () {
                          Navigator.of(dialogContext).pop(true);
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Saya Setuju dan Lanjutkan'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || accepted != true) {
      return false;
    }

    setState(() {
      _hasKtpVerificationConsent = true;
    });

    return true;
  }

  Future<void> _uploadKtp() async {
    final image = ktpImage;

    if (image == null) {
      _showError('Silakan pilih foto KTP terlebih dahulu.');
      return;
    }

    if (uploadingKtp || processingKtpOcr) return;

    // Minta persetujuan sebelum KTP diproses.
    final consented = await _requestKtpVerificationConsent();

    if (!consented || !mounted) return;

    setState(() {
      processingKtpOcr = true;
    });

    try {
      final ocrResult = await api.uploadKtpForOcr(image);

      if (!mounted) return;

      setState(() {
        ktpOcrResult = ocrResult;
      });

      final confirmed = await _confirmOcrResult(ocrResult);

      if (!mounted || confirmed != true) return;

      setState(() {
        ktpConfirmed = true;
        currentStep = 1;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Data KTP berhasil dikonfirmasi. '
            'Silakan ambil swafoto untuk melanjutkan.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError(_formatError(e));
    } finally {
      if (mounted) {
        setState(() {
          processingKtpOcr = false;
        });
      }
    }
  }

  Future<bool?> _confirmOcrResult(KtpOcrData data) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Periksa Data KTP'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Pastikan informasi berikut sesuai dengan KTP Anda.',
                ),
                const SizedBox(height: 16),
                _ocrRow('NIK', data.nik),
                _ocrRow('Nama', data.nama),
                _ocrRow('Tempat lahir', data.tempatLahir),
                _ocrRow('Tanggal lahir', data.tanggalLahir),
                _ocrRow('Jenis kelamin', data.jenisKelamin),
                _ocrRow('Alamat', data.alamat),
                const SizedBox(height: 12),
                const Text(
                  'Jika ada informasi yang keliru, periksa kembali foto KTP '
                  'atau koreksi datanya pada formulir profil.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Periksa Ulang'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Data Sudah Sesuai'),
            ),
          ],
        );
      },
    );
  }

  Widget _ocrRow(String label, String? value) {
    final displayValue = value == null || value.trim().isEmpty
        ? 'Tidak terbaca'
        : value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 3),
          Text(
            displayValue,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // SELFIE
  // ==========================================================

  Future<void> _uploadSelfie() async {
    final selfie = selfieImage;

    if (selfie == null) {
      _showError('Silakan ambil foto selfie terlebih dahulu.');
      return;
    }

    if (!ktpConfirmed && !ktpUploaded) {
      _showError('Silakan konfirmasi data KTP terlebih dahulu.');
      return;
    }

    if (ktpNeedsUpload && !ktpConfirmed) {
      _showError('Silakan periksa dan konfirmasi foto KTP terbaru.');
      return;
    }

    if (uploadingSelfie) return;

    setState(() {
      uploadingSelfie = true;
    });

    try {
      // Unggah KTP hanya ketika diperlukan.
      if (!ktpUploaded || ktpNeedsUpload) {
        final ktpFile = ktpImage;

        if (ktpFile == null) {
          throw Exception('Foto KTP belum tersedia.');
        }

        final documentResult = await api.uploadIdentityDocument(
          verificationId: widget.verificationId,
          file: ktpFile,
        );

        widget.onKtpCaptured?.call(ktpFile);

        if (!mounted) return;

        if (!documentResult.documentUploaded) {
          throw Exception('Foto KTP belum berhasil disimpan.');
        }

        setState(() {
          verification = documentResult;
          ktpUploaded = true;
          ktpNeedsUpload = false;
        });
      }

      // Unggah swafoto setelah KTP tersedia di backend.
      final result = await api.uploadIdentitySelfie(
        verificationId: widget.verificationId,
        file: selfie,
      );

      if (!mounted) return;

      setState(() {
        verification = result;
        selfieUploaded = result.selfieUploaded;
      });

      if (!result.documentUploaded ||
          !result.selfieUploaded ||
          result.status != 'MANUAL_REVIEW') {
        _showError('KTP dan swafoto belum berhasil dikirim untuk ditinjau.');
        return;
      }
    } catch (e) {
      if (!mounted) return;
      _showError(_formatError(e));
      return;
    } finally {
      if (mounted) {
        setState(() {
          uploadingSelfie = false;
        });
      }
    }

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _pickSelfie() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1200,
        preferredCameraDevice: CameraDevice.front,
      );

      if (file == null) return;

      if (!mounted) return;

      setState(() {
        selfieImage = file;
      });
    } catch (e) {
      _showError('Gagal mengambil foto selfie.');
    }
  }

  // ==========================================================
  // UI
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: darkGreen),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Verifikasi Data Diri',
          style: TextStyle(
            color: darkGreen,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: loadingVerification
          ? const Center(child: CircularProgressIndicator())
          : verification == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'Data verifikasi belum dapat dimuat.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loadVerification,
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                _buildTabs(),
                Expanded(
                  child: IndexedStack(
                    index: currentStep,
                    children: [_buildKtpTab(), _buildSelfieTab()],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5EAE4))),
      ),
      child: Row(
        children: [
          Expanded(child: _buildTab(label: 'Verifikasi KTP', index: 0)),
          Expanded(
            child: _buildTab(
              label: ktpUploaded ? 'Swafoto' : '🔒 Swafoto',
              index: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab({required String label, required int index}) {
    final selected = currentStep == index;
    final enabled =
        index == 0 || (ktpConfirmed || (ktpUploaded && !ktpNeedsUpload));

    return InkWell(
      onTap: enabled
          ? () {
              setState(() {
                currentStep = index;
              });
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? primaryGreen : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected
                ? primaryGreen
                : enabled
                ? const Color(0xFF8A9589)
                : const Color(0xFFC5CCC3),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // KTP TAB
  // ==========================================================

  Widget _buildKtpTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildKtpPreview(),
          const SizedBox(height: 20),

          const Text(
            'Posisikan KTP Anda di Dalam Bingkai',
            style: TextStyle(
              color: textGreen,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 7),

          const Text(
            'Pastikan informasi pada KTP dapat terlihat dengan jelas.',
            style: TextStyle(
              color: Color(0xFF7B877A),
              fontSize: 12,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 12),

          _buildInstruction('Pastikan seluruh bagian KTP terlihat.'),
          _buildInstruction('Gunakan pencahayaan yang cukup.'),
          _buildInstruction('Pastikan foto tidak blur atau terlalu gelap.'),

          const SizedBox(height: 24),

          if (ktpImage == null)
            _buildPrimaryButton(
              label: 'Pilih Foto KTP',
              icon: Icons.add_a_photo_outlined,
              onPressed: _showKtpSourcePicker,
            )
          else ...[
            _buildPrimaryButton(
              label: uploadingKtp
                  ? processingKtpOcr
                        ? 'Membaca Data KTP...'
                        : 'Menyimpan Foto...'
                  : 'Periksa KTP & Lanjut',
              icon: uploadingKtp ? null : Icons.arrow_forward,
              loading: uploadingKtp,
              onPressed: uploadingKtp ? null : _uploadKtp,
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton(
                onPressed: uploadingKtp ? null : _showKtpSourcePicker,
                child: const Text('Ambil Ulang / Ganti Foto'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKtpPreview() {
    if (ktpImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 1.58,
          child: Image.file(File(ktpImage!.path), fit: BoxFit.cover),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD9E4D6)),
      ),
      child: AspectRatio(
        aspectRatio: 1.58,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF5E8),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.badge_outlined,
                size: 32,
                color: primaryGreen,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Foto KTP belum dipilih',
              style: TextStyle(
                color: textGreen,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstruction(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 15, color: primaryGreen),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF657263),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // SELFIE TAB
  // ==========================================================

  Widget _buildBackToKtpButton() {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton.icon(
        onPressed: uploadingSelfie
            ? null
            : () {
                setState(() {
                  currentStep = 0;
                });
              },
        icon: const Icon(Icons.arrow_back),
        label: const Text(
          'Kembali ke Foto KTP',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryGreen,
          side: const BorderSide(color: Color(0xFFBFD8B9)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildSelfieTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSelfiePreview(),

          const SizedBox(height: 20),

          const Text(
            'Posisikan Wajah Anda',
            style: TextStyle(
              color: textGreen,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 7),

          const Text(
            'Gunakan kamera depan dan pastikan wajah terlihat jelas.',
            style: TextStyle(
              color: Color(0xFF7B877A),
              fontSize: 12,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 12),

          _buildInstruction('Pastikan wajah berada di tengah.'),
          _buildInstruction('Lepaskan masker atau benda yang menutupi wajah.'),
          _buildInstruction('Gunakan pencahayaan yang cukup.'),

          const SizedBox(height: 24),

          if (selfieImage == null)
            _buildPrimaryButton(
              label: 'Ambil Swafoto',
              icon: Icons.camera_front_outlined,
              onPressed: _pickSelfie,
            )
          else ...[
            _buildPrimaryButton(
              label: uploadingSelfie
                  ? 'Mengirim Verifikasi...'
                  : 'Kirim Verifikasi',
              icon: uploadingSelfie ? null : Icons.verified_outlined,
              loading: uploadingSelfie,
              onPressed: uploadingSelfie ? null : _uploadSelfie,
            ),

            const SizedBox(height: 10),

            _buildBackToKtpButton(),

            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton(
                onPressed: uploadingSelfie ? null : _pickSelfie,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFBFD8B9)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Ambil Ulang Swafoto',
                  style: TextStyle(
                    color: primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelfiePreview() {
    if (selfieImage != null) {
      return Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 230,
            height: 280,
            child: Image.file(File(selfieImage!.path), fit: BoxFit.cover),
          ),
        ),
      );
    }

    return Center(
      child: Container(
        width: 230,
        height: 280,
        decoration: BoxDecoration(
          color: const Color(0xFFF4F7F3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD9E4D6)),
        ),
        child: const Icon(
          Icons.face_outlined,
          size: 80,
          color: Color(0xFF91A68D),
        ),
      ),
    );
  }

  // ==========================================================
  // BUTTON
  // ==========================================================

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    bool loading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: primaryGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ==========================================================
  // HELPERS
  // ==========================================================

  String _formatError(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 401) {
        return 'Sesi login sudah tidak tersedia.';
      }

      if (error.statusCode == 403) {
        return 'Anda tidak memiliki akses untuk melakukan verifikasi.';
      }

      return error.message;
    }

    return 'Terjadi kesalahan. Silakan coba lagi.';
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}
