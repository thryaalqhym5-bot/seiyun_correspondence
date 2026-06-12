import 'package:cloud_firestore/cloud_firestore.dart';

class CollegeModel {
  final String id;
  final String name;
  final String entityCode;
  final bool isActive;
  final String? sealUrl;
  final DateTime? createdAt;

  CollegeModel({
    required this.id,
    required this.name,
    required this.entityCode,
    required this.isActive,
    this.sealUrl,
    this.createdAt,
  });

  factory CollegeModel.fromJson(Map<String, dynamic> json, String docId) {
    return CollegeModel(
      id: docId,
      name: json['name'] as String? ?? 'بدون اسم',
      entityCode: json['entity_code'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      sealUrl: json['seal_url'] as String?,
      createdAt: json['created_at'] != null ? (json['created_at'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'entity_code': entityCode,
      'is_active': isActive,
      if (sealUrl != null) 'seal_url': sealUrl,
      if (createdAt != null) 'created_at': Timestamp.fromDate(createdAt!),
    };
  }
}
