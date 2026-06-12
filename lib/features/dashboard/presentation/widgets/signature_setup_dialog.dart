import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_signaturepad/signaturepad.dart';
import 'package:image/image.dart' as img;
import '../../../../core/theme/app_colors.dart';

class SignatureSetupDialog extends StatefulWidget {
  const SignatureSetupDialog({super.key});

  @override
  State<SignatureSetupDialog> createState() => _SignatureSetupDialogState();
}

class _SignatureSetupDialogState extends State<SignatureSetupDialog> {
  final GlobalKey<SfSignaturePadState> _signaturePadKey = GlobalKey();
  bool _isSaving = false;

  void _handleClear() {
    _signaturePadKey.currentState?.clear();
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    try {
      final data = await _signaturePadKey.currentState?.toImage(pixelRatio: 3.0);
      if (data == null) {
        throw 'الرجاء رسم التوقيع أولاً';
      }
      final byteData = await data.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();
      
      // Auto-crop transparent pixels
      img.Image? decodedImage = img.decodePng(pngBytes);
      Uint8List finalBytes = pngBytes;
      
      if (decodedImage != null) {
        int minX = decodedImage.width;
        int minY = decodedImage.height;
        int maxX = 0;
        int maxY = 0;

        for (int y = 0; y < decodedImage.height; y++) {
          for (int x = 0; x < decodedImage.width; x++) {
            final pixel = decodedImage.getPixel(x, y);
            if (pixel.a > 0) {
              if (x < minX) minX = x;
              if (y < minY) minY = y;
              if (x > maxX) maxX = x;
              if (y > maxY) maxY = y;
            }
          }
        }

        if (maxX >= minX && maxY >= minY) {
          // Add a small padding (e.g. 5 pixels)
          minX = (minX - 5).clamp(0, decodedImage.width - 1);
          minY = (minY - 5).clamp(0, decodedImage.height - 1);
          maxX = (maxX + 5).clamp(0, decodedImage.width - 1);
          maxY = (maxY + 5).clamp(0, decodedImage.height - 1);
          
          final cropped = img.copyCrop(decodedImage, x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1);
          finalBytes = Uint8List.fromList(img.encodePng(cropped));
        }
      }
      
      if (mounted) {
        Navigator.pop(context, finalBytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('إعداد التوقيع الإلكتروني', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 500,
        height: 300,
        child: Column(
          children: [
            const Text(
              'قم برسم توقيعك المعتمد داخل المربع الأبيض أدناه. سيتم استخدام هذا التوقيع في جميع المراسلات الصادرة منك.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SfSignaturePad(
                    key: _signaturePadKey,
                    backgroundColor: Colors.transparent,
                    strokeColor: Colors.blue[900]!, // التوقيع بلون أزرق رسمي
                    minimumStrokeWidth: 2.0,
                    maximumStrokeWidth: 4.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : _handleClear,
          child: const Text('مسح وإعادة الرسم', style: TextStyle(color: Colors.orangeAccent)),
        ),
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _handleSave,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: _isSaving 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('اعتماد وحفظ', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
