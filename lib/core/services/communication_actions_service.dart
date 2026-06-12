import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'routing_service.dart';

/// =====================================================
/// CommunicationActionsService — إجراءات المراسلات
/// =====================================================
/// مسؤول عن جميع العمليات التي تتم على مراسلة موجودة:
/// الإحالة، الرفض، الأرشفة، الرد، إعادة المسودة، إلخ.
///
/// كل إجراء يقوم بـ 3 أشياء:
///  1. التحقق من هوية المستخدم الحالي
///  2. تحديث حالة المراسلة + الحقول المطلوبة
///  3. تسجيل الإجراء في سجل التتبع (tracking subcollection)
/// =====================================================
class CommunicationActionsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final RoutingService _routing = RoutingService();

  // =====================================================
  // المساعدات الداخلية (Private Helpers)
  // =====================================================

  /// يجلب المستخدم الحالي أو يرمي استثناء واضح
  User _requireCurrentUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('غير مسجل الدخول. يرجى تسجيل الدخول مرة أخرى.');
    }
    return user;
  }

  /// يجلب اسم المستخدم الحالي من قاعدة البيانات
  Future<String> _getCurrentUserName(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return (doc.data()?['full_name'] ?? 'مستخدم').toString();
    } catch (e) {
      debugPrint('خطأ في جلب اسم المستخدم: $e');
      return 'مستخدم';
    }
  }

  /// التحقق من أن المستخدم الحالي هو المستلم الفعلي أو مفوض له
  Future<void> _requireCurrentRecipient(String commId, String uid) async {
    final doc = await _firestore.collection('communications').doc(commId).get();
    if (!doc.exists) throw Exception('المراسلة غير موجودة');
    
    final currentRcvId = doc.data()?['current_rcv_id'] as String?;
    if (currentRcvId != uid) {
      // السماح في حال كانت المراسلة تعميماً (is_circular == true)
      final isCircular = doc.data()?['is_circular'] == true;
      if (!isCircular) {
        throw Exception('غير مصرح لك باتخاذ إجراء على هذه المراسلة. لست المستلم الحالي.');
      }
    }
  }

  /// يسجل إجراء في سجل التتبع (Tracking Subcollection)
  Future<void> _addTrackingEntry({
    required String commId,
    required String action,
    required String fromId,
    required String fromName,
    required String toId,
    required String toName,
    required String fromStatus,
    required String toStatus,
    required String comment,
  }) async {
    await _firestore
        .collection('communications')
        .doc(commId)
        .collection('tracking')
        .add({
      'action': action,
      'from_id': fromId,
      'from_name': fromName,
      'to_id': toId,
      'to_name': toName,
      'from_status': fromStatus,
      'to_status': toStatus,
      'comment': comment,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // =====================================================
  // القراءة والعلم بالاستلام
  // =====================================================

  /// تعليم المراسلة كمقروءة
  Future<void> markAsReadIfNeeded(String commId) async {
    final user = _requireCurrentUser();
    
    final doc = await _firestore.collection('communications').doc(commId).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final isCircular = data['is_circular'] == true;
    
    if (isCircular) {
      // It's a circular, do implicit tracking only once
      final trackingQuery = await _firestore.collection('communications')
          .doc(commId).collection('tracking')
          .where('action', isEqualTo: 'acknowledge_circular')
          .where('from_id', isEqualTo: user.uid)
          .limit(1)
          .get();
          
      if (trackingQuery.docs.isEmpty) {
        await acknowledgeCircularRead(commId);
      }
      return;
    }

    // Normal communication
    await _requireCurrentRecipient(commId, user.uid);

    if (data['is_read'] == true) return;

    await _firestore.collection('communications').doc(commId).update({
      'is_read': true,
      'read_at': FieldValue.serverTimestamp(),
    });

    final userName = await _getCurrentUserName(user.uid);
    await _addTrackingEntry(
      commId: commId,
      action: 'read',
      fromId: user.uid,
      fromName: userName,
      toId: '',
      toName: '',
      fromStatus: 'sent',
      toStatus: 'read',
      comment: 'تم فتح وقراءة المراسلة',
    );
  }

  // =====================================================
  // الإحالة الداخلية (Forward)
  // =====================================================

  /// إحالة مراسلة داخلية لمستخدم آخر
  /// يُحدّث current_rcv_id لضمان ظهور المراسلة في بريد المستلم الجديد
  Future<void> forwardCommunication(
    String commId,
    String targetUserId,
    String targetName,
    String targetDeptId,
    String comment,
  ) async {
    final user = _requireCurrentUser();
    final userName = await _getCurrentUserName(user.uid);
    await _requireCurrentRecipient(commId, user.uid);

    // جلب الحالة الحالية قبل التحديث
    final doc = await _firestore.collection('communications').doc(commId).get();
    final oldStatus = (doc.data()?['status'] ?? '').toString();

    final routingResult = await _routing.resolveRecipient(
      senderId: user.uid,
      selectedTargetId: targetUserId,
    );

    await _firestore.collection('communications').doc(commId).update({
      'target_id': targetUserId,
      'target_name': targetName,
      'target_dept_id': targetDeptId,
      'current_dept_id': targetDeptId,
      'current_rcv_id': routingResult.actualRecipientId,
      'manager_notes': comment,
      'status': routingResult.status,
      'is_read': false, // إعادة تعيين حالة القراءة للمستلم الجديد
      'updated_at': FieldValue.serverTimestamp(),
      'last_action_at': FieldValue.serverTimestamp(),
    });

    await _addTrackingEntry(
      commId: commId,
      action: 'forward',
      fromId: user.uid,
      fromName: userName,
      toId: targetUserId,
      toName: targetName,
      fromStatus: oldStatus,
      toStatus: 'forwarded',
      comment: comment.isNotEmpty ? comment : 'تمت إحالة المراسلة',
    );
  }

  // =====================================================
  // إحالة المراسلات الخارجية
  // =====================================================

  /// إحالة مراسلة خارجية لمستخدم داخلي
  Future<void> forwardExternalCommunication(
    String commId,
    String targetUserId,
    String targetName,
    String targetDeptId,
    String comment,
  ) async {
    final user = _requireCurrentUser();
    final userName = await _getCurrentUserName(user.uid);
    await _requireCurrentRecipient(commId, user.uid);

    final doc = await _firestore.collection('communications').doc(commId).get();
    final oldStatus = (doc.data()?['status'] ?? '').toString();

    await _firestore.collection('communications').doc(commId).update({
      'target_id': targetUserId,
      'target_name': targetName,
      'target_dept_id': targetDeptId,
      'current_dept_id': targetDeptId,
      'current_rcv_id': targetUserId, // ✅ الإصلاح الحرج
      'manager_notes': comment,
      'status': 'forwarded',
      'is_read': false,
      'updated_at': FieldValue.serverTimestamp(),
      'last_action_at': FieldValue.serverTimestamp(),
    });

    await _addTrackingEntry(
      commId: commId,
      action: 'forward_external',
      fromId: user.uid,
      fromName: userName,
      toId: targetUserId,
      toName: targetName,
      fromStatus: oldStatus,
      toStatus: 'forwarded',
      comment: comment.isNotEmpty ? comment : 'تمت إحالة المراسلة الخارجية',
    );
  }

  // =====================================================
  // تعميم المراسلات الخارجية
  // =====================================================

  /// تحويل مراسلة خارجية إلى تعميم داخلي
  Future<void> circulateExternalCommunication(
    String commId,
    String targetGroup,
    String comment,
  ) async {
    final user = _requireCurrentUser();
    final userName = await _getCurrentUserName(user.uid);
    await _requireCurrentRecipient(commId, user.uid);

    final doc = await _firestore.collection('communications').doc(commId).get();
    final oldStatus = (doc.data()?['status'] ?? '').toString();

    await _firestore.collection('communications').doc(commId).update({
      'target_group': targetGroup,
      'manager_notes': comment,
      'status': 'published',
      'is_circular': true,
      'published_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'last_action_at': FieldValue.serverTimestamp(),
    });

    await _addTrackingEntry(
      commId: commId,
      action: 'circulate_external',
      fromId: user.uid,
      fromName: userName,
      toId: 'all',
      toName: 'المجموعة المستهدفة: $targetGroup',
      fromStatus: oldStatus,
      toStatus: 'published',
      comment: comment.isNotEmpty ? comment : 'تم تعميم المراسلة الخارجية',
    );
  }

  // =====================================================
  // الرد على المراسلات
  // =====================================================

  /// الرد على مراسلة — يُعيد المراسلة للمرسل الأصلي مع الملاحظات
  Future<void> replyToCommunication(String commId, String replyText) async {
    final user = _requireCurrentUser();
    final userName = await _getCurrentUserName(user.uid);
    await _requireCurrentRecipient(commId, user.uid);

    final doc = await _firestore.collection('communications').doc(commId).get();
    if (!doc.exists) throw Exception('المراسلة غير موجودة');

    final data = doc.data()!;
    final oldStatus = (data['status'] ?? '').toString();
    final senderId = (data['sender_id'] ?? '').toString();
    final senderName = (data['sender_name'] ?? '').toString();

    await _firestore.collection('communications').doc(commId).update({
      'manager_notes': replyText,
      'status': 'replied',
      'current_rcv_id': senderId, // ✅ إعادة المراسلة للمرسل الأصلي
      'is_read': false,
      'updated_at': FieldValue.serverTimestamp(),
      'last_action_at': FieldValue.serverTimestamp(),
    });

    await _addTrackingEntry(
      commId: commId,
      action: 'reply',
      fromId: user.uid,
      fromName: userName,
      toId: senderId,
      toName: senderName,
      fromStatus: oldStatus,
      toStatus: 'replied',
      comment: replyText,
    );
  }

  // =====================================================
  // الرفض
  // =====================================================

  /// رفض مراسلة مع ذكر السبب — يُعيدها للمرسل
  Future<void> rejectCommunication(String commId, String reason) async {
    final user = _requireCurrentUser();
    final userName = await _getCurrentUserName(user.uid);
    await _requireCurrentRecipient(commId, user.uid);

    final doc = await _firestore.collection('communications').doc(commId).get();
    if (!doc.exists) throw Exception('المراسلة غير موجودة');

    final data = doc.data()!;
    final oldStatus = (data['status'] ?? '').toString();
    final senderId = (data['sender_id'] ?? '').toString();
    final senderName = (data['sender_name'] ?? '').toString();

    await _firestore.collection('communications').doc(commId).update({
      'status': 'rejected',
      'manager_notes': reason,
      'current_rcv_id': senderId, // إعادة المراسلة المرفوضة للمرسل
      'is_read': false,
      'updated_at': FieldValue.serverTimestamp(),
      'last_action_at': FieldValue.serverTimestamp(),
    });

    await _addTrackingEntry(
      commId: commId,
      action: 'reject',
      fromId: user.uid,
      fromName: userName,
      toId: senderId,
      toName: senderName,
      fromStatus: oldStatus,
      toStatus: 'rejected',
      comment: 'تم رفض المراسلة: $reason',
    );
  }

  // =====================================================
  // الأرشفة
  // =====================================================

  /// أرشفة مراسلة
  Future<void> archiveCommunication(String commId) async {
    final user = _requireCurrentUser();
    final userName = await _getCurrentUserName(user.uid);
    await _requireCurrentRecipient(commId, user.uid);

    final doc = await _firestore.collection('communications').doc(commId).get();
    final oldStatus = (doc.data()?['status'] ?? '').toString();

    await _firestore.collection('communications').doc(commId).update({
      'status': 'مؤرشف',
      'archived_at': FieldValue.serverTimestamp(),
      'archived_by': user.uid,
      'archived_by_name': userName,
      'updated_at': FieldValue.serverTimestamp(),
      'last_action_at': FieldValue.serverTimestamp(),
    });

    await _addTrackingEntry(
      commId: commId,
      action: 'archive',
      fromId: user.uid,
      fromName: userName,
      toId: '',
      toName: '',
      fromStatus: oldStatus,
      toStatus: 'مؤرشف',
      comment: 'تمت أرشفة المراسلة',
    );
  }

  // =====================================================
  // إعادة المسودة للسكرتير
  // =====================================================

  /// إعادة مسودة خطاب للسكرتير لإعادة التحرير
  Future<void> returnDraftToSecretary(String commId, String managerNotes) async {
    final user = _requireCurrentUser();
    final userName = await _getCurrentUserName(user.uid);
    await _requireCurrentRecipient(commId, user.uid);

    final doc = await _firestore.collection('communications').doc(commId).get();
    if (!doc.exists) throw Exception('المراسلة غير موجودة');

    final data = doc.data()!;
    final oldStatus = (data['status'] ?? '').toString();

    // البحث عن السكرتير (المرسل الأصلي للمسودة)
    final originalSenderId = (data['sender_id'] ?? '').toString();
    final originalSenderName = (data['sender_name'] ?? '').toString();

    await _firestore.collection('communications').doc(commId).update({
      'status': 'returned_for_edit',
      'manager_notes': managerNotes,
      'current_rcv_id': originalSenderId, // إعادة للسكرتير
      'is_read': false,
      'updated_at': FieldValue.serverTimestamp(),
      'last_action_at': FieldValue.serverTimestamp(),
    });

    await _addTrackingEntry(
      commId: commId,
      action: 'return_to_secretary',
      fromId: user.uid,
      fromName: userName,
      toId: originalSenderId,
      toName: originalSenderName,
      fromStatus: oldStatus,
      toStatus: 'returned_for_edit',
      comment: 'تمت إعادة المسودة للتعديل: $managerNotes',
    );
  }

  // =====================================================
  // العلم بالاستلام (التعاميم والمراسلات الخارجية)
  // =====================================================

  /// العلم باستلام وقراءة تعميم
  Future<void> acknowledgeCircularRead(String commId) async {
    final user = _requireCurrentUser();
    final userName = await _getCurrentUserName(user.uid);
    await _requireCurrentRecipient(commId, user.uid);

    await _firestore.collection('communications').doc(commId).update({
      'updated_at': FieldValue.serverTimestamp(),
    });

    await _addTrackingEntry(
      commId: commId,
      action: 'acknowledge_circular',
      fromId: user.uid,
      fromName: userName,
      toId: '',
      toName: '',
      fromStatus: 'published',
      toStatus: 'acknowledged',
      comment: 'تم العلم بالتعميم',
    );
  }

  /// تعليم مراسلة خارجية كمراجعة
  Future<void> markExternalAsReviewed(String commId) async {
    final user = _requireCurrentUser();
    final userName = await _getCurrentUserName(user.uid);
    await _requireCurrentRecipient(commId, user.uid);

    await _firestore.collection('communications').doc(commId).update({
      'status': 'external_reviewed',
      'is_read_by_dean': true,
      'updated_at': FieldValue.serverTimestamp(),
      'last_action_at': FieldValue.serverTimestamp(),
    });

    await _addTrackingEntry(
      commId: commId,
      action: 'review_external',
      fromId: user.uid,
      fromName: userName,
      toId: '',
      toName: '',
      fromStatus: 'sent',
      toStatus: 'external_reviewed',
      comment: 'تمت مراجعة المراسلة الخارجية',
    );
  }

  /// العلم باستلام مراسلة خارجية
  Future<void> acknowledgeExternalCommunication(String commId) async {
    final user = _requireCurrentUser();
    final userName = await _getCurrentUserName(user.uid);
    
    await _requireCurrentRecipient(commId, user.uid);

    await _firestore.collection('communications').doc(commId).update({
      'status': 'acknowledged',
      'is_read_by_dean': true,
      'updated_at': FieldValue.serverTimestamp(),
      'last_action_at': FieldValue.serverTimestamp(),
    });

    await _addTrackingEntry(
      commId: commId,
      action: 'acknowledge_external',
      fromId: user.uid,
      fromName: userName,
      toId: '',
      toName: '',
      fromStatus: 'sent',
      toStatus: 'acknowledged',
      comment: 'تم العلم بالمراسلة الخارجية',
    );
  }


}
