import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'archive_service.dart';
import 'docx_generator_service.dart';
import 'routing_service.dart';
import 'communication_actions_service.dart';
import 'notification_service.dart';

class CommunicationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ArchiveService _archiveService = ArchiveService();

  final DocxGeneratorService docxGenerator = DocxGeneratorService();
  final RoutingService routing = RoutingService();
  final CommunicationActionsService actions = CommunicationActionsService();

  Future<List<DocumentSnapshot>> fetchAllowedTargets() => routing.fetchAllowedTargets();

  Future<void> markAsReadIfNeeded(String commId) => actions.markAsReadIfNeeded(commId);
  Future<void> rejectCommunication(String commId, String reason) => actions.rejectCommunication(commId, reason);
  Future<void> acknowledgeCircularRead(String commId) => actions.acknowledgeCircularRead(commId);
  Future<void> archiveCommunication(String commId) => actions.archiveCommunication(commId);

  Future<void> markExternalAsReviewed(String commId) => actions.markExternalAsReviewed(commId);
  Future<void> forwardExternalCommunication(String commId, String targetUserId, String targetName, String targetDeptId, String comment) => actions.forwardExternalCommunication(commId, targetUserId, targetName, targetDeptId, comment);
  Future<void> circulateExternalCommunication(String commId, String targetGroup, String comment) => actions.circulateExternalCommunication(commId, targetGroup, comment);
  Future<void> acknowledgeExternalCommunication(String commId) => actions.acknowledgeExternalCommunication(commId);
  Future<void> forwardCommunication(String commId, String targetUserId, String targetName, String targetDeptId, String comment) => actions.forwardCommunication(commId, targetUserId, targetName, targetDeptId, comment);
  Future<void> replyToCommunication(String commId, String replyText) => actions.replyToCommunication(commId, replyText);
  Future<void> returnDraftToSecretary(String commId, String managerNotes) => actions.returnDraftToSecretary(commId, managerNotes);

  Future<void> requestDraftFromSecretary(String subject, String instructions, {String? overrideSenderTitle}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw 'غير مسجل الدخول';

    final userDoc = await _firestore.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};
    final myTitle = overrideSenderTitle ?? userData['administrative_title'] ?? 'staff';
    
    final deanRoles = ['dean', 'deputy_dean', 'center_director', 'admin_director', 'university_president', 'university_vp', 'general_secretary'];
    if (!deanRoles.contains(myTitle)) {
      throw 'ليس لديك الصلاحية لطلب صياغة خطاب. هذه الخاصية متاحة للمدراء فقط.';
    }

    final myName = userData['full_name'] ?? 'مجهول';

    final secQuery = await _firestore.collection('users')
        .where('manager_id', isEqualTo: uid)
        .where('administrative_title', whereIn: ['secretary', 'executive_secretary'])
        .limit(1)
        .get();

    if (secQuery.docs.isEmpty) {
      throw 'لم يتم العثور على سكرتير مرتبط بحسابك لإرسال الطلب إليه.';
    }

    final secId = secQuery.docs.first.id;
    final secName = secQuery.docs.first.data()['full_name'] ?? 'سكرتير';

    final docRef = _firestore.collection('communications').doc();
    await docRef.set({
      'id': docRef.id,
      'sender_id': uid,
      'sender_name': myName,
      'sender_title': myTitle,
      'target_id': secId,
      'target_name': secName,
      'current_rcv_id': secId,
      'subject': subject,
      'body_text': instructions,
      'status': 'draft_requested',
      'type': 'draft_request',
      'priority': 'normal',
      'security_level': 'normal',
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'history': [
        {
          'action': 'draft_requested',
          'actor_id': uid,
          'actor_name': myName,
          'timestamp': DateTime.now().toIso8601String(),
          'notes': 'طلب صياغة خطاب: $instructions'
        }
      ]
    });

    // ✅ إرسال تنبيه للسكرتير بطلب مسودة
    await NotificationService().sendNotification(
      targetUserId: secId,
      title: 'طلب صياغة خطاب',
      body: 'طلب منك $myName صياغة خطاب بموضوع: $subject',
      type: 'draft_request',
      relatedDocId: docRef.id,
    );
  }

  Future<void> addWallReminder(String commId, String commTitle, String noteText) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('المستخدم غير مسجل الدخول');

    await _firestore.collection('user_reminders').add({
      'user_id': user.uid,
      'communication_id': commId,
      'communication_title': commTitle,
      'note_text': noteText,
      'is_done': false,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getUserRemindersStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    // إزالة orderBy لتجنب الحاجة إلى إنشاء Composite Index في فايربيس
    // سيتم الترتيب لاحقاً في الواجهة إذا لزم الأمر، أو الاعتماد على جلب الوثائق بدون ترتيب
    return _firestore
        .collection('user_reminders')
        .where('user_id', isEqualTo: user.uid)
        .where('is_done', isEqualTo: false)
        .snapshots();
  }

  Future<void> deleteWallReminder(String reminderId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('المستخدم غير مسجل الدخول');

    final doc = await _firestore.collection('user_reminders').doc(reminderId).get();
    if (!doc.exists) throw Exception('التذكير غير موجود');
    if (doc.data()?['user_id'] != user.uid) {
      throw Exception('ليس لديك صلاحية لحذف هذا التذكير');
    }

    await _firestore.collection('user_reminders').doc(reminderId).update({
      'is_done': true,
    });
  }

  Future<void> sendCommunication({
    required String subject,
    required String bodyText,
    required String selectedType,
    required String selectedPriority,
    required String selectedTemplateId,
    required String selectedTargetId,
    required String selectedTargetName,
    required String selectedTargetDeptId,
    required String enteredPin,
    List<File>? attachedFiles,
    bool isCircular = false,
    String? targetGroup,
    String? draftId,
    List<Map<String, dynamic>>? existingAttachments,
    String? parentCommId,
    String? parentRefNumber,
    String securityLevel = 'normal',
    bool isExternalOutgoing = false,
    String? overrideSenderTitle,
    String? overrideSenderDeptId,
    String? overrideSenderCollegeId,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw 'لا يوجد مستخدم مسجل دخول';

    final userDoc = await _firestore.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};

    final dbPin = userData['pin'] ?? userData['pin_code'];
    final enteredHashed = sha256.convert(utf8.encode(enteredPin)).toString();

    if (dbPin != null && dbPin.toString().trim().isNotEmpty) {
      final dbPinStr = dbPin.toString().trim();
      bool isMatch = false;
      if (dbPinStr.length == 64) {
        isMatch = (enteredHashed == dbPinStr);
      } else {
        isMatch = (enteredPin == dbPinStr);
        if (isMatch) {
          // Upgrade to hashed PIN
          await userDoc.reference.update({'pin': enteredHashed});
        }
      }
      
      if (!isMatch) {
        throw 'الرمز السري (PIN) غير صحيح';
      }
    } else {
      throw 'لم يتم إعداد الرمز السري لهذا الحساب';
    }

    final isDraft = userData['administrative_title'] == 'secretary';
    String generatedUrl = '';
    String refNumber = '';
    String senderSealUrl = '';
    String effectiveSenderName = userData['full_name'] ?? 'موظف';
    String? signatureUrl = userData['signature_url'];
    String senderFolderId = '';

    if (isDraft && userData['manager_id'] != null) {
      try {
        final managerDoc = await _firestore.collection('users').doc(userData['manager_id']).get();
        if (managerDoc.exists) {
          effectiveSenderName = managerDoc.data()?['full_name'] ?? effectiveSenderName;
          signatureUrl = managerDoc.data()?['signature_url'];
        }
      } catch (e) {
        debugPrint('Error fetching manager data for draft: $e');
      }
    }

    if (!isDraft) {
      String entityId = overrideSenderDeptId ?? userData['dept_id'] ?? '';
      String entityType = 'department';
      String entityCode = 'بدون';

      final senderTitleTemp = overrideSenderTitle ?? userData['administrative_title'] ?? 'staff';

      if (entityId.isEmpty || senderTitleTemp == 'dean') {
        entityId = overrideSenderCollegeId ?? userData['college_id'] ?? '';
        entityType = 'college';
        if (entityId.isNotEmpty) {
          final colDoc = await _firestore.collection('colleges').doc(entityId).get();
          final rawCollegeCode = colDoc.data()?['entity_code'] ?? '';
          entityCode = 'ك $rawCollegeCode'.trim();
        }
      } else {
        final deptDoc = await _firestore.collection('departments').doc(entityId).get();
        entityCode = deptDoc.data()?['dept_code'] ?? 'ق';
      }

      if (entityId.isNotEmpty) {
        await _archiveService.ensureDefaultFoldersExist(entityId: entityId, entityType: entityType);
      }

      final outgoingQuery = await _firestore
          .collection('archive_folders')
          .where('entity_id', isEqualTo: entityId)
          .where('folder_type', isEqualTo: 'outgoing')
          .limit(1)
          .get();

      if (outgoingQuery.docs.isNotEmpty) {
        senderFolderId = outgoingQuery.docs.first.id;
        final senderTitle = overrideSenderTitle ?? userData['administrative_title'] ?? 'staff';
        final senderCollegeId = overrideSenderCollegeId ?? userData['college_id'] ?? '';

        String receiverCollegeId = '';
        final targetUserDoc = await _firestore.collection('users').doc(selectedTargetId).get();
        if (targetUserDoc.exists) {
          receiverCollegeId = targetUserDoc.data()?['college_id'] ?? '';
        }

        final isExternalToCollege = senderCollegeId != receiverCollegeId;

        if ((senderTitle == 'dean' || senderTitle == 'university_president') && isExternalToCollege) {
          refNumber = await _archiveService.generateReferenceNumber(folderId: senderFolderId, entityCode: entityCode);

          if (senderCollegeId.isNotEmpty) {
            final senderColDoc = await _firestore.collection('colleges').doc(senderCollegeId).get();
            if (senderColDoc.exists) {
              senderSealUrl = senderColDoc.data()?['seal_url'] ?? '';
            }
          }
        }
      }

      generatedUrl = await docxGenerator.generateAndUploadDocx(
        templateId: selectedTemplateId,
        subject: subject,
        bodyText: bodyText,
        senderName: effectiveSenderName,
        targetName: selectedTargetName,
        refNumber: refNumber,
        senderSealUrl: senderSealUrl,
        signatureUrl: signatureUrl,
      );
    }

    String receiverEntityId = selectedTargetDeptId;
    String receiverEntityType = 'department';

    if (receiverEntityId.isEmpty || receiverEntityId == 'group') {
      try {
        final targetUserDoc = await _firestore.collection('users').doc(selectedTargetId).get();
        if (targetUserDoc.exists) {
          receiverEntityId = targetUserDoc.data()?['college_id'] ?? '';
          receiverEntityType = 'college';
        }
      } catch (e) {
        debugPrint('Error fetching target user college: $e');
      }
    }

    if (receiverEntityId.isEmpty) {
      try {
        final allowedQuery = await _firestore.collection('allowed_users').where('dept_ids', arrayContains: selectedTargetDeptId).limit(1).get();
        if (allowedQuery.docs.isNotEmpty) {
        } else {
          final emailQuery = await _firestore.collection('allowed_users').doc(selectedTargetId).get();
          if (emailQuery.exists) {
            receiverEntityId = emailQuery.data()?['college_id'] ?? '';
            receiverEntityType = 'college';
          }
        }
      } catch (e) {
        debugPrint('Error fetching from allowed_users: $e');
      }
    }

    String? receiverFolderId;
    if (receiverEntityId.isNotEmpty && receiverEntityId != 'group') {
      await _archiveService.ensureDefaultFoldersExist(entityId: receiverEntityId, entityType: receiverEntityType);
      receiverFolderId = await _archiveService.getIncomingFolderId(receiverEntityId);
    }

    final batch = _firestore.batch();
    final commRef = draftId != null ? _firestore.collection('communications').doc(draftId) : _firestore.collection('communications').doc();

    List<Map<String, dynamic>> uploadedAttachments = existingAttachments != null ? List.from(existingAttachments) : [];
    if (attachedFiles != null && attachedFiles.isNotEmpty) {
      for (var file in attachedFiles) {
        final String origName = p.basename(file.path);
        final String safeName = '${DateTime.now().millisecondsSinceEpoch}_$origName';
        final attPath = 'communications/attachments/${commRef.id}/$safeName';

        final attRef = _storage.ref().child(attPath);
        await attRef.putFile(file);
        final downloadUrl = await attRef.getDownloadURL();

        uploadedAttachments.add({
          'name': origName,
          'url': downloadUrl,
          'size': await file.length(),
          'extension': p.extension(file.path).replaceAll('.', ''),
        });
      }
    }

    final String rawData = '${commRef.id}-$subject-$bodyText-$uid-${DateTime.now().millisecondsSinceEpoch}';
    // ignore: non_constant_identifier_names
    final hmacObj = Hmac(sha256, utf8.encode(enteredPin));
    final String digitalSignature = hmacObj.convert(utf8.encode(rawData)).toString();

    String actualRcvId = selectedTargetId;
    String actualStatus = 'sent';

    if (securityLevel == 'top_secret' || selectedPriority == 'highly_confidential') {
      actualRcvId = selectedTargetId;
      actualStatus = 'sent';
    } else {
      final routingResult = await routing.resolveRecipient(
        senderId: uid,
        selectedTargetId: selectedTargetId,
      );
      actualRcvId = routingResult.actualRecipientId;
      actualStatus = routingResult.status;
    }

    if (isExternalOutgoing) {
      actualStatus = 'ready_for_dispatch';
      actualRcvId = 'external_entity';
    }

    final Map<String, dynamic> commData = {
      'comm_id': commRef.id,
      'type': selectedType,
      'subject': subject,
      'body': bodyText,
      'body_text': bodyText,
      'sender_id': uid,
      'sender_name': effectiveSenderName,
      'sender_dept_id': overrideSenderDeptId ?? userData['dept_id'] ?? '',
      'sender_title': overrideSenderTitle ?? userData['administrative_title'] ?? 'staff',
      'sender_college_id': overrideSenderCollegeId ?? userData['college_id'] ?? '',
      'target_id': selectedTargetId,
      'target_name': selectedTargetName,
      'current_rcv_id': actualRcvId,
      'target_dept_id': selectedTargetDeptId,
      'current_dept_id': selectedTargetDeptId,
      'is_circular': isCircular,
      'status': actualStatus,
      'priority': selectedPriority,
      'template_id': selectedTemplateId,
      'generated_docx_url': generatedUrl,
      'reference_number': refNumber,
      'sender_archive_folder_id': senderFolderId,
      'digital_signature': digitalSignature,
      'security_level': securityLevel,
      'sender_seal_url': senderSealUrl,
      'is_external_outgoing': isExternalOutgoing,
      if (draftId == null) 'created_at': FieldValue.serverTimestamp(),
      'sent_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'last_action_at': FieldValue.serverTimestamp(),
    };

    if (targetGroup != null) commData['target_group'] = targetGroup;
    if (receiverFolderId != null) {
      commData['receiver_archive_folder_id'] = receiverFolderId;
    }
    if (signatureUrl != null) commData['sender_signature_url'] = signatureUrl;
    if (parentCommId != null) commData['parent_comm_id'] = parentCommId;
    if (parentRefNumber != null) commData['parent_ref_number'] = parentRefNumber;
    if (uploadedAttachments.isNotEmpty) {
      commData['attachments'] = uploadedAttachments;
    }

    if (draftId != null) {
      batch.set(commRef, commData, SetOptions(merge: true));
    } else {
      batch.set(commRef, commData);
    }

    final trackingRef = commRef.collection('tracking').doc();
    batch.set(trackingRef, {
      'action': 'send',
      'from_id': uid,
      'to_id': selectedTargetId,
      'from_status': 'new',
      'to_status': 'sent',
      'timestamp': FieldValue.serverTimestamp(),
      'comment': 'تم إنشاء وإرسال المخاطبة عبر النظام',
      'verification_method': 'pin',
    });

    await batch.commit();

    if (!isCircular && actualRcvId.isNotEmpty && actualRcvId != 'external_entity') {
      String notifTitle = 'رسالة واردة جديدة';
      String notifBody = 'وصلتك رسالة جديدة من $effectiveSenderName بعنوان: $subject';
      
      if (actualStatus == 'pending') {
        notifTitle = 'مسودة مجهزة للاعتماد';
        notifBody = 'قام $effectiveSenderName بتجهيز مسودة ( $subject ) وهي بانتظار اعتمادك.';
      }

      await NotificationService().sendNotification(
        targetUserId: actualRcvId,
        title: notifTitle,
        body: notifBody,
        type: (securityLevel == 'top_secret' || selectedPriority == 'highly_confidential') ? 'urgent' : 'new_message',
        relatedDocId: commRef.id,
      );
    }
  }

  Future<String> _getCurrentUserName() async {
    final user = _auth.currentUser;
    if (user == null) return '';
    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data();
    return (data?['full_name'] ?? '').toString();
  }

  Future<void> approveCommunication(String commId) async {
    final user = _auth.currentUser;
    if (user == null) throw 'غير مسجل الدخول. يرجى تسجيل الدخول مرة أخرى.';
    final currentUserName = await _getCurrentUserName();
    final ref = _firestore.collection('communications').doc(commId);

    final doc = await ref.get();
    if (!doc.exists) throw 'المخاطبة غير موجودة';
    final data = doc.data() as Map<String, dynamic>;
    final oldStatus = (data['status'] ?? '').toString();

    if (data['current_rcv_id'] != user.uid) {
      throw 'غير مصرح لك باعتماد هذه المخاطبة.';
    }

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userDocData = userDoc.data() ?? {};

    final allowedTitles = ['dean', 'vice_dean', 'vice_dean_student', 'vice_dean_academic', 'vice_dean_postgraduate', 'center_director', 'vice_director', 'general_director', 'head_of_department', 'university_president', 'university_vp', 'general_secretary'];
    if (!allowedTitles.contains(userDocData['administrative_title'])) {
      throw 'غير مصرح لرتبتك الإدارية باعتماد المراسلات.';
    }

    final isCircular = data['is_circular'] == true;

    if (oldStatus == 'pending_approval') {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userDocData = userDoc.data() ?? {};

      final templateId = data['template_id'];
      String senderFolderId = '';
      String refNumber = '';
      String senderSealUrl = '';
      String? signatureUrl;

      String entityId = userDocData['college_id'] ?? '';
      String entityCode = 'بدون';
      if (entityId.isNotEmpty) {
        final colDoc = await _firestore.collection('colleges').doc(entityId).get();
        final rawCollegeCode = colDoc.data()?['entity_code'] ?? '';
        entityCode = 'ك $rawCollegeCode'.trim();
      }

      try {
        final outgoingQuery = await _firestore
            .collection('archive_folders')
            .where('entity_id', isEqualTo: entityId)
            .where('folder_type', isEqualTo: 'outgoing')
            .limit(1)
            .get();

        if (outgoingQuery.docs.isNotEmpty) {
          senderFolderId = outgoingQuery.docs.first.id;
          final senderCollegeId = userDocData['college_id'] ?? '';
          String receiverCollegeId = '';
          final targetUserDoc = await _firestore.collection('users').doc(data['target_id']).get();
          if (targetUserDoc.exists) {
            receiverCollegeId = targetUserDoc.data()?['college_id'] ?? '';
          }
          final isExternalToCollege = senderCollegeId != receiverCollegeId;

          if (isExternalToCollege) {
            refNumber = await _archiveService.generateReferenceNumber(
              folderId: senderFolderId,
              entityCode: entityCode,
            );
            if (senderCollegeId.isNotEmpty) {
              final senderColDoc = await _firestore.collection('colleges').doc(senderCollegeId).get();
              if (senderColDoc.exists) {
                senderSealUrl = senderColDoc.data()?['seal_url'] ?? '';
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error getting folder or generating ref: $e');
      }

      signatureUrl = userDocData['signature_url'];

      if (templateId != null && templateId.toString().isNotEmpty) {
        try {
          final generatedUrl = await docxGenerator.generateAndUploadDocx(
            templateId: templateId.toString(),
            subject: data['subject'] ?? '',
            bodyText: data['body_text'] ?? data['body'] ?? '',
            senderName: userDocData['full_name'] ?? '',
            targetName: data['target_name'] ?? '',
            refNumber: refNumber,
            senderSealUrl: senderSealUrl,
            signatureUrl: signatureUrl,
          );
          await ref.update({'generated_docx_url': generatedUrl});
        } catch (e) {
          debugPrint('Error generating docx during approval: $e');
        }
      }

      final newStatus = isCircular ? 'published' : 'sent';

      await ref.update({
        'status': newStatus,
        'reference_number': refNumber,
        if (senderFolderId.isNotEmpty) 'sender_archive_folder_id': senderFolderId,
        if (senderSealUrl.isNotEmpty) 'sender_seal_url': senderSealUrl,
        if (signatureUrl != null && signatureUrl.isNotEmpty) 'sender_signature_url': signatureUrl,
        'sender_name': userDocData['full_name'], 
        'sender_id': user.uid, 
        'sender_title': userDocData['administrative_title'],
        if (!isCircular) 'current_rcv_id': data['target_id'], 
        'is_approved': true,
        'approved_at': FieldValue.serverTimestamp(),
        if (isCircular) 'published_at': FieldValue.serverTimestamp(),
        'last_action_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      await ref.collection('tracking').add({
        'action': isCircular ? 'publish' : 'approve_and_send',
        'from_id': user.uid,
        'from_name': currentUserName,
        'to_id': isCircular ? 'all' : data['target_id'],
        'to_name': isCircular ? 'المجموعة المستهدفة' : data['target_name'],
        'from_status': oldStatus,
        'to_status': newStatus,
        'comment': isCircular ? 'تم اعتماد ونشر التعميم' : 'تم اعتماد المخاطبة من قبل المدير وإرسالها للجهة المعنية',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // ✅ إرسال تنبيه بتم الاعتماد للمرسل الأصلي للمسودة
      if (data['sender_id'] != null && data['sender_id'] != user.uid) {
        await NotificationService().sendNotification(
          targetUserId: data['sender_id'],
          title: 'تم الاعتماد',
          body: 'تم اعتماد وإرسال المسودة التي قمت بصياغتها (موضوع: ${data['subject']})',
          type: 'approved',
          relatedDocId: commId,
        );
      }
      return;
    }

    final newStatus = isCircular ? 'published' : 'archived';
    final actionComment = isCircular
        ? 'تم اعتماد ونشر التعميم'
        : 'تم اعتماد وأرشفة المخاطبة رسميا';

    await ref.update({
      'status': newStatus,
      'is_approved': true,
      'approved_at': FieldValue.serverTimestamp(),
      if (!isCircular) 'archived_at': FieldValue.serverTimestamp(),
      if (!isCircular) 'archived_by_name': currentUserName,
      if (isCircular) 'published_at': FieldValue.serverTimestamp(),
      'last_action_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    await ref.collection('tracking').add({
      'action': isCircular ? 'publish' : 'approve',
      'from_id': user.uid,
      'from_name': currentUserName,
      'to_id': isCircular ? 'all' : data['sender_id'],
      'to_name': isCircular ? 'المجموعة المستهدفة' : data['sender_name'],
      'from_status': oldStatus,
      'to_status': newStatus,
      'comment': actionComment,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // ✅ إرسال تنبيه بتم الاعتماد للمرسل الأصلي للمسودة
    if (data['sender_id'] != null && data['sender_id'] != user.uid) {
      await NotificationService().sendNotification(
        targetUserId: data['sender_id'],
        title: 'تم الاعتماد',
        body: 'تم اعتماد وأرشفة المسودة التي قمت بصياغتها (موضوع: ${data['subject']})',
        type: 'approved',
        relatedDocId: commId,
      );
    }
  }

  Future<void> updateCommunication({
    required String commId,
    required String subject,
    required String bodyText,
    required String selectedType,
    required String selectedPriority,
    required String selectedTemplateId,
    required String selectedTargetId,
    required String selectedTargetName,
    required String selectedTargetDeptId,
    required bool isCircular,
    required String? selectedTargetGroup,
    List<File> attachments = const [],
    List<Map<String, dynamic>> existingAttachments = const [],
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('غير مسجل الدخول. يرجى تسجيل الدخول مرة أخرى.');
    final currentUserName = await _getCurrentUserName();

    final ref = _firestore.collection('communications').doc(commId);
    final docSnap = await ref.get();
    if (!docSnap.exists) throw Exception('المراسلة غير موجودة');
    
    final docData = docSnap.data()!;
    if (docData['sender_id'] != user.uid) {
      throw Exception('غير مصرح لك بتعديل هذه المراسلة. أنت لست مرسلها الأصلي.');
    }
    
    final currentStatus = docData['status'];
    if (currentStatus != 'returned_for_edit' && currentStatus != 'draft') {
      throw Exception('لا يمكن تعديل هذه المراسلة حالياً.');
    }

    final routingResult = await routing.resolveRecipient(
      senderId: user.uid,
      selectedTargetId: selectedTargetId,
    );

    List<Map<String, dynamic>> updatedAttachments = List.from(existingAttachments);
    if (attachments.isNotEmpty) {
      for (var file in attachments) {
        final String origName = p.basename(file.path);
        final String safeName = '${DateTime.now().millisecondsSinceEpoch}_$origName';
        final attPath = 'communications/attachments/$commId/$safeName';

        final attRef = _storage.ref().child(attPath);
        await attRef.putFile(file);
        final downloadUrl = await attRef.getDownloadURL();

        updatedAttachments.add({
          'name': origName,
          'url': downloadUrl,
          'size': await file.length(),
          'extension': p.extension(file.path).replaceAll('.', ''),
        });
      }
    }
    
    await ref.update({
      'subject': subject,
      'body_text': bodyText,
      'body': bodyText,
      'type': selectedType,
      'priority': selectedPriority,
      'template_id': selectedTemplateId,
      'target_id': selectedTargetId,
      'target_name': selectedTargetName,
      'target_dept_id': selectedTargetDeptId,
      'current_dept_id': selectedTargetDeptId,
      'is_circular': isCircular,
      'target_group': selectedTargetGroup,
      'status': routingResult.status,
      'current_rcv_id': routingResult.actualRecipientId,
      'updated_at': FieldValue.serverTimestamp(),
      'last_action_at': FieldValue.serverTimestamp(),
      'attachments': updatedAttachments,
    });

    await ref.collection('tracking').add({
      'action': 'edit_and_resubmit',
      'from_id': user.uid,
      'from_name': currentUserName,
      'to_id': routingResult.actualRecipientId,
      'to_name': selectedTargetName, // Name might differ, but acceptable for tracking
      'from_status': currentStatus,
      'to_status': routingResult.status,
      'timestamp': FieldValue.serverTimestamp(),
      'comment': 'تم تعديل المراسلة وإعادة إرسالها',
    });
  }
}
