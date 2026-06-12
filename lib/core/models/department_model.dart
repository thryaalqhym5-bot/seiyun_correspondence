import 'package:cloud_firestore/cloud_firestore.dart';

class DepartmentModel {
  final String id;
  final String name;
  final String entityCode;
  final bool isActive;
  final DateTime? createdAt;

  DepartmentModel({
    required this.id,
    required this.name,
    required this.entityCode,
    required this.isActive,
    this.createdAt,
  });

  factory DepartmentModel.fromJson(Map<String, dynamic> json, String docId) {
    return DepartmentModel(
      id: docId,
      name: json['name'] as String? ?? 'بدون اسم',
      entityCode: json['entity_code'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null ? (json['created_at'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'entity_code': entityCode,
      'is_active': isActive,
      if (createdAt != null) 'created_at': Timestamp.fromDate(createdAt!),
    };
  }
}
