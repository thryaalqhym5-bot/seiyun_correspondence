import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/communication_service.dart';

class OfficialLetterViewPage extends StatefulWidget {
  final String communicationId;

  const OfficialLetterViewPage({
    super.key,
    required this.communicationId,
  });

  @override
  State<OfficialLetterViewPage> createState() => _OfficialLetterViewPageState();
}

class _OfficialLetterViewPageState extends State<OfficialLetterViewPage> {
  final CommunicationService _communicationService = CommunicationService();
  final TextEditingController commentController = TextEditingController();
  Map<String, dynamic>? userData;

  Future<void> loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc =
    await FirebaseFirestore.instance.collection('users').doc(uid).get();
    userData = doc.data();
  }

  bool get canApprove => userData?['can_approve'] == true;
  bool get canReject => userData?['can_reject'] == true;
  bool get canForward => userData?['can_forward'] == true;
  bool get canArchive => userData?['can_archive'] == true;

  Future<void> approveCommunication() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('communications').doc(widget.communicationId).get();
      final data = doc.data() ?? {};
      final isCircular = data['is_circular'] == true;
      final isDraft = data['status'] == 'pending_approval';

      await _communicationService.approveCommunication(widget.communicationId);
      
      if (!mounted) return;
      
      String msg = 'تم اعتماد وأرشفة المخاطبة';
      if (isCircular && isDraft) msg = 'تم اعتماد ونشر التعميم بنجاح';
      else if (!isCircular && isDraft) msg = 'تم اعتماد المخاطبة وإرسالها للجهة المعنية';
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> rejectCommunication() async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final commRef = FirebaseFirestore.instance
        .collection('communications')
        .doc(widget.communicationId);

    final commDoc = await commRef.get();
    final data = commDoc.data() as Map<String, dynamic>;
    final oldStatus = data['status'] ?? '';

    await commRef.update({
      'status': 'rejected',
      'rejected_at': FieldValue.serverTimestamp(),
      'last_action_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    await commRef.collection('tracking').add({
      'action': 'reject',
      'from_id': currentUser.uid,
      'to_id': data['sender_id'],
      'from_status': oldStatus,
      'to_status': 'rejected',
      'timestamp': FieldValue.serverTimestamp(),
      'comment': 'تم رفض المخاطبة من صفحة الخطاب الرسمي',
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم رفض المخاطبة')),
    );
    Navigator.pop(context);
  }

  Future<void> archiveCommunication() async {
    final currentUser = FirebaseAuth.instance.currentUser!;
    final commRef = FirebaseFirestore.instance
        .collection('communications')
        .doc(widget.communicationId);

    final commDoc = await commRef.get();
    final data = commDoc.data() as Map<String, dynamic>;
    final oldStatus = data['status'] ?? '';

    await commRef.update({
      'status': 'archived',
      'archived_at': FieldValue.serverTimestamp(),
      'last_action_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });

    await commRef.collection('tracking').add({
      'action': 'archive',
      'from_id': currentUser.uid,
      'to_status': 'archived',
      'from_status': oldStatus,
      'timestamp': FieldValue.serverTimestamp(),
      'comment': 'تمت أرشفة المخاطبة',
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تمت أرشفة المخاطبة')),
    );
    Navigator.pop(context);
  }

  // Removed addComment and showCommentDialog

  void showForwardDialog() {
    final usersFuture = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'staff')
        .where('is_active', isEqualTo: true)
        .get();

    showDialog(
      context: context,
      builder: (context) {
        String selectedUserId = '';
        String selectedUserName = '';
        String selectedDeptId = '';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('تحويل المخاطبة'),
              content: FutureBuilder<QuerySnapshot>(
                future: usersFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox(
                      height: 80,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final docs = snapshot.data!.docs;

                  return DropdownButtonFormField<String>(
                    initialValue:
                    selectedUserId.isEmpty ? null : selectedUserId,
                    decoration: const InputDecoration(
                      labelText: 'اختاري المستخدم',
                      border: OutlineInputBorder(),
                    ),
                    items: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final fullName = data['full_name'] ?? '';
                      final deptId = data['dept_id'] ?? '';
                      return DropdownMenuItem<String>(
                        value: doc.id,
                        child: Text('$fullName - $deptId'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        final selectedDoc =
                        docs.firstWhere((doc) => doc.id == value);
                        final selectedData =
                        selectedDoc.data() as Map<String, dynamic>;

                        setDialogState(() {
                          selectedUserId = value;
                          selectedUserName = selectedData['full_name'] ?? '';
                          selectedDeptId = selectedData['dept_id'] ?? '';
                        });
                      }
                    },
                  );
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedUserId.isEmpty) return;
                    try {
                      await _communicationService.forwardCommunication(
                        widget.communicationId,
                        selectedUserId,
                        selectedUserName,
                        selectedDeptId,
                        'تم التحويل من صفحة الخطاب الرسمي',
                      );
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحويل المخاطبة')));
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                      }
                    }
                  },
                  child: const Text('تحويل'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _forwardToManager() async {
    if (userData == null || userData!['manager_id'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('المدير المباشر غير محدد لهذا الحساب')));
      return;
    }
    
    try {
      final managerId = userData!['manager_id'];
      final managerDoc = await FirebaseFirestore.instance.collection('users').doc(managerId).get();
      if (!managerDoc.exists) throw 'حساب المدير غير موجود';
      
      final mData = managerDoc.data()!;
      await _communicationService.forwardCommunication(
        widget.communicationId,
        managerId,
        mData['full_name'] ?? 'المدير',
        mData['dept_id'] ?? '',
        'إحالة من السكرتارية',
      );
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت الإحالة للمدير المباشر بنجاح')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  void _showAddWallReminderDialog(String title) {
    final TextEditingController noteController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: const Color(0xFF0F1E38),
          title: const Text('إضافة تذكير للحائط', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: noteController,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'اكتب تذكيرك هنا (مثلاً: إرسال الأسماء قبل يوم الخميس)',
              hintStyle: const TextStyle(color: Colors.white54),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
              focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFD4AF37))),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
              onPressed: isSaving ? null : () async {
                if (noteController.text.trim().isEmpty) return;
                setStateDialog(() => isSaving = true);
                try {
                  await _communicationService.addWallReminder(widget.communicationId, title, noteController.text.trim());
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة التذكير لحائطك بنجاح')));
                  }
                } catch (e) {
                  setStateDialog(() => isSaving = false);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
                }
              },
              child: isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : const Text('إضافة للتذكيرات', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final commFuture = FirebaseFirestore.instance
        .collection('communications')
        .doc(widget.communicationId)
        .get();

    return FutureBuilder(
      future: Future.wait([commFuture, loadUserData()]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final commDoc = snapshot.data![0] as DocumentSnapshot;
        final data = commDoc.data() as Map<String, dynamic>;

        final status = data['status'] ?? '';
        final isArchived = status == 'archived';

        return Scaffold(
          appBar: AppBar(
            title: const Text('عرض المخاطبة'),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.push_pin, color: Color(0xFFD4AF37)),
                tooltip: 'إضافة لحائط التذكيرات',
                onPressed: () => _showAddWallReminderDialog(data['subject'] ?? 'بدون عنوان'),
              ),
            ],
          ),
          body: Center(
            child: Container(
              width: 800,
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 10,
                    color: Colors.black.withValues(alpha: 0.05),
                  ),
                ],
              ),
              child: ListView(
                children: [
                  const Center(
                    child: Column(
                      children: [
                        Text(
                          'جامعة سيئون',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'كلية الحاسبات - مكتب العميد',
                          style: TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'رقم الخطاب: ${data['letter_no'] ?? ''}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      Text(
                        'التاريخ: ${data['created_at'] != null ? 'موجود' : ''}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'الأخ / ${data['target_name'] ?? ''}',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'الموضوع: ${data['subject'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    data['body_text'] ?? '',
                    style: const TextStyle(fontSize: 18, height: 1.8),
                  ),
                  const SizedBox(height: 40),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'المرسل:\n${data['sender_name'] ?? ''}',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(height: 30),
                  if (!isArchived) ...[
                    if (canApprove || canReject)
                      Row(
                        children: [
                          if (canApprove)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: approveCommunication,
                                icon: const Icon(Icons.check),
                                label: const Text('اعتماد'),
                              ),
                            ),
                          if (canApprove && canReject)
                            const SizedBox(width: 12),
                          if (canReject)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: rejectCommunication,
                                icon: const Icon(Icons.close),
                                label: const Text('رفض'),
                              ),
                            ),
                        ],
                      ),
                    if (canApprove || canReject) const SizedBox(height: 12),
                      Row(
                        children: [
                          if (canForward)
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: showForwardDialog,
                                icon: const Icon(Icons.forward),
                                label: const Text('تحويل'),
                              ),
                            ),
                          if (canForward && userData?['administrative_title'] == 'secretary') const SizedBox(width: 12),
                          if (userData?['administrative_title'] == 'secretary')
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _forwardToManager,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                                icon: const Icon(Icons.arrow_upward, color: Colors.white),
                                label: const Text('إحالة للمدير', style: TextStyle(color: Colors.white)),
                              ),
                            ),
                        ],
                      ),
                    if (canArchive) const SizedBox(height: 12),
                    if (canArchive)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: archiveCommunication,
                          icon: const Icon(Icons.archive),
                          label: const Text('أرشفة'),
                        ),
                      ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'هذه المخاطبة مؤرشفة وهي للقراءة فقط',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}