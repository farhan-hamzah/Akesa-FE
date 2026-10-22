import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/material.dart';

import '../../pages/notification_page.dart';
import '../../services/notification_service.dart';

class NotificationBellButton extends StatelessWidget {
  final ClerkAuthState authState;
  final Color iconColor;
  final Color badgeColor;
  final Color badgeTextColor;
  final double size;
  final VoidCallback? onOpened;

  const NotificationBellButton({
    super.key,
    required this.authState,
    this.iconColor = Colors.white,
    this.badgeColor = const Color(0xFFE53935),
    this.badgeTextColor = Colors.white,
    this.size = 24.0,
    this.onOpened,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationService.instance.unreadCount,
      builder: (context, count, _) {
        final hasUnread = count > 0;
        final countText = count > 99 ? '99+' : '$count';

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NotificationPage(authState: authState),
                ),
              );
              if (onOpened != null) {
                onOpened!();
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    hasUnread
                        ? Icons.notifications_rounded
                        : Icons.notifications_none_rounded,
                    color: iconColor,
                    size: size,
                  ),
                  if (hasUnread)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 17,
                          minHeight: 17,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            countText,
                            style: TextStyle(
                              color: badgeTextColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
