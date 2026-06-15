import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DelegationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// إضافة تفويض جديد
  /// لا يسمح بإنشاء تفويض إذا كان المفوض إليه مفوضاً لشخص آخر (منع سلسلة التفويض)
  Future<void> createDelegation({
    required String delegateeId,
    required DateTime startDate,
    required DateTime endDate,
    required String notes,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('المستخدم غير مسجل الدخول');

    if (user.uid == delegateeId) {
      throw Exception('لا يمكن للمستخدم التفويض لنفسه.');
    }

    final delegateeDoc = await _firestore.collection('users').doc(delegateeId).get();
    if (!delegateeDoc.exists || delegateeDoc.data()?['is_active'] != true) {
      throw Exception('المستخدم المفوض إليه غير موجود أو غير مفعل.');
    }

    await _firestore.collection('delegations').add({
      'delegator_id': user.uid,
      'delegatee_id': delegateeId,
      'start_date': Timestamp.fromDate(startDate),
      'end_date': Timestamp.fromDate(endDate),
      'notes': notes,
      'status': 'active',
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  /// إلغاء التفويض
  Future<void> revokeDelegation(String delegationId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('المستخدم غير مسجل الدخول');

    final doc = await _firestore.collection('delegations').doc(delegationId).get();
    if (!doc.exists) throw Exception('التفويض غير موجود');
    if (doc.data()?['delegator_id'] != user.uid) {
      throw Exception('ليس لديك صلاحية لإلغاء هذا التفويض');
    }

    await _firestore.collection('delegations').doc(delegationId).update({
      'status': 'revoked',
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// جلب التفويضات التي أعطاها المستخدم (سواء نشطة أو سابقة حسب السجل)
  Stream<QuerySnapshot> getMyDelegations() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('delegations')
        .where('delegator_id', isEqualTo: user.uid)
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  /// التحقق مما إذا كان المستخدم الحالي لديه تفويض نشط من مدير معين
  Future<bool> hasActiveDelegation(String delegatorId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final now = DateTime.now();
    final query = await _firestore
        .collection('delegations')
        .where('delegatee_id', isEqualTo: user.uid)
        .where('delegator_id', isEqualTo: delegatorId)
        .where('status', isEqualTo: 'active')
        .get();

    for (var doc in query.docs) {
      final start = (doc['start_date'] as Timestamp).toDate();
      final end = (doc['end_date'] as Timestamp).toDate();
      if (now.isAfter(start) && now.isBefore(end)) {
        return true;
      }
    }
    return false;
  }

  /// جلب قائمة بالمعرفات (المدراء) الذين فوضوا المستخدم الحالي وتفويضهم نشط حالياً
  Future<List<String>> getActiveDelegatorsForUser() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final now = DateTime.now();
    final query = await _firestore
        .collection('delegations')
        .where('delegatee_id', isEqualTo: user.uid)
        .where('status', isEqualTo: 'active')
        .get();

    List<String> delegatorIds = [];
    for (var doc in query.docs) {
      final start = (doc['start_date'] as Timestamp).toDate();
      final end = (doc['end_date'] as Timestamp).toDate();
      if (now.isAfter(start) && now.isBefore(end)) {
        delegatorIds.add(doc['delegator_id']);
      }
    }
    return delegatorIds;
  }
}
