import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:firebase_auth/firebase_auth.dart';

class ArchiveService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String universityPrefix = 'ج س/';

  Future<void> _requireAdmin() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('المستخدم غير مسجل الدخول');
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists || doc.data()?['role'] != 'admin') {
      throw Exception('ليس لديك صلاحية لإجراء هذه العملية. (مطلوب صلاحية مدير نظام)');
    }
  }

  /// تأكد من وجود ملفي "الوارد" و "الصادر" للمستخدم/الجهة.
  /// يتم ربط الملفات بمعرف الجهة (College أو Department) وليس المستخدم شخصياً،
  /// لكي يبقى الأرشيف للجهة حتى لو تغير العميد.
  Future<void> ensureDefaultFoldersExist({
    required String entityId, // college_id or dept_id
    required String entityType, // 'college' or 'department'
  }) async {
    final query = await _firestore
        .collection('archive_folders')
        .where('entity_id', isEqualTo: entityId)
        .where('is_default', isEqualTo: true)
        .get();

    if (query.docs.isEmpty) {
      // Create Default Outgoing Folder
      final outgoingDoc = _firestore.collection('archive_folders').doc();
      await outgoingDoc.set({
        'folder_id': outgoingDoc.id,
        'entity_id': entityId,
        'entity_type': entityType,
        'folder_name': 'ملف الصادر',
        'folder_number': 1,
        'current_sequence': 0,
        'is_default': true,
        'folder_type': 'outgoing', // outgoing or incoming
        'created_at': FieldValue.serverTimestamp(),
      });

      // Create Default Incoming Folder
      final incomingDoc = _firestore.collection('archive_folders').doc();
      await incomingDoc.set({
        'folder_id': incomingDoc.id,
        'entity_id': entityId,
        'entity_type': entityType,
        'folder_name': 'ملف الوارد',
        'folder_number': 2,
        'current_sequence': 0,
        'is_default': true,
        'folder_type': 'incoming',
        'created_at': FieldValue.serverTimestamp(),
      });

      // Create Default External Incoming Folder
      final externalDoc = _firestore.collection('archive_folders').doc();
      await externalDoc.set({
        'folder_id': externalDoc.id,
        'entity_id': entityId,
        'entity_type': entityType,
        'folder_name': 'ملف الوارد الخارجي',
        'folder_number': 3,
        'current_sequence': 0,
        'is_default': true,
        'folder_type': 'external_incoming',
        'created_at': FieldValue.serverTimestamp(),
      });
      debugPrint('تم إنشاء ملفات الأرشيف الافتراضية (صادر + وارد + وارد خارجي) للجهة: $entityId');
    } else {
      // التأكد من وجود ملف الوارد الخارجي (للجهات الموجودة مسبقاً)
      final hasExternal = query.docs.any((doc) {
        final d = doc.data();
        return d['folder_type'] == 'external_incoming';
      });
      if (!hasExternal) {
        final externalDoc = _firestore.collection('archive_folders').doc();
        await externalDoc.set({
          'folder_id': externalDoc.id,
          'entity_id': entityId,
          'entity_type': entityType,
          'folder_name': 'ملف الوارد الخارجي',
          'folder_number': 3,
          'current_sequence': 0,
          'is_default': true,
          'folder_type': 'external_incoming',
          'created_at': FieldValue.serverTimestamp(),
        });
        debugPrint('تم إنشاء ملف الوارد الخارجي المفقود للجهة: $entityId');
      }
    }
  }

  /// يولد رقم مرجع جديد بناءً على الكلية/القسم والملف المختار
  Future<String> generateReferenceNumber({
    required String folderId,
    required String entityCode, // e.g., 'ك ح'
  }) async {
    try {
      final folderRef = _firestore.collection('archive_folders').doc(folderId);

      // استخدام Transactions الذرية لضمان عدم تصادم الأرقام المرجعية (Atomic Operation)
      final String referenceNumber = await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(folderRef);
        
        if (!snapshot.exists) {
          throw Exception('الملف غير موجود في الأرشيف!');
        }

        final data = snapshot.data()!;
        int currentSequence = (data['current_sequence'] ?? 0) as int;
        final int folderNumber = (data['folder_number'] ?? 1) as int;
        final int lastSequenceYear = (data['last_sequence_year'] ?? DateTime.now().year) as int;

        final currentYear = DateTime.now().year;

        if (currentYear > lastSequenceYear) {
          currentSequence = 0;
        }

        final newSequence = currentSequence + 1;

        transaction.update(folderRef, {
          'current_sequence': newSequence,
          'last_sequence_year': currentYear,
        });

        return '$universityPrefix$entityCode/$newSequence/$folderNumber';
      });

      return referenceNumber;
    } catch (e) {
      debugPrint('خطأ في توليد المرجع: $e');
      rethrow;
    }
  }

  /// استرجاع ملفات الأرشيف لجهة معينة
  Stream<QuerySnapshot> getFoldersForEntity(String entityId) {
    if (_auth.currentUser == null) return const Stream.empty();
    return _firestore
        .collection('archive_folders')
        .where('entity_id', isEqualTo: entityId)
        .snapshots();
  }

  /// إضافة ملف مخصص جديد من قبل الأدمن
  Future<void> addCustomFolder({
    required String entityId,
    required String entityType,
    required String folderName,
    required int folderNumber,
  }) async {
    await _requireAdmin();
    final doc = _firestore.collection('archive_folders').doc();
    await doc.set({
      'folder_id': doc.id,
      'entity_id': entityId,
      'entity_type': entityType,
      'folder_name': folderName,
      'folder_number': folderNumber,
      'current_sequence': 0,
      'is_default': false,
      'folder_type': 'custom',
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  /// دالة لمعرفة معرّف "ملف الوارد" لجهة معينة (المستقبل) لكي يتم حفظ الخطاب فيه تلقائياً
  Future<String?> getIncomingFolderId(String entityId) async {
    final query = await _firestore
        .collection('archive_folders')
        .where('entity_id', isEqualTo: entityId)
        .where('folder_type', isEqualTo: 'incoming')
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return query.docs.first.id;
    }
    return null;
  }

  /// دالة لمعرفة معرّف "ملف الوارد الخارجي" لجهة معينة
  Future<String?> getExternalIncomingFolderId(String entityId) async {
    final query = await _firestore
        .collection('archive_folders')
        .where('entity_id', isEqualTo: entityId)
        .where('folder_type', isEqualTo: 'external_incoming')
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return query.docs.first.id;
    }
    return null;
  }

  // =====================================================
  // دوال الإدارة المتقدمة (Enterprise Archive Management)
  // =====================================================

  /// إعادة تسمية مجلد أرشيف
  Future<void> renameFolder(String folderId, String newName) async {
    await _requireAdmin();
    await _firestore.collection('archive_folders').doc(folderId).update({
      'folder_name': newName,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// تعديل رقم المجلد (يؤثر على الرقم المرجعي)
  Future<void> updateFolderNumber(String folderId, int newNumber) async {
    await _requireAdmin();
    await _firestore.collection('archive_folders').doc(folderId).update({
      'folder_number': newNumber,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// إعادة تعيين العداد التسلسلي لمجلد (يبدأ الترقيم من 1)
  Future<void> resetFolderSequence(String folderId) async {
    await _requireAdmin();
    await _firestore.collection('archive_folders').doc(folderId).update({
      'current_sequence': 0,
      'last_sequence_year': DateTime.now().year,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// عدد المراسلات داخل مجلد معين
  Future<int> getFolderDocumentCount(String folderId) async {
    // البحث في حقلي sender و receiver لأن المراسلة قد تكون في أحدهما
    final senderQuery = await _firestore
        .collection('communications')
        .where('sender_archive_folder_id', isEqualTo: folderId)
        .count()
        .get();

    final receiverQuery = await _firestore
        .collection('communications')
        .where('receiver_archive_folder_id', isEqualTo: folderId)
        .count()
        .get();

    return (senderQuery.count ?? 0) + (receiverQuery.count ?? 0);
  }

  /// إحصائيات شاملة للأرشيف
  Future<Map<String, int>> getArchiveStatistics() async {
    await _requireAdmin();
    final foldersSnap = await _firestore.collection('archive_folders').get();
    final commsSnap = await _firestore
        .collection('communications')
        .where('status', isEqualTo: 'archived')
        .count()
        .get();
    final collegesSnap = await _firestore.collection('colleges').count().get();
    final deptsSnap = await _firestore.collection('departments').count().get();

    return {
      'total_folders': foldersSnap.docs.length,
      'total_archived': commsSnap.count ?? 0,
      'total_colleges': collegesSnap.count ?? 0,
      'total_departments': deptsSnap.count ?? 0,
    };
  }

  /// نقل مراسلة من مجلد إلى آخر
  Future<void> moveCommunicationToFolder({
    required String commId,
    required String newFolderId,
    required String fieldName, // 'sender_archive_folder_id' or 'receiver_archive_folder_id'
  }) async {
    await _requireAdmin();
    if (fieldName != 'sender_archive_folder_id' && fieldName != 'receiver_archive_folder_id') {
      throw Exception('اسم حقل غير صالح');
    }
    await _firestore.collection('communications').doc(commId).update({
      fieldName: newFolderId,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
}
