import 'package:cloud_firestore/cloud_firestore.dart';

class CommunicationModel {
  final String? id;
  final String subject;
  final String body;
  final String type;
  final String priority;
  final String templateId;
  final String targetId;
  final String targetName;
  final String targetDeptId;
  final String senderId;
  final String senderName;
  final String status;
  final String currentRcvId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? generatedDocxUrl;
  final String? finalPdfPath;
  final String? digitalSignature;
  final String? senderSignatureUrl;
  final String? senderSealUrl;
  final List<Map<String, dynamic>>? attachments;
  final String? managerNotes;

  // حقول الوارد الخارجي
  final bool isExternal;
  final String? documentDate;
  final String? referenceNumber;
  final String? externalReferenceNumber;
  final bool isReadByDean;
  final bool isRead;

  // حقول ربط الرد بالمراسلة الأصلية (Threading)
  final String? parentCommId;
  final String? parentRefNumber;

  // حقول السرية والتفويض
  final String securityLevel; // 'normal', 'confidential', 'top_secret'

  final String? targetGroup;
  final String? senderCollegeId;
  final String? senderDeptId;
  final bool isCircular;
  final bool isExternalOutgoing;
  bool isDelegated;

  CommunicationModel({
    this.id,
    required this.subject,
    required this.body,
    required this.type,
    required this.priority,
    required this.templateId,
    required this.targetId,
    required this.targetName,
    required this.targetDeptId,
    required this.senderId,
    required this.senderName,
    required this.status,
    required this.currentRcvId,
    this.createdAt,
    this.updatedAt,
    this.generatedDocxUrl,
    this.finalPdfPath,
    this.digitalSignature,
    this.senderSignatureUrl,
    this.senderSealUrl,
    this.attachments,
    this.managerNotes,
    this.isExternal = false,
    this.documentDate,
    this.referenceNumber,
    this.externalReferenceNumber,
    this.isReadByDean = false,
    this.isRead = false,
    this.parentCommId,
    this.parentRefNumber,
    this.securityLevel = 'normal',
    this.targetGroup,
    this.senderCollegeId,
    this.senderDeptId,
    this.isCircular = false,
    this.isExternalOutgoing = false,
    this.isDelegated = false,
  });

  factory CommunicationModel.fromJson(Map<String, dynamic> json, [String? docId]) {
    return CommunicationModel(
      id: docId,
      subject: json['subject'] as String? ?? 'بدون عنوان',
      body: (json['body'] ?? json['body_text']) as String? ?? '',
      type: json['type'] as String? ?? 'outgoing',
      priority: json['priority'] as String? ?? 'normal',
      templateId: json['template_id'] as String? ?? '',
      targetId: json['target_id'] as String? ?? '',
      targetName: json['target_name'] as String? ?? '',
      targetDeptId: (json['target_dept_id'] ?? json['current_dept_id']) as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      senderName: json['sender_name'] as String? ?? '',
      status: json['status'] as String? ?? 'قيد المعالجة',
      currentRcvId: json['current_rcv_id'] as String? ?? '',
      createdAt: json['created_at'] != null ? (json['created_at'] as Timestamp).toDate() : null,
      updatedAt: json['updated_at'] != null ? (json['updated_at'] as Timestamp).toDate() : null,
      generatedDocxUrl: json['generated_docx_url'] as String?,
      finalPdfPath: json['final_pdf_path'] as String?,
      digitalSignature: json['digital_signature'] as String?,
      senderSignatureUrl: json['sender_signature_url'] as String?,
      senderSealUrl: json['sender_seal_url'] as String?,
      attachments: json['attachments'] != null ? List<Map<String, dynamic>>.from(json['attachments']) : null,
      managerNotes: json['manager_notes'] as String?,
      isExternal: json['is_external'] as bool? ?? false,
      documentDate: json['document_date'] as String?,
      referenceNumber: json['reference_number'] as String?,
      externalReferenceNumber: json['external_reference_number'] as String?,
      isReadByDean: json['is_read_by_dean'] as bool? ?? false,
      isRead: json['is_read'] as bool? ?? false,
      parentCommId: json['parent_comm_id'] as String?,
      parentRefNumber: json['parent_ref_number'] as String?,
      securityLevel: json['security_level'] as String? ?? 'normal',
      targetGroup: json['target_group'] as String?,
      senderCollegeId: json['sender_college_id'] as String?,
      senderDeptId: json['sender_dept_id'] as String?,
      isCircular: json['is_circular'] as bool? ?? false,
      isExternalOutgoing: json['is_external_outgoing'] as bool? ?? false,
      isDelegated: json['is_delegated'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subject': subject,
      'body': body,
      'type': type,
      'priority': priority,
      'template_id': templateId,
      'target_id': targetId,
      'target_name': targetName,
      'target_dept_id': targetDeptId,
      'sender_id': senderId,
      'sender_name': senderName,
      'status': status,
      'current_rcv_id': currentRcvId,
      if (createdAt != null) 'created_at': Timestamp.fromDate(createdAt!),
      'updated_at': FieldValue.serverTimestamp(),
      if (generatedDocxUrl != null) 'generated_docx_url': generatedDocxUrl,
      if (finalPdfPath != null) 'final_pdf_path': finalPdfPath,
      if (digitalSignature != null) 'digital_signature': digitalSignature,
      if (senderSignatureUrl != null) 'sender_signature_url': senderSignatureUrl,
      if (senderSealUrl != null) 'sender_seal_url': senderSealUrl,
      if (attachments != null) 'attachments': attachments,
      if (managerNotes != null) 'manager_notes': managerNotes,
      'is_external': isExternal,
      if (documentDate != null) 'document_date': documentDate,
      if (referenceNumber != null) 'reference_number': referenceNumber,
      if (externalReferenceNumber != null) 'external_reference_number': externalReferenceNumber,
      'is_read_by_dean': isReadByDean,
      'is_read': isRead,
      if (parentCommId != null) 'parent_comm_id': parentCommId,
      if (parentRefNumber != null) 'parent_ref_number': parentRefNumber,
      'security_level': securityLevel,
      if (targetGroup != null) 'target_group': targetGroup,
      if (senderCollegeId != null) 'sender_college_id': senderCollegeId,
      if (senderDeptId != null) 'sender_dept_id': senderDeptId,
      'is_circular': isCircular,
      'is_external_outgoing': isExternalOutgoing,
      'is_delegated': isDelegated,
    };
  }

  bool get isLate {
    if (createdAt == null) return false;
    // إذا كانت المعاملة منجزة أو مؤرشفة فلا تعتبر متأخرة
    if (status == 'archived' || status == 'completed' || status == 'مكتملة' || status == 'مؤرشفة') {
      return false;
    }

    final now = DateTime.now();
    final difference = now.difference(createdAt!);

    if (priority == 'urgent' || priority == 'عاجل') {
      return difference.inHours >= 24;
    } else {
      return difference.inHours >= 48;
    }
  }

  String get statusAr {
    switch (status) {
      case 'draft_requested': return 'مطلوب صياغتها';
      case 'draft': return 'مسودة';
      case 'pending': return 'مجهزة للاعتماد';
      case 'approved': return 'معتمدة';
      case 'returned_for_edit': return 'معادة للتعديل';
      case 'processing': return 'قيد المعالجة';
      case 'completed': return 'منجزة';
      case 'archived': return 'مؤرشفة';
      case 'rejected': return 'مرفوضة';
      default: return status;
    }
  }

  String get typeAr {
    switch (type) {
      case 'draft_request': return 'طلب صياغة';
      case 'internal': return 'مخاطبة داخلية';
      case 'outgoing': return 'مراسلة صادرة';
      case 'incoming': return 'مراسلة واردة';
      case 'circular': return 'تعميم';
      default: return type;
    }
  }
}
