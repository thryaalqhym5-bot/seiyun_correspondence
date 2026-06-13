import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'package:barcode_image/barcode_image.dart' as bc;
import 'package:image/image.dart' as img;
import 'package:barcode/barcode.dart';

class PdfSecurityUtils {
  /// يُطبّق العلامة المائية والباركود على ملف PDF ويعيد ملفاً مؤقتاً جديداً
  static Future<File> applySecurityFeatures({
    required File originalPdf,
    required String userName,
    required String documentId,
    String? digitalSignature,
    String? senderSignatureUrl,
    String? senderSealUrl,
    bool skipWatermark = false,
  }) async {
    try {
      // 1. قراءة الـ PDF الأصلي
      final List<int> bytes = await originalPdf.readAsBytes();
      final PdfDocument document = PdfDocument(inputBytes: bytes);

      final PdfFont watermarkFont = PdfStandardFont(PdfFontFamily.helvetica, 16);
      final PdfFont footerFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
      
      // 2. توليد الباركود كصورة (PNG Bytes)
      PdfBitmap? qrBitmap;
      final String finalHash = (digitalSignature != null && digitalSignature.isNotEmpty) 
          ? digitalSignature 
          : 'legacy_$documentId';
          
      final verifyUrl = 'https://seiyun.edu.ye/verify?id=$documentId&hash=$finalHash';
      
      // إنشاء صورة بثلاث قنوات (RGB) لتجنب مشكلة الشفافية التي تجعل الباركود مخفياً
      final image = img.Image(width: 200, height: 200, numChannels: 3);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));
      
      // رسم الباركود باللون الأسود
      bc.drawBarcode(
        image, 
        Barcode.qrCode(), 
        verifyUrl, 
      );
      
      final pngBytes = img.encodePng(image);
      qrBitmap = PdfBitmap(pngBytes);
      
      // 3. تحميل صورة التوقيع الإلكتروني إذا وجدت (مع ميزة التخزين المحلي للأوفلاين)
      PdfBitmap? signatureBitmap;
      if (senderSignatureUrl != null && senderSignatureUrl.isNotEmpty) {
        try {
          final tempDir = await getTemporaryDirectory();
          // إنشاء اسم فريد للصورة بناءً على الرابط
          final String sigFileName = 'sig_${senderSignatureUrl.hashCode}.png';
          final File localSigFile = File('${tempDir.path}/$sigFileName');
          
          List<int> sigBytes;
          
          // إذا كانت الصورة موجودة مسبقاً في الجهاز (تم فتحها من قبل)
          if (localSigFile.existsSync()) {
            sigBytes = await localSigFile.readAsBytes();
          } else {
            // إذا لم تكن موجودة، قم بتحميلها من الإنترنت
            final client = HttpClient();
            final request = await client.getUrl(Uri.parse(senderSignatureUrl));
            final response = await request.close();
            final builder = BytesBuilder();
            await for (var chunk in response) {
              builder.add(chunk);
            }
            sigBytes = builder.toBytes();
            
            // حفظها في الجهاز للمرات القادمة
            if (sigBytes.isNotEmpty) {
              await localSigFile.writeAsBytes(sigBytes);
            }
          }
          
          if (sigBytes.isNotEmpty) {
            signatureBitmap = PdfBitmap(sigBytes);
          }
        } catch (e) {
          debugPrint('Error loading signature image: $e');
        }
      }
      
      // 3.5 تحميل ختم الكلية إذا وجد (خارجي فقط - مع التخزين المحلي)
      PdfBitmap? sealBitmap;
      if (senderSealUrl != null && senderSealUrl.isNotEmpty) {
        try {
          final tempDir = await getTemporaryDirectory();
          final String sealFileName = 'seal_${senderSealUrl.hashCode}.png';
          final File localSealFile = File('${tempDir.path}/$sealFileName');
          
          List<int> sealBytes;
          if (localSealFile.existsSync()) {
            sealBytes = await localSealFile.readAsBytes();
          } else {
            final client = HttpClient();
            final request = await client.getUrl(Uri.parse(senderSealUrl));
            final response = await request.close();
            final builder = BytesBuilder();
            await for (var chunk in response) {
              builder.add(chunk);
            }
            sealBytes = builder.toBytes();
            if (sealBytes.isNotEmpty) {
              await localSealFile.writeAsBytes(sealBytes);
            }
          }
          if (sealBytes.isNotEmpty) {
            sealBitmap = PdfBitmap(sealBytes);
          }
        } catch (e) {
          debugPrint('Error loading seal image: $e');
        }
      }
      
      // المرور على جميع صفحات المستند
      for (int i = 0; i < document.pages.count; i++) {
        final PdfPage page = document.pages[i];
        final Size pageSize = page.getClientSize();
        final PdfGraphics graphics = page.graphics;

        // --- إضافة العلامة المائية (Watermark) ---
        if (!skipWatermark) {
          graphics.save(); // حفظ الحالة الحالية
          graphics.setTransparency(0.2); // جعلها شفافة (20% وضوح)
          
          graphics.translateTransform(pageSize.width / 2, pageSize.height / 2);
          graphics.rotateTransform(-45);
          
          graphics.drawString(
            'Opener: $userName', 
            watermarkFont,
            pen: PdfPen(PdfColor(255, 0, 0)), 
            brush: PdfBrushes.red,
            format: PdfStringFormat(
              alignment: PdfTextAlignment.center,
              lineAlignment: PdfVerticalAlignment.middle,
            ),
          );
          graphics.restore(); // العودة للحالة الأصلية
        }

        // --- إضافة رقم الوثيقة والباركود أسفل الصفحة ---
        // رسم الباركود كصورة (في كل الصفحات)
        if (qrBitmap != null) {
          graphics.drawImage(qrBitmap, Rect.fromLTWH(10, pageSize.height - 80, 70, 70));
        }
        
        // التوقيع والختم يجب أن يظهرا فقط في (الصفحة الأخيرة) من الوثيقة لتجنب تغطية النص في المستندات الطويلة
        if (i == document.pages.count - 1) {
          // رسم التوقيع المرئي للمرسل
        if (signatureBitmap != null) {
          // رفع التوقيع ليكون أقرب لاسم المرسل (pageSize.height - 300)
          graphics.drawImage(signatureBitmap, Rect.fromLTWH(50, pageSize.height - 300, 150, 80));
        } else if (senderSignatureUrl != null && senderSignatureUrl.isNotEmpty) {
          graphics.drawRectangle(
            brush: PdfBrushes.red,
            bounds: Rect.fromLTWH(50, pageSize.height - 300, 150, 80),
          );
          graphics.drawString('Signature Load Failed', footerFont, brush: PdfBrushes.white, bounds: Rect.fromLTWH(50, pageSize.height - 300, 150, 80));
        }
        
        // رسم ختم الكلية
        if (sealBitmap != null) {
          final double sealWidth = 100;
          final double sealHeight = 100;
          final double sealX = (pageSize.width - sealWidth) / 2;
          final double sealY = pageSize.height - 270; // رفع الختم أيضاً
          
          graphics.save();
          graphics.setTransparency(0.6); // شفافية 60%
          graphics.drawImage(sealBitmap, Rect.fromLTWH(sealX, sealY, sealWidth, sealHeight));
          graphics.restore();
        }
      } // نهاية شرط الصفحة الأخيرة

        graphics.drawString(
          'Doc ID: $documentId\nSeiyun University\nSecured & Verified', 
          footerFont,
          brush: PdfBrushes.black,
          bounds: Rect.fromLTWH(qrBitmap != null ? 90 : 20, pageSize.height - 60, 300, 60),
          format: PdfStringFormat(
            alignment: PdfTextAlignment.left,
            lineAlignment: PdfVerticalAlignment.bottom,
          ),
        );
      }

      // حفظ الملف في مسار مؤقت
      final List<int> savedBytes = await document.save();
      document.dispose();

      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath = '${tempDir.path}/secured_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final File securedFile = File(tempPath);
      await securedFile.writeAsBytes(savedBytes);

      return securedFile;
    } catch (e) {
      debugPrint('Error applying PDF security: $e');
      // في حالة الفشل، نعود بالملف الأصلي حتى لا يتعطل العرض
      return originalPdf;
    }
  }
}
