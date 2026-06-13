import 'package:flutter/material.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CollegeAddUserDialog extends StatefulWidget {
  final String collegeId;

  const CollegeAddUserDialog({super.key, required this.collegeId});

  @override
  State<CollegeAddUserDialog> createState() => _CollegeAddUserDialogState();
}

class _CollegeAddUserDialogState extends State<CollegeAddUserDialog> {
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController deptIdController = TextEditingController();

  final UserService _userService = UserService();

  String selectedRole = 'staff'; // Only staff is allowed for standard members
  String selectedAdminTitle = 'staff'; // Default
  String selectedSecondaryTitle = 'none';
  String? selectedManagerId;
  List<Map<String, dynamic>> _managers = [];
  bool isActive = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadManagers();
  }

  Future<void> _loadManagers() async {
    // Only load managers from the same college (like Deans or Vice Deans)
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('college_ids', arrayContains: widget.collegeId)
        .where('administrative_title', whereIn: ['dean', 'vice_dean', 'vice_dean_academic', 'vice_dean_student', 'vice_dean_postgraduate', 'head_of_department'])
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
    final deptId = deptIdController.text.trim();

    if (fullName.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أكملي جميع الحقول المطلوبة')));
      return;
    }
    
    if (selectedAdminTitle == 'secretary' && selectedManagerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار المدير المباشر للسكرتير')));
      return;
    }

    setState(() => isSaving = true);

    try {
      await _userService.addUser(
        fullName: fullName,
        email: email,
        password: password,
        affiliations: [
          {
            'college_id': widget.collegeId,
            'dept_id': deptId,
            'administrative_title': selectedAdminTitle,
            'secondary_administrative_title': selectedSecondaryTitle,
          }
        ],
        selectedRole: selectedRole,
        isActive: isActive,
        managerId: selectedAdminTitle == 'secretary' ? selectedManagerId : null,
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
    deptIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A2942),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.person_add, color: Colors.blueAccent),
                  SizedBox(width: 8),
                  Text('إضافة مستخدم جديد للكلية', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 24),
              CustomTextField(controller: fullNameController, labelText: 'الاسم الرباعي واللقب', prefixIcon: Icons.person),
              const SizedBox(height: 16),
              CustomTextField(controller: emailController, labelText: 'البريد الإلكتروني', prefixIcon: Icons.email, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              CustomTextField(controller: passwordController, labelText: 'كلمة المرور', prefixIcon: Icons.lock, obscureText: true),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('departments').where('college_id', isEqualTo: widget.collegeId).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const CircularProgressIndicator();
                  final docs = snapshot.data!.docs;
                  return DropdownButtonFormField<String>(
                    value: deptIdController.text.isEmpty ? null : deptIdController.text,
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
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedAdminTitle,
                dropdownColor: const Color(0xFF112240),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'المنصب الإداري',
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                items: const [
                  DropdownMenuItem(value: 'staff', child: Text('عضو هيئة تدريس / أكاديمي')),
                  DropdownMenuItem(value: 'head_of_department', child: Text('رئيس قسم')),
                  DropdownMenuItem(value: 'center_director', child: Text('مدير مركز بالكلية')),
                  DropdownMenuItem(value: 'vice_director', child: Text('نائب مدير مركز بالكلية')),
                  DropdownMenuItem(value: 'secretary', child: Text('سكرتير / مدير مكتب')),
                ],
                onChanged: (value) => setState(() => selectedAdminTitle = value!),
              ),
              if (selectedAdminTitle == 'secretary') ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedManagerId,
                  dropdownColor: const Color(0xFF112240),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'المدير المباشر (يتبع لمن؟)',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  items: _managers.map<DropdownMenuItem<String>>((m) {
                    String managerLabel = m['administrative_title'] == 'dean' ? 'عميد الكلية'
                        : (m['administrative_title'] == 'vice_dean' ? 'نائب العميد'
                        : (m['administrative_title'] == 'vice_dean_academic' ? 'نائب الشؤون الأكاديمية'
                        : (m['administrative_title'] == 'head_of_department' ? 'رئيس قسم'
                        : m['administrative_title'] ?? 'مدير')));
                    
                    return DropdownMenuItem(
                      value: m['uid'],
                      child: Text('${m['full_name']} ($managerLabel)'),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => selectedManagerId = val),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Switch(
                    value: isActive,
                    onChanged: (val) => setState(() => isActive = val),
                    activeThumbColor: Colors.blueAccent,
                  ),
                  const Text('مفعل', style: TextStyle(color: Colors.white)),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isSaving ? null : () => Navigator.pop(context),
                    child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: isSaving ? null : handleSave,
                    child: isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('إضافة', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
