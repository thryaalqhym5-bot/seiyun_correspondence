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
    final data = doc.data();
    if (data == null) throw Exception('المستخدم غير موجود');
    
    final role = data['role'];
    final adminTitles = List<String>.from(data['administrative_titles'] ?? [data['administrative_title']]);
    
    if (role != 'admin' && !adminTitles.contains('vice_dean_academic') && !adminTitles.contains('university_vp_academic') && data['administrative_title'] != 'vice_dean_academic') {
      throw Exception('ليس لديك صلاحية لإجراء هذه العملية. (مطلوب صلاحية مدير نظام أو نائب عميد للشؤون الأكاديمية)');
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
    required String selectedRole,
    required bool isActive,
    required List<Map<String, dynamic>> affiliations,
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

    // Extract array properties for searching
    final collegeIds = affiliations.map((e) => e['college_id'] as String).toList();
    final deptIds = affiliations.map((e) => e['dept_id'] as String).toList();
    final adminTitles = affiliations.map((e) => e['administrative_title'] as String).toList();
    
    // Primary affiliation for backward compatibility
    final primary = affiliations.isNotEmpty ? affiliations.first : {
      'college_id': '', 'dept_id': '', 'administrative_title': 'none', 'secondary_administrative_title': 'none'
    };

    // 1. إضافة إلى جدول users
    final userRef = _firestore.collection('users').doc(newUid);
    batch.set(userRef, {
      'uid': newUid,
      'full_name': fullName,
      'email': email,
      'role': selectedRole,
      'college_id': primary['college_id'],
      'dept_id': primary['dept_id'],
      'administrative_title': primary['administrative_title'],
      'secondary_administrative_title': primary['secondary_administrative_title'],
      'affiliations': affiliations,
      'college_ids': collegeIds,
      'dept_ids': deptIds,
      'administrative_titles': adminTitles,
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
      'college_id': primary['college_id'],
      'dept_id': primary['dept_id'],
      'administrative_title': primary['administrative_title'],
      'secondary_administrative_title': primary['secondary_administrative_title'],
      'affiliations': affiliations,
      'college_ids': collegeIds,
      'dept_ids': deptIds,
      'administrative_titles': adminTitles,
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
    required String selectedRole,
    required bool isActive,
    required List<Map<String, dynamic>> affiliations,
    String? newPassword,
    String? managerId,
  }) async {
    await _requireAdmin();
    final batch = _firestore.batch();

    // Extract array properties for searching
    final collegeIds = affiliations.map((e) => e['college_id'] as String).toList();
    final deptIds = affiliations.map((e) => e['dept_id'] as String).toList();
    final adminTitles = affiliations.map((e) => e['administrative_title'] as String).toList();
    
    // Primary affiliation for backward compatibility
    final primary = affiliations.isNotEmpty ? affiliations.first : {
      'college_id': '', 'dept_id': '', 'administrative_title': 'none', 'secondary_administrative_title': 'none'
    };

    // 1. التحديث في allowed_users
    final allowedUserRef = _firestore.collection('allowed_users').doc(docId);
    batch.update(allowedUserRef, {
      'full_name': fullName,
      'college_id': primary['college_id'],
      'dept_id': primary['dept_id'],
      'administrative_title': primary['administrative_title'],
      'secondary_administrative_title': primary['secondary_administrative_title'],
      'affiliations': affiliations,
      'college_ids': collegeIds,
      'dept_ids': deptIds,
      'administrative_titles': adminTitles,
      'role': selectedRole,
      'is_active': isActive,
      if (managerId != null) 'manager_id': managerId,
    });

    // 2. البحث عن وثيقة المستخدم في جدول users
    final allowedSnap = await allowedUserRef.get();
    final allowedData = allowedSnap.data() as Map<String, dynamic>?;
    final emailsList = List<String>.from(allowedData?['emails'] ?? [docId]);
    if (!emailsList.contains(docId)) emailsList.add(docId);

    final usersQuery = await _firestore.collection('users').where('email', whereIn: emailsList).get();
    if (usersQuery.docs.isNotEmpty) {
      final userDocId = usersQuery.docs.first.id;
      final userRef = _firestore.collection('users').doc(userDocId);
      final updateData = <String, dynamic>{
        'full_name': fullName,
        'college_id': primary['college_id'],
        'dept_id': primary['dept_id'],
        'administrative_title': primary['administrative_title'],
        'secondary_administrative_title': primary['secondary_administrative_title'],
        'affiliations': affiliations,
        'college_ids': collegeIds,
        'dept_ids': deptIds,
        'administrative_titles': adminTitles,
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
