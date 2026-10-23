import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../models/access_request_data.dart';
import '../models/api_exception.dart';
import '../models/audit_log_data.dart';
import '../models/hospital_data.dart';
import '../models/patient_profile_data.dart';
import '../models/patient_qr.dart';
import '../services/akesa_api.dart';
import '../models/identity_verification_data.dart';

import 'patient_profile_form_page.dart';
import 'identify_verification_page.dart';
import 'auth_page.dart';

import '../widgets/patient/access_request_card.dart';
import '../widgets/patient/history_card.dart';
import '../widgets/patient/patient_code_card.dart';
import '../widgets/patient/patient_qr_sheet.dart';
import '../widgets/shared/ui_kit.dart';

class PatientHomePage extends StatefulWidget {
  final ClerkAuthState authState;

  const PatientHomePage({super.key, required this.authState});

  @override
  State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage> {
  static const Color primaryGreen = Color(0xFF4D8F00);
  static const Color darkGreen = Color(0xFF185C22);
  static const Color lightGreen = Color(0xFFEAF5E8);
  static const Color textGreen = Color(0xFF294529);

  late final AkesaApi api;

  final LocalAuthentication localAuth = LocalAuthentication();

  int selectedIndex = 0;

  bool loading = true;
  bool actionLoading = false;
  bool historyLoading = false;

  String? errorMessage;

  PatientProfileData? profile;
  PatientQr? patientQr;
  bool _isPromptOpen = false;

  bool qrLoading = false;
  bool qrRotating = false;

  IdentityVerificationData? _identityVerification;
  bool _identityLoading = false;

  bool _canCreateNewVerification(String status) {
    switch (status.toUpperCase()) {
      case 'EXPIRED':
      case 'DOCUMENT_REJECTED':
      case 'DATA_MISMATCH':
      case 'LIVENESS_FAILED':
      case 'FACE_MISMATCH':
        return true;

      case 'PENDING':
      case 'PROCESSING':
      case 'MANUAL_REVIEW':
        return false;

      case 'VERIFIED':
        return false;

      default:
        return true;
    }
  }

  String get _identityStatus =>
      (_identityVerification?.status ??
              profile?.identityVerificationStatus ??
              'NOT_VERIFIED')
          .trim()
          .toUpperCase();

  bool get _isIdentityVerified => _identityStatus == 'VERIFIED';

  bool get _canStartVerification =>
      profile != null &&
      !const {
        'VERIFIED',
        'PROCESSING',
        'MANUAL_REVIEW',
      }.contains(_identityStatus);

  bool get _canAccessPatientQr {
    return profile != null &&
        profile!.profileCompleted &&
        _isIdentityVerified &&
        profile!.patientCode.trim().isNotEmpty &&
        profile!.patientCode != '-';
  }

  List<HospitalData> hospitals = [];
  List<AccessRequestData> requests = [];
  List<AuditLogData> history = [];

  @override
  void initState() {
    super.initState();

    api = AkesaApi(authState: widget.authState);

    _loadHome();
  }

  // ==========================================================
  // DATA LOADING
  // ==========================================================

  Future<void> _loadHome() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      await api.syncUser();

      PatientProfileData? loadedProfile;

      try {
        loadedProfile = await api.getPatientProfile();
      } on ApiException catch (e) {
        if (e.statusCode != 404) rethrow;
        loadedProfile = null;
      }

      List<AccessRequestData> loadedRequests = [];
      List<HospitalData> loadedHospitals = [];
      IdentityVerificationData? loadedVerification;

      try {
        loadedRequests = await api.getAccessRequests();
      } catch (e) {
        debugPrint('Gagal memuat access requests: $e');
      }

      try {
        loadedHospitals = await api.getHospitals();
      } catch (e) {
        debugPrint('Gagal memuat daftar rumah sakit: $e');
      }

      try {
        loadedVerification = await api.getLatestIdentityVerification();
      } catch (e) {
        debugPrint('Gagal memuat status verifikasi: $e');
      }

      if (!mounted) return;

      setState(() {
        profile = loadedProfile;
        requests = loadedRequests;
        hospitals = loadedHospitals;
        _identityVerification = loadedVerification;
        patientQr = null;
      });

      if (loadedProfile == null && selectedIndex == 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && selectedIndex == 0 && profile == null) {
            _showCompleteProfilePrompt();
          }
        });
      }
    } catch (e) {
      debugPrint('Gagal memuat data utama Patient Home: $e');

      if (!mounted) return;

      setState(() {
        errorMessage = _formatApiError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _loadHistory() async {
    if (historyLoading) return;

    setState(() {
      historyLoading = true;
    });

    try {
      final result = await api.getHistory();

      if (!mounted) return;

      setState(() {
        history = result;
      });
    } catch (e) {
      debugPrint('Gagal load history: $e');
    } finally {
      if (mounted) {
        setState(() {
          historyLoading = false;
        });
      }
    }
  }

  // ==========================================================
  // BIOMETRIC AUTH
  // ==========================================================

  Future<bool> _authenticateForQr() async {
    try {
      final bool authenticated = await localAuth.authenticate(
        localizedReason: 'Verifikasi untuk menampilkan QR pasien',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
        sensitiveTransaction: true,
      );

      return authenticated;
    } on LocalAuthException catch (e) {
      debugPrint('Local authentication error: ${e.code}');

      if (!mounted) return false;

      String message;

      switch (e.code) {
        case LocalAuthExceptionCode.noCredentialsSet:
          message =
              'Belum ada PIN, pola, password, atau biometrik yang '
              'diatur pada perangkat.';
          break;
        case LocalAuthExceptionCode.noBiometricsEnrolled:
          message = 'Belum ada biometrik yang terdaftar pada perangkat.';
          break;
        case LocalAuthExceptionCode.biometricLockout:
        case LocalAuthExceptionCode.temporaryLockout:
          message =
              'Verifikasi biometrik terkunci sementara. '
              'Silakan gunakan PIN atau coba lagi nanti.';
          break;
        case LocalAuthExceptionCode.userCanceled:
          message = 'Verifikasi dibatalkan.';
          break;
        case LocalAuthExceptionCode.userRequestedFallback:
          message = 'Silakan gunakan metode keamanan perangkat.';
          break;
        case LocalAuthExceptionCode.authInProgress:
          message = 'Verifikasi sedang berlangsung.';
          break;
        default:
          message = 'Verifikasi perangkat gagal (${e.code}).';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );

      return false;
    } catch (e) {
      debugPrint('Unexpected local authentication error: $e');

      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Terjadi kesalahan saat melakukan verifikasi perangkat.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return false;
    }
  }

  // ==========================================================
  // VERIFICATION & IDENTIFY KTP
  // ==========================================================

  Future<void> _openIdentityVerification() async {
    if (_identityLoading) return;

    // Verifikasi baru bisa dimulai setelah profil tersimpan.
    if (profile == null) {
      _showCompleteProfilePrompt();
      return;
    }

    setState(() {
      _identityLoading = true;
    });

    try {
      final latestVerification = await api.getLatestIdentityVerification();

      IdentityVerificationData verification;

      if (latestVerification == null ||
          _canCreateNewVerification(latestVerification.status)) {
        verification = await api.createIdentityVerification();
      } else {
        verification = latestVerification;
      }

      if (!mounted) return;

      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => IdentityVerificationPage(
            authState: widget.authState,
            verificationId: verification.id,
          ),
        ),
      );

      if (!mounted) return;

      // Muat ulang profil + status verifikasi
      await _loadHome();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_formatApiError(e)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _identityLoading = false;
        });
      }
    }
  }

  Future<void> _promptVerificationAfterProfile() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Verifikasi Identitas'),
        content: const Text(
          'Profil Anda sudah tersimpan. Selanjutnya verifikasi identitas '
          'dengan foto KTP dan swafoto. Kode pasien dan QR aktif setelah '
          'verifikasi berhasil.\n\n'
          'Dengan melanjutkan, Anda menyetujui pemrosesan foto KTP dan '
          'swafoto untuk keperluan verifikasi, termasuk pemeriksaan oleh '
          'petugas berwenang.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Nanti'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: primaryGreen),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Verifikasi Sekarang'),
          ),
        ],
      ),
    );

    if (go == true && mounted) await _openIdentityVerification();
  }

  // ==========================================================
  // QR
  // ==========================================================

  Future<void> _showPatientQr() async {
    if (qrLoading) return;

    if (!_canAccessPatientQr) {
      if (profile == null || !(profile?.profileCompleted ?? false)) {
        _showCompleteProfilePrompt();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Patient code dan QR tersedia setelah identitas '
              'berhasil diverifikasi.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final authenticated = await _authenticateForQr();
    if (!authenticated) return;

    if (!mounted) return;
    setState(() => qrLoading = true);

    try {
      final loadedQr = await api.getPatientQr();
      if (!mounted) return;

      setState(() {
        patientQr = loadedQr;
      });

      await _openQrSheet();
    } catch (e) {
      debugPrint('Gagal mengambil QR pasien: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_formatApiError(e)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => qrLoading = false);
    }
  }

  Future<void> _openQrSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Text(
                      'QR Pasien',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: darkGreen,
                      ),
                    ),
                    const SizedBox(height: 16),
                    PatientQrSheet(
                      qr: patientQr,
                      rotating: qrRotating,
                      onRotate: () async {
                        await _rotatePatientQr();
                        setSheetState(() {});
                      },
                      onClose: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;
    setState(() {
      patientQr = null;
    });
  }

  Future<void> _rotatePatientQr() async {
    if (qrRotating) return;

    final authenticated = await _authenticateForQr();
    if (!authenticated) return;

    if (!mounted) return;
    setState(() => qrRotating = true);

    try {
      final newQr = await api.rotatePatientQr();
      if (!mounted) return;

      setState(() {
        patientQr = newQr;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR pasien berhasil diperbarui.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_formatApiError(e)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => qrRotating = false);
    }
  }

  Future<void> _copyPatientCode() async {
    if (!_canAccessPatientQr) return;

    final code = profile?.patientCode;
    if (code == null || code.isEmpty || code == '-') return;

    await Clipboard.setData(ClipboardData(text: code));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Kode pasien disalin.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ==========================================================
  // ACCESS REQUEST ACTIONS
  // ==========================================================

  Future<void> _approve(AccessRequestData request) async {
    await _performAction(
      action: () => api.approveAccessRequest(request.id),
      successMessage: 'Akses berhasil disetujui.',
    );
  }

  Future<void> _reject(AccessRequestData request) async {
    await _performAction(
      action: () => api.rejectAccessRequest(request.id),
      successMessage: 'Permintaan akses ditolak.',
    );
  }

  Future<void> _revoke(AccessRequestData request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cabut izin akses?'),
          content: const Text(
            'Rumah sakit tidak akan lagi memiliki '
            'izin berdasarkan permintaan akses ini.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cabut Izin'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _performAction(
      action: () => api.revokeAccessRequest(request.id),
      successMessage: 'Izin akses berhasil dicabut.',
    );
  }

  Future<void> _performAction({
    required Future<AccessRequestData?> Function() action,
    required String successMessage,
  }) async {
    if (actionLoading) return;

    setState(() {
      actionLoading = true;
    });

    try {
      await action();
      await _loadHome();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_formatApiError(e)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          actionLoading = false;
        });
      }
    }
  }

  // ==========================================================
  // LOGOUT
  // ==========================================================

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text(
          'Anda perlu masuk kembali untuk mengakses aplikasi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await performLogout(context, widget.authState);
  }

  // ==========================================================
  // HELPERS
  // ==========================================================

  String _formatApiError(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 401) return 'Sesi login sudah tidak tersedia.';
      if (error.statusCode == 403) return 'Akses ke data pasien ditolak.';
      if (error.statusCode == 404) return 'Data pasien belum ditemukan.';
      return error.message;
    }

    return 'Terjadi kesalahan. Silakan coba lagi.';
  }

  String _hospitalName(String hospitalId) {
    for (final hospital in hospitals) {
      if (hospital.id == hospitalId) {
        return hospital.name;
      }
    }

    return 'Rumah Sakit';
  }

  String _patientInitial() {
    final name = profile?.fullName.trim();

    if (name == null || name.isEmpty) {
      return 'P';
    }

    return name.substring(0, 1).toUpperCase();
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFEFC),
      body: SafeArea(child: _buildCurrentPage()),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildCurrentPage() {
    switch (selectedIndex) {
      case 1:
        return _buildHistoryPage();
      case 2:
        return _buildProfilePage();
      default:
        return _buildHomePage();
    }
  }

  // ==========================================================
  // HOME
  // ==========================================================

  Widget _buildHomePage() {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: primaryGreen),
      );
    }

    if (errorMessage != null) {
      return _buildErrorPage();
    }

    return RefreshIndicator(
      color: primaryGreen,
      onRefresh: _loadHome,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 4),
            if (profile != null && !_isIdentityVerified) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
                child: _buildIdentityStatusBanner(),
              ),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: PatientCodeCard(
                patientCode: _canAccessPatientQr
                    ? profile!.patientCode
                    : 'Belum tersedia',
                qrLoading: qrLoading,
                onCopyCode: _canAccessPatientQr ? _copyPatientCode : null,
                onShowQr: _canAccessPatientQr && !qrLoading
                    ? _showPatientQr
                    : null,
              ),
            ),
            const SizedBox(height: 18),
            _buildAccessSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final name = profile?.fullName ?? 'Pasien';

    return SizedBox(
      height: 170,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/auth_background.webp', fit: BoxFit.cover),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.25),
                  darkGreen.withOpacity(0.90),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Selamat Datang,',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0B713D),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _patientInitial(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // ACCESS SECTION
  // ==========================================================

  Widget _buildAccessSection() {
    final pendingCount = requests
        .where((r) => r.status.toUpperCase() == 'PENDING')
        .length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Permintaan Izin Akses',
                  style: TextStyle(
                    color: textGreen,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3E8),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Column(
                  children: [
                    Text(
                      '$pendingCount',
                      style: const TextStyle(
                        color: textGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Pending',
                      style: TextStyle(color: Color(0xFF668065), fontSize: 9),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (requests.isEmpty)
            _buildEmptyRequest()
          else
            ...requests.map(
              (request) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AccessRequestCard(
                  request: request,
                  hospitalName: _hospitalName(request.hospitalId),
                  actionLoading: actionLoading,
                  onApprove: () => _approve(request),
                  onReject: () => _reject(request),
                  onRevoke: () => _revoke(request),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyRequest() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE4ECE2)),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: lightGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: primaryGreen,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Tidak ada permintaan akses',
            style: TextStyle(
              color: textGreen,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Belum ada rumah sakit yang meminta akses data Anda.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF849282),
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // HISTORY PAGE
  // ==========================================================

  Widget _buildHistoryPage() {
    if (historyLoading) {
      return const Center(
        child: CircularProgressIndicator(color: primaryGreen),
      );
    }

    if (history.isEmpty) {
      return RefreshIndicator(
        color: primaryGreen,
        onRefresh: _loadHistory,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 30),
            const Icon(
              Icons.history_rounded,
              size: 52,
              color: Color(0xFF9AAF99),
            ),
            const SizedBox(height: 14),
            const Text(
              'Belum ada riwayat',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textGreen,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Aktivitas akses data Anda akan ditampilkan di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF7F8C7D), fontSize: 12),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: primaryGreen,
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        itemCount: history.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Riwayat Aktivitas',
                style: TextStyle(
                  color: textGreen,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
            );
          }

          final log = history[index - 1];

          String hospitalId = log.payloadMap['hospitalId']?.toString() ?? '';

          if (hospitalId.isEmpty) {
            final matchingRequest = requests
                .where((r) => r.id == log.entityId)
                .toList();
            if (matchingRequest.isNotEmpty) {
              hospitalId = matchingRequest.first.hospitalId;
            }
          }

          final hospitalName = hospitalId.isEmpty
              ? 'Informasi rumah sakit tidak tersedia'
              : _hospitalName(hospitalId);

          return HistoryCard(log: log, hospitalName: hospitalName);
        },
      ),
    );
  }

  // ==========================================================
  // PROFILE PAGE
  // ==========================================================

  Future<void> _openProfileForm() async {
    final result = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(
        builder: (_) => PatientProfileFormPage(
          authState: widget.authState,
          profile: profile,
          identityVerification: _identityVerification,
        ),
      ),
    );

    if (!mounted || result == null) return;

    if (result is PatientProfileData) {
      setState(() => profile = result);
    }

    await _loadHome();
    if (!mounted) return;

    // Setelah profil tersimpan, tawarkan verifikasi KTP + swafoto.
    if (result is PatientProfileData && _canStartVerification) {
      await _promptVerificationAfterProfile();
    }
  }

  Future<void> _showCompleteProfilePrompt() async {
    if (_isPromptOpen || !mounted || profile != null) return;
    _isPromptOpen = true;
    bool? fillNow;

    try {
      fillNow = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (ctx) => const _CompleteProfilePromptSheet(),
      );

      if (fillNow == true && mounted) {
        await _openProfileForm();
      }
    } finally {
      _isPromptOpen = false;
    }

    if (!mounted) return;

    if (fillNow == false) {
      await _logout();
    } else if (profile == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showCompleteProfilePrompt();
      });
    }
  }

  Widget _buildIdentityStatusBanner() {
    if (profile == null) return const SizedBox.shrink();

    final status = _identityStatus;

    if (status == 'VERIFIED') return const SizedBox.shrink();

    final inReview = status == 'MANUAL_REVIEW' || status == 'PROCESSING';
    final color = inReview ? Colors.orange.shade800 : Colors.redAccent;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                inReview ? Icons.hourglass_top_rounded : Icons.error_outline,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  inReview
                      ? 'Menunggu Verifikasi Admin'
                      : 'Verifikasi Identitas Diperlukan',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            inReview
                ? 'KTP dan swafoto Anda sedang diperiksa admin. Kode pasien dan QR '
                      'belum dapat diakses sampai verifikasi berhasil.'
                : 'Verifikasi KTP dan swafoto Anda belum selesai. Kode pasien dan QR '
                      'tersedia setelah identitas terverifikasi.',
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Color(0xFF5E6D5D),
            ),
          ),
          if (!inReview) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _identityLoading ? null : _openIdentityVerification,
                style: FilledButton.styleFrom(backgroundColor: primaryGreen),
                child: Text(
                  _identityLoading ? 'Mempersiapkan...' : 'Verifikasi Sekarang',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIdentityVerificationCard() {
    final status = _identityStatus;

    String title;
    String description;

    switch (status) {
      case 'VERIFIED':
        title = 'Identitas Terverifikasi';
        description = 'Identitas kamu sudah berhasil diverifikasi.';
        break;

      case 'PENDING':
        title = 'Verifikasi Belum Selesai';
        description = 'Lengkapi foto KTP dan swafoto untuk melanjutkan verifikasi identitas.';
        break;

      case 'PROCESSING':
        title = 'Verifikasi Sedang Diproses';
        description = 'Dokumen dan data kamu sedang diproses oleh sistem.';
        break;

      case 'MANUAL_REVIEW':
        title = 'KTP Sedang Diverifikasi';
        description = 'KTP dan swafoto sudah diterima dan sedang menunggu verifikasi admin.';
        break;

      case 'DATA_MISMATCH':
        title = 'Data Tidak Sesuai';
        description = 'Data KTP tidak sesuai dengan profil kamu.';
        break;

      case 'DOCUMENT_REJECTED':
        title = 'KTP Ditolak';
        description = 'Dokumen KTP tidak dapat digunakan. Silakan lakukan verifikasi kembali.';
        break;

      case 'LIVENESS_FAILED':
        title = 'Verifikasi Wajah Gagal';
        description = 'Swafoto tidak memenuhi pemeriksaan liveness.';
        break;

      case 'FACE_MISMATCH':
        title = 'Wajah Tidak Sesuai';
        description =
            'Wajah pada swafoto tidak sesuai dengan foto pada dokumen.';
        break;

      case 'EXPIRED':
        title = 'Verifikasi Kedaluwarsa';
        description = 'Sesi verifikasi sebelumnya sudah kedaluwarsa. Silakan lakukan verifikasi kembali.';
        break;

      default:
        title = 'Verifikasi Identitas';
        description = profile == null
            ? 'Lengkapi profil Anda terlebih dahulu, lalu verifikasi dengan KTP dan swafoto.'
            : 'Verifikasi dengan foto KTP dan swafoto untuk mengaktifkan kode pasien dan QR.';
    }

    final isVerified = status == 'VERIFIED';
    final canContinueVerification =
        _canStartVerification &&
        const {
          'NOT_VERIFIED',
          'PENDING',
          'EXPIRED',
          'DOCUMENT_REJECTED',
          'DATA_MISMATCH',
          'LIVENESS_FAILED',
          'FACE_MISMATCH',
        }.contains(status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isVerified ? Icons.verified_outlined : Icons.badge_outlined,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(description),

            if (canContinueVerification) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _identityLoading
                      ? null
                      : _openIdentityVerification,
                  icon: _identityLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file),
                  label: Text(
                    _identityLoading
                        ? 'Mempersiapkan verifikasi...'
                        : status == 'PENDING'
                        ? 'Lanjutkan Verifikasi'
                        : 'Verifikasi Data Diri',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePage() {
    final patient = profile;

    return RefreshIndicator(
      color: primaryGreen,
      onRefresh: _loadHome,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Profil Saya',
              style: TextStyle(
                color: textGreen,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 18),

            // PROFILE HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE3EAE1)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: lightGreen,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _patientInitial(),
                      style: const TextStyle(
                        color: darkGreen,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    patient?.fullName ?? 'Pasien',
                    style: const TextStyle(
                      color: textGreen,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 3),

                  // Kode pasien tidak boleh tampil sebelum VERIFIED.
                  Text(
                    _canAccessPatientQr
                        ? patient!.patientCode
                        : 'Kode pasien belum tersedia',
                    style: const TextStyle(
                      color: Color(0xFF829181),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // EDIT PROFILE BUTTON
            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: _openProfileForm,
                icon: Icon(
                  patient == null
                      ? Icons.add_circle_outline
                      : Icons.edit_outlined,
                  color: primaryGreen,
                ),
                label: Text(
                  patient == null
                      ? 'Lengkapi Profil Pasien'
                      : 'Edit Profil Pasien',
                  style: const TextStyle(
                    color: primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFBFD8B9)),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            // IDENTITY VERIFICATION
            const SizedBox(height: 14),

            _buildIdentityVerificationCard(),

            const SizedBox(height: 14),

            // PROFILE INFORMATION
            _buildProfileInfo(
              icon: Icons.phone_outlined,
              label: 'Nomor Telepon',
              value: patient?.phoneNumber,
            ),

            _buildProfileInfo(
              icon: Icons.location_on_outlined,
              label: 'Alamat',
              value: patient?.address,
            ),

            _buildProfileInfo(
              icon: Icons.bloodtype_outlined,
              label: 'Golongan Darah',
              value: patient?.bloodType,
            ),

            _buildProfileInfo(
              icon: Icons.health_and_safety_outlined,
              label: 'Nomor Asuransi',
              value: patient?.insuranceNumber,
            ),

            const SizedBox(height: 15),

            // LOGOUT
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, color: Colors.redAccent),
                label: const Text(
                  'Keluar dari Akun',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFFD2D2)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfo({
    required IconData icon,
    required String label,
    required String? value,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5EBE3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: const Color(0xFF6B8F68)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Color(0xFF879287), fontSize: 9),
                ),
                const SizedBox(height: 2),
                Text(
                  value?.isNotEmpty == true ? value! : '-',
                  style: const TextStyle(
                    color: textGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // ERROR PAGE
  // ==========================================================

  Widget _buildErrorPage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF2F2),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.cloud_off_outlined,
                color: Colors.redAccent,
                size: 32,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Gagal memuat data',
              style: TextStyle(
                color: textGreen,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              errorMessage ?? 'Terjadi kesalahan.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF7C887A),
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _loadHome,
              style: FilledButton.styleFrom(backgroundColor: primaryGreen),
              child: const Text('Coba Lagi'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _logout,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Color(0xFFFFCDD2)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              icon: const Icon(Icons.logout, size: 16),
              label: const Text('Keluar (Logout)'),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // BOTTOM NAVIGATION
  // ==========================================================

  Widget _buildBottomNavigation() {
    return NavigationBar(
      height: 67,
      backgroundColor: Colors.white,
      elevation: 8,
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) async {
        setState(() {
          selectedIndex = index;
        });

        if (index == 0 && profile == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && selectedIndex == 0 && profile == null) {
              _showCompleteProfilePrompt();
            }
          });
        } else if (index == 1 && history.isEmpty && !historyLoading) {
          await _loadHistory();
        } else if (index == 2 && profile == null && !loading) {
          await _loadHome();
        }
      },
      indicatorColor: Colors.transparent,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined, color: Color(0xFF8DA18A)),
          selectedIcon: Icon(Icons.home, color: primaryGreen),
          label: 'Beranda',
        ),
        NavigationDestination(
          icon: Icon(Icons.history_outlined, color: Color(0xFF8DA18A)),
          selectedIcon: Icon(Icons.history, color: primaryGreen),
          label: 'Riwayat',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline, color: Color(0xFF8DA18A)),
          selectedIcon: Icon(Icons.person, color: primaryGreen),
          label: 'Profil',
        ),
      ],
    );
  }
}

class _CompleteProfilePromptSheet extends StatelessWidget {
  const _CompleteProfilePromptSheet();

  static const Color primaryGreen = Color(0xFF4D8F00);
  static const Color lightGreen = Color(0xFFEAF5E8);
  static const Color textGreen = Color(0xFF294529);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: lightGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.assignment_ind_outlined,
              size: 36,
              color: primaryGreen,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Lengkapi Profil Pasien',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: textGreen,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Selamat datang di Akesa! Lengkapi profil Anda secara manual atau '
            'bantu dengan pemindaian KTP. Setelah profil tersimpan, lanjutkan '
            'verifikasi KTP dan swafoto. Kode pasien dan QR aktif setelah '
            'identitas terverifikasi.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF5E6D5D),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: primaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.edit_note_rounded, size: 20),
              label: const Text(
                'Lengkapi Sekarang',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Keluar dari akun',
                style: TextStyle(
                  color: Color(0xFF70806F),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
