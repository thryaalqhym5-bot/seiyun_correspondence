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
        final existingUsersByName = <String, String>{};
        for (var doc in existingUsersSnap.docs) {
          final data = doc.data();
          if (data['full_name'] != null) {
            existingUsersByName[data['full_name'].toString().trim()] = doc.id;
          }
          existingRoles[doc.id] = {
            'full_name': data['full_name'],
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
            
            // ربط الاسم بالموظف الموجود مسبقاً في حال تم رفع القيادات قبله
            if (existingUsersByName.containsKey(docName)) {
                userDocId = existingUsersByName[docName]!;
            } else {
                for (String existingName in existingUsersByName.keys) {
                    if (_areNamesMatching(existingName, docName)) {
                        userDocId = existingUsersByName[existingName]!;
                        break;
                    }
                }
            }
            
            String finalAdminTitle = adminTitle;
            String finalRole = 'staff';
            String? finalEmail; // سيكون فارغاً إلا لو تم تفعيله لاحقاً بواسطة النائب
            String finalName = docName;
            
            if (existingRoles.containsKey(userDocId)) {
              final existingData = existingRoles[userDocId]!;
              if (existingData['full_name'] != null) {
                 finalName = existingData['full_name'];
              }
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
            
            Map<String, dynamic> newAffiliation = {
              'college_id': collegeRef.id,
              'dept_id': departmentRefs[deptName]!.id,
              'administrative_title': finalAdminTitle,
              'secondary_administrative_title': 'none',
            };

            Map<String, dynamic> userData = {
              'full_name': finalName,
              'college_id': collegeRef.id,
              'dept_id': departmentRefs[deptName]!.id,
              'administrative_title': finalAdminTitle,
              'role': finalRole,
              'is_active': finalEmail != null, // يعتبر نشطاً فقط إذا كان له إيميل حقيقي
            };

            List<Map<String, dynamic>> finalAffiliations = [newAffiliation];

            if (existingRoles.containsKey(userDocId)) {
               var oldData = existingRoles[userDocId]!;
               
               userData['college_id'] = oldData['college_id'] ?? collegeRef.id;
               userData['dept_id'] = oldData['dept_id'] ?? departmentRefs[deptName]!.id;
               userData['administrative_title'] = oldData['administrative_title'] ?? finalAdminTitle;
               userData['secondary_administrative_title'] = oldData['secondary_administrative_title'] ?? 'none';

               List<Map<String, dynamic>> existingAffiliations = [];
               if (oldData['affiliations'] != null && oldData['affiliations'] is List) {
                  existingAffiliations = List<Map<String, dynamic>>.from(oldData['affiliations'].map((e) => Map<String, dynamic>.from(e)));
               } else {
                  existingAffiliations.add({
                    'college_id': oldData['college_id'] ?? '',
                    'dept_id': oldData['dept_id'] ?? '',
                    'administrative_title': oldData['administrative_title'] ?? 'staff',
                    'secondary_administrative_title': oldData['secondary_administrative_title'] ?? 'none',
                  });
               }
               
               bool exists = existingAffiliations.any((a) => a['college_id'] == collegeRef.id && a['administrative_title'] == finalAdminTitle);
               if (!exists) {
                  existingAffiliations.add(newAffiliation);
               }
               finalAffiliations = existingAffiliations;
            }

            userData['affiliations'] = finalAffiliations;
            userData['college_ids'] = finalAffiliations.map((e) => e['college_id'] as String).toList();
            userData['dept_ids'] = finalAffiliations.map((e) => e['dept_id'] as String).toList();
            userData['administrative_titles'] = finalAffiliations.map((e) => e['administrative_title'] as String).toList();
            
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
      res = res.replaceAll(RegExp(r'^(أ\.د\.|أ\.د|د\.|د/|أ\.|أ/|م\.|م/|الدكتور|المهندس|د |أ |م )\s*'), '');
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
    
    // تطابق الاسم الأول والأخير بدقة
    if (w1.first == w2.first && w1.last == w2.last && w1.length >= 2 && w2.length >= 2) {
        return true;
    }
    
    // التقاطع (عدد الكلمات المشتركة)
    int common = s1.intersection(s2).length;
    if (common >= 3) {
      if (w1.first == w2.first) return true;
    }
    if (common >= 2 && (w1.length <= 3 || w2.length <= 3)) {
      if (w1.first == w2.first) return true;
    }
    
    return false;
  }

  /// دالة تصحيح المكررين وحذفهم
  Future<void> cleanDuplicates(Function(String) onProgress) async {
    try {
      onProgress('جاري فحص المستخدمين للبحث عن المكررين...');
      final snap = await _firestore.collection('allowed_users').get();
      List<DocumentSnapshot> allDocs = snap.docs;
      
      onProgress('تم العثور على ${allDocs.length} مستخدم. جاري البحث...');
      
      int deletedCount = 0;
      WriteBatch batch = _firestore.batch();
      
      Set<String> processedIds = {};
      
      for (int i = 0; i < allDocs.length; i++) {
        var doc1 = allDocs[i];
        if (processedIds.contains(doc1.id)) continue;
        
        var data1 = doc1.data() as Map<String, dynamic>?;
        if (data1 == null) continue;
        String name1 = data1['full_name']?.toString().trim() ?? '';
        if (name1.isEmpty) continue;
        
        List<DocumentSnapshot> duplicates = [doc1];
        
        for (int j = i + 1; j < allDocs.length; j++) {
          var doc2 = allDocs[j];
          if (processedIds.contains(doc2.id)) continue;
          
          var data2 = doc2.data() as Map<String, dynamic>?;
          if (data2 == null) continue;
          String name2 = data2['full_name']?.toString().trim() ?? '';
          if (name2.isEmpty) continue;
          
          if (_areNamesMatching(name1, name2)) {
            duplicates.add(doc2);
          }
        }
        
        if (duplicates.length > 1) {
          for (var d in duplicates) {
            processedIds.add(d.id);
          }
          
          // تحديد الحساب الذي سنحتفظ به (نفضل الحساب الخاص بالموظف ذو الـ ID الطويل لأنه يحتوي على القسم الصحيح)
          duplicates.sort((a, b) => b.id.length.compareTo(a.id.length));
          
          var docToKeep = duplicates.first;
          var dataToKeep = docToKeep.data() as Map<String, dynamic>;
          
          for (int k = 1; k < duplicates.length; k++) {
             var dup = duplicates[k];
             var dupData = dup.data() as Map<String, dynamic>;
             
             if (dupData['email'] != null && dupData['email'].toString().isNotEmpty) {
                 dataToKeep['email'] = dupData['email'];
                 dataToKeep['emails'] = dupData['emails'] ?? dataToKeep['emails'];
             }
             if (dupData['is_active'] == true) {
                 dataToKeep['is_active'] = true;
             }
             if (dupData['is_registered'] == true) {
                 dataToKeep['is_registered'] = true;
             }
             if (dupData['administrative_title'] != null && dupData['administrative_title'] != 'staff') {
                 dataToKeep['administrative_title'] = dupData['administrative_title'];
                 dataToKeep['secondary_administrative_title'] = dupData['secondary_administrative_title'] ?? 'none';
                 dataToKeep['raw_title'] = dupData['raw_title'] ?? dataToKeep['raw_title'];
             }
             if (dupData['full_name'] != null && dupData['full_name'].toString().contains('د.')) {
                 dataToKeep['full_name'] = dupData['full_name'];
             }
             if (dataToKeep['college_id'] == null || dataToKeep['college_id'].toString().isEmpty) {
                 dataToKeep['college_id'] = dupData['college_id'];
             }
             if (dataToKeep['dept_id'] == null || dataToKeep['dept_id'].toString().isEmpty) {
                 dataToKeep['dept_id'] = dupData['dept_id'];
             }
             
             batch.delete(dup.reference);
             deletedCount++;
          }
          
          batch.set(docToKeep.reference, dataToKeep, SetOptions(merge: true));

          // تحديث الحساب الموثق في حال كان قد سجل دخوله مسبقاً
          if (dataToKeep['email'] != null) {
              final usersQuery = await _firestore.collection('users').where('email', isEqualTo: dataToKeep['email']).get();
              if (usersQuery.docs.isNotEmpty) {
                  final userRef = _firestore.collection('users').doc(usersQuery.docs.first.id);
                  batch.update(userRef, {
                      'full_name': dataToKeep['full_name'],
                      'administrative_title': dataToKeep['administrative_title'],
                      'secondary_administrative_title': dataToKeep['secondary_administrative_title'] ?? 'none',
                      'college_id': dataToKeep['college_id'],
                      'dept_id': dataToKeep['dept_id'],
                      'is_active': dataToKeep['is_active'],
                  });
              }
          }
        }
      }
      
      if (deletedCount > 0) {
        onProgress('جاري حذف $deletedCount حساب مكرر ودمج بياناتهم...');
        await batch.commit();
        onProgress('تم تنظيف المكررين بنجاح!');
      } else {
        onProgress('لم يتم العثور على أي حسابات مكررة.');
      }
      
    } catch (e) {
      onProgress('حدث خطأ أثناء تنظيف المكررين: $e');
    }
  }

  Future<int> _processLeadershipData(List<List<dynamic>> rows, String sheetName, Function(String) onProgress) async {
      WriteBatch batch = _firestore.batch();
      int operationCount = 0;
      int maxBatchSize = 450;

      onProgress('جاري فحص البيانات السابقة لربط الأسماء...');
      final existingUsersSnap = await _firestore.collection('allowed_users').get();
      final existingUsersByName = <String, String>{};
      final existingUserData = <String, Map<String, dynamic>>{};
      for (var doc in existingUsersSnap.docs) {
        final data = doc.data();
        if (data['full_name'] != null) {
          existingUsersByName[data['full_name'].toString().trim()] = doc.id;
          existingUserData[doc.id] = data;
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
          
          Map<String, dynamic> newAffiliation = {
            'college_id': entityId,
            'dept_id': deptId.isNotEmpty ? deptId : '',
            'administrative_title': adminTitle,
            'secondary_administrative_title': secondaryTitle,
          };

          Map<String, dynamic> userData = {
            'full_name': name,
            'raw_title': position,
            'role': role,
            'college_id': entityId,
            'administrative_title': adminTitle,
            'secondary_administrative_title': secondaryTitle,
          };
          if (deptId.isNotEmpty) {
             userData['dept_id'] = deptId;
          }

          List<Map<String, dynamic>> finalAffiliations = [newAffiliation];

          // الحفاظ على الكلية والقسم الأصلية ودمج المناصب
          if (existingUserData.containsKey(userDocId)) {
             var oldData = existingUserData[userDocId]!;
             
             userData['college_id'] = oldData['college_id'] ?? entityId;
             userData['dept_id'] = oldData['dept_id'] ?? deptId;
             userData['administrative_title'] = oldData['administrative_title'] ?? adminTitle;
             userData['secondary_administrative_title'] = oldData['secondary_administrative_title'] ?? secondaryTitle;
             
             List<Map<String, dynamic>> existingAffiliations = [];
             if (oldData['affiliations'] != null && oldData['affiliations'] is List) {
                existingAffiliations = List<Map<String, dynamic>>.from(oldData['affiliations'].map((e) => Map<String, dynamic>.from(e)));
             } else {
                existingAffiliations.add({
                  'college_id': oldData['college_id'] ?? '',
                  'dept_id': oldData['dept_id'] ?? '',
                  'administrative_title': oldData['administrative_title'] ?? 'staff',
                  'secondary_administrative_title': oldData['secondary_administrative_title'] ?? 'none',
                });
             }
             
             bool exists = existingAffiliations.any((a) => a['college_id'] == entityId && a['administrative_title'] == adminTitle);
             if (!exists) {
                existingAffiliations.add(newAffiliation);
             }
             finalAffiliations = existingAffiliations;
          }

          userData['affiliations'] = finalAffiliations;
          userData['college_ids'] = finalAffiliations.map((e) => e['college_id'] as String).toList();
          userData['dept_ids'] = finalAffiliations.map((e) => e['dept_id'] as String).toList();
          userData['administrative_titles'] = finalAffiliations.map((e) => e['administrative_title'] as String).toList();

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
