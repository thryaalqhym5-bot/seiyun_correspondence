import 'package:cloud_firestore/cloud_firestore.dart';

class TrackingEntryModel {
  final String id;
  final String action;
  final String fromId;
  final String fromName;
  final String toId;
  final String toName;
  final String fromStatus;
  final String toStatus;
  final String comment;
  final DateTime? timestamp;

  TrackingEntryModel({
    required this.id,
    required this.action,
    required this.fromId,
    required this.fromName,
    required this.toId,
    required this.toName,
    required this.fromStatus,
    required this.toStatus,
    required this.comment,
    this.timestamp,
  });

  factory TrackingEntryModel.fromJson(Map<String, dynamic> json, String docId) {
    return TrackingEntryModel(
      id: docId,
      action: json['action'] as String? ?? '',
      fromId: json['from_id'] as String? ?? '',
      fromName: json['from_name'] as String? ?? '',
      toId: json['to_id'] as String? ?? '',
      toName: json['to_name'] as String? ?? '',
      fromStatus: json['from_status'] as String? ?? '',
      toStatus: json['to_status'] as String? ?? '',
      comment: json['comment'] as String? ?? '',
      timestamp: json['timestamp'] != null ? (json['timestamp'] as Timestamp).toDate() : null,
    );
  }
}
