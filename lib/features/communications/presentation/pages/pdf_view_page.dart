import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../../../../core/services/communication_service.dart';
import '../widgets/forward_dialog.dart';
import 'tracking_page.dart';

class PdfViewPage extends StatefulWidget {
  final String? pdfUrl;
  final String? localFilePath;
  final String title;
  final String communicationId;
  final List<dynamic>? attachments;

  const PdfViewPage({
    super.key,
    this.pdfUrl,
    this.localFilePath,
    required this.title,
    required this.communicationId,
    this.attachments,
  });

  @override
  State<PdfViewPage> createState() => _PdfViewPageState();
}

class _PdfViewPageState extends State<PdfViewPage> {
  final PdfViewerController _pdfController = PdfViewerController();
  final CommunicationService _communicationService = CommunicationService();
  Map<String, dynamic>? userData;

  @override
  void initState() {
    super.initState();
    _markAsReadIfNeeded();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (mounted) {
      setState(() {
        userData = doc.data();
      });
    }
  }

  bool _canApprove(Map<String, dynamic> data) {
    if (userData == null) return false;
    final myTitle = userData!['administrative_title'] ?? 'staff';
    final senderTitle = data['sender_title'] ?? 'staff';
    final senderCollegeId = data['sender_college_id'] ?? '';
    final senderDeptId = data['sender_dept_id'] ?? '';
    final myCollegeId = userData!['college_id'] ?? '';
    final myDeptId = userData!['dept_id'] ?? '';

    final deanRoles = ['dean', 'center_director', 'general_director'];
    final viceDeanRoles = ['vice_dean', 'vice_dean_student', 'vice_dean_academic', 'vice_dean_postgraduate', 'vice_director'];

    if (myTitle == 'university_president') return true;
    if (deanRoles.contains(myTitle)) {
      if (senderCollegeId == myCollegeId) return true;
      return false;
    }
    if (viceDeanRoles.contains(myTitle)) {
      if (deanRoles.contains(senderTitle) || senderTitle == 'university_president') return false;
      if (senderCollegeId == myCollegeId) return true;
      return false;
    }
    if (myTitle == 'head_of_department') {
      if (deanRoles.contains(senderTitle) || viceDeanRoles.contains(senderTitle) || senderTitle == 'university_president') return false;
      if (senderDeptId == myDeptId) return true;
      return false;
    }
    return false;
  }

  Future<void> _markAsReadIfNeeded() async {
    await _communicationService.markAsReadIfNeeded(widget.communicationId);
  }

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

  void _showRejectDialog() {
    String reason = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF112240),
        title: const Text('سبب الرفض', style: TextStyle(color: Colors.white)),
        content: TextField(
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'اكتب سبب الرفض هنا...',
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
          ),
          onChanged: (v) => reason = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              if (reason.trim().isEmpty) return;
              Navigator.pop(context);
              _rejectWithReason(reason);
            },
            child: const Text('تأكيد الرفض', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectWithReason(String reason) async {
    try {
      await _communicationService.rejectCommunication(widget.communicationId, reason);
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت الأرشفة')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  void _showReplyDialog() {
    String replyText = '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF112240),
        title: const Text('إضافة رد إداري', style: TextStyle(color: Colors.white)),
        content: TextField(
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'اكتب إفادتك للمرسل الأساسي...',
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
          ),
          onChanged: (v) => replyText = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () {
              if (replyText.trim().isEmpty) return;
              Navigator.pop(context);
              _replyWithText(replyText);
            },
            child: const Text('إرسال الرد', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _replyWithText(String replyText) async {
    try {
      await _communicationService.replyToCommunication(widget.communicationId, replyText);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال الرد للمرسل')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  void _showForwardDialog() {
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
        },
      ),
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

  Future<void> _downloadAndOpenAttachment(String url, String fileName) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('جاري تحميل $fileName...')));
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}\\$fileName';
      final file = File(savePath);

      if (!file.existsSync()) {
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close();
        final bytes = await consolidateHttpClientResponseBytes(response);
        await file.writeAsBytes(bytes);
      }

      await OpenFilex.open(savePath);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء فتح الملف: $e')));
      }
    }
  }

  void _showAddWallReminderDialog() {
    
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
                  final service = CommunicationService();
                  await service.addWallReminder(widget.communicationId, widget.title, noteController.text.trim());
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

  void _showAttachmentsSheet() {
    if (widget.attachments == null || widget.attachments!.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF112240),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('المرفقات الإضافية', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.attachments!.length,
                  itemBuilder: (context, index) {
                    final att = widget.attachments![index] as Map<String, dynamic>;
                    final name = att['name'] ?? 'ملف مجهول';
                    final url = att['url'] ?? '';
                    final ext = att['extension']?.toString().toLowerCase() ?? '';
                    
                    IconData iconData = Icons.insert_drive_file;
                    Color iconColor = Colors.grey;
                    if (ext == 'pdf') { iconData = Icons.picture_as_pdf; iconColor = Colors.redAccent; }
                    else if (['jpg', 'jpeg', 'png'].contains(ext)) { iconData = Icons.image; iconColor = Colors.blueAccent; }
                    else if (['doc', 'docx'].contains(ext)) { iconData = Icons.description; iconColor = Colors.blue; }
                    else if (['xls', 'xlsx'].contains(ext)) { iconData = Icons.grid_on; iconColor = Colors.green; }

                    return ListTile(
                      leading: Icon(iconData, color: iconColor),
                      title: Text(name, style: const TextStyle(color: Colors.white)),
                      trailing: const Icon(Icons.download, color: Colors.white54),
                      onTap: () {
                        Navigator.pop(context);
                        _downloadAndOpenAttachment(url, name);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCircularReadersDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF112240),
        title: const Text('سجل قراءة التعميم', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('communications')
                .doc(widget.communicationId)
                .collection('tracking')
                .where('action', isEqualTo: 'acknowledge_circular')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('لم يقم أحد بقراءة التعميم بعد', style: TextStyle(color: Colors.white54)));
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final readerName = data['from_name'] ?? 'مستخدم غير معروف';
                  final timestamp = data['timestamp'];
                  
                  String formattedTime = '';
                  if (timestamp is Timestamp) {
                      final dt = timestamp.toDate();
                      formattedTime = "${dt.year}/${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
                  }
                  
                  return ListTile(
                    leading: const Icon(Icons.person, color: Colors.blueAccent),
                    title: Text(readerName, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(formattedTime, style: const TextStyle(color: Colors.white54)),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق', style: TextStyle(color: Colors.white54)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget pdfWidget;

    if (widget.localFilePath != null && widget.localFilePath!.isNotEmpty) {
      pdfWidget = SfPdfViewer.file(
        File(widget.localFilePath!),
        controller: _pdfController,
        canShowScrollHead: false,
      );
    } else if (widget.pdfUrl != null && widget.pdfUrl!.isNotEmpty) {
      pdfWidget = SfPdfViewer.network(
        widget.pdfUrl!,
        controller: _pdfController,
        canShowScrollHead: false,
      );
    } else {
      pdfWidget = const Center(child: Text('لا يوجد مسار أو رابط لعرض الملف.'));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        backgroundColor: const Color(0xFF0A192F),
        actions: [
          IconButton(
            icon: const Icon(Icons.push_pin, color: Color(0xFFD4AF37)),
            tooltip: 'إضافة لحائط التذكيرات',
            onPressed: _showAddWallReminderDialog,
          ),
          if (widget.attachments != null && widget.attachments!.isNotEmpty)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file, color: Colors.blueAccent),
                  tooltip: 'المرفقات',
                  onPressed: _showAttachmentsSheet,
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text(
                      '${widget.attachments!.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            tooltip: 'تكبير',
            onPressed: () => _pdfController.zoomLevel += 0.25,
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            tooltip: 'تصغير',
            onPressed: () {
              if (_pdfController.zoomLevel > 1) {
                _pdfController.zoomLevel -= 0.25;
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'سجل التتبع',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TrackingPage(
                    communicationId: widget.communicationId,
                    title: widget.title,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: pdfWidget,
      bottomNavigationBar: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('communications').doc(widget.communicationId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data == null) return const SizedBox.shrink();

          final isCircular = data['is_circular'] == true;
          final status = data['status'] ?? '';
          final currentRcvId = data['current_rcv_id'] ?? '';
          final senderId = data['sender_id'] ?? '';
          final myId = FirebaseAuth.instance.currentUser?.uid ?? '';
          
          final isArchived = status == 'archived';
          final isRejected = status == 'rejected';
          final isPublished = status == 'published';
          final isReceiver = currentRcvId == myId;

          // Circular Logic
          if (isCircular) {
            if (isPublished) {
              if (senderId == myId || userData?['role'] == 'admin') {
                return Container(
                  color: const Color(0xFF112240),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: SafeArea(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                      onPressed: _showCircularReadersDialog,
                      icon: const Icon(Icons.people, color: Colors.white),
                      label: const Text('سجل قراء التعميم', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                );
              } else {
                return Container(
                  color: const Color(0xFF112240),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: SafeArea(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text('تم تسجيل إطلاعك على التعميم تلقائياً', style: TextStyle(color: Colors.white, fontSize: 16)),
                      ],
                    ),
                  ),
                );
              }
            } else {
              // Not published yet, and it's a circular (means it's pending approval)
              final bool canApproveMsg = _canApprove(data);
              if (isReceiver && canApproveMsg) {
                return Container(
                  color: const Color(0xFF112240),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            onPressed: approveCommunication,
                            icon: const Icon(Icons.campaign, color: Colors.white),
                            label: const Text('اعتماد ونشر التعميم', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                            onPressed: _showRejectDialog,
                            icon: const Icon(Icons.close, color: Colors.white),
                            label: const Text('رفض النشر', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                return Container(
                  color: const Color(0xFF112240),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: const Text('تعميم قيد الاعتماد من الإدارة', style: TextStyle(color: Colors.white54, fontSize: 16), textAlign: TextAlign.center),
                );
              }
            }
          }

          // Regular Communication Logic
          final bool showButtons = isReceiver && !isArchived && !isRejected;
          final bool canApproveMsg = _canApprove(data);

          return Container(
            color: const Color(0xFF112240),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: !showButtons
                ? Text(
                    isArchived ? 'المخاطبة مؤرشفة أو معتمدة - وضع القراءة فقط' : (isRejected ? 'المخاطبة مرفوضة - وضع القراءة فقط' : 'وضع القراءة فقط (لست المستلم الحالي)'),
                    style: const TextStyle(color: Colors.white54, fontSize: 16),
                    textAlign: TextAlign.center,
                  )
                : SafeArea(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (canApproveMsg)
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              onPressed: approveCommunication,
                              icon: const Icon(Icons.check, color: Colors.white),
                              label: const Text('اعتماد', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        if (canApproveMsg) const SizedBox(width: 8),
                        if (canApproveMsg)
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                              onPressed: _showRejectDialog,
                              icon: const Icon(Icons.close, color: Colors.white),
                              label: const Text('رفض', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        if (canApproveMsg) const SizedBox(width: 8),
                        
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                            onPressed: _showForwardDialog,
                            icon: const Icon(Icons.forward, color: Colors.white),
                            label: const Text('تحويل', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        
                        if (userData?['administrative_title'] == 'secretary') ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                              onPressed: _forwardToManager,
                              icon: const Icon(Icons.arrow_upward, color: Colors.white),
                              label: const Text('إحالة للمدير', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                            onPressed: _showReplyDialog,
                            icon: const Icon(Icons.reply, color: Colors.white),
                            label: const Text('رد', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 8),

                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
                            onPressed: archiveCommunication,
                            icon: const Icon(Icons.archive, color: Colors.white),
                            label: const Text('أرشفة', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }
}