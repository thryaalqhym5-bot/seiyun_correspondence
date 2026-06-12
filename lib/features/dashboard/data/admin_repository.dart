import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/models/college_model.dart';
import '../../../../core/models/department_model.dart';

class AdminRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ===================== Users =====================

  /// جلب المستخدمين من جدول المصرح لهم لكي يظهر الجميع (حتى من لم يقم بالتسجيل بعد)
  Stream<List<UserModel>> getUsersStream() {
    return _firestore.collection('allowed_users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => UserModel.fromJson(doc.data(), doc.id)).toList();
    });
  }

  /// تحديث حالة المستخدم
  Future<void> toggleUserStatus(String email, bool currentStatus) async {
    final batch = _firestore.batch();
    final newStatus = !currentStatus;

    // تحديث في allowed_users
    final allowedUserRef = _firestore.collection('allowed_users').doc(email);
    batch.update(allowedUserRef, {'is_active': newStatus});

    // تحديث في users
    final usersQuery = await _firestore.collection('users').where('email', isEqualTo: email).get();
    if (usersQuery.docs.isNotEmpty) {
      final userRef = _firestore.collection('users').doc(usersQuery.docs.first.id);
      batch.update(userRef, {
        'is_active': newStatus,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<void> deleteUser(String email) async {
    final batch = _firestore.batch();
    final allowedUserRef = _firestore.collection('allowed_users').doc(email);
    batch.delete(allowedUserRef);

    final usersQuery = await _firestore.collection('users').where('email', isEqualTo: email).get();
    for (var doc in usersQuery.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ===================== Colleges =====================

  Stream<List<CollegeModel>> getCollegesStream() {
    return _firestore.collection('colleges').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => CollegeModel.fromJson(doc.data(), doc.id)).toList();
    });
  }

  Future<void> addCollege(CollegeModel college) async {
    final docRef = _firestore.collection('colleges').doc(college.id);
    final existing = await docRef.get();
    if (existing.exists) {
      throw Exception('معرف الكلية موجود مسبقاً!');
    }
    await docRef.set(college.toJson());
  }

  Future<void> deleteCollege(String collegeId) async {
    await _firestore.collection('colleges').doc(collegeId).delete();
  }

  // ===================== Departments =====================

  Stream<List<DepartmentModel>> getDepartmentsStream(String collegeId) {
    return _firestore
        .collection('colleges')
        .doc(collegeId)
        .collection('departments')
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => DepartmentModel.fromJson(doc.data(), doc.id)).toList();
    });
  }

  Future<void> addDepartment(String collegeId, DepartmentModel dept) async {
    final docRef = _firestore.collection('colleges').doc(collegeId).collection('departments').doc(dept.id);
    final existing = await docRef.get();
    if (existing.exists) {
      throw Exception('معرف القسم موجود مسبقاً!');
    }
    await docRef.set(dept.toJson());
  }

  Future<void> deleteDepartment(String collegeId, String deptId) async {
    await _firestore.collection('colleges').doc(collegeId).collection('departments').doc(deptId).delete();
  }
}
