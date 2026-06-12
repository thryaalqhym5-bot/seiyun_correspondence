import 'package:flutter/material.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
class EditUserDialog extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const EditUserDialog({super.key, required this.docId, required this.data});

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  late final TextEditingController fullNameController;
  late final TextEditingController deptIdController;
  late final TextEditingController collegeIdController;
  final TextEditingController newPasswordController = TextEditingController();

  final UserService _userService = UserService();

  late String selectedRole;
  late String selectedAdminTitle;
  late String selectedSecondaryTitle;
  String? selectedManagerId;
  List<Map<String, dynamic>> _managers = [];
  late bool isActive;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    fullNameController = TextEditingController(text: widget.data['full_name'] ?? '');
    deptIdController = TextEditingController(text: widget.data['dept_id'] ?? '');
    collegeIdController = TextEditingController(text: widget.data['college_id'] ?? '');

    final validRoles = [
      'staff', 'admin', 'president', 'vp_student_affairs', 
      'vp_academic_affairs', 'vp_postgraduate_studies', 
      'secretary_general', 'executive_secretary'
    ];
    selectedRole = validRoles.contains(widget.data['role']) ? widget.data['role'] : 'staff';

    final validAdminTitles = ['university_president', 'dean', 'vice_dean', 'head_of_department', 'secretary', 'staff'];
    selectedAdminTitle = validAdminTitles.contains(widget.data['administrative_title']) 
        ? widget.data['administrative_title'] 
        : 'staff';
        
    selectedManagerId = widget.data['manager_id'];
    _loadManagers();

    final validSecondaryTitles = ['none', 'vice_dean', 'head_of_department'];
    selectedSecondaryTitle = validSecondaryTitles.contains(widget.data['secondary_administrative_title']) 
        ? widget.data['secondary_administrative_title'] 
        : 'none';

    isActive = widget.data['is_active'] ?? true;
  }

  Future<void> _loadManagers() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', whereIn: [
          'president', 'vp_student_affairs', 'vp_academic_affairs', 
          'vp_postgraduate_studies', 'secretary_general', 'dean', 'vice_dean'
        ])
        .get();
    
    if (mounted) {
      setState(() {
        _managers = snap.docs.map((doc) {
          final data = doc.data();
          data['uid'] = doc.id;
          return data;
        }).toList();
        
        // Ensure selectedManagerId exists in the loaded list, otherwise set to null
        if (selectedManagerId != null && !_managers.any((m) => m['uid'] == selectedManagerId)) {
           // Might be an old manager, keep it or clear it. We keep it to avoid data loss.
           // You could fetch it specifically if needed, but this is fine for now.
        }
      });
    }
  }

  Future<void> handleSave() async {
    final fullName = fullNameController.text.trim();
    final deptId = deptIdController.text.trim();
    final collegeId = collegeIdController.text.trim();

    if (fullName.isEmpty || collegeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الاسم ومعرف الكلية مطلوبة')));
      return;
    }

    setState(() => isSaving = true);

    try {
      await _userService.editUser(
        docId: widget.docId,
        fullName: fullName,
        deptId: deptId,
        collegeId: collegeId,
        selectedRole: selectedRole,
        selectedAdminTitle: selectedAdminTitle,
        selectedSecondaryTitle: selectedSecondaryTitle,
        isActive: isActive,
        newPassword: newPasswordController.text.trim(),
        managerId: (selectedRole == 'executive_secretary' || selectedAdminTitle == 'secretary') ? selectedManagerId : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث بيانات المستخدم بنجاح')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  void dispose() {
    fullNameController.dispose();
    deptIdController.dispose();
    collegeIdController.dispose();
    newPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF112240),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      title: const Text('تعديل بيانات المستخدم', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(controller: fullNameController, labelText: 'الاسم الكامل'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('colleges').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const CircularProgressIndicator();
                        final docs = snapshot.data!.docs;
                        return DropdownButtonFormField<String>(
                          value: collegeIdController.text.isNotEmpty && docs.any((doc) => doc.id == collegeIdController.text) ? collegeIdController.text : null,
                          decoration: const InputDecoration(labelText: 'الجهة (رئاسة الجامعة / الكلية)', border: OutlineInputBorder()),
                          dropdownColor: const Color(0xFF112240),
                          style: const TextStyle(color: Colors.white),
                          isExpanded: true,
                          items: docs.map((doc) => DropdownMenuItem(value: doc.id, child: Text(doc['name'] ?? ''))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => collegeIdController.text = val);
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('departments').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const CircularProgressIndicator();
                        final docs = snapshot.data!.docs;
                        return DropdownButtonFormField<String>(
                          value: deptIdController.text.isEmpty ? '' : (docs.any((doc) => doc.id == deptIdController.text) ? deptIdController.text : null),
                          decoration: const InputDecoration(labelText: 'القسم (اختياري)', border: OutlineInputBorder()),
                          dropdownColor: const Color(0xFF112240),
                          style: const TextStyle(color: Colors.white),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(value: '', child: Text('بدون قسم')),
                            ...docs.map((doc) => DropdownMenuItem(value: doc.id, child: Text(doc['name'] ?? ''))),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => deptIdController.text = val);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedRole,
                dropdownColor: const Color(0xFF112240),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'صلاحية الدخول (Role)',
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                items: const [
                  DropdownMenuItem(value: 'staff', child: Text('موظف/أكاديمي (Staff)')),
                  DropdownMenuItem(value: 'admin', child: Text('مدير نظام (Admin)')),
                  DropdownMenuItem(value: 'president', child: Text('رئيس الجامعة')),
                  DropdownMenuItem(value: 'vp_student_affairs', child: Text('نائب شؤون الطلاب')),
                  DropdownMenuItem(value: 'vp_academic_affairs', child: Text('نائب الشؤون الأكاديمية')),
                  DropdownMenuItem(value: 'vp_postgraduate_studies', child: Text('نائب الدراسات العليا')),
                  DropdownMenuItem(value: 'secretary_general', child: Text('الأمين العام')),
                  DropdownMenuItem(value: 'executive_secretary', child: Text('سكرتير تنفيذي / مدير مكتب')),
                ],
                onChanged: (value) => setState(() => selectedRole = value!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedAdminTitle,
                dropdownColor: const Color(0xFF112240),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'المنصب الإداري الأساسي',
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                items: const [
                  DropdownMenuItem(value: 'university_president', child: Text('رئيس الجامعة')),
                  DropdownMenuItem(value: 'university_vp', child: Text('نائب رئيس الجامعة')),
                  DropdownMenuItem(value: 'general_secretary', child: Text('أمين عام الجامعة')),
                  DropdownMenuItem(value: 'dean', child: Text('عميد الكلية')),
                  DropdownMenuItem(value: 'vice_dean', child: Text('نائب العميد')),
                  DropdownMenuItem(value: 'vice_dean_student', child: Text('نائب العميد لشؤون الطلاب')),
                  DropdownMenuItem(value: 'vice_dean_academic', child: Text('نائب العميد للشؤون الأكاديمية')),
                  DropdownMenuItem(value: 'vice_dean_postgraduate', child: Text('نائب العميد للدراسات العليا')),
                  DropdownMenuItem(value: 'center_director', child: Text('مدير مركز')),
                  DropdownMenuItem(value: 'vice_director', child: Text('نائب مدير مركز')),
                  DropdownMenuItem(value: 'general_director', child: Text('مدير عام')),
                  DropdownMenuItem(value: 'head_of_department', child: Text('رئيس القسم')),
                  DropdownMenuItem(value: 'secretary', child: Text('سكرتير / مدير مكتب')),
                  DropdownMenuItem(value: 'staff', child: Text('لا يوجد منصب')),
                ],
                onChanged: (value) => setState(() => selectedAdminTitle = value!),
              ),
              if (selectedRole == 'executive_secretary' || selectedAdminTitle == 'secretary') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _managers.any((m) => m['uid'] == selectedManagerId) ? selectedManagerId : null,
                  dropdownColor: const Color(0xFF112240),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'المدير المباشر (يتبع لمن؟)',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  items: _managers.map<DropdownMenuItem<String>>((m) {
                    String managerLabel = m['administrative_title'] == 'university_president' ? 'رئيس الجامعة'
                        : (m['administrative_title'] == 'university_vp' ? 'نائب رئيس الجامعة'
                        : (m['administrative_title'] == 'dean' ? 'عميد الكلية'
                        : (m['administrative_title'] == 'center_director' ? 'مدير المركز'
                        : (m['administrative_title'] == 'general_director' ? 'مدير عام'
                        : (m['administrative_title']?.contains('vice_dean') == true ? 'نائب العميد' : 'مسؤول')))));
                    return DropdownMenuItem<String>(value: m['uid'], child: Text('${m['full_name']} ($managerLabel)'));
                  }).toList(),
                  onChanged: (value) => setState(() => selectedManagerId = value),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedSecondaryTitle,
                dropdownColor: const Color(0xFF112240),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'المنصب الإداري الإضافي (إن وُجد)',
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('لا يوجد (None)')),
                  DropdownMenuItem(value: 'vice_dean', child: Text('نائب العميد')),
                  DropdownMenuItem(value: 'head_of_department', child: Text('رئيس القسم')),
                ],
                onChanged: (value) => setState(() => selectedSecondaryTitle = value!),
              ),
              const SizedBox(height: 16),
              CustomTextField(controller: newPasswordController, labelText: 'كلمة مرور جديدة (اتركه فارغاً لعدم التغيير)', obscureText: true),
              const SizedBox(height: 12),
              SwitchListTile(
                value: isActive,
                title: const Text('الحساب مفعل', style: TextStyle(color: Colors.white)),
                activeThumbColor: Colors.blueAccent,
                onChanged: (value) => setState(() => isActive = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (isSaving) const CircularProgressIndicator(),
        if (!isSaving) TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
        if (!isSaving) ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
          onPressed: handleSave,
          child: const Text('حفظ التعديلات'),
        ),
      ],
    );
  }
}
