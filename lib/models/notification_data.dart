class NotificationData {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String category;
  final String severity;
  final bool isRead;
  final String? actionUrl;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime? readAt;

  NotificationData({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.category,
    required this.severity,
    required this.isRead,
    this.actionUrl,
    required this.metadata,
    required this.createdAt,
    this.readAt,
  });

  bool get isCritical => severity.toUpperCase() == 'CRITICAL';
  bool get isWarning => severity.toUpperCase() == 'WARNING';
  bool get isAccessRequest => category.toUpperCase() == 'ACCESS_REQUEST';
  bool get isSecurityAlert => category.toUpperCase() == 'SECURITY_ALERT';

  factory NotificationData.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> meta = {};
    final rawMeta = json['metadata'];
    if (rawMeta is Map<String, dynamic>) {
      meta = rawMeta;
    }

    DateTime parsedCreatedAt = DateTime.now();
    if (json['createdAt'] != null) {
      try {
        parsedCreatedAt = DateTime.parse(json['createdAt'].toString());
      } catch (_) {}
    }

    DateTime? parsedReadAt;
    if (json['readAt'] != null) {
      try {
        parsedReadAt = DateTime.parse(json['readAt'].toString());
      } catch (_) {}
    }

    return NotificationData(
      id: '${json['id'] ?? ''}',
      userId: '${json['userId'] ?? ''}',
      title: '${json['title'] ?? ''}',
      message: '${json['message'] ?? ''}',
      category: '${json['category'] ?? 'SYSTEM'}',
      severity: '${json['severity'] ?? 'INFO'}',
      isRead: json['isRead'] == true,
      actionUrl: json['actionUrl']?.toString(),
      metadata: meta,
      createdAt: parsedCreatedAt,
      readAt: parsedReadAt,
    );
  }

  NotificationData copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    String? category,
    String? severity,
    bool? isRead,
    String? actionUrl,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? readAt,
  }) {
    return NotificationData(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      isRead: isRead ?? this.isRead,
      actionUrl: actionUrl ?? this.actionUrl,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
    );
  }
}

class NotificationListResponse {
  final List<NotificationData> notifications;
  final int total;
  final int unreadCount;

  NotificationListResponse({
    required this.notifications,
    required this.total,
    required this.unreadCount,
  });

  factory NotificationListResponse.fromJson(Map<String, dynamic> json) {
    final rawList = json['notifications'];
    List<NotificationData> items = [];
    if (rawList is List) {
      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          items.add(NotificationData.fromJson(item));
        }
      }
    }

    return NotificationListResponse(
      notifications: items,
      total: json['total'] is int ? json['total'] : items.length,
      unreadCount: json['unreadCount'] is int ? json['unreadCount'] : 0,
    );
  }
}
