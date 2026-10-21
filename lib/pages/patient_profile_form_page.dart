import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:image_picker/image_picker.dart';


import '../models/api_exception.dart';
import '../models/patient_profile_data.dart';
import '../models/identity_verification_data.dart';
import '../services/akesa_api.dart';

class PatientProfileFormPage extends StatefulWidget {
  const PatientProfileFormPage({
    super.key,
    required this.authState,
    this.profile,
    this.identityVerification,
    this.onProfileCreated,
    this.onStartIdentityVerification,
  });

  final ClerkAuthState authState;
  final PatientProfileData? profile;
  final IdentityVerificationData? identityVerification;
  final VoidCallback? onProfileCreated;

  final Future<void> Function(XFile? ktpImage)? onStartIdentityVerification;

  @override
  State<PatientProfileFormPage> createState() => _PatientProfileFormPageState();
}

class _PatientProfileFormPageState extends State<PatientProfileFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final AkesaApi api;

  final _fullNameController = TextEditingController();
  final _nikController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _drugAllergyController = TextEditingController();
  final _medicalHistoryController = TextEditingController();
  final _insuranceController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  XFile? _ktpImage;
  DateTime? _dateOfBirth;
  String? _selectedGender;
  String? _selectedBloodType;
  bool _isSaving = false;
  bool _isReadingKtp = false;
  PatientProfileData? _currentProfile;

  bool get _isIdentityVerified {
    return widget.identityVerification?.status == 'VERIFIED';
  }

  static const Color akesaGreen = Color(0xFF4D8F00);
  static const Color akesaDarkGreen = Color(0xFF185C22);

  @override
  void initState() {
    super.initState();

    api = AkesaApi(authState: widget.authState);
    _currentProfile = widget.profile;

    final profile = widget.profile;

    if (profile != null) {
      _fullNameController.text = profile.fullName;
      _nikController.text = profile.nik ?? '';
      _phoneController.text = profile.phoneNumber ?? '';
      _addressController.text = profile.address ?? '';

      _drugAllergyController.text = profile.drugAllergy ?? '';
      _medicalHistoryController.text = profile.medicalHistory ?? '';
      _insuranceController.text = profile.insuranceNumber ?? '';

      _selectedGender = profile.gender;
      _selectedBloodType = profile.bloodType;

      if (profile.dateOfBirth != null && profile.dateOfBirth!.isNotEmpty) {
        _dateOfBirth = DateTime.tryParse(profile.dateOfBirth!);
      }
    } else {
      final clerkUser = widget.authState.user;
      final clerkName = clerkUser?.name ??
          [clerkUser?.firstName, clerkUser?.lastName]
              .whereType<String>()
              .where((s) => s.isNotEmpty)
              .join(' ');

      if (clerkName.trim().isNotEmpty) {
        _fullNameController.text = clerkName.trim();
      }

      final phone = clerkUser?.phoneNumber;
      if (phone != null && phone.isNotEmpty) {
        _phoneController.text = phone;
      }

      _checkExistingProfile();
    }
  }

  Future<void> _checkExistingProfile() async {
    try {
      final existing = await api.getPatientProfile();
      if (!mounted) return;
      _currentProfile = existing;
      if (_fullNameController.text.isEmpty && existing.fullName.isNotEmpty) {
        _fullNameController.text = existing.fullName;
      }
      if (_nikController.text.isEmpty && existing.nik != null) {
        _nikController.text = existing.nik!;
      }
      if (_phoneController.text.isEmpty && existing.phoneNumber != null) {
        _phoneController.text = existing.phoneNumber!;
      }
      if (_addressController.text.isEmpty && existing.address != null) {
        _addressController.text = existing.address!;
      }
      if (_drugAllergyController.text.isEmpty && existing.drugAllergy != null) {
        _drugAllergyController.text = existing.drugAllergy!;
      }
      if (_medicalHistoryController.text.isEmpty &&
          existing.medicalHistory != null) {
        _medicalHistoryController.text = existing.medicalHistory!;
      }
      if (_insuranceController.text.isEmpty &&
          existing.insuranceNumber != null) {
        _insuranceController.text = existing.insuranceNumber!;
      }
      if (_selectedGender == null &&
          existing.gender != null &&
          existing.gender!.isNotEmpty) {
        setState(() {
          _selectedGender = existing.gender;
        });
      }
      if (_selectedBloodType == null && existing.bloodType != null) {
        setState(() {
          _selectedBloodType = existing.bloodType;
        });
      }
      if (_dateOfBirth == null &&
          existing.dateOfBirth != null &&
          existing.dateOfBirth!.isNotEmpty) {
        setState(() {
          _dateOfBirth = DateTime.tryParse(existing.dateOfBirth!);
        });
      }
    } catch (_) {
      // Wajar jika belum pernah dibuat
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _nikController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _drugAllergyController.dispose();
    _medicalHistoryController.dispose();
    _insuranceController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();

    super.dispose();
  }

  Future<void> _selectDateOfBirth() async {
    final now = DateTime.now();

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Pilih tanggal lahir',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );

    if (selectedDate != null) {
      setState(() {
        _dateOfBirth = selectedDate;
      });
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  String _formatDateForApi(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_dateOfBirth == null) {
      _showMessage('Tanggal lahir wajib dipilih.');
      return;
    }

    if (_selectedGender == null) {
      _showMessage('Jenis kelamin wajib dipilih.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final dateOfBirth = _formatDateForApi(_dateOfBirth!);

      final bloodType = _emptyToNull(_selectedBloodType ?? '');

      final drugAllergy = _emptyToNull(_drugAllergyController.text);

      final medicalHistory = _emptyToNull(_medicalHistoryController.text);

      final insuranceNumber = _emptyToNull(_insuranceController.text);

      final emergencyContactName = _emptyToNull(_emergencyNameController.text);

      final emergencyContactPhone = _emptyToNull(
        _emergencyPhoneController.text,
      );

      PatientProfileData result;

      if (_currentProfile == null) {
        try {
          result = await api.createPatientProfile(
            nik: _nikController.text.trim(),
            fullName: _fullNameController.text.trim(),
            dateOfBirth: dateOfBirth,
            gender: _selectedGender!,
            phoneNumber: _phoneController.text.trim(),
            address: _addressController.text.trim(),
            bloodType: bloodType,
            drugAllergy: drugAllergy,
            medicalHistory: medicalHistory,
            insuranceNumber: insuranceNumber,
            emergencyContactName: emergencyContactName,
            emergencyContactPhone: emergencyContactPhone,
          );
        } on ApiException catch (e) {
          if (e.statusCode == 409 ||
              e.message.toLowerCase().contains('profile_already_exists')) {
            // Profil sudah terdaftar di backend (misalnya request sebelumnya berhasil masuk DB
            // namun sempat gagal di tahap audit log/blockchain).
            // Lakukan update dengan data form saat ini.
            try {
              result = await api.updatePatientProfile(
                nik: _nikController.text.trim(),
                fullName: _fullNameController.text.trim(),
                dateOfBirth: dateOfBirth,
                gender: _selectedGender!,
                phoneNumber: _phoneController.text.trim(),
                address: _addressController.text.trim(),
                bloodType: bloodType,
                drugAllergy: drugAllergy,
                medicalHistory: medicalHistory,
                insuranceNumber: insuranceNumber,
                emergencyContactName: emergencyContactName,
                emergencyContactPhone: emergencyContactPhone,
              );
            } on ApiException catch (updateErr) {
              if (updateErr.statusCode == 500) {
                // Jika update data masuk ke DB tetapi audit log gagal, ambil data profil langsung
                result = await api.getPatientProfile();
              } else {
                rethrow;
              }
            }
          } else if (e.statusCode == 500) {
            // 500 sering terjadi bila row profil tersimpan di DB namun blockchain audit log gagal.
            // Cek apakah profil berhasil tersimpan di DB:
            try {
              result = await api.getPatientProfile();
            } catch (_) {
              rethrow;
            }
          } else {
            rethrow;
          }
        }
      } else {
        try {
          result = await api.updatePatientProfile(
            nik: _nikController.text.trim(),
            fullName: _fullNameController.text.trim(),
            dateOfBirth: dateOfBirth,
            gender: _selectedGender!,
            phoneNumber: _phoneController.text.trim(),
            address: _addressController.text.trim(),
            bloodType: bloodType,
            drugAllergy: drugAllergy,
            medicalHistory: medicalHistory,
            insuranceNumber: insuranceNumber,
            emergencyContactName: emergencyContactName,
            emergencyContactPhone: emergencyContactPhone,
          );
        } on ApiException catch (e) {
          if (e.statusCode == 500) {
            // Update berhasil masuk DB namun audit log gagal
            try {
              result = await api.getPatientProfile();
            } catch (_) {
              rethrow;
            }
          } else {
            rethrow;
          }
        }
      }

      _currentProfile = result;

      // Sinkronkan nama lengkap ke akun Clerk
      final updatedFullName = _fullNameController.text.trim();
      if (updatedFullName.isNotEmpty) {
        try {
          final nameParts = updatedFullName.split(' ');
          final firstName = nameParts.first;
          final lastName =
              nameParts.length > 1 ? nameParts.sublist(1).join(' ') : null;

          await widget.authState.updateUser(
            firstName: firstName,
            lastName: lastName,
          );
        } catch (clerkErr) {
          debugPrint('Gagal sinkronisasi nama ke Clerk: $clerkErr');
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil berhasil disimpan.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      widget.onProfileCreated?.call();

      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getErrorMessage(e)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }

  String _getErrorMessage(Object error) {
    final message = error.toString();

    if (message.contains('nik_already_registered')) {
      return 'NIK tersebut sudah terdaftar. Silakan periksa kembali NIK Anda.';
    }

    if (message.contains('profile_already_exists')) {
      return 'Profil Anda sudah terdaftar.';
    }

    if (message.contains('invalid')) {
      return 'Data yang dimasukkan belum sesuai. Silakan periksa kembali.';
    }

    return 'Profil gagal disimpan. Silakan coba lagi.';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _showKtpPicker() async {
    if (_isReadingKtp || _isIdentityVerified) return;

    FocusScope.of(context).unfocus();

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await _pickAndReadKtp(ImageSource.gallery);
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  'Pilih Sumber Foto KTP',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Ambil Foto dengan Kamera'),
                onTap: () {
                  Navigator.pop(context, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Pilih dari Galeri'),
                onTap: () {
                  Navigator.pop(context, ImageSource.gallery);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );

    if (source != null && mounted) {
      await _pickAndReadKtp(source);
    }
  }

  Future<void> _pickAndReadKtp(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2000,
      );

      if (image == null || !mounted) return;

      setState(() {
        _ktpImage = image;
        _isReadingKtp = true;
      });

      // Kirim foto KTP ke API OCR Akesa.
      final result = await api.uploadKtpForOcr(image);

      if (!mounted) return;

      setState(() {
        if (result.nama != null && result.nama!.trim().isNotEmpty) {
          _fullNameController.text = result.nama!.trim();
        }

        if (result.nik != null && result.nik!.trim().isNotEmpty) {
          _nikController.text = result.nik!.replaceAll(RegExp(r'\s+'), '');
        }

        if (result.alamat != null && result.alamat!.trim().isNotEmpty) {
          _addressController.text = result.alamat!.trim();
        }

        final birthDate = _parseOcrDate(result.tanggalLahir);
        if (birthDate != null) {
          _dateOfBirth = birthDate;
        }

        final gender = _parseOcrGender(result.jenisKelamin);
        if (gender != null) {
          _selectedGender = gender;
        }

        final clerkPhone = widget.authState.user?.phoneNumber;
        if (_phoneController.text.trim().isEmpty &&
            clerkPhone != null &&
            clerkPhone.isNotEmpty) {
          _phoneController.text = clerkPhone;
        }
      });

      _showMessage(
        'Pemindaian selesai. Periksa kembali data KTP sebelum menyimpan profil.',
      );
    } catch (e) {
      if (!mounted) return;

      debugPrint('KTP OCR Error: $e');
      final msg = e is ApiException ? e.message : e.toString();
      _showMessage('Gagal membaca KTP: $msg');
    } finally {
      if (mounted) {
        setState(() {
          _isReadingKtp = false;
        });
      }
    }
  }

  DateTime? _parseOcrDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    final input = value.trim();

    // Format ISO, misalnya 2003-08-17.
    final isoDate = DateTime.tryParse(input);
    if (isoDate != null) return isoDate;

    // Format dengan pemisah '-' atau '/' atau '.'
    final normalized = input.replaceAll('-', '/').replaceAll('.', '/');
    final parts = normalized.split('/');

    if (parts.length != 3) return null;

    try {
      int day;
      int month;
      int year;

      if (parts[0].length == 4) {
        year = int.parse(parts[0]);
        month = int.parse(parts[1]);
        day = int.parse(parts[2]);
      } else {
        day = int.parse(parts[0]);
        month = int.parse(parts[1]);
        year = int.parse(parts[2]);
      }

      final date = DateTime(year, month, day);

      // Menolak tanggal yang tidak valid, misalnya 31/02/2003.
      if (date.year != year || date.month != month || date.day != day) {
        return null;
      }

      return date;
    } catch (_) {
      return null;
    }
  }

  String? _parseOcrGender(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    final gender = value.trim().toUpperCase();

    if (gender == 'L' ||
        gender == 'LAKI-LAKI' ||
        gender == 'LAKI LAKI' ||
        gender == 'PRIA' ||
        gender == 'MALE') {
      return 'MALE';
    }

    if (gender == 'P' ||
        gender == 'PEREMPUAN' ||
        gender == 'WANITA' ||
        gender == 'FEMALE') {
      return 'FEMALE';
    }

    return null;
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: akesaGreen),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: akesaGreen, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 24, bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: akesaGreen.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: akesaGreen.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: akesaGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: akesaDarkGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool enabled = true,
    int? maxLength,
    bool showCounter = true,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        maxLength: maxLength,
        inputFormatters: inputFormatters,
        enabled: enabled,
        buildCounter: (maxLength != null && showCounter)
            ? null
            : (
                context, {
                required currentLength,
                required isFocused,
                maxLength,
              }) => null,
        textInputAction: maxLines > 1
            ? TextInputAction.newline
            : TextInputAction.next,
        decoration: _inputDecoration(label: label, icon: icon, hint: hint),
        validator: validator,
      ),
    );
  }

  Widget _buildDateField() {
    final enabled = !_isIdentityVerified;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: enabled ? _selectDateOfBirth : null,
        borderRadius: BorderRadius.circular(14),
        child: InputDecorator(
          decoration:
              _inputDecoration(
                label: 'Tanggal Lahir *',
                icon: Icons.calendar_month_outlined,
                hint: 'Pilih tanggal lahir',
              ).copyWith(
                enabled: enabled,
                suffixIcon: _isIdentityVerified
                    ? const Icon(Icons.lock_outline, color: Colors.grey)
                    : null,
              ),
          child: Text(
            _dateOfBirth == null
                ? 'Pilih tanggal lahir'
                : _formatDate(_dateOfBirth!),
            style: TextStyle(
              fontSize: 16,
              color: _dateOfBirth == null
                  ? Colors.grey.shade600
                  : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        value: _selectedGender,
        decoration:
            _inputDecoration(
              label: 'Jenis Kelamin',
              icon: Icons.wc_outlined,
            ).copyWith(
              suffixIcon: _isIdentityVerified
                  ? const Icon(Icons.lock_outline, color: Colors.grey)
                  : null,
            ),
        items: const [
          DropdownMenuItem(value: 'MALE', child: Text('Laki-laki')),
          DropdownMenuItem(value: 'FEMALE', child: Text('Perempuan')),
        ],
        onChanged: _isIdentityVerified
            ? null
            : (value) {
                setState(() {
                  _selectedGender = value;
                });
              },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Jenis kelamin wajib dipilih';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildBloodTypeSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String?>(
        value: _selectedBloodType,
        decoration: _inputDecoration(
          label: 'Golongan Darah',
          icon: Icons.bloodtype_outlined,
          hint: 'Pilih jika Anda tahu',
          suffixIcon: _selectedBloodType != null
              ? IconButton(
                  icon: const Icon(
                    Icons.clear_rounded,
                    size: 20,
                    color: Colors.grey,
                  ),
                  tooltip: 'Kosongkan pilihan',
                  onPressed: () {
                    setState(() {
                      _selectedBloodType = null;
                    });
                  },
                )
              : null,
        ),
        items: const [
          DropdownMenuItem<String?>(
            value: null,
            child: Text(
              'Belum tahu / Kosongkan',
              style: TextStyle(
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          DropdownMenuItem<String?>(value: 'A+', child: Text('A+')),
          DropdownMenuItem<String?>(value: 'A-', child: Text('A-')),
          DropdownMenuItem<String?>(value: 'B+', child: Text('B+')),
          DropdownMenuItem<String?>(value: 'B-', child: Text('B-')),
          DropdownMenuItem<String?>(value: 'AB+', child: Text('AB+')),
          DropdownMenuItem<String?>(value: 'AB-', child: Text('AB-')),
          DropdownMenuItem<String?>(value: 'O+', child: Text('O+')),
          DropdownMenuItem<String?>(value: 'O-', child: Text('O-')),
        ],
        onChanged: (value) {
          setState(() {
            _selectedBloodType = value;
          });
        },
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Lengkapi data Anda dengan benar. Data ini akan digunakan '
              'untuk proses pendaftaran dan pelayanan rumah sakit.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Colors.blue.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _requiredValidator(String? value, {required String fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName wajib diisi';
    }

    return null;
  }

  String? _nikValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'NIK wajib diisi';
    }

    final nik = value.trim();

    if (nik.length != 16) {
      return 'NIK harus terdiri dari 16 angka';
    }

    if (!RegExp(r'^\d{16}$').hasMatch(nik)) {
      return 'NIK hanya boleh berisi angka';
    }

    return null;
  }

  String? _phoneValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nomor telepon wajib diisi';
    }

    final phone = value.trim();

    if (phone.length < 10) {
      return 'Nomor telepon terlalu pendek';
    }

    return null;
  }

  Future<void> _startIdentityVerification() async {
    final callback = widget.onStartIdentityVerification;

    if (callback == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fitur verifikasi identitas belum tersedia.'),
        ),
      );
      return;
    }

    if (_isReadingKtp) {
      return;
    }

    try {
      await callback(_ktpImage);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuka verifikasi identitas: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: akesaDarkGreen,
        centerTitle: false,
        title: const Text(
          'Lengkapi Profil',
          style: TextStyle(fontWeight: FontWeight.bold, color: akesaDarkGreen),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoCard(),

                if (_isIdentityVerified)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.verified_outlined, color: Colors.green),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Identitas Anda telah diverifikasi menggunakan KTP. '
                            'Nama, NIK, tanggal lahir, jenis kelamin, dan alamat '
                            'dikunci untuk menjaga keakuratan data.',
                            style: TextStyle(fontSize: 13, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),

                _buildSectionTitle(
                  icon: Icons.person_outline,
                  title: 'Identitas Diri',
                  description:
                      'Masukkan data sesuai dengan identitas resmi Anda.',
                ),

                _buildTextField(
                  controller: _fullNameController,
                  label: 'Nama Lengkap *',
                  hint: 'Contoh: Budi Santoso',
                  icon: Icons.person_outline,
                  enabled: !_isIdentityVerified,
                  maxLength: 100,
                  showCounter: false,
                  validator: (value) =>
                      _requiredValidator(value, fieldName: 'Nama lengkap'),
                ),

                _buildTextField(
                  controller: _nikController,
                  label: 'NIK *',
                  hint: '16 angka',
                  icon: Icons.badge_outlined,
                  keyboardType: TextInputType.number,
                  maxLength: 16,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  enabled: !_isIdentityVerified,
                  validator: _nikValidator,
                ),

                _buildDateField(),

                _buildGenderSelector(),

                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: akesaGreen.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: akesaGreen.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.verified_user_outlined),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Verifikasi Identitas',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Pindai KTP untuk mengisi data secara otomatis, '
                        'kemudian lanjutkan verifikasi identitas Anda.',
                        style: TextStyle(fontSize: 13, height: 1.5),
                      ),

                      const SizedBox(height: 16),

                      OutlinedButton.icon(
                        onPressed: (_isReadingKtp || _isIdentityVerified)
                            ? null
                            : _showKtpPicker,
                        icon: const Icon(Icons.document_scanner_outlined),
                        label: Text(
                          _isReadingKtp
                              ? 'Sedang membaca KTP...'
                              : 'Pindai KTP & Isi Otomatis',
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),

                      const SizedBox(height: 10),

                      FilledButton.icon(
                        onPressed: (_isSaving || _isIdentityVerified)
                            ? null
                            : _startIdentityVerification,
                        icon: const Icon(Icons.verified_user_outlined),
                        label: const Text('Verifikasi Identitas'),
                        style: FilledButton.styleFrom(
                          backgroundColor: akesaGreen,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                _buildSectionTitle(
                  icon: Icons.home_outlined,
                  title: 'Data Kontak',
                  description:
                      'Data ini membantu rumah sakit menghubungi Anda.',
                ),

                _buildTextField(
                  controller: _phoneController,
                  label: 'Nomor Telepon *',
                  hint: 'Contoh: 081234567890',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  maxLength: 15,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: _phoneValidator,
                ),

                _buildTextField(
                  controller: _addressController,
                  label: 'Alamat Lengkap *',
                  hint: 'Masukkan alamat tempat tinggal Anda',
                  icon: Icons.location_on_outlined,
                  maxLines: 3,
                  maxLength: 255,
                  enabled: !_isIdentityVerified,
                  validator: (value) =>
                      _requiredValidator(value, fieldName: 'Alamat'),
                ),

                _buildSectionTitle(
                  icon: Icons.medical_information_outlined,
                  title: 'Informasi Kesehatan',
                  description: 'Data kesehatan membantu tenaga medis memberikan pelayanan yang sesuai.',
                ),

                _buildBloodTypeSelector(),

                _buildTextField(
                  controller: _drugAllergyController,
                  label: 'Alergi Obat',
                  hint: 'Contoh: Amoxicillin / Tidak ada',
                  icon: Icons.warning_amber_outlined,
                  maxLines: 2,
                  maxLength: 255,
                ),

                _buildTextField(
                  controller: _medicalHistoryController,
                  label: 'Riwayat Penyakit',
                  hint: 'Contoh: Asma / Tidak ada',
                  icon: Icons.history_edu_outlined,
                  maxLines: 3,
                  maxLength: 255,
                ),

                _buildSectionTitle(
                  icon: Icons.assignment_outlined,
                  title: 'Data Tambahan',
                  description: 'Bagian ini bersifat opsional dan dapat dilengkapi nanti.',
                ),

                _buildTextField(
                  controller: _insuranceController,
                  label: 'Nomor Asuransi',
                  hint: 'Opsional',
                  icon: Icons.health_and_safety_outlined,
                  maxLength: 50,
                  showCounter: false,
                ),

                _buildTextField(
                  controller: _emergencyNameController,
                  label: 'Nama Kontak Darurat',
                  hint: 'Opsional',
                  icon: Icons.contact_emergency_outlined,
                  maxLength: 100,
                  showCounter: false,
                ),

                _buildTextField(
                  controller: _emergencyPhoneController,
                  label: 'Nomor Kontak Darurat',
                  hint: 'Opsional',
                  icon: Icons.phone_in_talk_outlined,
                  keyboardType: TextInputType.phone,
                  maxLength: 15,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: akesaGreen,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline),
                              SizedBox(width: 8),
                              Text(
                                'Simpan Profil',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 14),

                Center(
                  child: Text(
                    'Data bertanda * wajib diisi',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
