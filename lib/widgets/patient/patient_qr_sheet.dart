import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/patient_qr.dart';

/// Content shown inside the bottom sheet opened from [PatientCodeCard]'s
/// QR button. Pure display + callbacks - all state (loading, the QR data
/// itself, the biometric check before it's ever fetched) lives in the
/// parent page.
class PatientQrSheet extends StatelessWidget {
  final PatientQr? qr;
  final bool rotating;
  final VoidCallback onRotate;
  final VoidCallback onClose;

  const PatientQrSheet({
    super.key,
    required this.qr,
    required this.rotating,
    required this.onRotate,
    required this.onClose,
  });

  static const Color primaryGreen = Color(0xFF4D8F00);
  static const Color darkGreen = Color(0xFF185C22);

  @override
  Widget build(BuildContext context) {
    final currentQr = qr;

    if (currentQr == null || currentQr.qrPayload.isEmpty || !currentQr.isActive) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text('QR pasien tidak tersedia.'),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withOpacity(0.08)),
          ),
          child: QrImageView(
            data: currentQr.qrPayload,
            size: 200,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          currentQr.displayCode,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: darkGreen,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: rotating ? null : onRotate,
                icon: rotating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: Text(rotating ? 'Memperbarui...' : 'Perbarui QR'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryGreen,
                  side: const BorderSide(color: primaryGreen),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: onClose,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Tutup'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Jangan tampilkan QR ini kepada orang yang tidak berwenang.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
