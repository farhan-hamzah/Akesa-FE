import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';

import '../models/api_exception.dart';
import '../models/notification_data.dart';
import '../services/akesa_api.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';

class NotificationPage extends StatefulWidget {
  final ClerkAuthState authState;

  const NotificationPage({super.key, required this.authState});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage>
    with SingleTickerProviderStateMixin {
  late final AkesaApi _api = AkesaApi(authState: widget.authState);
  late final TabController _tabController;

  bool _loading = true;
  bool _markingAll = false;
  String? _errorMessage;

  List<NotificationData> _allNotifications = [];
  List<NotificationData> _unreadNotifications = [];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadNotifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final res = await _api.getNotifications(limit: 50);
      if (!mounted) return;

      setState(() {
        _allNotifications = res.notifications;
        _unreadNotifications =
            res.notifications.where((n) => !n.isRead).toList();
        _unreadCount = res.unreadCount;
        _loading = false;
      });

      NotificationService.instance.setUnreadCount(res.unreadCount);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = e is ApiException
            ? e.message
            : 'Gagal memuat notifikasi. Periksa koneksi Anda.';
      });
    }
  }

  Future<void> _markAllAsRead() async {
    if (_markingAll || _unreadCount == 0) return;

    setState(() => _markingAll = true);
    try {
      await _api.markAllNotificationsAsRead();
      if (!mounted) return;

      setState(() {
        _allNotifications = _allNotifications
            .map((n) => n.copyWith(isRead: true, readAt: DateTime.now()))
            .toList();
        _unreadNotifications = [];
        _unreadCount = 0;
        _markingAll = false;
      });

      NotificationService.instance.setUnreadCount(0);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Semua notifikasi ditandai telah dibaca'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _markingAll = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Gagal menandai notifikasi.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _onNotificationTap(NotificationData item) async {
    // If not read yet, mark as read
    if (!item.isRead) {
      try {
        await _api.markNotificationAsRead(item.id);
        NotificationService.instance.decrementUnreadCount();

        if (mounted) {
          setState(() {
            final idx = _allNotifications.indexWhere((n) => n.id == item.id);
            if (idx != -1) {
              _allNotifications[idx] = _allNotifications[idx]
                  .copyWith(isRead: true, readAt: DateTime.now());
            }
            _unreadNotifications.removeWhere((n) => n.id == item.id);
            if (_unreadCount > 0) _unreadCount--;
          });
        }
      } catch (e) {
        debugPrint('[NotificationPage] Gagal tandai baca: $e');
      }
    }

    if (!mounted) return;
    _showNotificationDetail(item);
  }

  void _showNotificationDetail(NotificationData item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final categoryConfig = _getCategoryConfig(item.category);
        final severityConfig = _getSeverityConfig(item.severity);

        return Container(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: categoryConfig.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          categoryConfig.icon,
                          size: 14,
                          color: categoryConfig.color,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          categoryConfig.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: categoryConfig.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: severityConfig.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      severityConfig.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: severityConfig.color,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatTime(item.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7F8C7D),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E291F),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                item.message,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF3B483A),
                ),
              ),
              if (item.metadata.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FBF6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE4ECE2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Informasi Tambahan:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4D8F00),
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...item.metadata.entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            '• ${e.key}: ${e.value}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF4A5548),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Tutup',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  _CategoryConfig _getCategoryConfig(String category) {
    switch (category.toUpperCase()) {
      case 'SECURITY_ALERT':
        return _CategoryConfig(
          label: 'Keamanan',
          icon: Icons.shield_rounded,
          color: const Color(0xFFD32F2F),
        );
      case 'ACCESS_REQUEST':
        return _CategoryConfig(
          label: 'Izin Akses',
          icon: Icons.vpn_key_rounded,
          color: const Color(0xFF2E7D32),
        );
      case 'HOSPITAL_LIFECYCLE':
        return _CategoryConfig(
          label: 'Rumah Sakit',
          icon: Icons.local_hospital_rounded,
          color: const Color(0xFF00796B),
        );
      case 'SYSTEM':
      default:
        return _CategoryConfig(
          label: 'Sistem',
          icon: Icons.notifications_active_rounded,
          color: const Color(0xFF1976D2),
        );
    }
  }

  _SeverityConfig _getSeverityConfig(String severity) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL':
        return _SeverityConfig(
          label: 'KRITIS',
          color: const Color(0xFFC62828),
        );
      case 'WARNING':
        return _SeverityConfig(
          label: 'PERINGATAN',
          color: const Color(0xFFE65100),
        );
      case 'INFO':
      default:
        return _SeverityConfig(
          label: 'INFO',
          color: const Color(0xFF455A64),
        );
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';

    final d = time.day.toString().padLeft(2, '0');
    final m = time.month.toString().padLeft(2, '0');
    final y = time.year;
    return '$d/$m/$y';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF8),
      appBar: AppBar(
        title: const Text(
          'Pusat Notifikasi',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 19,
            color: Color(0xFF185C22),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Color(0xFF185C22)),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markingAll ? null : _markAllAsRead,
              child: _markingAll
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryGreen,
                      ),
                    )
                  : const Text(
                      'Tandai dibaca',
                      style: TextStyle(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFEAEFE9), width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primaryGreen,
              indicatorWeight: 3,
              labelColor: AppColors.primaryGreen,
              unselectedLabelColor: const Color(0xFF7F8C7D),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Semua'),
                      if (_allNotifications.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF5E8),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_allNotifications.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Belum Dibaca'),
                      if (_unreadCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$_unreadCount',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFD32F2F),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : _errorMessage != null
              ? _buildErrorState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildList(_allNotifications, isUnreadTab: false),
                    _buildList(_unreadNotifications, isUnreadTab: true),
                  ],
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF333333),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: _loadNotifications,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<NotificationData> list, {required bool isUnreadTab}) {
    if (list.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primaryGreen,
        onRefresh: _loadNotifications,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF7EE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        size: 36,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isUnreadTab
                          ? 'Tidak ada notifikasi belum dibaca'
                          : 'Belum ada notifikasi',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF294529),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'Pemberitahuan aktivitas rekam medis, izin akses, dan peringatan keamanan akan muncul di sini.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF7F8C7D),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: _loadNotifications,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = list[index];
          return _buildNotificationCard(item);
        },
      ),
    );
  }

  Widget _buildNotificationCard(NotificationData item) {
    final catConfig = _getCategoryConfig(item.category);
    final isCritical = item.isCritical;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _onNotificationTap(item),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: item.isRead
                ? Colors.white
                : isCritical
                    ? const Color(0xFFFFF7F7)
                    : const Color(0xFFF6FBF5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCritical
                  ? const Color(0xFFFFCDD2)
                  : item.isRead
                      ? const Color(0xFFE9EFE7)
                      : const Color(0xFFB7DEB2),
              width: item.isRead ? 1.0 : 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Container
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isCritical
                      ? const Color(0xFFFFEBEE)
                      : catConfig.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isCritical ? Icons.error_outline_rounded : catConfig.icon,
                  color: isCritical ? const Color(0xFFD32F2F) : catConfig.color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              // Body
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          catConfig.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: catConfig.color,
                          ),
                        ),
                        if (isCritical) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD32F2F),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'CRITICAL',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          _formatTime(item.createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8C9B8A),
                          ),
                        ),
                        if (!item.isRead) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isCritical
                                  ? const Color(0xFFD32F2F)
                                  : AppColors.primaryGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            item.isRead ? FontWeight.w700 : FontWeight.w800,
                        color: const Color(0xFF1E291F),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: item.isRead
                            ? const Color(0xFF6B7869)
                            : const Color(0xFF3B483A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryConfig {
  final String label;
  final IconData icon;
  final Color color;

  _CategoryConfig({
    required this.label,
    required this.icon,
    required this.color,
  });
}

class _SeverityConfig {
  final String label;
  final Color color;

  _SeverityConfig({
    required this.label,
    required this.color,
  });
}
