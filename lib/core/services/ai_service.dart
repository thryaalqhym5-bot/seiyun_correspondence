import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

class AiService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// جلب الإعدادات (مفتاح API والمودل) من Firestore أو من متغيرات البيئة كبديل احتياطي
  Future<Map<String, String>> _getConfig() async {
    String? apiKey;
    String model = 'gemini-2.5-flash'; // الافتراضي لعام 2026

    try {
      final doc = await _firestore.collection('settings').doc('ai_config').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final key = data['api_key'] as String?;
        if (key != null && key.trim().isNotEmpty) {
          apiKey = key.trim();
        }
        final dbModel = data['model'] as String?;
        if (dbModel != null && dbModel.trim().isNotEmpty) {
          model = dbModel.trim();
        }
      }
    } catch (e) {
      debugPrint('Error fetching config from Firestore: $e');
    }

    // 2. كحل احتياطي، البحث في متغيرات البيئة (Environment variables)
    if (apiKey == null || apiKey.isEmpty) {
      apiKey = const String.fromEnvironment('GEMINI_API_KEY');
    }

    return {
      'api_key': apiKey.isEmpty ? '' : apiKey,
      'model': model,
    };
  }

  /// جلب قائمة النماذج المتاحة لمفتاح الـ API لتشخيص الأخطاء
  Future<List<String>> _listAvailableModels(String apiKey) async {
    try {
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey');
      final client = HttpClient();
      final request = await client.getUrl(url);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      client.close();
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(responseBody);
        final modelsList = data['models'] as List?;
        if (modelsList != null) {
          return modelsList
              .map((m) {
                final name = m['name'] as String? ?? '';
                return name.startsWith('models/') ? name.substring(7) : name;
              })
              .where((name) => name.isNotEmpty)
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error listing models: $e');
    }
    return [];
  }

  /// استخلاص بيانات المراسلة الرسمية من الملف المرفق باستخدام Gemini
  Future<Map<String, String>?> extractDocumentMetadata(PlatformFile file) async {
    if (file.path == null) {
      throw 'مسار الملف غير متوفر. الرجاء اختيار الملف مجدداً.';
    }

    // 1. تحديد نوع الميم (MimeType) بناءً على امتداد الملف
    final extension = file.name.split('.').last.toLowerCase();
    String mimeType;
    if (extension == 'pdf') {
      mimeType = 'application/pdf';
    } else if (extension == 'jpg' || extension == 'jpeg') {
      mimeType = 'image/jpeg';
    } else if (extension == 'png') {
      mimeType = 'image/png';
    } else {
      throw 'صيغة الملف غير مدعومة للمعالجة بالذكاء الاصطناعي. يرجى رفع ملف PDF أو صورة (JPG/PNG).';
    }

    // 2. التحقق من وجود مفتاح الـ API والإعدادات
    final config = await _getConfig();
    final apiKey = config['api_key']!;
    final modelName = config['model']!;

    if (apiKey.isEmpty) {
      throw 'لم يتم العثور على مفتاح Gemini API. يرجى إعداد مستند الإعدادات في Firestore تحت المسار:\n/settings/ai_config وإضافة حقل باسم api_key يحمل قيمة المفتاح.';
    }

    // 3. قراءة محتوى الملف وتحويله لـ Base64
    final File localFile = File(file.path!);
    if (!await localFile.exists()) {
      throw 'الملف المحدد غير موجود على الجهاز.';
    }

    final bytes = await localFile.readAsBytes();
    final base64Data = base64Encode(bytes);

    // 4. بناء الطلب وإرساله لـ Gemini
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 30);

    final promptText = 'أنت مساعد إداري خبير في أرشفة المراسلات الرسمية في جامعة سيئون. '
        'قم بقراءة وتحليل وثيقة الخطاب الرسمية المرفقة باللغة العربية بدقة فائقة، واستخلص الحقول الإدارية التالية:\n'
        '1. موضوع الخطاب بدقة وعناية واختصار (subject)\n'
        '2. اسم الجهة المرسِلة للخطاب بالكامل متبوعاً باسم الشخص الموقّع أسفل الخطاب إن وجد بين قوسين (senderName) (مثل: وزارة التعليم العالي والبحث العلمي (توقيع: د. خالد صالح)، أو جامعة سيئون - كلية الحاسبات (توقيع: فهمي عبد الله الكثيري))\n'
        '3. الرقم المرجعي أو الإشاري للخطاب المكتوب في الأعلى (referenceNumber) (مثل: و ت/123/2026 أو م خ/90)\n'
        '4. تاريخ الخطاب بصيغة YYYY-MM-DD (date)\n\n'
        'يجب إرجاع النتيجة كـ JSON كائن فقط (Object) يطابق البنية التالية تماماً دون أي كتابة خارجها:\n'
        '{\n'
        '  "subject": "موضوع الخطاب المستخلص",\n'
        '  "senderName": "الجهة المرسلة المستخلصة (توقيع: اسم الموقع إن وجد)",\n'
        '  "referenceNumber": "الرقم المرجعي المستخلص",\n'
        '  "date": "التاريخ المستخلص بصيغة YYYY-MM-DD"\n'
        '}';

    final requestPayload = {
      'contents': [
        {
          'parts': [
            {'text': promptText},
            {
              'inlineData': {
                'mimeType': mimeType,
                'data': base64Data,
              }
            }
          ]
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
      }
    };

    final modelsToTry = [modelName, 'gemini-1.5-flash', 'gemini-2.0-flash-lite', 'gemini-pro'];

    for (int i = 0; i < modelsToTry.length; i++) {
      final currentModel = modelsToTry[i];
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$currentModel:generateContent?key=$apiKey');

      try {
        final request = await client.postUrl(url);
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(requestPayload));

        final response = await request.close();
        final responseBody = await response.transform(utf8.decoder).join();

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseJson = jsonDecode(responseBody);
          
          final candidates = responseJson['candidates'] as List?;
          if (candidates == null || candidates.isEmpty) {
            throw 'لم يقم الذكاء الاصطناعي بتوليد أي رد.';
          }

          final parts = candidates[0]['content']?['parts'] as List?;
          if (parts == null || parts.isEmpty) {
            throw 'لم يتم العثور على محتوى مستخلص في رد الذكاء الاصطناعي.';
          }

          final String textResult = parts[0]['text'] as String? ?? '';
          final Map<String, dynamic> parsedResult = jsonDecode(textResult.trim());

          return {
            'subject': parsedResult['subject']?.toString() ?? '',
            'senderName': parsedResult['senderName']?.toString() ?? '',
            'referenceNumber': parsedResult['referenceNumber']?.toString() ?? '',
            'date': parsedResult['date']?.toString() ?? '',
          };
        } else {
          bool isRetryable = response.statusCode == 503 || response.statusCode == 429 || 
              responseBody.contains('high demand') || responseBody.contains('not found');
              
          if (i < modelsToTry.length - 1 && isRetryable) {
            debugPrint('Model $currentModel failed ($responseBody), retrying with next model...');
            continue; // Try next model
          }

          // فحص النماذج المتاحة للتشخيص
          final models = await _listAvailableModels(apiKey);
          
          String errMsg = 'فشل الاتصال بخدمة الذكاء الاصطناعي (كود: ${response.statusCode})';
          try {
            final errJson = jsonDecode(responseBody);
            if (errJson['error']?['message'] != null) {
              errMsg = 'خطأ: ${errJson['error']['message']}';
            }
          } catch (_) {}
          
          if (models.isNotEmpty) {
            errMsg += '\nالنماذج المتاحة لمفتاحك هي: ${models.join(", ")}';
          }
          throw errMsg;
        }
      } catch (e) {
        debugPrint('AI Extraction Error: $e');
        if (e is SocketException) {
          throw 'فشل في الاتصال بالإنترنت. يرجى التحقق من اتصال الشبكة وإعادة المحاولة.';
        }
        
        // If it's the last model, rethrow
        if (i == modelsToTry.length - 1) {
          rethrow;
        }
      }
    } // end of for loop
    
    // Fallback if loop ends without returning
    throw 'تعذر استخلاص البيانات من جميع النماذج المتاحة.';
  }
}
