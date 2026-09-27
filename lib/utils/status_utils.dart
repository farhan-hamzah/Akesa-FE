import 'package:flutter/material.dart';

String accessStatusLabel(String status) {
  switch (status.toUpperCase()) {
    case 'PENDING':
      return 'Pending';
    case 'APPROVED':
      return 'Aktif';
    case 'REJECTED':
      return 'Ditolak';
    case 'REVOKED':
      return 'Dicabut';
    default:
      return status;
  }
}

/// [approvedColor] is passed in rather than hardcoded here so this stays
/// a pure, page-agnostic helper - the caller's theme owns its own greens.
Color accessStatusColor(String status, {required Color approvedColor}) {
  switch (status.toUpperCase()) {
    case 'APPROVED':
      return approvedColor;
    case 'REJECTED':
    case 'REVOKED':
      return Colors.redAccent;
    case 'PENDING':
    default:
      return const Color(0xFF8A6A00);
  }
}

String historyActionLabel(String action) {
  switch (action.toUpperCase()) {
    case 'ACCESS_REQUESTED':
      return 'Permintaan akses dibuat';
    case 'ACCESS_APPROVED':
      return 'Akses disetujui';
    case 'ACCESS_REJECTED':
      return 'Akses ditolak';
    case 'ACCESS_REVOKED':
      return 'Akses dicabut';
    case 'DATA_ACCESSED':
      return 'Data diakses';
    default:
      return action.replaceAll('_', ' ');
  }
}

IconData historyActionIcon(String action) {
  switch (action.toUpperCase()) {
    case 'ACCESS_REQUESTED':
      return Icons.mail_outline;
    case 'ACCESS_APPROVED':
      return Icons.check_circle_outline;
    case 'ACCESS_REJECTED':
      return Icons.cancel_outlined;
    case 'ACCESS_REVOKED':
      return Icons.block_outlined;
    case 'DATA_ACCESSED':
      return Icons.visibility_outlined;
    default:
      return Icons.history_rounded;
  }
}

String formatDate(String? value) {
  if (value == null || value.isEmpty) {
    return '-';
  }

  final date = DateTime.tryParse(value);
  if (date == null) {
    return value;
  }

  final local = date.toLocal();

  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/'
      '${local.year} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}
