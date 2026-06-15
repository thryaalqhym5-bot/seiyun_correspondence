import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/user_model.dart';
import 'signature_setup_dialog.dart';

class ProfileSettingsDialog extends StatefulWidget {
  final UserModel currentUser;

  const ProfileSettingsDialog({super.key, required this.currentUser});

  @override
  State<ProfileSettingsDialog> createState() => _ProfileSettingsDialogState();
}

class _ProfileSettingsDialogState extends State<ProfileSettingsDialog> {
  final _oldPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _oldPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _updatePin() async {
    final oldPin = _oldPinController.text.trim();
    final newPin = _newPinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (oldPin.isEmpty || newPin.isEmpty || confirmPin.isEmpty) {
      setState(() => _errorMessage = 'يرجى تعبئة جميع الحقول');
      return;
    }

    if (newPin != confirmPin) {
      setState(() => _errorMessage = 'الرمز السري الجديد غير متطابق');
      return;
    }

    if (newPin.length < 4) {
      setState(() => _errorMessage = 'يجب أن يتكون الرمز من 4 أرقام على الأقل');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final uid = widget.currentUser.uid;
      if (uid == null) {
        setState(() => _errorMessage = 'معرف المستخدم غير صالح');
        return;
      }
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      // Remove dbPin manual check, we will rely on FirebaseAuth reauthentication to verify the old pin

      final newHashed = sha256.convert(utf8.encode(newPin)).toString();
      
      final userAuth = FirebaseAuth.instance.currentUser;
      print('DEBUG: userAuth is ${userAuth?.email}');
      if (userAuth != null && userAuth.email != null) {
        try {
          print('DEBUG: Starting signInWithEmailAndPassword for reauth');
          // Use signInWithEmailAndPassword instead of reauthenticateWithCredential to bypass Windows bug
          await FirebaseAuth.instance.signInWithEmailAndPassword(email: userAuth.email!, password: oldPin).timeout(const Duration(seconds: 15));
          
          print('DEBUG: Starting updatePassword');
          await userAuth.updatePassword(newPin).timeout(const Duration(seconds: 15));
          print('DEBUG: Finished updatePassword');
        } catch (e) {
          print('DEBUG: Exception in FirebaseAuth block: $e');
          setState(() => _errorMessage = 'حدث خطأ: $e');
          return;
        }
      }

      print('DEBUG: Starting doc.reference.update');
      await doc.reference.update({'pin': newHashed}).timeout(const Duration(seconds: 10));
      print('DEBUG: Finished doc.reference.update');

      setState(() {
        _successMessage = 'تم تغيير الرمز السري بنجاح!';
        _oldPinController.clear();
        _newPinController.clear();
        _confirmPinController.clear();
      });
    } catch (e) {
      setState(() => _errorMessage = 'حدث خطأ أثناء تحديث الرمز السري');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSignature() async {
    // Open Signature Pad Dialog
    final dynamic signatureBytes = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SignatureSetupDialog(),
    );

    if (signatureBytes != null && signatureBytes is Uint8List) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _successMessage = null;
      });

      try {
        final uid = widget.currentUser.uid;
        if (uid == null) return;
        final storageRef = FirebaseStorage.instance.ref().child('signatures/$uid.png');
        await storageRef.putData(signatureBytes, SettableMetadata(contentType: 'image/png'));
        final url = await storageRef.getDownloadURL();
        
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'signature_url': url,
        });
        
        setState(() {
          _successMessage = 'تم تحديث واعتماد التوقيع الجديد بنجاح!';
        });
      } catch (e) {
        setState(() => _errorMessage = 'حدث خطأ أثناء حفظ التوقيع');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.manage_accounts, color: AppColors.primary, size: 28),
                    SizedBox(width: 12),
                    Text('إعدادات الملف الشخصي', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 32, color: AppColors.border),
            
            // Personal Info (Read Only)
            Text('البيانات الشخصية', style: TextStyle(color: AppColors.primary.withValues(alpha: 0.8), fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildInfoRow('الاسم:', widget.currentUser.fullName),
                  const SizedBox(height: 8),
                  _buildInfoRow('البريد:', widget.currentUser.email),
                  const SizedBox(height: 8),
                  _buildInfoRow('المنصب:', widget.currentUser.affiliations.isNotEmpty ? widget.currentUser.affiliations.first.administrativeTitle : 'غير محدد'),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Signature Update
            Text('التوقيع الإلكتروني', style: TextStyle(color: AppColors.primary.withValues(alpha: 0.8), fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text('يمكنك رسم توقيعك واعتماده للظهور في خطاباتك الصادرة.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _updateSignature,
                    icon: const Icon(Icons.draw, size: 18),
                    label: const Text('تغيير التوقيع'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // PIN Update
            Text('تغيير الرمز السري (PIN)', style: TextStyle(color: AppColors.primary.withValues(alpha: 0.8), fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _oldPinController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'الرمز السري القديم',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newPinController,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'الرمز الجديد',
                            labelStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _confirmPinController,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'تأكيد الرمز',
                            labelStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _updatePin,
                      icon: const Icon(Icons.save),
                      label: const Text('حفظ الرمز السري'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),


              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                ),
              
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))),
                    ],
                  ),
                ),
              
              if (_successMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(_successMessage!, style: const TextStyle(color: AppColors.success)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
        Expanded(child: Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold))),
      ],
    );
  }
}
