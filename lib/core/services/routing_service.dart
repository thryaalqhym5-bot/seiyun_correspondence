import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// خدمة توجيه المراسلات (Routing)
/// مسؤولة عن: تحديد المستقبل الفعلي (سكرتير ↔ عميد) + التحقق من الصلاحيات
class RoutingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// تحديد المستقبل الفعلي بناءً على دور المرسل والمستقبل
  /// سكرتير يرسل ← يوجه لمديره أولاً (pending_approval)
  /// غير سكرتير يرسل ← يبحث عن سكرتير المستقبل ويوجه إليه
  Future<RoutingResult> resolveRecipient({
    required String senderId,
    required String selectedTargetId,
  }) async {
    final userDoc = await _firestore.collection('users').doc(senderId).get();
    if (!userDoc.exists) throw 'بيانات المرسل غير موجودة';
    final userData = userDoc.data()!;

    String actualRecipientId = selectedTargetId;
    String status = 'sent';

    if (userData['administrative_title'] == 'secretary') {
      actualRecipientId = userData['manager_id'] ?? selectedTargetId;
      status = 'pending_approval';
    } else {
      final secQuery = await _firestore
          .collection('users')
          .where('administrative_title', isEqualTo: 'secretary')
          .where('manager_id', isEqualTo: selectedTargetId)
          .limit(1)
          .get();

      if (secQuery.docs.isNotEmpty) {
        actualRecipientId = secQuery.docs.first.id;
        status = 'sent';
      }
    }

    // تحقق من التفويض بشكل متسلسل (Recursive) مع منع الحلقات المفرغة (Infinite Loops)
    final now = DateTime.now();
    Set<String> visitedIds = {actualRecipientId};
    bool delegationFound = true;

    while (delegationFound) {
      delegationFound = false;
      final delegationQuery = await _firestore
          .collection('delegations')
          .where('delegator_id', isEqualTo: actualRecipientId)
          .where('status', isEqualTo: 'active')
          .get();

      for (var doc in delegationQuery.docs) {
        final data = doc.data();
        final startDate = (data['start_date'] as Timestamp?)?.toDate();
        final endDate = (data['end_date'] as Timestamp?)?.toDate();
        if (startDate != null && endDate != null) {
          if (now.isAfter(startDate) && now.isBefore(endDate)) {
            final nextDelegatee = data['delegatee_id'] as String?;
            if (nextDelegatee != null && !visitedIds.contains(nextDelegatee)) {
              actualRecipientId = nextDelegatee;
              visitedIds.add(actualRecipientId);
              delegationFound = true;
              break; // إعادة فحص التفويضات للشخص الجديد
            }
          }
        }
      }
    }

    return RoutingResult(
      actualRecipientId: actualRecipientId,
      status: status,
    );
  }

  /// جلب المستخدمين المسموح بمراسلتهم بناءً على المنصب والصلاحيات
  Future<List<DocumentSnapshot>> fetchAllowedTargets() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (!userDoc.exists) return [];

    final userData = userDoc.data()!;
    String title = userData['administrative_title'] ?? 'staff';
    String collegeId = userData['college_id'] ?? '';
    String deptId = userData['dept_id'] ?? '';

    String? managerEmail;
    if (title == 'secretary' && userData['manager_id'] != null) {
      final managerDoc = await _firestore
          .collection('users')
          .doc(userData['manager_id'])
          .get();
      if (managerDoc.exists) {
        final mData = managerDoc.data()!;
        title = mData['administrative_title'] ?? title;
        collegeId = mData['college_id'] ?? collegeId;
        deptId = mData['dept_id'] ?? deptId;
        managerEmail = mData['email'] as String?;
      }
    }

    final snapshot = await _firestore.collection('allowed_users').get();
    final allUsers = snapshot.docs;

    return allUsers.where((doc) {
      if (doc.id == _auth.currentUser?.email) return false;
      if (managerEmail != null && doc.id == managerEmail) return false;

      final data = doc.data();
      final targetTitle = data['administrative_title'] ?? 'staff';
      final targetCollegeId = data['college_id'] ?? '';
      final targetDeptId = data['dept_id'] ?? '';
      final targetRole = data['role'] ?? 'staff';

      if (targetRole == 'admin') return false;

      final deanRoles = ['dean', 'vice_dean', 'vice_dean_student', 'vice_dean_academic', 'vice_dean_postgraduate', 'center_director', 'vice_director', 'general_director', 'university_vp', 'general_secretary'];
      
      if (title == 'university_president') {
        return true;
      } else if (deanRoles.contains(title)) {
        if (targetTitle == 'university_president') return true;
        if (deanRoles.contains(targetTitle)) return true;
        if (targetTitle == 'head_of_department' && targetCollegeId == collegeId) return true;
        return false;
      } else if (title == 'head_of_department') {
        if (targetTitle == 'staff' && targetDeptId == deptId) return true;
        if (deanRoles.contains(targetTitle) &&
            targetCollegeId == collegeId) return true;
        return false;
      } else {
        if (targetTitle == 'head_of_department' && targetDeptId == deptId) return true;
        return false;
      }
    }).toList();
  }

}

/// نتيجة التوجيه: المستقبل الفعلي + حالة المراسلة
class RoutingResult {
  final String actualRecipientId;
  final String status;

  RoutingResult({required this.actualRecipientId, required this.status});
}
