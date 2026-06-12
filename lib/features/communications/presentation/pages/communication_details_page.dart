import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/word_service.dart';
import '../../../../core/services/communication_service.dart';
import '../widgets/forward_dialog.dart';

class CommunicationDetailsPage extends StatefulWidget {
  final String communicationId;

  const CommunicationDetailsPage({
    super.key,
    required this.communicationId,
  });

  @override
  State<CommunicationDetailsPage> createState() =>
      _CommunicationDetailsPageState();
}

class _CommunicationDetailsPageState extends State<CommunicationDetailsPage> {
  final CommunicationService _communicationService = CommunicationService();
  Map<String, dynamic>? userData;

  Future<void> loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc =
    await FirebaseFirestore.instance.collection('users').doc(uid).get();
    userData = doc.data();
  }

  bool get _isManager {
    final title = userData?['administrative_title'] ?? 'staff';
    return ['dean', 'vice_dean', 'vice_dean_student', 'vice_dean_academic', 'vice_dean_postgraduate', 'center_director', 'vice_director', 'general_director', 'head_of_department', 'university_president', 'university_vp', 'general_secretary'].contains(title);
  }

  bool get _isSecretary {
    final title = userData?['administrative_title'] ?? 'staff';
    final role = userData?['role'] ?? 'staff';
    return title == 'secretary' || role == 'executive_secretary';
  }

  bool get canApprove => _isManager;
  bool get canReject => _isManager;
  bool get canForward => true;
  bool get canArchive => true;

  Future<void> openOrGeneratePdf(Map<String, dynamic> data) async {
    await WordService.openCommunicationPdf(context, data, widget.communicationId, data['subject'] ?? 'المخاطبة');
  }

  Future<void> approveCommunication() async {
    try {
      await _communicationService.approveCommunication(widget.communicationId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم اعتماد المخاطبة')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> rejectCommunication() async {
    try {
      await _communicationService.rejectCommunication(widget.communicationId, 'تم الرفض من صفحة التفاصيل');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفض المخاطبة')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> archiveCommunication() async {
    try {
      await _communicationService.archiveCommunication(widget.communicationId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت أرشفة المخاطبة')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  void showReplyDialog() {
    final TextEditingController replyController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF112240),
        title: const Text('إرسال رد', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: replyController,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'اكتب ردك هنا...',
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (replyController.text.trim().isEmpty) return;
              await _communicationService.replyToCommunication(widget.communicationId, replyController.text.trim());
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال الرد بنجاح')));
              }
            },
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }

  void showBriefAndForwardDialog(Map<String, dynamic> commData) {
    final TextEditingController briefController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF112240),
        title: const Text('كتابة ملخص وإحالة للمسؤول', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: briefController,
          style: const TextStyle(color: Colors.white),
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'اكتب الملخص (Briefing) هنا ليطلع عليه المسؤول...',
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (briefController.text.trim().isEmpty) return;
              final managerId = userData?['manager_id'];
              if (managerId == null) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يوجد مدير مباشر مرتبط بحسابك')));
                 return;
              }
              // We need the manager's data to forward properly
              final managerDoc = await FirebaseFirestore.instance.collection('users').doc(managerId).get();
              final managerName = managerDoc.data()?['full_name'] ?? 'المسؤول';
              final managerDept = managerDoc.data()?['dept_id'] ?? '';
              
              await _communicationService.forwardCommunication(
                widget.communicationId,
                managerId,
                managerName,
                managerDept,
                'ملخص من السكرتارية: ' + briefController.text.trim(),
              );
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إحالة المخاطبة للمسؤول مع الملخص')));
              }
            },
            child: const Text('إحالة'),
          ),
        ],
      ),
    );
  }

  void showForwardDialog() {
    showDialog(
      context: context,
      builder: (context) => ForwardDialog(
        onForward: (targetUserId, targetName, targetDeptId, comment) async {
          await _communicationService.forwardCommunication(
            widget.communicationId,
            targetUserId,
            targetName,
            targetDeptId,
            comment,
          );
          if (mounted) Navigator.pop(context);
        },
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
            backgroundColor: Color(0xFF0A192F),
            body: Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
          );
        }

        final commDoc = snapshot.data![0] as DocumentSnapshot;
        final data = commDoc.data() as Map<String, dynamic>;
        final status = data['status'] ?? '';
        final isArchived = status == 'archived';

        return Scaffold(
          backgroundColor: const Color(0xFF0A192F),
          appBar: AppBar(
            backgroundColor: const Color(0xFF112240),
            title: const Text('تفاصيل المخاطبة', style: TextStyle(color: Colors.white)),
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: ListView(
              children: [
                Text(
                  data['subject'] ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF112240),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Text(
                    data['body_text'] ?? '',
                    style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
                  ),
                ),
                const SizedBox(height: 16),
                Text('الحالة: $status', style: const TextStyle(color: Colors.white54)),
                Text('المرسل: ${data['sender_name'] ?? ''}', style: const TextStyle(color: Colors.white54)),
                Text('المستقبل: ${data['target_name'] ?? ''}', style: const TextStyle(color: Colors.white54)),
                const SizedBox(height: 24),

                ElevatedButton.icon(
                  onPressed: () => openOrGeneratePdf(data),
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                  label: const Text('فتح الكليشة PDF', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),

                const SizedBox(height: 16),

                if (!isArchived) ...[
                  if (canApprove || canReject)
                    Row(
                      children: [
                        if (canApprove)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: approveCommunication,
                              icon: const Icon(Icons.check, color: Colors.white),
                              label: const Text('اعتماد', style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            ),
                          ),
                        if (canApprove && canReject)
                          const SizedBox(width: 12),
                        if (canReject)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: rejectCommunication,
                              icon: const Icon(Icons.close, color: Colors.white),
                              label: const Text('رفض', style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
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
                            icon: const Icon(Icons.forward, color: Colors.white),
                            label: const Text('تحويل', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      if (_isSecretary) const SizedBox(width: 12),
                      if (_isSecretary)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => showBriefAndForwardDialog(data),
                            icon: const Icon(Icons.upload_file, color: Colors.black),
                            label: const Text('إحالة للمدير مع ملخص', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amberAccent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
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
                        icon: const Icon(Icons.archive, color: Colors.white),
                        label: const Text('أرشفة', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade700,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF112240),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: const Text(
                      'هذه المخاطبة مؤرشفة وهي للقراءة فقط',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}