import 'package:flutter/material.dart';

/// The green "patient code" card at the top of the patient home page -
/// compact label + copy/QR action buttons, matching the Figma layout.
/// Pure display + callbacks; all state (loading, the code itself) lives
/// in the parent page.
class PatientCodeCard extends StatelessWidget {
  final String patientCode;
  final bool qrLoading;
  final VoidCallback onCopyCode;
  final VoidCallback? onShowQr;

  const PatientCodeCard({
    super.key,
    required this.patientCode,
    required this.qrLoading,
    required this.onCopyCode,
    required this.onShowQr,
  });

  static const Color primaryGreen = Color(0xFF4D8F00);
  static const Color lightGreen = Color(0xFFEAF5E8);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryGreen,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primaryGreen.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.badge_outlined, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'KODE UNIK PASIEN',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: Colors.white,
                  ),
                ),
              ),
              _ActionButton(
                icon: Icons.copy_rounded,
                tooltip: 'Salin kode',
                onTap: onCopyCode,
              ),
              const SizedBox(width: 8),
              _ActionButton(
                icon: Icons.qr_code_2_rounded,
                tooltip: 'Tampilkan QR',
                onTap: onShowQr,
                loading: qrLoading,
                highlighted: true,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.20),
              borderRadius: BorderRadius.circular(16),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                patientCode,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: lightGreen,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 16,
                color: lightGreen.withOpacity(0.85),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Tunjukkan kode ini ke Petugas RS saat pendaftaran, atau '
                  'ketuk ikon QR di atas untuk menampilkan QR pasien.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: lightGreen.withOpacity(0.85),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool loading;
  final bool highlighted;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.loading = false,
    this.highlighted = false,
  });

  static const Color primaryGreen = Color(0xFF4D8F00);
  static const Color darkGreen = Color(0xFF185C22);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: highlighted ? primaryGreen : Colors.white.withOpacity(0.75),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Center(
              child: loading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: highlighted ? Colors.white : primaryGreen,
                      ),
                    )
                  : Icon(
                      icon,
                      size: 18,
                      color: highlighted ? Colors.white : darkGreen,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
