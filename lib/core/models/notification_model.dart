import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String? id;
  final String targetUserId;
  final String title;
  final String body;
  final String type; // e.g., 'new_message', 'returned_draft', 'approved', 'draft_request', 'urgent'
  final bool isRead;
  final String? relatedDocId;
  final DateTime? createdAt;

  NotificationModel({
    this.id,
    required this.targetUserId,
    required this.title,
    required this.body,
    required this.type,
    this.isRead = false,
    this.relatedDocId,
    this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json, [String? id]) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return NotificationModel(
      id: id,
      targetUserId: json['target_user_id'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      type: json['type'] ?? 'info',
      isRead: json['is_read'] ?? false,
      relatedDocId: json['related_doc_id'],
      createdAt: parseDate(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'target_user_id': targetUserId,
      'title': title,
      'body': body,
      'type': type,
      'is_read': isRead,
      'related_doc_id': relatedDocId,
      'created_at': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
