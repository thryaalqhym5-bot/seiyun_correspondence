import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

class TemplateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// يرفع ملف إلى Firebase Storage ويعيد رابط التحميل
  /// تم استخدام REST API لتجنب مشكلة تجميد المكتبة الرسمية على بيئة Windows
  Future<String?> uploadFile(PlatformFile file, String folderPath) async {
    try {
      if (file.path == null) return null;
      final extension = file.name.split('.').last;
      final safeFileName = '${DateTime.now().millisecondsSinceEpoch}.$extension';
      final pathName = '$folderPath/$safeFileName';

      final bytes = await File(file.path!).readAsBytes();

      final bucket = _storage.bucket;
      final url = Uri.parse(
          'https://firebasestorage.googleapis.com/v0/b/$bucket/o?name=${Uri.encodeQueryComponent(pathName)}');

      final client = HttpClient();
      final request = await client.postUrl(url);

      final idToken = await _auth.currentUser?.getIdToken();
      if (idToken != null) {
        request.headers.add('Authorization', 'Bearer $idToken');
      }

      final contentType = extension.toLowerCase() == 'pdf'
          ? 'application/pdf'
          : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      request.headers.add('Content-Type', contentType);
      request.add(bytes);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(responseBody);
        final token = data['downloadTokens'];
        return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/${Uri.encodeComponent(pathName)}?alt=media&token=$token';
      } else {
        debugPrint('REST Upload failed: ${response.statusCode} - $responseBody');
        return null;
      }
    } on FileSystemException catch (e) {
      debugPrint('File is locked: $e');
      throw Exception('عذراً، يجب إغلاق الملف من برنامج Word أو الـ PDF قبل محاولة رفعه!');
    } catch (e) {
      debugPrint('Error uploading file: $e');
      return null;
    }
  }

  /// التحقق من عدم وجود قالب بنفس المعرف مسبقاً
  Future<bool> checkTemplateExists(String templateId) async {
    final existingDoc = await _firestore.collection('templates').doc(templateId).get();
    return existingDoc.exists;
  }

  /// إضافة قالب جديد إلى قاعدة البيانات
  Future<void> addTemplate({
    required String templateId,
    required String templateName,
    required String selectedTemplateType,
    required int version,
    required bool isActive,
    required String docxUrl,
    String? pdfUrl,
  }) async {
    await _firestore.collection('templates').doc(templateId).set({
      'template_id': templateId,
      'template_name': templateName,
      'template_type': selectedTemplateType,
      'docx_path': docxUrl,
      'pdf_preview_path': pdfUrl ?? '',
      'version': version,
      'is_active': isActive,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// تعديل قالب موجود
  Future<void> editTemplate({
    required String docId,
    required String templateName,
    required String selectedTemplateType,
    required int version,
    required bool isActive,
    required String docxUrl,
    required String pdfUrl,
  }) async {
    await _firestore.collection('templates').doc(docId).update({
      'template_name': templateName,
      'template_type': selectedTemplateType,
      'docx_path': docxUrl,
      'pdf_preview_path': pdfUrl,
      'version': version,
      'is_active': isActive,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// حذف قالب من قاعدة البيانات وحذف ملفاته من Storage
  Future<void> deleteTemplate(String docId, Map<String, dynamic> data) async {
    final docxPath = data['docx_path'] as String?;
    if (docxPath != null && docxPath.isNotEmpty) {
      try {
        await _storage.refFromURL(docxPath).delete();
      } catch (e) {
        debugPrint('خطأ في حذف ملف الوورد: $e');
      }
    }

    final pdfPath = data['pdf_preview_path'] as String?;
    if (pdfPath != null && pdfPath.isNotEmpty) {
      try {
        await _storage.refFromURL(pdfPath).delete();
      } catch (e) {
        debugPrint('خطأ في حذف ملف الـ PDF: $e');
      }
    }

    await _firestore.collection('templates').doc(docId).delete();
  }

  /// تفعيل أو تعطيل قالب
  Future<void> toggleTemplateStatus(String docId, bool currentStatus) async {
    await _firestore.collection('templates').doc(docId).update({
      'is_active': !currentStatus,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// حذف ملف من Storage بشكل اقتصادي (بدون أخطاء مقاطعة)
  Future<void> deleteFileEconomically(String fileUrl) async {
    if (fileUrl.isEmpty) return;
    try {
      await _storage.refFromURL(fileUrl).delete();
    } catch (e) {
      debugPrint('خطأ في حذف الملف القديم: $e');
    }
  }
}
