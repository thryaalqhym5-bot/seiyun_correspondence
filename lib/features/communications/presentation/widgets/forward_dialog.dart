import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/communication_service.dart';

class ForwardDialog extends StatefulWidget {
  final Future<void> Function(String targetUserId, String targetName, String targetDeptId, String comment) onForward;

  const ForwardDialog({super.key, required this.onForward});

  @override
  State<ForwardDialog> createState() => _ForwardDialogState();
}

class _ForwardDialogState extends State<ForwardDialog> {
  final CommunicationService _communicationService = CommunicationService();
  final TextEditingController _commentController = TextEditingController();
  
  bool _isLoadingUsers = true;
  bool _isSaving = false;
  
  List<DocumentSnapshot> _users = [];
  String? _selectedUserId;
  String? _selectedUserName;
  String? _selectedUserDeptId;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await _communicationService.fetchAllowedTargets();
      if (mounted) {
        setState(() {
          _users = users;
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingUsers = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في جلب المستخدمين: $e')));
      }
    }
  }

  Future<void> _handleForward() async {
    if (_selectedUserId == null) return;
    
    setState(() => _isSaving = true);
    try {
      await widget.onForward(
        _selectedUserId!,
        _selectedUserName!,
        _selectedUserDeptId ?? '',
        _commentController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحويل المخاطبة بنجاح')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF112240),
      title: const Text('تحويل المخاطبة (إحالة)', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('اختر الموظف أو القسم:', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            _isLoadingUsers
                ? const Center(child: CircularProgressIndicator())
                : DropdownButtonFormField<String>(
                    dropdownColor: const Color(0xFF0A192F),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
                    ),
                    items: _users.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final id = doc.id;
                      final name = data['full_name'] ?? 'مجهول';
                      final title = data['administrative_title'] ?? 'staff';
                      return DropdownMenuItem(
                        value: id,
                        child: Text('$name ($title)'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      final selectedDoc = _users.firstWhere((doc) => doc.id == val);
                      final data = selectedDoc.data() as Map<String, dynamic>;
                      setState(() {
                        _selectedUserId = val;
                        _selectedUserName = data['full_name'] ?? 'مجهول';
                        _selectedUserDeptId = data['dept_id'] ?? '';
                      });
                    },
                    hint: const Text('اختر من القائمة...', style: TextStyle(color: Colors.white54)),
                  ),
            const SizedBox(height: 16),
            const Text('التوجيه / الإفادة (اختياري):', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'اكتب توجيهك هنا...',
                hintStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (_isSaving) const CircularProgressIndicator(),
        if (!_isSaving)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
        if (!_isSaving)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: _selectedUserId == null ? null : _handleForward,
            icon: const Icon(Icons.forward, color: Colors.white),
            label: const Text('إرسال التوجيه', style: TextStyle(color: Colors.white)),
          ),
      ],
    );
  }
}
