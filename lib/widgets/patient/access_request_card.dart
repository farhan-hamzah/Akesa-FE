import 'package:flutter/material.dart';

import '../../models/access_request_data.dart';
import '../../utils/category_utils.dart';
import '../../utils/status_utils.dart';

/// One access-request card in the patient home "Permintaan Izin Akses"
/// list - shows the requesting hospital, the categories asked for, and
/// (depending on status) approve/reject or revoke actions.
class AccessRequestCard extends StatelessWidget {
  final AccessRequestData request;
  final String hospitalName;
  final bool actionLoading;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onRevoke;

  const AccessRequestCard({
    super.key,
    required this.request,
    required this.hospitalName,
    required this.actionLoading,
    required this.onApprove,
    required this.onReject,
    required this.onRevoke,
  });

  static const Color primaryGreen = Color(0xFF4D8F00);
  static const Color darkGreen = Color(0xFF185C22);
  static const Color lightGreen = Color(0xFFEAF5E8);
  static const Color textGreen = Color(0xFF294529);

  @override
  Widget build(BuildContext context) {
    final status = request.status.toUpperCase();
    final isPending = status == 'PENDING';
    final isApproved = status == 'APPROVED';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE6ECE5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: lightGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.local_hospital_outlined,
                    color: darkGreen,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hospitalName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: textGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        request.purpose.isEmpty
                            ? 'Permintaan akses data pasien'
                            : 'Tujuan: ${request.purpose}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF7C887A),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isPending)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: accessStatusColor(status, approvedColor: primaryGreen)
                          .withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      accessStatusLabel(status),
                      style: TextStyle(
                        color: accessStatusColor(status, approvedColor: primaryGreen),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 13),
            const Text(
              'Kategori Data Ditagihkan:',
              style: TextStyle(
                color: Color(0xFF354535),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            if (request.categories.isEmpty)
              const Text(
                'Tidak ada kategori data.',
                style: TextStyle(color: Colors.grey, fontSize: 11),
              )
            else
              ...request.categories.map(
                (category) => _CategoryRow(category: category, isApproved: isApproved),
              ),
            if (isPending) ...[
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 39,
                      child: FilledButton(
                        onPressed: actionLoading ? null : onApprove,
                        style: FilledButton.styleFrom(
                          backgroundColor: primaryGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: actionLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Setujui Akses',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 39,
                      child: OutlinedButton(
                        onPressed: actionLoading ? null : onReject,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFDDE3DC)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: const Text(
                          'Tolak',
                          style: TextStyle(
                            color: Color(0xFF596459),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (isApproved) ...[
              const SizedBox(height: 9),
              SizedBox(
                width: double.infinity,
                height: 39,
                child: OutlinedButton.icon(
                  onPressed: actionLoading ? null : onRevoke,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF5F5),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  icon: const Icon(Icons.block_outlined, color: Colors.redAccent, size: 16),
                  label: const Text(
                    'Cabut Izin Akses (Revoke)',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final String category;
  final bool isApproved;

  const _CategoryRow({required this.category, required this.isApproved});

  static const Color primaryGreen = Color(0xFF4D8F00);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(categoryIcon(category), size: 15, color: const Color(0xFF658064)),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              categoryLabel(category),
              style: const TextStyle(color: Color(0xFF435143), fontSize: 11),
            ),
          ),
          Container(
            width: 30,
            height: 18,
            decoration: BoxDecoration(
              color: isApproved ? const Color(0xFF236A38) : const Color(0xFF6F7B73),
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 3),
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: isApproved ? const Icon(Icons.check, size: 9, color: primaryGreen) : null,
            ),
          ),
        ],
      ),
    );
  }
}
