import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/custom_text_field.dart';

import 'department_users_page.dart';

class DepartmentsPage extends StatefulWidget {
  final String collegeId;
  final String collegeName;
  final bool showBackButton;

  const DepartmentsPage({
    super.key,
    required this.collegeId,
    required this.collegeName,
    this.showBackButton = true,
  });

  @override
  State<DepartmentsPage> createState() => _DepartmentsPageState();
}

class _DepartmentsPageState extends State<DepartmentsPage> {
  String searchQuery = '';
  final TextEditingController searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final TextEditingController deptIdController = TextEditingController();
  final TextEditingController deptNameController = TextEditingController();
  final TextEditingController deptCodeController = TextEditingController();
  final TextEditingController managerIdController = TextEditingController();
  final TextEditingController parentDeptIdController = TextEditingController();
  final TextEditingController sortOrderController = TextEditingController();

  late Stream<QuerySnapshot> _departmentsStream;

  @override
  void initState() {
    super.initState();
    _departmentsStream = FirebaseFirestore.instance
        .collection('departments')
        .where('college_id', isEqualTo: widget.collegeId)
        .snapshots();
  }

  @override
  void dispose() {
    searchController.dispose();
    _scrollController.dispose();
    deptIdController.dispose();
    deptNameController.dispose();
    deptCodeController.dispose();
    managerIdController.dispose();
    parentDeptIdController.dispose();
    sortOrderController.dispose();
    super.dispose();
  }

  Future<void> _deleteDepartment(String deptId, String deptName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF112240),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white)),
        content: Text(
          'هل أنت متأكد من حذف "$deptName"؟',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('departments').doc(deptId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حذف $deptName')));
      }
    }
  }

  void _showAddDepartmentDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF112240),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: const Text('إضافة قسم جديد', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomTextField(controller: deptIdController, labelText: 'معرف القسم'),
                  const SizedBox(height: 12),
                  CustomTextField(controller: deptNameController, labelText: 'اسم القسم'),
                  const SizedBox(height: 12),
                  CustomTextField(controller: deptCodeController, labelText: 'رمز القسم'),
                  const SizedBox(height: 12),
                  CustomTextField(controller: parentDeptIdController, labelText: 'القسم الأعلى (اختياري)'),
                  const SizedBox(height: 12),
                  CustomTextField(controller: managerIdController, labelText: 'UID المدير (اختياري)'),
                  const SizedBox(height: 12),
                  CustomTextField(controller: sortOrderController, labelText: 'ترتيب العرض', keyboardType: TextInputType.number),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, foregroundColor: Colors.white),
              onPressed: () async {
                final deptId = deptIdController.text.trim();
                final deptName = deptNameController.text.trim();
                final deptCode = deptCodeController.text.trim();
                final managerId = managerIdController.text.trim();
                final parentDeptId = parentDeptIdController.text.trim();
                final sortOrderText = sortOrderController.text.trim();

                if (deptId.isEmpty || deptName.isEmpty || deptCode.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('أدخلي معرف القسم واسم القسم والرمز')),
                  );
                  return;
                }

                final existingDoc = await FirebaseFirestore.instance.collection('departments').doc(deptId).get();
                if (existingDoc.exists) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('معرف القسم موجود مسبقاً، يرجى اختيار معرف آخر!'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                  return;
                }

                final sortOrder = int.tryParse(sortOrderText) ?? 0;

                await FirebaseFirestore.instance.collection('departments').doc(deptId).set({
                  'dept_id': deptId,
                  'dept_name': deptName,
                  'dept_code': deptCode,
                  'college_id': widget.collegeId,
                  'parent_dept_id': parentDeptId.isEmpty ? null : parentDeptId,
                  'manager_id': managerId.isEmpty ? null : managerId,
                  'is_active': true,
                  'sort_order': sortOrder,
                  'created_at': FieldValue.serverTimestamp(),
                  'updated_at': FieldValue.serverTimestamp(),
                });

                deptIdController.clear();
                deptNameController.clear();
                deptCodeController.clear();
                managerIdController.clear();
                parentDeptIdController.clear();
                sortOrderController.clear();

                if (!mounted) return;
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تمت إضافة القسم بنجاح')),
                );
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editDepartment(String deptId, String currentName) async {
    final TextEditingController nameController = TextEditingController(text: currentName);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF112240),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          title: const Text('تعديل اسم القسم', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomTextField(controller: nameController, labelText: 'اسم القسم الجديد'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حفظ التعديلات'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final newName = nameController.text.trim();
      if (newName.isNotEmpty && newName != currentName) {
        await FirebaseFirestore.instance.collection('departments').doc(deptId).update({
          'dept_name': newName,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث اسم القسم بنجاح')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // تعتمد على خلفية DashboardLayout
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Breadcrumbs
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (widget.showBackButton) ...[
                            InkWell(
                              onTap: () => Navigator.pop(context),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.surface2,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.arrow_back, color: Colors.white54, size: 18),
                                    SizedBox(width: 8),
                                    Text('العودة للكليات', style: TextStyle(color: Colors.white54, fontSize: 14)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Text(
                              '/  ',
                              style: TextStyle(color: Colors.white54, fontSize: 14),
                            ),
                          ],
                          const Text(
                            'إدارة الأقسام',
                            style: TextStyle(color: Colors.white54, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'أقسام ${widget.collegeName}',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      // Deans Display
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('allowed_users')
                            .where('college_ids', arrayContains: widget.collegeId)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
                          
                          final allUsers = snapshot.data!.docs;
                          final deanRoles = ['dean', 'vice_dean', 'vice_dean_student', 'vice_dean_academic', 'vice_dean_postgraduate', 'center_director', 'vice_director', 'general_director'];
                          
                          final List<Map<String, String>> displayLeaders = [];
                          
                          for (var doc in allUsers) {
                            final data = doc.data() as Map<String, dynamic>;
                            final name = data['full_name'] ?? data['name'] ?? '';
                            
                            String primaryTitle = '';
                            String secondaryTitle = '';
                            
                            if (data['affiliations'] != null && data['affiliations'] is List) {
                              final affs = data['affiliations'] as List;
                              for (var aff in affs) {
                                if (aff is Map && aff['college_id'] == widget.collegeId) {
                                  final pTitle = aff['administrative_title'] ?? '';
                                  final sTitle = aff['secondary_administrative_title'] ?? '';
                                  if (deanRoles.contains(pTitle) || deanRoles.contains(sTitle)) {
                                    primaryTitle = pTitle;
                                    secondaryTitle = sTitle;
                                    break; 
                                  }
                                }
                              }
                            } else {
                              primaryTitle = data['administrative_title'] ?? '';
                              secondaryTitle = data['secondary_administrative_title'] ?? '';
                            }
                            
                            if (deanRoles.contains(primaryTitle) || deanRoles.contains(secondaryTitle)) {
                              String title = 'عميد';
                              final isCenterDirector = primaryTitle == 'center_director' || secondaryTitle == 'center_director';
                              final isGeneralDirector = primaryTitle == 'general_director' || secondaryTitle == 'general_director';
                              final isDean = primaryTitle == 'dean' || secondaryTitle == 'dean';
                              
                              if (isDean) {
                                title = 'عميد';
                              } else if (isCenterDirector) {
                                title = 'مدير مركز';
                              } else if (isGeneralDirector) {
                                title = 'مدير عام';
                              } else {
                                title = 'نائب';
                              }
                              
                              displayLeaders.add({'name': name, 'title': title});
                            }
                          }

                          if (displayLeaders.isEmpty) return const SizedBox.shrink();

                          return Row(
                            children: displayLeaders.map((leader) {
                              final name = leader['name']!;
                              final title = leader['title']!;

                              return Padding(
                                padding: const EdgeInsets.only(left: 12.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.person, color: AppColors.primary, size: 16),
                                      const SizedBox(width: 6),
                                      Text('$title: $name', style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _showAddDepartmentDialog,
                    icon: const Icon(Icons.add_business),
                    label: const Text('إضافة قسم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Data Table Card
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _departmentsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return AppCard(child: _buildEmptyState('لا توجد أقسام مسجلة حالياً.'));
                    }

                    final docs = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = (data['dept_name'] ?? data['name'] ?? '').toString().toLowerCase();
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
                                    '${docs.length} قسم',
                                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                                SizedBox(
                                  width: 300,
                                  child: TextField(
                                    controller: searchController,
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'ابحث عن قسم...',
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
                            child: docs.isEmpty 
                            ? _buildEmptyState('لم يتم العثور على نتائج تطابق البحث.')
                            : RawScrollbar(
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
                                      DataColumn(label: Text('اسم القسم', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('معرف القسم', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('الأعضاء', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('الحالة', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('الإجراءات', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold))),
                                    ],
                                    rows: docs.map((doc) {
                                      final data = doc.data() as Map<String, dynamic>;
                                      final deptName = data['dept_name'] ?? data['name'] ?? 'بدون اسم';
                                      final isActive = data['is_active'] ?? true;
                                      
                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 16,
                                                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                                  child: const Icon(Icons.corporate_fare, color: AppColors.primary, size: 16),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(deptName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                          DataCell(Text(doc.id, style: const TextStyle(color: Colors.white70))),
                                          DataCell(
                                            FutureBuilder<AggregateQuerySnapshot>(
                                              future: FirebaseFirestore.instance.collection('allowed_users')
                                                  .where('dept_ids', arrayContains: doc.id).count().get(),
                                              builder: (context, snap) {
                                                if (snap.connectionState == ConnectionState.waiting) {
                                                  return const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary));
                                                }
                                                return Row(
                                                  children: [
                                                    const Icon(Icons.people_outline, color: Colors.white54, size: 16),
                                                    const SizedBox(width: 6),
                                                    Text('${snap.data?.count ?? 0}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                                                  ],
                                                );
                                              },
                                            ),
                                          ),
                                          DataCell(
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: isActive ? AppColors.success.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: isActive ? AppColors.success.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2)),
                                              ),
                                              child: Text(
                                                isActive ? 'نشط' : 'معطل',
                                                style: TextStyle(color: isActive ? AppColors.success : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
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
                                                      MaterialPageRoute(
                                                        builder: (_) => DepartmentUsersPage(
                                                          deptId: doc.id,
                                                          deptName: deptName,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  icon: const Icon(Icons.people, size: 16),
                                                  label: const Text('الأعضاء', style: TextStyle(fontSize: 12)),
                                                ),
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                                                  onPressed: () => _editDepartment(doc.id, deptName),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                                                  onPressed: () => _deleteDepartment(doc.id, deptName),
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

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_tree_outlined, size: 80, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 24),
          Text(message, style: const TextStyle(color: Colors.white54, fontSize: 18)),
        ],
      ),
    );
  }
}