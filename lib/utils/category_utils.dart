import 'package:flutter/material.dart';

/// Human-readable label for a data category code (`IDENTITY`, `CONTACT`,
/// etc.) as returned by the backend. Kept in one place since both the
/// access-request card and the history card need the same mapping.
String categoryLabel(String category) {
  switch (category.toUpperCase()) {
    case 'IDENTITY':
      return 'Identitas Diri';
    case 'CONTACT':
      return 'Kontak';
    case 'MEDICAL_BASIC':
      return 'Data Medis Dasar';
    case 'INSURANCE':
      return 'Asuransi';
    case 'EMERGENCY_CONTACT':
      return 'Kontak Darurat';
    default:
      return category;
  }
}

IconData categoryIcon(String category) {
  switch (category.toUpperCase()) {
    case 'IDENTITY':
      return Icons.badge_outlined;
    case 'CONTACT':
      return Icons.phone_outlined;
    case 'MEDICAL_BASIC':
      return Icons.medical_information_outlined;
    case 'INSURANCE':
      return Icons.health_and_safety_outlined;
    case 'EMERGENCY_CONTACT':
      return Icons.contact_phone_outlined;
    default:
      return Icons.folder_outlined;
  }
}
