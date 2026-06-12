import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:docx_template/docx_template.dart';

/// خدمة توليد مستندات Word (DOCX)
/// مسؤولة عن: تحميل القالب → حقن البيانات (توقيع/ختم/محتوى) → رفع الملف المُولد
class DocxGeneratorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// توليد مستند DOCX وحقن التوقيع والختم ورفعه إلى Firebase Storage
  Future<String> generateAndUploadDocx({
    required String templateId,
    required String subject,
    required String bodyText,
    required String senderName,
    required String targetName,
    required String refNumber,
    required String senderSealUrl,
    required String? signatureUrl,
  }) async {
    // 1. جلب بيانات القالب
    final templateDoc = await _firestore
        .collection('templates')
        .doc(templateId)
        .get();
    if (!templateDoc.exists) throw 'القالب المختار غير موجود أو تم حذفه';

    final templateData = templateDoc.data()!;
    final docxUrl = (templateData['docx_path'] ?? templateData['file_url']) as String?;
    if (docxUrl == null || docxUrl.isEmpty) {
      throw 'القالب لا يحتوي على ملف وورد (Word) صالح';
    }

    // 2. تحميل ملف الوورد من السيرفر
    final templateBytes = await _downloadFile(docxUrl);
    if (templateBytes.isEmpty) {
      throw 'فشل في تحميل ملف القالب من الخادم (الملف فارغ)';
    }

    // 3. حقن البيانات في القالب
    DocxTemplate docx;
    try {
      docx = await DocxTemplate.fromBytes(templateBytes);
    } catch (e) {
      throw 'ملف القالب الحالي تالف أو أنه ليس ملف Word (.docx) صحيح. الرجاء رفع قالب سليم من حساب الإدارة.';
    }

    final now = DateTime.now();
    Content c = Content();
    c.add(TextContent("subject", subject));
    c.add(TextContent("body_text", bodyText));
    c.add(TextContent("sender_name", senderName));
    c.add(TextContent("date",
        "${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}"));
    c.add(TextContent("target_name", targetName));
    c.add(TextContent("ref", refNumber));

    // إضافة التوقيع
    if (signatureUrl != null && signatureUrl.isNotEmpty) {
      try {
        final sigBytes = await _downloadFile(signatureUrl);
        if (sigBytes.isNotEmpty) c.add(ImageContent("signature", sigBytes));
      } catch (e) {
        debugPrint('Error downloading signature image: $e');
      }
    }

    // إضافة الختم
    if (senderSealUrl.isNotEmpty) {
      try {
        final sealBytes = await _downloadFile(senderSealUrl);
        if (sealBytes.isNotEmpty) c.add(ImageContent("seal", sealBytes));
      } catch (e) {
        debugPrint('Error downloading seal image: $e');
      }
    }

    final generatedBytes = await docx.generate(c);
    if (generatedBytes == null) throw 'فشل في توليد المستند النهائي';

    // 4. رفع المستند المولد
    return _uploadFile(generatedBytes, 'comm_${now.millisecondsSinceEpoch}.docx');
  }

  /// تحميل ملف من رابط URL
  Future<List<int>> _downloadFile(String url) async {
    final client = HttpClient();
    final req = await client.getUrl(Uri.parse(url));
    final res = await req.close();
    if (res.statusCode != 200) {
      throw 'فشل في تحميل الملف (خطأ ${res.statusCode})';
    }
    final builder = BytesBuilder();
    await for (var chunk in res) {
      builder.add(chunk);
    }
    return builder.toBytes();
  }

  /// رفع ملف إلى Firebase Storage
  Future<String> _uploadFile(List<int> bytes, String fileName) async {
    final pathName = 'communications/docx/$fileName';
    final bucket = _storage.bucket;
    final uploadUrl = Uri.parse(
      'https://firebasestorage.googleapis.com/v0/b/$bucket/o?name=${Uri.encodeQueryComponent(pathName)}',
    );

    final client = HttpClient();
    final postReq = await client.postUrl(uploadUrl);
    final idToken = await _auth.currentUser?.getIdToken();
    if (idToken != null) {
      postReq.headers.add('Authorization', 'Bearer $idToken');
    }
    postReq.headers.add('Content-Type',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
    postReq.add(bytes);

    final postRes = await postReq.close();
    final postBody = await postRes.transform(utf8.decoder).join();

    if (postRes.statusCode != 200) {
      throw 'فشل رفع المستند المولد: ${postRes.statusCode}';
    }
    final uploadData = jsonDecode(postBody);
    return 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/${Uri.encodeComponent(pathName)}?alt=media&token=${uploadData['downloadTokens']}';
  }
}
