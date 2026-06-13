import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/custom_text_field.dart';
import 'departments_page.dart';

class CollegesPage extends StatefulWidget {
  const CollegesPage({super.key});

  @override
  State<CollegesPage> createState() => _CollegesPageState();
}

class _CollegesPageState extends State<CollegesPage> {
  String searchQuery = '';
  final TextEditingController collegeIdController = TextEditingController();
  final TextEditingController collegeNameController = TextEditingController();
  final TextEditingController entityCodeController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    collegeIdController.dispose();
    collegeNameController.dispose();
    entityCodeController.dispose();
    super.dispose();
  }

  Future<void> _addCollege() async {
    final collegeId = collegeIdController.text.trim();
    final collegeName = collegeNameController.text.trim();
    final entityCode = entityCodeController.text.trim();

    if (collegeId.isEmpty || collegeName.isEmpty || entityCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال جميع البيانات')),
      );
      return;
    }

    final existingDoc = await FirebaseFirestore.instance.collection('colleges').doc(collegeId).get();
    if (existingDoc.exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('معرف الكلية موجود مسبقاً!'), backgroundColor: AppColors.danger),
        );
      }
      return;
    }

    await FirebaseFirestore.instance.collection('colleges').doc(collegeId).set({
      'name': collegeName,
      'entity_code': entityCode,
      'is_active': true,
      'created_at': FieldValue.serverTimestamp(),
    });

    collegeIdController.clear();
    collegeNameController.clear();
    entityCodeController.clear();

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إضافة الكلية بنجاح', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.success),
      );
    }
  }

  Future<void> _uploadSeal(String docId) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('جاري رفع الختم...')),
        );

        final File file = File(result.files.single.path!);
        final storageRef = FirebaseStorage.instance.ref().child('colleges_seals/$docId.png');
        await storageRef.putFile(file);
        final downloadUrl = await storageRef.getDownloadURL();

        await FirebaseFirestore.instance.collection('colleges').doc(docId).update({
          'seal_url': downloadUrl,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم رفع الختم بنجاح', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.success),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء الرفع: $e', style: const TextStyle(color: Colors.white)), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('إضافة جهة/كلية جديدة', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(
                  controller: collegeIdController,
                  labelText: 'معرف الكلية الإنجليزي (مثال: eng_college)',
                  prefixIcon: Icons.code,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: collegeNameController,
                  labelText: 'اسم الكلية أو الجهة',
                  prefixIcon: Icons.account_balance,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: entityCodeController,
                  labelText: 'رمز الأرشيف (مثال: 01)',
                  prefixIcon: Icons.archive,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                collegeIdController.clear();
                collegeNameController.clear();
                entityCodeController.clear();
                Navigator.pop(context);
              },
              child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: _addCollege,
              child: const Text('إضافة'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteDialog(String docId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.danger),
              SizedBox(width: 8),
              Text('تأكيد الحذف', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: const Text('هل أنت متأكد من حذف هذه الكلية؟', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger.withValues(alpha: 0.2), foregroundColor: AppColors.danger, elevation: 0),
              onPressed: () async {
                Navigator.pop(context);
                await FirebaseFirestore.instance.collection('colleges').doc(docId).delete();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحذف بنجاح')));
                }
              },
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );
  }

  void _showEditEntityCodeDialog(String docId, String currentCode) {
    final TextEditingController editController = TextEditingController(text: currentCode == 'غير محدد' ? '' : currentCode);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تعديل رمز الأرشيف', style: TextStyle(color: Colors.white)),
          content: CustomTextField(
            controller: editController,
            labelText: 'رمز الأرشيف للكلية (مثال: EDU, MED)',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                if (editController.text.trim().isEmpty) return;
                Navigator.pop(context);
                await FirebaseFirestore.instance.collection('colleges').doc(docId).update({
                  'entity_code': editController.text.trim(),
                  'updated_at': FieldValue.serverTimestamp(),
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث الرمز بنجاح')));
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'الكليات والأقسام',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _showAddDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('إضافة جهة/كلية', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Data Table Card
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('colleges').orderBy('name').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('لا توجد كليات مضافة بعد.', style: TextStyle(color: Colors.white54)));
                    }

                    final docs = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = (data['name'] ?? '').toString().toLowerCase();
                      return name.contains(searchQuery);
                    }).toList();

                    return AppCard(
                      padding: const EdgeInsets.all(0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Toolbar
                          Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${docs.length} جهة',
                                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                                SizedBox(
                                  width: 300,
                                  child: TextField(
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'ابحث عن جهة أو كلية...',
                                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                                      prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
                                      filled: true,
                                      fillColor: AppColors.surface2,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                    ),
                                    onChanged: (val) => setState(() => searchQuery = val.toLowerCase()),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Colors.white10),
                          
                          // DataTable
                          Expanded(
                            child: RawScrollbar(
                              controller: _scrollController,
                              thumbVisibility: true,
                              thumbColor: AppColors.primary.withValues(alpha: 0.5),
                              thickness: 6,
                              radius: const Radius.circular(8),
                              child: SingleChildScrollView(
                                controller: _scrollController,
                                scrollDirection: Axis.vertical,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(AppColors.surface2.withValues(alpha: 0.5)),
                                    dataRowMinHeight: 70,
                                    dataRowMaxHeight: 80,
                                    horizontalMargin: 24,
                                    columnSpacing: 40,
                                    columns: const [
                                      DataColumn(label: Text('اسم الكلية / الجهة', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('المعرف (ID)', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('رمز الأرشيف', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('الختم الرسمي', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('الإجراءات', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold))),
                                    ],
                                    rows: docs.map((doc) {
                                      final data = doc.data() as Map<String, dynamic>;
                                      final name = data['name'] ?? 'بدون اسم';
                                      final entityCode = data['entity_code'] ?? 'غير محدد';
                                      final sealUrl = data['seal_url'] as String?;
                                      
                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 16,
                                                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                                  child: const Icon(Icons.account_balance, color: AppColors.primary, size: 16),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                          DataCell(Text(doc.id, style: const TextStyle(color: Colors.white70))),
                                          DataCell(
                                            InkWell(
                                              onTap: () => _showEditEntityCodeDialog(doc.id, entityCode),
                                              borderRadius: BorderRadius.circular(12),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: AppColors.purple.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: AppColors.purple.withValues(alpha: 0.2)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      entityCode,
                                                      style: const TextStyle(color: AppColors.purple, fontSize: 12, fontWeight: FontWeight.bold),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    const Icon(Icons.edit, size: 12, color: AppColors.purple),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Row(
                                              children: [
                                                if (sealUrl != null && sealUrl.isNotEmpty)
                                                  const Icon(Icons.verified, color: AppColors.success, size: 20)
                                                else
                                                  const Icon(Icons.cancel, color: Colors.white38, size: 20),
                                                const SizedBox(width: 8),
                                                TextButton.icon(
                                                  onPressed: () => _uploadSeal(doc.id),
                                                  icon: const Icon(Icons.upload_file, size: 16),
                                                  label: const Text('رفع الختم', style: TextStyle(fontSize: 12)),
                                                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                                                ),
                                              ],
                                            ),
                                          ),
                                          DataCell(
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: AppColors.surface2,
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                    elevation: 0,
                                                  ),
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(builder: (_) => DepartmentsPage(collegeId: doc.id, collegeName: name)),
                                                    );
                                                  },
                                                  icon: const Icon(Icons.account_tree_outlined, size: 16),
                                                  label: const Text('الأقسام', style: TextStyle(fontSize: 12)),
                                                ),
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                                                  onPressed: () => _showDeleteDialog(doc.id),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
