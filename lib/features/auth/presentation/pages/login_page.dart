import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';import '../../../../core/models/user_model.dart';
import '../../../../data/services/local_storage_service.dart';
import '../../../dashboard/presentation/pages/admin_dashboard_page.dart';
import '../../../dashboard/presentation/pages/staff_dashboard_page.dart';
import '../../../dashboard/presentation/pages/executive_dashboard_page.dart';
import 'inquiry_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;

  final LocalStorageService _localStorageService = LocalStorageService();

  @override
  void initState() {
    super.initState();
    _checkLocalLogin();
  }

  Future<void> _checkLocalLogin() async {
    setState(() => isLoading = true);
    final user = await _localStorageService.getUser();
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          final isActive = data['is_active'] ?? false;
          if (isActive) {
            final freshUser = UserModel.fromJson(data, doc.id);
            await _localStorageService.saveUser(freshUser);
            if (mounted) {
              _navigateBasedOnRole(freshUser);
              return;
            }
          } else {
            await FirebaseAuth.instance.signOut();
            await _localStorageService.clearUser();
            if (mounted) setState(() => errorMessage = 'هذا الحساب غير مفعل حالياً');
          }
        } else {
          await FirebaseAuth.instance.signOut();
          await _localStorageService.clearUser();
        }
      } catch (e) {
        if (mounted) _navigateBasedOnRole(user);
      }
    }
    if (mounted) setState(() => isLoading = false);
  }

  void _navigateBasedOnRole(UserModel userModel) {
    if (userModel.role == 'admin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AdminDashboardPage(fullName: userModel.fullName),
        ),
      );
    } else if (['president', 'vp_student_affairs', 'vp_academic_affairs', 'vp_postgraduate_studies', 'secretary_general'].contains(userModel.role)) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ExecutiveDashboardPage(fullName: userModel.fullName, role: userModel.role),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => StaffDashboardPage(fullName: userModel.fullName),
        ),
      );
    }
  }

  Future<void> _processAuthenticatedUser(User user, String email, String password) async {
    final existingUserDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (existingUserDoc.exists) {
      final data = existingUserDoc.data()!;
      final userModel = UserModel.fromJson(data, existingUserDoc.id);
      if (!userModel.isActive) {
        setState(() => errorMessage = 'هذا الحساب غير مفعل حالياً');
        await FirebaseAuth.instance.signOut();
        return;
      }
      await _localStorageService.saveUser(userModel);
      if (!mounted) return;
      _navigateBasedOnRole(userModel);
      return;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('allowed_users')
        .where('emails', arrayContains: email)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      await FirebaseAuth.instance.signOut();
      setState(() => errorMessage = 'هذا الإيميل ($email) غير مصرح له بالدخول للنظام');
      return;
    }

    final allowedUserDoc = snapshot.docs.first;
    final data = allowedUserDoc.data();

    if (data['is_registered'] == false || data['is_registered'] == null) {
      final newUser = UserModel(
        uid: user.uid,
        fullName: data['full_name'],
        email: email,
        role: data['role'] ?? 'faculty_member',
        collegeId: data['college_id'] ?? '',
        deptId: data['dept_id'] ?? '',
        administrativeTitle: data['administrative_title'] ?? '',
        secondaryAdministrativeTitle: data['secondary_administrative_title'] ?? 'none',
        isActive: true,
        managerId: data['manager_id'] ?? '',
      );

      final userMap = newUser.toLocalMap();
      userMap['pin'] = sha256.convert(utf8.encode(password)).toString();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(userMap);
      await allowedUserDoc.reference.update({'is_registered': true});
    } else {
      // Sync affiliations from allowed_users to users if already registered
      if (data.containsKey('affiliations')) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'affiliations': data['affiliations'],
        }, SetOptions(merge: true));
      }
    }

    var userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    if (!userDoc.exists) {
      setState(() => errorMessage = 'بيانات المستخدم غير موجودة في قاعدة البيانات الأساسية');
      return;
    }

    final userModel = UserModel.fromJson(userDoc.data()!, userDoc.id);

    if (!userModel.isActive) {
      setState(() => errorMessage = 'هذا الحساب غير مفعل حالياً');
      return;
    }

    await _localStorageService.saveUser(userModel);

    if (!mounted) return;
    _navigateBasedOnRole(userModel);
  }

  Future<void> login() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final email = emailController.text.trim().toLowerCase();
    final password = passwordController.text.trim();

    try {
      UserCredential credential;
      try {
        credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code.contains('unknown') || e.code.contains('internal') || e.code == 'INVALID_LOGIN_CREDENTIALS') {
          // محاولة التسجيل لأول مرة إذا كان في القائمة البيضاء
          final snapshot = await FirebaseFirestore.instance
              .collection('allowed_users')
              .where('emails', arrayContains: email)
              .limit(1)
              .get();

          if (snapshot.docs.isNotEmpty) {
            final allowedUserDoc = snapshot.docs.first;
            final data = allowedUserDoc.data();

            if (data['is_registered'] == false || data['is_registered'] == null) {
              // إنشاء الحساب لأول مرة في Firebase Auth
              credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                email: email,
                password: password,
              );
            } else {
              setState(() => errorMessage = 'الحساب مسجل مسبقاً، كلمة المرور غير صحيحة');
              return;
            }
          } else {
            setState(() => errorMessage = 'الإيميل غير مسجل في النظام، ولا تملك صلاحية الدخول');
            return;
          }
        } else if (e.code == 'wrong-password') {
          setState(() => errorMessage = 'كلمة المرور غير صحيحة');
          return;
        } else {
          setState(() => errorMessage = 'الإيميل أو كلمة المرور غير صحيحة، يرجى مراجعة مسؤول النظام (${e.code})');
          return;
        }
      }

      await _processAuthenticatedUser(credential.user!, email, password);

    } on FirebaseAuthException catch (e) {
      setState(() => errorMessage = 'خطأ (${e.code}): ${e.message}');
    } catch (e) {
      setState(() => errorMessage = 'خطأ غير متوقع: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const darkBlueBg = Color(0xFF0A192F);

    return Scaffold(
      backgroundColor: darkBlueBg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/logo.png.png',
                  height: 140,
                  errorBuilder: (context, error, stackTrace) {
                    return const Column(
                      children: [
                        Icon(
                          Icons.account_balance_rounded,
                          size: 80,
                          color: Colors.white,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'جامعة سيئون',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
                        )
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'نظام المراسلات الإدارية',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'تسجيل الدخول',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, color: Colors.white70),
                      ),
                      const SizedBox(height: 40),

                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'البريد الإلكتروني الرسمي',
                          hintStyle: const TextStyle(color: Colors.white38),
                          prefixIcon: const Icon(Icons.email_outlined, color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.08),
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: passwordController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'كلمة المرور',
                          hintStyle: const TextStyle(color: Colors.white38),
                          prefixIcon: const Icon(Icons.lock_outline, color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.08),
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
                          ),
                        ),
                      ),

                      if (errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorMessage!,
                                  style: TextStyle(color: Colors.red[100], fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent, 
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 24, width: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  'تسجيل الدخول',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const InquiryPage()));
                        },
                        icon: const Icon(Icons.qr_code_scanner, color: Colors.white70),
                        label: const Text('استعلام عن صحة وثيقة', style: TextStyle(color: Colors.white70, decoration: TextDecoration.underline)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}