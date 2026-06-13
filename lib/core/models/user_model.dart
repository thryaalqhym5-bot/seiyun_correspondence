import 'package:cloud_firestore/cloud_firestore.dart';

class Affiliation {
  final String collegeId;
  final String deptId;
  final String administrativeTitle;
  final String secondaryAdministrativeTitle;

  Affiliation({
    required this.collegeId,
    required this.deptId,
    required this.administrativeTitle,
    required this.secondaryAdministrativeTitle,
  });

  factory Affiliation.fromJson(Map<String, dynamic> json) {
    return Affiliation(
      collegeId: json['college_id'] as String? ?? '',
      deptId: json['dept_id'] as String? ?? '',
      administrativeTitle: json['administrative_title'] as String? ?? 'none',
      secondaryAdministrativeTitle: json['secondary_administrative_title'] as String? ?? 'none',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'college_id': collegeId,
      'dept_id': deptId,
      'administrative_title': administrativeTitle,
      'secondary_administrative_title': secondaryAdministrativeTitle,
    };
  }
}

class UserModel {
  final String? uid;
  final String fullName;
  final String email;
  final String role;
  final String collegeId;
  final String deptId;
  final String administrativeTitle;
  final String secondaryAdministrativeTitle;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? managerId; // Can point to the executive's UID if role is executive_secretary
  final String? rawTitle; // Exact job title from Excel

  final List<Affiliation> affiliations;
  final List<String> collegeIds;
  final List<String> deptIds;
  final List<String> administrativeTitles;

  bool get isExecutive => const [
        'president',
        'vp_student_affairs',
        'vp_academic_affairs',
        'vp_postgraduate_studies',
        'secretary_general',
      ].contains(role);

  bool get isExecutiveSecretary => role == 'executive_secretary';
  UserModel({
    this.uid,
    required this.fullName,
    required this.email,
    required this.role,
    required this.collegeId,
    required this.deptId,
    required this.administrativeTitle,
    required this.secondaryAdministrativeTitle,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.managerId,
    this.rawTitle,
    this.affiliations = const [],
    this.collegeIds = const [],
    this.deptIds = const [],
    this.administrativeTitles = const [],
  });

  factory UserModel.fromJson(Map<String, dynamic> json, [String? id]) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }
    return UserModel(
      uid: json['uid'] as String? ?? id,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'staff',
      collegeId: json['college_id'] as String? ?? '',
      deptId: json['dept_id'] as String? ?? '',
      administrativeTitle: json['administrative_title'] as String? ?? 'none',
      secondaryAdministrativeTitle: json['secondary_administrative_title'] as String? ?? 'none',
      isActive: json['is_active'] ?? true,
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
      managerId: json['manager_id'] as String?,
      rawTitle: json['raw_title'] as String?,
      affiliations: _parseAffiliations(json),
      collegeIds: _parseStringList(json['college_ids']) ?? [json['college_id'] as String? ?? ''],
      deptIds: _parseStringList(json['dept_ids']) ?? [json['dept_id'] as String? ?? ''],
      administrativeTitles: _parseStringList(json['administrative_titles']) ?? [json['administrative_title'] as String? ?? 'none'],
    );
  }

  static List<String>? _parseStringList(dynamic val) {
    if (val is List) {
      return val.map((e) => e.toString()).toList();
    }
    return null;
  }

  static List<Affiliation> _parseAffiliations(Map<String, dynamic> json) {
    if (json['affiliations'] != null && json['affiliations'] is List) {
      return (json['affiliations'] as List).map((e) => Affiliation.fromJson(e as Map<String, dynamic>)).toList();
    }
    // Backward compatibility
    return [
      Affiliation(
        collegeId: json['college_id'] as String? ?? '',
        deptId: json['dept_id'] as String? ?? '',
        administrativeTitle: json['administrative_title'] as String? ?? 'none',
        secondaryAdministrativeTitle: json['secondary_administrative_title'] as String? ?? 'none',
      )
    ];
  }

  Map<String, dynamic> toJson() {
    return {
      if (uid != null) 'uid': uid,
      'full_name': fullName,
      'email': email,
      'role': role,
      'college_id': collegeId,
      'dept_id': deptId,
      'administrative_title': administrativeTitle,
      'secondary_administrative_title': secondaryAdministrativeTitle,
      'is_active': isActive,
      if (createdAt != null) 'created_at': Timestamp.fromDate(createdAt!),
      'updated_at': FieldValue.serverTimestamp(),
      if (managerId != null) 'manager_id': managerId,
      if (rawTitle != null) 'raw_title': rawTitle,
      'affiliations': affiliations.map((e) => e.toJson()).toList(),
      'college_ids': collegeIds,
      'dept_ids': deptIds,
      'administrative_titles': administrativeTitles,
    };
  }

  Map<String, dynamic> toLocalMap() {
    return {
      'uid': uid,
      'full_name': fullName,
      'email': email,
      'role': role,
      'college_id': collegeId,
      'dept_id': deptId,
      'administrative_title': administrativeTitle,
      'secondary_administrative_title': secondaryAdministrativeTitle,
      'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (managerId != null) 'manager_id': managerId,
      'affiliations': affiliations.map((e) => e.toJson()).toList(),
    };
  }

  UserModel copyWith({
    String? uid,
    String? fullName,
    String? email,
    String? role,
    String? collegeId,
    String? deptId,
    String? administrativeTitle,
    String? secondaryAdministrativeTitle,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? managerId,
    List<Affiliation>? affiliations,
    List<String>? collegeIds,
    List<String>? deptIds,
    List<String>? administrativeTitles,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      collegeId: collegeId ?? this.collegeId,
      deptId: deptId ?? this.deptId,
      administrativeTitle: administrativeTitle ?? this.administrativeTitle,
      secondaryAdministrativeTitle: secondaryAdministrativeTitle ?? this.secondaryAdministrativeTitle,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      managerId: managerId ?? this.managerId,
      affiliations: affiliations ?? this.affiliations,
      collegeIds: collegeIds ?? this.collegeIds,
      deptIds: deptIds ?? this.deptIds,
      administrativeTitles: administrativeTitles ?? this.administrativeTitles,
    );
  }
}
