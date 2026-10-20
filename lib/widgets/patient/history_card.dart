import 'package:flutter/material.dart';

import '../../models/audit_log_data.dart';
import '../../utils/category_utils.dart';
import '../../utils/status_utils.dart';

class HistoryCard extends StatelessWidget {
  final AuditLogData log;
  final String hospitalName;

  const HistoryCard({super.key, required this.log, required this.hospitalName});

  static const Color primaryGreen = Color(0xFF4D8F00);
  static const Color darkGreen = Color(0xFF185C22);
  static const Color lightGreen = Color(0xFFEAF5E8);
  static const Color textGreen = Color(0xFF294529);

  @override
  Widget build(BuildContext context) {
    final payload = log.payloadMap;
    final categories = payload['categories'] is List
        ? (payload['categories'] as List).map((e) => e.toString()).toList()
        : <String>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4EAE2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: lightGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              historyActionIcon(log.action),
              color: primaryGreen,
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  historyActionLabel(log.action),
                  style: const TextStyle(
                    color: textGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hospitalName,
                  style: const TextStyle(
                    color: Color(0xFF5E6B5D),
                    fontSize: 11,
                  ),
                ),
                if (categories.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: categories
                        .map(
                          (category) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: lightGreen,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              categoryLabel(category),
                              style: const TextStyle(
                                color: darkGreen,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 7),
                Text(
                  formatDate(log.createdAt),
                  style: const TextStyle(color: Color(0xFF98A398), fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
