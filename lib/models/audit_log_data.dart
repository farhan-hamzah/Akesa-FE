import 'dart:convert';

class AuditLogData {
  final String entityType;
  final String entityId;
  final String action;
  final String actorId;
  final dynamic payload;
  final String? createdAt;

  AuditLogData({
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.actorId,
    this.payload,
    this.createdAt,
  });

  factory AuditLogData.fromJson(Map<String, dynamic> json) {
    return AuditLogData(
      entityType: '${json['entityType'] ?? ''}',
      entityId: '${json['entityId'] ?? ''}',
      action: '${json['action'] ?? ''}',
      actorId: '${json['actorId'] ?? ''}',
      payload: json['payload'],
      createdAt: json['createdAt']?.toString(),
    );
  }

  Map<String, dynamic> get payloadMap {
    if (payload is Map<String, dynamic>) {
      return payload as Map<String, dynamic>;
    }

    if (payload is String) {
      try {
        final decoded = jsonDecode(payload);

        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (_) {
      }
    }

    return {};
  }
}
