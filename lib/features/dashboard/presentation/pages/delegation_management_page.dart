import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/delegation_service.dart';

class DelegationManagementPage extends StatefulWidget {
  const DelegationManagementPage({Key? key}) : super(key: key);

  @override
  _DelegationManagementPageState createState() => _DelegationManagementPageState();
}

class _DelegationManagementPageState extends State<DelegationManagementPage> {
  final DelegationService _delegationService = DelegationService();
  final _notesController = TextEditingController();
  String? _selectedDelegateeId;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 3));
  bool _isLoading = false;
  
  List<Map<String, dynamic>> _availableUsers = [];
  bool _isLoadingUsers = true;

  @override
  void initState() {
    super.initState();
    _fetchColleagues();
  }

  Future<void> _fetchColleagues() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      if (!userDoc.exists) return;
      
      final collegeId = userDoc.data()?['college_id'];
      final deptId = userDoc.data()?['dept_id'];
      
      final title = userDoc.data()?['administrative_title'];
      
      Query query = FirebaseFirestore.instance.collection('users').where('is_active', isEqualTo: true);
      
      // If the user belongs to a specific department, fetch users in the same department.
      // If they belong to a college but no specific department, fetch users in the college.
      if (deptId != null && deptId.toString().isNotEmpty) {
        query = query.where('dept_id', isEqualTo: deptId);
      } else if (collegeId != null && collegeId.toString().isNotEmpty) {
        query = query.where('college_id', isEqualTo: collegeId);
      }

      final snapshot = await query.get();
      final allDocs = snapshot.docs.toList();

      // Add direct reports for high-level executives
      if (title == 'university_president') {
        final snap2 = await FirebaseFirestore.instance.collection('users').where('administrative_title', whereIn: [
          'university_vp', 'general_secretary', 'vp_academic_affairs', 'vp_student_affairs', 'vp_postgraduate_studies'
        ]).get();
        allDocs.addAll(snap2.docs.where((d) => (d.data() as Map<String, dynamic>)['is_active'] == true));
      } else if (title?.startsWith('vp_') == true || title == 'general_secretary') {
        final snap2 = await FirebaseFirestore.instance.collection('users').where('administrative_title', whereIn: [
          'dean', 'general_director', 'center_director'
        ]).get();
        allDocs.addAll(snap2.docs.where((d) => (d.data() as Map<String, dynamic>)['is_active'] == true));
      }

      // Remove duplicates and self
      final uniqueUsers = <String, Map<String, dynamic>>{};
      for (var d in allDocs) {
        if (d.id != currentUser.uid) {
           uniqueUsers[d.id] = {'id': d.id, ...d.data() as Map<String, dynamic>};
        }
      }

      final users = uniqueUsers.values.toList();

      setState(() {
        _availableUsers = users;
        _isLoadingUsers = false;
      });
    } catch (e) {
      setState(() => _isLoadingUsers = false);
    }
  }

  Future<void> _createDelegation() async {
    if (_selectedDelegateeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار الشخص المفوض')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _delegationService.createDelegation(
        delegateeId: _selectedDelegateeId!,
        startDate: _startDate,
        endDate: _endDate,
        notes: _notesController.text,
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تفويض الصلاحيات بنجاح')));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('تفويض الصلاحيات', style: TextStyle(color: Color(0xFFD4AF37))),
        backgroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الشخص المفوض إليه:', style: TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 8),
            _isLoadingUsers
                ? const CircularProgressIndicator(color: Color(0xFFD4AF37))
                : DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      hintText: 'اختر الموظف...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white),
                    initialValue: _selectedDelegateeId,
                    items: _availableUsers.map((u) {
                      return DropdownMenuItem<String>(
                        value: u['id'],
                        child: Text('${u['full_name'] ?? 'بدون اسم'} - ${u['administrative_title'] ?? ''}'),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedDelegateeId = val),
                  ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('تاريخ البدء', style: TextStyle(color: Colors.white)),
                    subtitle: Text('${_startDate.toLocal()}'.split(' ')[0], style: const TextStyle(color: Color(0xFFD4AF37))),
                    onTap: () async {
                      final d = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime.now(), lastDate: DateTime(2030));
                      if (d != null) setState(() => _startDate = d);
                    },
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: const Text('تاريخ الانتهاء', style: TextStyle(color: Colors.white)),
                    subtitle: Text('${_endDate.toLocal()}'.split(' ')[0], style: const TextStyle(color: Color(0xFFD4AF37))),
                    onTap: () async {
                      final d = await showDatePicker(context: context, initialDate: _endDate, firstDate: DateTime.now(), lastDate: DateTime(2030));
                      if (d != null) setState(() => _endDate = d);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText: 'ملاحظات (مثال: تفويض خلال فترة السفر)',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
                onPressed: _isLoading ? null : _createDelegation,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text('تأكيد التفويض', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
