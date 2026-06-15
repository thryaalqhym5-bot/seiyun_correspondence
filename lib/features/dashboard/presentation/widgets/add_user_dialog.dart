import 'package:flutter/material.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddUserDialog extends StatefulWidget {
  const AddUserDialog({super.key});

  @override
  State<AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<AddUserDialog> {
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final UserService _userService = UserService();

  String selectedRole = 'staff';
  String? selectedManagerId;
  final List<Map<String, dynamic>> _affiliations = [
    {
      'college_id': '',
      'dept_id': '',
      'administrative_title': 'staff',
      'secondary_administrative_title': 'none',
    }
  ];
  List<Map<String, dynamic>> _managers = [];
  bool isActive = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadManagers();
  }

  Future<void> _loadManagers() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', whereIn: [
          'president', 
          'vp_student_affairs', 
          'vp_academic_affairs', 
          'vp_postgraduate_studies', 
          'secretary_general',
          'dean', 
          'vice_dean' // Keep existing managers if any
        ])
        .get();
    
    if (mounted) {
      setState(() {
        _managers = snap.docs.map((doc) {
          final data = doc.data();
          data['uid'] = doc.id;
          return data;
        }).toList();
      });
    }
  }

  Future<void> handleSave() async {
    final fullName = fullNameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (fullName.isEmpty || email.isEmpty || password.isEmpty || _affiliations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الاسم الكامل والإيميل وكلمة المرور مطلوبة')));
      return;
    }
    
    if (_affiliations.any((a) => a['administrative_title'] == 'secretary') && selectedManagerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار المدير المباشر للسكرتير')));
      return;
    }

    setState(() => isSaving = true);

    try {
      await _userService.addUser(
        fullName: fullName,
        email: email,
        password: password,
        selectedRole: selectedRole,
        isActive: isActive,
        affiliations: _affiliations,
        managerId: _affiliations.any((a) => a['administrative_title'] == 'secretary') ? selectedManagerId : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة المستخدم بنجاح')));
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
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _addAffiliation() {
    setState(() {
      _affiliations.add({
        'college_id': '',
        'dept_id': '',
        'administrative_title': 'staff',
        'secondary_administrative_title': 'none',
      });
    });
  }

  void _removeAffiliation(int index) {
    if (_affiliations.length > 1) {
      setState(() {
        _affiliations.removeAt(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يجب أن يكون للمستخدم منصب واحد على الأقل')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF112240),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      title: const Text('إضافة مستخدم جديد', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(controller: fullNameController, labelText: 'الاسم الكامل'),
              const SizedBox(height: 12),
              CustomTextField(controller: emailController, labelText: 'البريد الإلكتروني', keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              CustomTextField(controller: passwordController, labelText: 'كلمة المرور', obscureText: true),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('المناصب والجهات', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.blueAccent),
                    onPressed: _addAffiliation,
                  ),
                ],
              ),
              ...List.generate(_affiliations.length, (index) {
                final aff = _affiliations[index];
                return Card(
                  color: Colors.white.withValues(alpha: 0.05),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('المنصب ${index + 1}', style: const TextStyle(color: Colors.white70)),
                            if (_affiliations.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                onPressed: () => _removeAffiliation(index),
                              ),
                          ],
                        ),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('colleges').snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const CircularProgressIndicator();
                            final docs = snapshot.data!.docs;
                            return DropdownButtonFormField<String>(
                              initialValue: docs.any((doc) => doc.id == aff['college_id']) ? aff['college_id'] : '',
                              decoration: const InputDecoration(labelText: 'الجهة (رئاسة الجامعة / الكلية)', border: OutlineInputBorder()),
                              dropdownColor: const Color(0xFF112240),
                              style: const TextStyle(color: Colors.white),
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem(value: '', child: Text('رئاسة الجامعة')),
                                ...docs.map((doc) => DropdownMenuItem(value: doc.id, child: Text(doc['name'] ?? ''))),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _affiliations[index]['college_id'] = val);
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('departments').snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const CircularProgressIndicator();
                            final docs = snapshot.data!.docs;
                            return DropdownButtonFormField<String>(
                              initialValue: (aff['dept_id'] as String).isEmpty ? '' : (docs.any((doc) => doc.id == aff['dept_id']) ? aff['dept_id'] : null),
                              decoration: const InputDecoration(labelText: 'القسم (اختياري)', border: OutlineInputBorder()),
                              dropdownColor: const Color(0xFF112240),
                              style: const TextStyle(color: Colors.white),
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem(value: '', child: Text('بدون قسم')),
                                ...docs.map((doc) => DropdownMenuItem(value: doc.id, child: Text(doc['name'] ?? ''))),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _affiliations[index]['dept_id'] = val);
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: aff['administrative_title'],
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
                          onChanged: (val) => setState(() => _affiliations[index]['administrative_title'] = val!),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: aff['secondary_administrative_title'] ?? 'none',
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
                          onChanged: (val) => setState(() => _affiliations[index]['secondary_administrative_title'] = val!),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
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
                  DropdownMenuItem(value: 'vp_student_affairs', child: Text('نائب رئيس الجامعة لشؤون الطلاب')),
                  DropdownMenuItem(value: 'vp_academic_affairs', child: Text('نائب رئيس الجامعة للشؤون الأكاديمية')),
                  DropdownMenuItem(value: 'vp_postgraduate_studies', child: Text('نائب رئيس الجامعة للدراسات العليا')),
                  DropdownMenuItem(value: 'secretary_general', child: Text('الأمين العام')),
                  DropdownMenuItem(value: 'executive_secretary', child: Text('سكرتير تنفيذي / مدير مكتب')),
                ],
                onChanged: (value) => setState(() => selectedRole = value!),
              ),
              if (selectedRole == 'executive_secretary' || (_affiliations.isNotEmpty && _affiliations.first['administrative_title'] == 'secretary')) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _managers.any((m) => m['uid'] == selectedManagerId) ? selectedManagerId : null,
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
          child: const Text('حفظ وإضافة'),
        ),
      ],
    );
  }
}
