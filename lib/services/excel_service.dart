import 'dart:io';
import 'package:excel/excel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
class ExcelService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// دالة رفع ملف الهيكل والأكاديميين (الملف الأول بدون إيميلات)
  Future<void> uploadExcelFile({required String filePath, required Function(String) onProgress}) async {
    try {
      if (filePath.isNotEmpty) {
        onProgress('جاري قراءة الملف المختار...');
        var bytes = File(filePath).readAsBytesSync();
        var excel = Excel.decodeBytes(bytes);

        // جلب المستخدمين الحاليين للحفاظ على أدوارهم وإيميلاتهم (إذا تمت إضافتها مسبقاً من قبل النائب)
        onProgress('جاري فحص البيانات السابقة...');
        final existingUsersSnap = await _firestore.collection('allowed_users').get();
        final existingRoles = <String, Map<String, dynamic>>{};
        for (var doc in existingUsersSnap.docs) {
          final data = doc.data();
          existingRoles[doc.id] = {
            'administrative_title': data['administrative_title'],
            'role': data['role'],
            'email': data['email'], // قد يكون لديهم إيميل حقيقي تمت إضافته لاحقاً
          };
        }

        WriteBatch batch = _firestore.batch();
        int operationCount = 0;
        int maxBatchSize = 450; 

        onProgress('جاري تنظيف الأقسام القديمة...');
        final oldDepts = await _firestore.collection('departments').get();
        for (var doc in oldDepts.docs) {
          batch.delete(doc.reference);
          operationCount++;
          if (operationCount >= maxBatchSize) {
            await batch.commit();
            batch = _firestore.batch();
            operationCount = 0;
          }
        }
        if (operationCount > 0) {
          await batch.commit();
          batch = _firestore.batch();
          operationCount = 0;
        }
        onProgress('تم التنظيف. جاري استيراد البيانات وبناء الهيكل...');

        for (var table in excel.tables.keys) {
          String collegeName = table.trim();
          onProgress('جاري معالجة بيانات $collegeName...');

          DocumentReference collegeRef = _firestore.collection('colleges').doc(collegeName);
          batch.set(collegeRef, {
            'name': collegeName,
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          operationCount++;

          Map<String, DocumentReference> departmentRefs = {};

          var tableObj = excel.tables[table]!;
          var rows = tableObj.rows;
          
          String getCellStringSafe(int r, int c) {
            if (r >= rows.length || c >= rows[r].length || rows[r][c] == null) return '';
            var val = rows[r][c]?.value;
            if (val == null) return ''; 
            if (val is TextCellValue) return val.value.text ?? '';
            if (val is IntCellValue) return val.value.toString();
            if (val is DoubleCellValue) return val.value.toString();
            return val.toString();
          }

          int nameIdx = 1, titleIdx = 2, deptIdx = 3, notesIdx = 5;
          
          for (int r = 0; r < 10 && r < rows.length; r++) {
            bool foundHeaderRow = false;
            for (int c = 0; c < rows[r].length; c++) {
              String cellValue = getCellStringSafe(r, c).trim();
              if (cellValue.isEmpty) continue;
              if (cellValue == 'الاسم' || cellValue.contains('الاسم')) { nameIdx = c; foundHeaderRow = true; }
              else if (cellValue.contains('اللقب')) { titleIdx = c; foundHeaderRow = true; }
              else if (cellValue == 'القسم' || cellValue.contains('القسم')) { deptIdx = c; foundHeaderRow = true; }
              else if (cellValue.contains('ملاحظات')) { notesIdx = c; foundHeaderRow = true; }
            }
            if (foundHeaderRow) break;
          }
          
          for (int i = 1; i < rows.length; i++) {
            var row = rows[i];
            if (row.isEmpty) continue;

            String getCellString(int index) {
              if (index >= row.length || row[index] == null) return '';
              var val = row[index]?.value;
              if (val == null) return ''; 
              if (val is TextCellValue) return val.value.text ?? '';
              if (val is IntCellValue) return val.value.toString();
              if (val is DoubleCellValue) return val.value.toString();
              return val.toString();
            }

            String docName = getCellString(nameIdx).trim(); 
            if (docName.isEmpty || docName == 'الاسم' || docName.contains('كشف')) {
              continue; 
            }

            String notes = getCellString(notesIdx).trim();
            if (notes.contains('متوفي') || notes.contains('متقاعد')) {
              continue; 
            }
            
            String adminTitle = getCellString(titleIdx).trim();
            if (adminTitle.isEmpty) adminTitle = 'staff';
            
            String deptName = getCellString(deptIdx).trim();
            if (deptName.isEmpty) deptName = 'قسم عام';

            if (!departmentRefs.containsKey(deptName)) {
              String uniqueDeptId = '${collegeName}_$deptName';
              DocumentReference deptRef = _firestore.collection('departments').doc(uniqueDeptId);
              batch.set(deptRef, {
                'name': deptName,
                'college_id': collegeRef.id,
                'updated_at': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
              departmentRefs[deptName] = deptRef;
              operationCount++;
            }

            // إنشاء معرف ثابت للموظف لمنع التكرار عند إعادة الرفع (استبدال المسافات بشرطة سفلية)
            String userDocId = '${collegeName}_${deptName}_$docName'.replaceAll(RegExp(r'\s+'), '_');
            
            String finalAdminTitle = adminTitle;
            String finalRole = 'staff';
            String? finalEmail; // سيكون فارغاً إلا لو تم تفعيله لاحقاً بواسطة النائب
            
            if (existingRoles.containsKey(userDocId)) {
              final existingData = existingRoles[userDocId]!;
              if (existingData['administrative_title'] != null && existingData['administrative_title'] != 'staff') {
                finalAdminTitle = existingData['administrative_title'];
              }
              if (existingData['role'] != null) {
                finalRole = existingData['role'];
              }
              if (existingData['email'] != null) {
                finalEmail = existingData['email'];
              }
            }

            DocumentReference userRef = _firestore.collection('allowed_users').doc(userDocId);
            
            Map<String, dynamic> userData = {
              'full_name': docName,
              'college_id': collegeRef.id,
              'dept_id': departmentRefs[deptName]!.id,
              'administrative_title': finalAdminTitle,
              'role': finalRole,
              'is_active': finalEmail != null, // يعتبر نشطاً فقط إذا كان له إيميل حقيقي
            };
            
            // إضافة الإيميل للبيانات المرفوعة فقط إن وجد سابقاً
            if (finalEmail != null) {
              userData['email'] = finalEmail;
            }
            
            batch.set(userRef, userData, SetOptions(merge: true));
            operationCount++;

            if (operationCount >= maxBatchSize) {
              onProgress('جاري رفع حزمة بيانات للسيرفر...');
              await batch.commit();
              batch = _firestore.batch();
              operationCount = 0;
            }
          }
        }

        if (operationCount > 0) {
          onProgress('جاري استكمال رفع البيانات...');
          await batch.commit();
        }

        onProgress('تم تأسيس هيكل الجامعة والأكاديميين بنجاح!');
      }
    } catch (e) {
      onProgress('حدث خطأ أثناء رفع الملف: $e');
    }
  }

  /// دالة استيراد ملف القيادات الذكي (الملف الثاني)
  Future<void> importLeadershipExcel({required String filePath, required Function(String) onProgress}) async {
    try {
      if (filePath.isEmpty) return;
      onProgress('جاري قراءة ملف القيادات...');

      List<List<dynamic>> rows = [];
      String sheetName = 'القيادات';
      int totalAdded = 0;

      if (filePath.toLowerCase().endsWith('.csv')) {
        onProgress('جاري معالجة ملف CSV...');
        String rawData = await File(filePath).readAsString(); // يفترض أن الترميز UTF-8
        List<String> lines = rawData.split('\n');

        // تخطي أول 5 أسطر
        int skipLines = 5;
        if (lines.length > skipLines) {
           String cleanData = lines.sublist(skipLines).join('\n');
           
           // نحاول تحديد الفاصل التلقائي بناءً على تكرار الفاصلة والفاصلة المنقوطة في أول سطر
           String firstLine = lines.sublist(skipLines).firstWhere((element) => element.trim().isNotEmpty, orElse: () => '');
           String delimiter = firstLine.split(';').length > firstLine.split(',').length ? ';' : ',';

           rows = Csv(fieldDelimiter: delimiter).decode(cleanData);
        } else {
            onProgress('الملف فارغ أو لا يحتوي على بيانات كافية (يجب أن يحتوي على أكثر من 5 أسطر).');
            return;
        }

        totalAdded += await _processLeadershipData(rows, sheetName, onProgress);

      } else {
        var bytes = File(filePath).readAsBytesSync();
        var excel = Excel.decodeBytes(bytes);

        for (var table in excel.tables.keys) {
          sheetName = table.trim();
          var tableObj = excel.tables[table]!;
          rows = tableObj.rows.map((row) => row.map((cell) => cell?.value).toList()).toList();
          totalAdded += await _processLeadershipData(rows, sheetName, onProgress);
        }
      }

      if (totalAdded == 0) {
        throw Exception('لم يتم العثور على أي قيادي لإضافته! تأكد من أن الملف يحتوي على أعمدة (الاسم، المنصب) وأنها مكتوبة بشكل صحيح في أول 20 سطر.');
      }

      onProgress('تم استيراد بيانات $totalAdded قيادي بنجاح!');
    } catch (e) {
      onProgress('حدث خطأ أثناء رفع ملف القيادات: $e');
      throw e;
    }
  }

  // دالة مساعدة لتوحيد الأسماء للبحث المتقدم
  bool _areNamesMatching(String name1, String name2) {
    String clean(String n) {
      // إزالة المسافات قبل وبعد النص أولاً
      String res = n.trim();
      // إزالة الألقاب العلمية
      res = res.replaceAll(RegExp(r'^(أ\.د\.|أ\.د|د\.|د|أ\.|أ|م\.|م|د/|أ/|م/|الدكتور|المهندس)\s*'), '');
      // توحيد الحروف العربية لتجنب أخطاء الإدخال
      res = res.replaceAll(RegExp(r'[أإآ]'), 'ا');
      res = res.replaceAll('ة', 'ه');
      res = res.replaceAll('ى', 'ي');
      return res.replaceAll(RegExp(r'\s+'), ' ').trim();
    }
    
    String n1 = clean(name1);
    String n2 = clean(name2);
    if (n1 == n2) return true;
    
    List<String> w1 = n1.split(' ');
    List<String> w2 = n2.split(' ');
    if (w1.isEmpty || w2.isEmpty) return false;
    
    Set<String> s1 = w1.toSet();
    Set<String> s2 = w2.toSet();
    
    // إذا كان أحدهما يحتوي على كل كلمات الآخر
    if (s1.containsAll(s2) || s2.containsAll(s1)) {
      return true;
    }
    
    // التقاطع (عدد الكلمات المشتركة)
    int common = s1.intersection(s2).length;
    if (common >= 3) return true; // يشتركان في 3 أسماء (مثلاً الاسم الأول واسم الأب واللقب)
    if (common >= 2 && (w1.length <= 3 || w2.length <= 3)) return true; // اسمان فقط وهما متطابقان
    
    return false;
  }

  Future<int> _processLeadershipData(List<List<dynamic>> rows, String sheetName, Function(String) onProgress) async {
      WriteBatch batch = _firestore.batch();
      int operationCount = 0;
      int maxBatchSize = 450;

      onProgress('جاري فحص البيانات السابقة لربط الأسماء...');
      final existingUsersSnap = await _firestore.collection('allowed_users').get();
      final existingUsersByName = <String, String>{};
      for (var doc in existingUsersSnap.docs) {
        final data = doc.data();
        if (data['full_name'] != null) {
          existingUsersByName[data['full_name'].toString().trim()] = doc.id;
        }
      }

        // دالة مساعدة لاستخراج النص من الخلية (تدعم CSV و Excel)
        String getCellStringSafe(int r, int c) {
          if (r >= rows.length || c >= rows[r].length || rows[r][c] == null) return '';
          var val = rows[r][c];
          if (val == null) return '';
          
          return val.toString().trim();
        }

        // دالة لاستخراج الإيميلات
        List<String> extractEmails(String rawEmailStr) {
          if (rawEmailStr.trim().isEmpty) return [];
          List<String> parts = rawEmailStr.split(RegExp(r'[\s,\n]+'));
          List<String> validEmails = [];
          for (String part in parts) {
            if (part.contains('@')) {
              validEmails.add(part.trim().toLowerCase());
            }
          }
          return validEmails;
        }

        onProgress('جاري معالجة الورقة: $sheetName...');

        // البحث الديناميكي عن الأعمدة في أول 5 صفوف
        int colIdx = -1, nameIdx = -1, posIdx = -1, emailIdx = -1;

        for (int r = 0; r < 20 && r < rows.length; r++) {
          for (int c = 0; c < rows[r].length; c++) {
            String cell = getCellStringSafe(r, c).trim();
            if (cell == 'الكلية' || cell.contains('كلية') || cell.contains('مركز') || cell.contains('الجهة')) { colIdx = c; }
            else if (cell.contains('الاسم')) { nameIdx = c; }
            else if (cell.contains('الدرجة') || cell.contains('العلمية')) { /* Skip */ }
            else if (cell.contains('المنصب')) { posIdx = c; }
            else if (cell.contains('الايميل') || cell.contains('الإيميل') || cell.contains('البريد')) { emailIdx = c; }
          }
          if (nameIdx != -1 && posIdx != -1) break; // توقف عند إيجاد الأعمدة الأساسية
        }

        if (nameIdx == -1 || posIdx == -1) {
          onProgress('تحذير: لم يتم العثور على أعمدة الاسم أو المنصب في ورقة $sheetName. جاري التخطي.');
          return 0;
        }

        String currentEntityName = sheetName.trim(); // كقيمة افتراضية

        for (int i = 1; i < rows.length; i++) {
          String name = getCellStringSafe(i, nameIdx).trim();
          if (name.isEmpty || name.contains('الاسم')) continue;

          // جلب أو تحديث الكيان (الكلية أو المركز)
          String entityNameFromCell = colIdx != -1 ? getCellStringSafe(i, colIdx).trim() : '';
          if (entityNameFromCell.isNotEmpty) {
            currentEntityName = entityNameFromCell;
          }

          // معالجة الكيان (استخدام نفس الاسم بدون استبدال المسافات لكي يتطابق مع الكليات الموجودة)
          String entityId = currentEntityName;
          
          if (currentEntityName.isNotEmpty) {
             DocumentReference collegeRef = _firestore.collection('colleges').doc(entityId);
             String entityType = 'college';
             if (currentEntityName.contains('مركز')) entityType = 'center';
             else if (currentEntityName == 'رئاسة الجامعة') entityType = 'presidency';

             batch.set(collegeRef, {
                'name': currentEntityName,
                'type': entityType,
                'updated_at': FieldValue.serverTimestamp(),
             }, SetOptions(merge: true));
          }

          // استخراج المناصب
          String position = getCellStringSafe(i, posIdx).trim();
          String rawEmail = emailIdx != -1 ? getCellStringSafe(i, emailIdx).trim() : '';
          List<String> extractedEmails = extractEmails(rawEmail);
          bool isActive = extractedEmails.isNotEmpty;
          
          // الإيميل الأساسي الذي سيستخدم كمعرف (ID) وفي حقل الـ email
          String primaryEmail = '';
          if (extractedEmails.isNotEmpty) {
             var uniEmails = extractedEmails.where((e) => e.endsWith('@seiyunu.edu.ye') || e.endsWith('@seiyun.edu.ye')).toList();
             if (uniEmails.isNotEmpty) {
                 primaryEmail = uniEmails.first;
             } else {
                 primaryEmail = extractedEmails.first;
             }
          }

          // إذا لم يوجد إيميل، نقوم بتوليد إيميل وهمي مؤقت لكي يُحفظ في النظام
          // يمكن للمدير تعديله لاحقاً من لوحة التحكم
          if (primaryEmail.isEmpty) {
              primaryEmail = 'temp_${DateTime.now().millisecondsSinceEpoch}_$i@seiyun.edu.ye';
              extractedEmails.add(primaryEmail);
          }

          // تحديد الـ role والـ administrative_title بناءً على المنصب
          String role = 'staff'; // القيمة الافتراضية للـ role في النظام هي دائماً staff (أو admin)
          String adminTitle = 'staff';
          String secondaryTitle = 'none';
          
          // يجب فحص (نائب) قبل (عميد) أو (رئيس) لتجنب الأخطاء
          if (position.contains('نائب') && position.contains('رئيس')) adminTitle = 'university_vp';
          else if (position.contains('رئيس الجامعة')) adminTitle = 'university_president';
          else if (position.contains('أمين') || position.contains('امين')) adminTitle = 'general_secretary';
          else if (position.contains('نائب') && (position.contains('عميد') || currentEntityName.contains('كلية'))) adminTitle = 'vice_dean';
          else if (position.contains('عميد')) adminTitle = 'dean';
          else if (position.contains('مدير') && currentEntityName.contains('مركز')) adminTitle = 'center_director';
          else if (position.contains('نائب') && currentEntityName.contains('مركز')) adminTitle = 'vice_director';
          else if (position.contains('مدير مركز') || position.contains('مدير المركز')) adminTitle = 'center_director';
          else if (position.contains('رئيس قسم')) adminTitle = 'head_of_department';
          else if (position.contains('مدير عام')) adminTitle = 'general_director';

          if (adminTitle == 'vice_dean' && position.contains('رئيس قسم')) {
              secondaryTitle = 'head_of_department';
          } else if (adminTitle == 'head_of_department' && position.contains('نائب عميد')) {
              adminTitle = 'vice_dean';
              secondaryTitle = 'head_of_department';
          }

          // إنشاء قسم خاص للقيادات في رئاسة الجامعة
          String deptId = '';
          if (currentEntityName == 'رئاسة الجامعة') {
             String deptName = position.trim(); 
             if (deptName.isEmpty) deptName = 'إدارة عامة';
             deptId = '${entityId}_$deptName'.replaceAll(RegExp(r'\s+'), '_');
             DocumentReference deptRef = _firestore.collection('departments').doc(deptId);
             batch.set(deptRef, {
               'name': deptName,
               'college_id': entityId,
               'updated_at': FieldValue.serverTimestamp(),
             }, SetOptions(merge: true));
          }

          // ربط الاسم بالموظف الموجود مسبقاً (إن وجد)
          String? userDocId;
          
          // بحث دقيق أولاً
          if (existingUsersByName.containsKey(name)) {
             userDocId = existingUsersByName[name]!;
          } else {
             // بحث ذكي مرن متقدم يتجاوز الألقاب والأسماء الوسطى المحذوفة
             for (String existingName in existingUsersByName.keys) {
               if (_areNamesMatching(existingName, name)) {
                 userDocId = existingUsersByName[existingName]!;
                 break;
               }
             }
          }
          
          if (userDocId == null) {
             if (primaryEmail.isEmpty) {
                 primaryEmail = 'temp_${DateTime.now().millisecondsSinceEpoch}_$i@seiyun.edu.ye';
                 extractedEmails.add(primaryEmail);
             }
             userDocId = primaryEmail;
          }

          DocumentReference userRef = _firestore.collection('allowed_users').doc(userDocId);
          
          Map<String, dynamic> userData = {
            'full_name': name,
            'administrative_title': adminTitle,
            'secondary_administrative_title': secondaryTitle,
            'raw_title': position, // Save exactly what was in the Excel file
            'role': role,
            'college_id': entityId,
          };
          if (deptId.isNotEmpty) {
             userData['dept_id'] = deptId;
          }
          if (primaryEmail.isNotEmpty) {
             userData['email'] = primaryEmail;
             userData['emails'] = extractedEmails;
             userData['is_active'] = isActive;
             userData['is_registered'] = false;
          }

          batch.set(userRef, userData, SetOptions(merge: true));
          
          operationCount++;

          if (operationCount >= maxBatchSize) {
            onProgress('جاري رفع حزمة بيانات للسيرفر...');
            await batch.commit();
            batch = _firestore.batch();
            operationCount = 0;
          }
        }

      if (operationCount > 0) {
        onProgress('جاري استكمال رفع بيانات القيادات...');
        await batch.commit();
      }
      return operationCount;

  }
}
