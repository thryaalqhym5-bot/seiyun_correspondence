import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/pdf_security_utils.dart';
import '../../features/communications/presentation/pages/pdf_view_page.dart';

class WordService {
  static Future<void> openCommunicationPdf(BuildContext context, Map<String, dynamic> data, String communicationId, String subject) async {
    try {
      String localPath = (data['final_pdf_path'] ?? '').toString();

      if (localPath.isNotEmpty && File(localPath).existsSync()) {
        final currentUser = FirebaseAuth.instance.currentUser;
        final prefs = await SharedPreferences.getInstance();
        
        String userName = prefs.getString('full_name') ?? '';
        if (userName.isEmpty) {
          userName = currentUser?.displayName ?? '';
        }
        
        final emailPrefix = (currentUser?.email ?? 'User').split('@')[0];
        final finalOpenerName = userName.isNotEmpty ? '$userName ($emailPrefix)' : emailPrefix;

        final securedPdf = await PdfSecurityUtils.applySecurityFeatures(
          originalPdf: File(localPath),
          userName: finalOpenerName,
          documentId: communicationId,
          digitalSignature: data['digital_signature']?.toString(),
          senderSignatureUrl: data['sender_signature_url']?.toString(),
          senderSealUrl: data['sender_seal_url']?.toString(),
        );

        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PdfViewPage(
                localFilePath: securedPdf.path,
                title: subject,
                communicationId: communicationId,
                attachments: data['attachments'] as List<dynamic>?,
              ),
            ),
          );
        }
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري تحميل وتجهيز الملف لعرضه داخل النظام...')));

      final docxUrl = data['generated_docx_url'] as String?;
      if (docxUrl == null || docxUrl.isEmpty) {
        throw 'لا يوجد ملف مرفق مع هذه المخاطبة (ربما تم إنشاؤها يدوياً)';
      }

      final ref = FirebaseStorage.instance.refFromURL(docxUrl);
      final bytes = await ref.getData(15 * 1024 * 1024);
      if (bytes == null) throw 'فشل تحميل المستند من الخادم';

      final dir = await getApplicationDocumentsDirectory();
      final docxFile = File('${dir.path}/downloaded_$communicationId.docx');
      await docxFile.writeAsBytes(bytes);

      final pdfFile = await convertDocxToPdf(docxFile);

      // --- Apply Security Features (Watermark & QR) ---
      final currentUser = FirebaseAuth.instance.currentUser;
      final prefs = await SharedPreferences.getInstance();
      
      String userName = prefs.getString('full_name') ?? '';
      if (userName.isEmpty) {
        userName = currentUser?.displayName ?? '';
      }
      
      final emailPrefix = (currentUser?.email ?? 'User').split('@')[0];
      
      // دمج الاسم العربي مع المعرف الإنجليزي لضمان ظهوره إذا لم يدعم الخط العربي
      final finalOpenerName = userName.isNotEmpty ? '$userName ($emailPrefix)' : emailPrefix;

      final securedPdf = await PdfSecurityUtils.applySecurityFeatures(
        originalPdf: pdfFile,
        userName: finalOpenerName,
        documentId: communicationId,
        digitalSignature: data['digital_signature']?.toString(),
        senderSignatureUrl: data['sender_signature_url']?.toString(),
        senderSealUrl: data['sender_seal_url']?.toString(),
      );
      // ------------------------------------------------

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfViewPage(
              localFilePath: securedPdf.path,
              title: subject,
              communicationId: communicationId,
              attachments: data['attachments'] as List<dynamic>?,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }


  static Future<File> convertDocxToPdf(File docxFile) async {
    if (!Platform.isWindows) {
      throw Exception('تحويل PDF مدعوم حاليًا على Windows فقط');
    }

    final pdfPath = docxFile.path.replaceAll('.docx', '.pdf');

    final script = r'''
param([string]$DocxPath, [string]$PdfPath)
$word = $null
$doc = $null
try {
  $word = New-Object -ComObject Word.Application
  $word.Visible = $false
  $doc = $word.Documents.Open($DocxPath)
  $doc.SaveAs([ref] $PdfPath, [ref] 17)
  $doc.Close()
  $word.Quit()
  Write-Output 'SUCCESS'
}
catch {
  if ($doc -ne $null) { $doc.Close() }
  if ($word -ne $null) { $word.Quit() }
  Write-Error $_.Exception.Message
  exit 1
}
''';

    final tempDir = await getTemporaryDirectory();
    final ps1File = File('${tempDir.path}/convert_${DateTime.now().millisecondsSinceEpoch}.ps1');
    await ps1File.writeAsString(script);

    final result = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        ps1File.path,
        docxFile.path,
        pdfPath,
      ],
    );

    if (ps1File.existsSync()) {
      try {
        ps1File.deleteSync();
      } catch (_) {}
    }

    if (result.exitCode != 0) {
      throw Exception(
        'فشل تحويل Word إلى PDF:\n${result.stderr}\n${result.stdout}',
      );
    }

    final pdfFile = File(pdfPath);
    if (!pdfFile.existsSync()) {
      throw Exception('تمت محاولة التحويل لكن ملف PDF غير موجود');
    }

    return pdfFile;
  }


}