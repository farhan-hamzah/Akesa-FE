import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';

import '../../models/api_exception.dart';
import '../../pages/auth_page.dart';
import '../../services/akesa_api.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';

const Color kBg = Color(0xFFFDFEFC);
const Color kBorder = Color(0xFFE4ECE2);
const Color kMuted = Color(0xFF7F8C7D);

final RegExp kUuidRegex = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

const List<String> kCategoryIds = [
  'IDENTITY',
  'CONTACT',
  'MEDICAL_BASIC',
  'INSURANCE',
  'EMERGENCY_CONTACT',
];

const Map<String, String> kCategoryLabels = {
  'IDENTITY': 'Identitas',
  'CONTACT': 'Kontak',
  'MEDICAL_BASIC': 'Medis Dasar',
  'INSURANCE': 'Asuransi',
  'EMERGENCY_CONTACT': 'Kontak Darurat',
};

const Map<String, String> kCategoryHints = {
  'IDENTITY': 'Nama lengkap, NIK, tanggal lahir, jenis kelamin',
  'CONTACT': 'Nomor telepon dan alamat',
  'MEDICAL_BASIC': 'Golongan darah dan alergi',
  'INSURANCE': 'Nomor asuransi',
  'EMERGENCY_CONTACT': 'Nama dan telepon kontak darurat',
};

// ------------------------------------------------------------ ERROR TEXT
const Map<String, String> _errorMessages = {
  'invalid_json_body': 'Format data yang dikirim tidak valid.',
  'unauthorized': 'Sesi login tidak valid. Silakan masuk kembali.',
  'forbidden': 'Permintaan ini bukan milik rumah sakit Anda.',
  'patient_not_found': 'Pasien dengan kode tersebut tidak ditemukan.',
  'access_request_not_found': 'Permintaan akses tidak ditemukan.',
  'access_request_not_pending':
      'Permintaan akses sudah tidak berstatus menunggu.',
  'access_request_not_approved':
      'Izin akses belum disetujui atau sudah dicabut oleh pasien.',
  'patient_data_integrity_violation': 'Data pasien gagal diverifikasi (hash tidak cocok). Akses diblokir demi keamanan.',
  'hospital_not_found': 'Rumah sakit tidak ditemukan.',
  'email_already_registered': 'Email sudah terdaftar pada rumah sakit lain.',
  'registration_number_already_registered': 'Nomor registrasi sudah terdaftar.',
  'user_already_staff': 'Pengguna ini sudah terhubung sebagai petugas.',
  'hospital_not_active': 'Rumah sakit harus berstatus Terverifikasi atau Aktif untuk menambah petugas.',
  'invalid_user_id': 'ID pengguna harus berupa UUID yang valid.',
  'invalid_hospital_id': 'ID rumah sakit tidak valid.',
  'invalid_request_id': 'ID permintaan tidak valid.',
  'internal_server_error': 'Terjadi kesalahan pada server. Coba lagi nanti.',
  'purpose is required': 'Tujuan permintaan wajib diisi.',
  'at least one data category is required': 'Pilih minimal satu kategori data.',
};

const Map<String, String> _fieldNames = {
  'name': 'Nama',
  'address': 'Alamat',
  'phone': 'Telepon',
  'email': 'Email',
  'registrationNumber': 'Nomor registrasi',
  'patientCode': 'Kode pasien',
};

String apiErrorMessage(Object error) {
  if (error is! ApiException) {
    return 'Terjadi kesalahan. Silakan coba lagi.';
  }
  final msg = error.message;
  if (_errorMessages.containsKey(msg)) return _errorMessages[msg]!;
  if (msg.startsWith('invalid data category')) {
    return 'Kategori data tidak valid.';
  }
  if (error.statusCode == 422 && msg.contains(': ')) {
    final i = msg.indexOf(': ');
    final field = msg.substring(0, i);
    return '${_fieldNames[field] ?? field} ${msg.substring(i + 2)}.';
  }
  if (error.statusCode == 401) return 'Sesi login sudah tidak tersedia.';
  if (error.statusCode == 403)
    return 'Anda tidak memiliki akses untuk tindakan ini.';
  return msg;
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? Colors.redAccent : null,
      ),
    );
}

String formatDate(String? iso) {
  if (iso == null || iso.isEmpty) return '-';
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return iso;
  const m = [
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
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.day} ${m[d.month - 1]} ${d.year}, ${two(d.hour)}:${two(d.minute)}';
}

// ---------------------------------------------------------------- TONES
class Tone {
  final String label;
  final Color fg;
  final Color bg;
  const Tone(this.label, this.fg, this.bg);
}

Tone hospitalApplicationTone(String status) {
  switch (status.toUpperCase()) {
    case 'PENDING_REVIEW':
      return const Tone(
        'Menunggu Tinjauan',
        Color(0xFF9A6700),
        Color(0xFFFFF4D6),
      );
    case 'REVISION_REQUIRED':
      return const Tone(
        'Perlu Revisi',
        Color(0xFFC05621),
        Color(0xFFFEEBC8),
      );
    case 'REJECTED':
      return const Tone(
        'Ditolak',
        Color(0xFFC53030),
        Color(0xFFFED7D7),
      );
    case 'APPROVED':
      return const Tone('Disetujui', AppColors.darkGreen, AppColors.lightGreen);
    default:
      return Tone(status, kMuted, const Color(0xFFEDEFEC));
  }
}

Tone hospitalTone(String status) {
  switch (status.toUpperCase()) {
    case 'ACTIVE':
      return const Tone('Aktif', AppColors.darkGreen, AppColors.lightGreen);
    case 'INACTIVE':
      return const Tone('Nonaktif', Color(0xFF5F6B5D), Color(0xFFEDEFEC));
    case 'PENDING':
      return const Tone(
        'Menunggu',
        Color(0xFF9A6700),
        Color(0xFFFFF4D6),
      );
    default:
      return Tone(status, kMuted, const Color(0xFFEDEFEC));
  }
}

Tone accessTone(String status) {
  switch (status.toUpperCase()) {
    case 'PENDING':
      return const Tone(
        'Menunggu Pasien',
        Color(0xFF9A6700),
        Color(0xFFFFF4D6),
      );
    case 'APPROVED':
      return const Tone('Disetujui', AppColors.darkGreen, AppColors.lightGreen);
    case 'REJECTED':
      return const Tone(
        'Ditolak',
        AppColors.errorText,
        AppColors.errorBackground,
      );
    case 'REVOKED':
      return const Tone('Dicabut', Color(0xFF5F6B5D), Color(0xFFEDEFEC));
    default:
      return Tone(status, kMuted, const Color(0xFFEDEFEC));
  }
}

// -------------------------------------------------------------- WIDGETS
class StatusBadge extends StatelessWidget {
  final Tone tone;
  const StatusBadge(this.tone, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: tone.bg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      tone.label,
      style: TextStyle(
        color: tone.fg,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class CategoryChips extends StatelessWidget {
  final List<String> categories;
  const CategoryChips(this.categories, {super.key});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: categories
        .map(
          (c) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.lightGreen,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              kCategoryLabels[c] ?? c,
              style: const TextStyle(
                color: AppColors.textGreen,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        )
        .toList(),
  );
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: borderColor ?? kBorder),
    ),
    child: child,
  );
}

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const InfoRow(this.icon, this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF6B8F68)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text.isEmpty ? '-' : text,
            style: const TextStyle(
              color: AppColors.textGreen,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
    child: Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: AppColors.lightGreen,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primaryGreen),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textGreen,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: kMuted, fontSize: 12, height: 1.4),
        ),
      ],
    ),
  );
}

/// Helper global untuk melakukan proses logout dan membersihkan seluruh
/// navigation stack kembali ke halaman login (AuthPage).
Future<void> performLogout(BuildContext context, ClerkAuthState authState) async {
  try {
    final api = AkesaApi(authState: authState);
    await NotificationService.instance.clearDeviceToken(api);
    await authState.signOut();
  } catch (e) {
    debugPrint('Logout error: $e');
  }
  if (context.mounted) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthPage()),
      (route) => false,
    );
  }
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onLogout;
  final ClerkAuthState? authState;

  const ErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.onLogout,
    this.authState,
  });

  @override
  Widget build(BuildContext context) {
    final isSessionError = message.toLowerCase().contains('sesi login') ||
        message.toLowerCase().contains('unauthorized') ||
        message.toLowerCase().contains('401');

    final VoidCallback? effectiveLogout = onLogout ??
        (authState != null ? () => performLogout(context, authState!) : null);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: isSessionError
                    ? const Color(0xFFFFF3E0)
                    : AppColors.errorBackground,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                isSessionError
                    ? Icons.lock_clock_outlined
                    : Icons.cloud_off_outlined,
                color: isSessionError
                    ? const Color(0xFFE65100)
                    : Colors.redAccent,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isSessionError ? 'Sesi Telah Berakhir' : 'Gagal memuat data',
              style: const TextStyle(
                color: AppColors.textGreen,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: kMuted, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
              ),
              child: const Text('Coba Lagi'),
            ),
            if (effectiveLogout != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: effectiveLogout,
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
          ],
        ),
      ),
    );
  }
}

/// Tombol hijau bergradasi (sama dengan tombol di halaman auth).
class GreenButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expanded;
  final bool compact;
  final bool danger;

  const GreenButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.expanded = true,
    this.compact = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final colors = danger
        ? const [Color(0xFFE5484D), Color(0xFFB42318)]
        : const [AppColors.buttonGreenStart, AppColors.buttonGreenEnd];
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: enabled ? onPressed : null,
            child: Container(
              height: compact ? 40 : 48,
              padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 18),
              child: Row(
                mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else if (icon != null)
                    Icon(icon, color: Colors.white, size: 18),
                  if (loading || icon != null) const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: compact ? 12.5 : 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SoftButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color color;
  const SoftButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.color = AppColors.primaryGreen,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon ?? Icons.check, size: 18, color: color),
    label: Text(
      label,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w600,
        fontSize: 12.5,
      ),
    ),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 40),
      side: BorderSide(color: color.withValues(alpha: 0.45)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

class PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 118,
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
                Colors.black.withValues(alpha: 0.25),
                AppColors.darkGreen.withValues(alpha: 0.92),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ],
    ),
  );
}

class CenteredBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const CenteredBody({super.key, required this.child, this.maxWidth = 820});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// Header hijau + isi yang dipusatkan (maks 820px) untuk setiap tab.
class TabPage extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;
  const TabPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      PageHeader(title: title, subtitle: subtitle, trailing: trailing),
      Expanded(child: CenteredBody(child: child)),
    ],
  );
}

class NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const NavItem(this.icon, this.selectedIcon, this.label);
}

/// Bottom navigation di HP, NavigationRail di tablet/layar lebar.
class AdaptiveShell extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  final List<NavItem> items;
  final Widget body;
  const AdaptiveShell({
    super.key,
    required this.index,
    required this.onSelect,
    required this.items,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 800;
    if (wide) {
      return Scaffold(
        backgroundColor: kBg,
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: index,
                onDestinationSelected: onSelect,
                labelType: NavigationRailLabelType.all,
                backgroundColor: Colors.white,
                indicatorColor: AppColors.lightGreen,
                destinations: items
                    .map(
                      (e) => NavigationRailDestination(
                        icon: Icon(e.icon, color: const Color(0xFF8DA18A)),
                        selectedIcon: Icon(
                          e.selectedIcon,
                          color: AppColors.primaryGreen,
                        ),
                        label: Text(e.label),
                      ),
                    )
                    .toList(),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(child: body),
      bottomNavigationBar: NavigationBar(
        height: 67,
        backgroundColor: Colors.white,
        elevation: 8,
        selectedIndex: index,
        onDestinationSelected: onSelect,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: items
            .map(
              (e) => NavigationDestination(
                icon: Icon(e.icon, color: const Color(0xFF8DA18A)),
                selectedIcon: Icon(
                  e.selectedIcon,
                  color: AppColors.primaryGreen,
                ),
                label: e.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

/// Bottom sheet form yang aman terhadap keyboard & layar lebar.
Future<T?> showAppSheet<T>(BuildContext context, String title, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.darkGreen,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    ),
  );
}

class InlineError extends StatelessWidget {
  final String message;
  const InlineError(this.message, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.errorBackground,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.errorBorder),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, color: AppColors.errorText, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: AppColors.errorText,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );
}
