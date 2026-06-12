import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _requireAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('المستخدم غير مسجل الدخول');
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists || doc.data()?['role'] != 'admin') {
      throw Exception('ليس لديك صلاحية لإجراء هذه العملية. (مطلوب صلاحية مدير نظام)');
    }
  }

  /// جلب المستخدمين كمجرى بيانات (Stream)
  Stream<QuerySnapshot> getUsersStream() {
    return _firestore.collection('allowed_users').snapshots();
  }

  /// إضافة مستخدم جديد (إنشاء حساب + إضافة لقواعد البيانات)
  Future<void> addUser({
    required String fullName,
    required String email,
    required String password,
    required String deptId,
    required String collegeId,
    required String selectedRole,
    required String selectedAdminTitle,
    required String selectedSecondaryTitle,
    required bool isActive,
    String? managerId,
  }) async {
    await _requireAdmin();

    FirebaseApp secondaryApp;
    try {
      secondaryApp = Firebase.app('SecondaryApp');
    } catch (e) {
      secondaryApp = await Firebase.initializeApp(
        name: 'SecondaryApp',
        options: Firebase.app().options,
      );
    }

    final auth = FirebaseAuth.instanceFor(app: secondaryApp);
    final credential = await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final newUid = credential.user!.uid;

    final batch = _firestore.batch();

    // 1. إضافة إلى جدول users
    final userRef = _firestore.collection('users').doc(newUid);
    batch.set(userRef, {
      'uid': newUid,
      'full_name': fullName,
      'email': email,
      'role': selectedRole,
      'college_id': collegeId,
      'dept_id': deptId,
      'administrative_title': selectedAdminTitle,
      'secondary_administrative_title': selectedSecondaryTitle,
      'is_active': isActive,
      'pin': sha256.convert(utf8.encode(password)).toString(),
      if (managerId != null && managerId.isNotEmpty) 'manager_id': managerId,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    // 2. إضافة إلى جدول allowed_users
    final allowedUserRef = _firestore.collection('allowed_users').doc(email);
    batch.set(allowedUserRef, {
      'full_name': fullName,
      'email': email,
      'college_id': collegeId,
      'dept_id': deptId,
      'administrative_title': selectedAdminTitle,
      'secondary_administrative_title': selectedSecondaryTitle,
      'role': selectedRole,
      'is_active': isActive,
      'is_registered': true,
      if (managerId != null && managerId.isNotEmpty) 'manager_id': managerId,
    }, SetOptions(merge: true));

    await batch.commit();
    await auth.signOut();
  }

  /// تعديل مستخدم موجود
  Future<void> editUser({
    required String docId, // Email in allowed_users
    required String fullName,
    required String deptId,
    required String collegeId,
    required String selectedRole,
    required String selectedAdminTitle,
    required String selectedSecondaryTitle,
    required bool isActive,
    String? newPassword,
    String? managerId,
  }) async {
    await _requireAdmin();
    final batch = _firestore.batch();

    // 1. التحديث في allowed_users
    final allowedUserRef = _firestore.collection('allowed_users').doc(docId);
    batch.update(allowedUserRef, {
      'full_name': fullName,
      'college_id': collegeId,
      'dept_id': deptId,
      'administrative_title': selectedAdminTitle,
      'secondary_administrative_title': selectedSecondaryTitle,
      'role': selectedRole,
      'is_active': isActive,
      if (managerId != null) 'manager_id': managerId,
    });

    // 2. البحث عن وثيقة المستخدم في جدول users
    final usersQuery = await _firestore.collection('users').where('email', isEqualTo: docId).get();
    if (usersQuery.docs.isNotEmpty) {
      final userDocId = usersQuery.docs.first.id;
      final userRef = _firestore.collection('users').doc(userDocId);
      final updateData = <String, dynamic>{
        'full_name': fullName,
        'college_id': collegeId,
        'dept_id': deptId,
        'administrative_title': selectedAdminTitle,
        'secondary_administrative_title': selectedSecondaryTitle,
        'role': selectedRole,
        'is_active': isActive,
        'updated_at': FieldValue.serverTimestamp(),
        if (managerId != null) 'manager_id': managerId,
      };
      if (newPassword != null && newPassword.isNotEmpty) {
        updateData['pin'] = sha256.convert(utf8.encode(newPassword)).toString();
      }
      batch.update(userRef, updateData);
    }

    await batch.commit();

    // تحديث كلمة المرور في FirebaseAuth يتطلب صلاحيات Admin SDK عبر وظائف سحابية،
    // لكن مؤقتاً نحفظه في الـ Firestore (PIN) كاحتياط، إذا استدعى الأمر.
  }

  /// تفعيل أو تعطيل مستخدم
  Future<void> toggleUserStatus(String email, bool currentStatus) async {
    await _requireAdmin();
    final batch = _firestore.batch();
    final newStatus = !currentStatus;

    final allowedUserRef = _firestore.collection('allowed_users').doc(email);
    batch.update(allowedUserRef, {'is_active': newStatus});

    final usersQuery = await _firestore.collection('users').where('email', isEqualTo: email).get();
    if (usersQuery.docs.isNotEmpty) {
      final userRef = _firestore.collection('users').doc(usersQuery.docs.first.id);
      batch.update(userRef, {'is_active': newStatus, 'updated_at': FieldValue.serverTimestamp()});
    }

    await batch.commit();
  }

  /// حذف مستخدم
  Future<void> deleteUser(String email) async {
    await _requireAdmin();
    final batch = _firestore.batch();

    final allowedUserRef = _firestore.collection('allowed_users').doc(email);
    batch.delete(allowedUserRef);

    final usersQuery = await _firestore.collection('users').where('email', isEqualTo: email).get();
    if (usersQuery.docs.isNotEmpty) {
      final userRef = _firestore.collection('users').doc(usersQuery.docs.first.id);
      batch.delete(userRef);
      // تنبيه: الحذف الفعلي من FirebaseAuth يحتاج Admin SDK، 
      // لذلك نكتفي بحذفه من الـ DB وسيفقد القدرة على الوصول.
    }

    await batch.commit();
  }
}
