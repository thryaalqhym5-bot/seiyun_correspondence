import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/models/communication_model.dart';
import '../../../../core/services/communication_service.dart';
import '../viewmodels/communications_viewmodel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'create_communication_page.dart';

class ExternalInboxPage extends StatefulWidget {
  const ExternalInboxPage({super.key});

  @override
  State<ExternalInboxPage> createState() => _ExternalInboxPageState();
}

class _ExternalInboxPageState extends State<ExternalInboxPage> {
  final CommunicationsViewModel _viewModel = CommunicationsViewModel();
  final CommunicationService _commService = CommunicationService();
  CommunicationModel? _selectedMessage;
  String _searchQuery = '';
  bool _isActionLoading = false;
  String _userTitle = 'staff';

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _userTitle = doc.data()?['administrative_title'] ?? 'staff';
        });
      }
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: AppCard(
            padding: EdgeInsets.zero,
            child: Row(
              children: [
                // ============ القائمة اليمنى (List) ============
                Expanded(
                  flex: 2,
                  child: _buildMessageList(),
                ),
                // ============ التفاصيل اليسرى (Detail) ============
                Expanded(
                  flex: 3,
                  child: _buildDetailPane(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // قائمة الخطابات الخارجية
  // ============================================================
  Widget _buildMessageList() {
    return Container(
      decoration: BoxDecoration(
        border:
            Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.markunread_mailbox_outlined,
                        color: Colors.orangeAccent, size: 22),
                    const SizedBox(width: 10),
                    const Text(
                      'الوارد الخارجي',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'بحث (الموضوع، الجهة المرسلة)...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    prefixIcon:
                        const Icon(Icons.search, color: Colors.orangeAccent),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: StreamBuilder<List<CommunicationModel>>(
              stream: _viewModel.getExternalInboxStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Colors.orangeAccent));
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text('خطأ: ${snapshot.error}',
                          style: const TextStyle(color: AppColors.danger)));
                }

                final allMessages = snapshot.data ?? [];
                final messages = allMessages.where((msg) {
                  if (_searchQuery.isEmpty) return true;
                  final q = _searchQuery.toLowerCase();
                  return msg.subject.toLowerCase().contains(q) ||
                      msg.senderName.toLowerCase().contains(q);
                }).toList();

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.markunread_mailbox_outlined,
                            size: 64,
                            color: Colors.white.withValues(alpha: 0.15)),
                        const SizedBox(height: 16),
                        const Text('لا توجد خطابات خارجية جديدة',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 16)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: messages.length,
                  separatorBuilder: (_, __) =>
                      Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isSelected = _selectedMessage?.id == msg.id;
                    final isUnread = !msg.isReadByDean;

                    return Material(
                      color: isSelected
                          ? Colors.orangeAccent.withValues(alpha: 0.1)
                          : Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() => _selectedMessage = msg);
                          // تحديث حالة القراءة عند الفتح
                          if (isUnread && msg.id != null) {
                            _commService.markExternalAsReviewed(msg.id!);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (isUnread)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin:
                                          const EdgeInsets.only(left: 8),
                                      decoration: const BoxDecoration(
                                        color: Colors.orangeAccent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  Expanded(
                                    child: Text(
                                      msg.senderName.isNotEmpty
                                          ? msg.senderName
                                          : 'جهة خارجية',
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.orangeAccent
                                            : Colors.white,
                                        fontWeight: isUnread
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  _buildBadge(
                                    msg.status == 'archived'
                                        ? 'جديد'
                                        : 'تمت المراجعة',
                                    msg.status == 'archived'
                                        ? Colors.orangeAccent
                                        : Colors.greenAccent,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                msg.subject,
                                style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white70,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (msg.referenceNumber != null &&
                                  msg.referenceNumber!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.confirmation_number_outlined,
                                        size: 14, color: Colors.white54),
                                    const SizedBox(width: 4),
                                    Text(
                                      'رقم القيد: ${msg.referenceNumber}',
                                      style: const TextStyle(
                                          color: Colors.white54, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                              if (msg.externalReferenceNumber != null &&
                                  msg.externalReferenceNumber!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.tag,
                                        size: 14, color: Colors.white54),
                                    const SizedBox(width: 4),
                                    Text(
                                      'المرجع الخارجي: ${msg.externalReferenceNumber}',
                                      style: const TextStyle(
                                          color: Colors.white54, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // تفاصيل الخطاب + عرض الملف الأصلي + أزرار الإجراءات
  // ============================================================
  Widget _buildDetailPane() {
    if (_selectedMessage == null) {
      return Container(
        color: AppColors.surface2.withValues(alpha: 0.3),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.markunread_mailbox_outlined,
                  size: 80, color: Colors.white.withValues(alpha: 0.1)),
              const SizedBox(height: 16),
              const Text('اختر خطاباً لعرض تفاصيله ومعاينة الوثيقة',
                  style: TextStyle(color: Colors.white54, fontSize: 18)),
            ],
          ),
        ),
      );
    }

    final msg = _selectedMessage!;
    return Container(
      color: AppColors.surface2.withValues(alpha: 0.3),
      child: Column(
        children: [
          // ===== Header =====
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(msg.subject,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                    ),
                    _buildBadge('وارد خارجي', Colors.orangeAccent),
                  ],
                ),
                const SizedBox(height: 16),
                // بيانات الخطاب
                Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    _buildInfoChip(Icons.business, 'الجهة', msg.senderName),
                    if (msg.referenceNumber != null &&
                        msg.referenceNumber!.isNotEmpty)
                      _buildInfoChip(
                          Icons.confirmation_number_outlined, 'رقم القيد', msg.referenceNumber!),
                    if (msg.externalReferenceNumber != null &&
                        msg.externalReferenceNumber!.isNotEmpty)
                      _buildInfoChip(
                          Icons.tag, 'المرجع الخارجي', msg.externalReferenceNumber!),
                    if (msg.documentDate != null &&
                        msg.documentDate!.isNotEmpty)
                      _buildInfoChip(
                          Icons.calendar_today, 'التاريخ', msg.documentDate!),
                  ],
                ),
              ],
            ),
          ),
          // ===== Document Preview =====
          Expanded(
            child: _buildDocumentPreview(msg),
          ),
          // ===== Action Bar =====
          if (msg.status == 'archived' ||
              msg.status == 'external_reviewed' ||
              msg.status == 'external_pending')
            _buildActionBar(msg),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white38),
        const SizedBox(width: 6),
        Text('$label: ',
            style: const TextStyle(color: Colors.white38, fontSize: 12)),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ============================================================
  // عرض الملف الأصلي (PDF أو صورة) مباشرة
  // ============================================================
  Widget _buildDocumentPreview(CommunicationModel msg) {
    final fileUrl = msg.generatedDocxUrl;
    if (fileUrl == null || fileUrl.isEmpty) {
      return const Center(
        child: Text('لا يوجد ملف مرفق',
            style: TextStyle(color: Colors.white54, fontSize: 16)),
      );
    }

    // تحديد نوع الملف من الرابط
    final lowerUrl = fileUrl.toLowerCase();
    final isPdf = lowerUrl.contains('.pdf') || lowerUrl.contains('pdf');
    final isImage = lowerUrl.contains('.jpg') ||
        lowerUrl.contains('.jpeg') ||
        lowerUrl.contains('.png') ||
        lowerUrl.contains('image');

    if (isPdf) {
      return SfPdfViewer.network(
        fileUrl,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        enableDoubleTapZooming: true,
      );
    } else if (isImage) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: Image.network(
            fileUrl,
            fit: BoxFit.contain,
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return const Center(
                  child: CircularProgressIndicator(
                      color: Colors.orangeAccent));
            },
            errorBuilder: (ctx, err, stack) => const Center(
              child: Text('فشل في تحميل الصورة',
                  style: TextStyle(color: Colors.white54)),
            ),
          ),
        ),
      );
    }

    // ملف غير مدعوم للمعاينة
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.insert_drive_file_outlined,
              size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          const Text('هذا النوع من الملفات لا يدعم المعاينة المباشرة',
              style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 8),
          const Text('يمكنك تحميل الملف لفتحه',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }

  // ============================================================
  // شريط الإجراءات (Action Bar)
  // ============================================================
  Widget _buildActionBar(CommunicationModel msg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border:
            Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: _isActionLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.orangeAccent))
          : Row(
              children: [
                // الرد
                _buildActionButton(
                  icon: Icons.reply,
                  label: 'الرد',
                  color: Colors.orangeAccent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateCommunicationPage(
                          replyTo: msg,
                          isExternalReply: true,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                // إحالة
                _buildActionButton(
                  icon: Icons.forward_to_inbox,
                  label: 'إحالة',
                  color: Colors.blueAccent,
                  onTap: () => _showForwardDialog(msg),
                ),
                const SizedBox(width: 12),
                // تعميم
                _buildActionButton(
                  icon: Icons.campaign_outlined,
                  label: 'تعميم',
                  color: Colors.purpleAccent,
                  onTap: () => _showCirculateDialog(msg),
                ),
                const SizedBox(width: 12),
                // اطلعت
                _buildActionButton(
                  icon: Icons.check_circle_outline,
                  label: 'اطلعت',
                  color: Colors.greenAccent,
                  onTap: () => _acknowledgeMessage(msg),
                ),
              ],
            ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 13)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.15),
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
      ),
    );
  }

  // ============================================================
  // نوافذ الإجراءات
  // ============================================================
  Future<void> _showForwardDialog(CommunicationModel msg) async {
    String? selectedUserId;
    String? selectedUserName;
    String? selectedDeptId;
    final commentController = TextEditingController();

    // جلب المستخدمين المسموح بهم
    final targets = await _commService.fetchAllowedTargets();

    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.forward_to_inbox, color: Colors.blueAccent),
              const SizedBox(width: 10),
              const Text('إحالة الخطاب',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('اختر الشخص المعني:',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  dropdownColor: AppColors.surface,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                  hint: const Text('اختر المستقبل',
                      style: TextStyle(color: Colors.white38)),
                  items: targets.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['full_name'] ?? doc.id;
                    return DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text(name.toString()),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setDialogState(() {
                      selectedUserId = val;
                      final target = targets.firstWhere((d) => d.id == val);
                      final tData = target.data() as Map<String, dynamic>;
                      selectedUserName = tData['full_name'] ?? '';
                      selectedDeptId = tData['dept_id'] ?? '';
                    });
                  },
                ),
                const SizedBox(height: 16),
                const Text('ملاحظة/توجيه (اختياري):',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                TextField(
                  controller: commentController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'أضف توجيهاً أو ملاحظة...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: selectedUserId == null
                  ? null
                  : () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent),
              child: const Text('إحالة'),
            ),
          ],
        ),
      ),
    );

    if (result == true &&
        selectedUserId != null &&
        msg.id != null) {
      setState(() => _isActionLoading = true);
      try {
        await _commService.forwardExternalCommunication(
          msg.id!,
          selectedUserId!,
          selectedUserName ?? '',
          selectedDeptId ?? '',
          commentController.text.trim(),
        );
        if (mounted) {
          setState(() => _selectedMessage = null);
          _showSnackBar('تم إحالة الخطاب بنجاح ✓', isError: false);
        }
      } catch (e) {
        _showSnackBar('خطأ: $e');
      } finally {
        if (mounted) setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _showCirculateDialog(CommunicationModel msg) async {
    List<DropdownMenuItem<String>> items = [];
    
    if (['university_president', 'university_vp', 'general_secretary'].contains(_userTitle)) {
      items = const [
        DropdownMenuItem(value: 'all_university', child: Text('كل منسوبي الجامعة')),
        DropdownMenuItem(value: 'all_deans', child: Text('عمداء الكليات ومدراء المراكز')),
      ];
    } else if (['dean', 'vice_dean', 'vice_dean_student', 'vice_dean_academic', 'vice_dean_postgraduate', 'center_director', 'vice_director', 'general_director'].contains(_userTitle)) {
      items = const [
        DropdownMenuItem(value: 'all_college', child: Text('كل منسوبي الكلية/المركز')),
        DropdownMenuItem(value: 'college_management', child: Text('رؤساء الأقسام والإدارات فقط')),
      ];
    } else if (_userTitle == 'head_of_department') {
      items = const [
        DropdownMenuItem(value: 'all_department', child: Text('كل منسوبي القسم')),
      ];
    } else {
      items = const [
        DropdownMenuItem(value: 'all_college', child: Text('كل المنسوبين')),
      ];
    }

    String targetGroup = items.first.value!;
    final commentController = TextEditingController();

    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.campaign_outlined, color: Colors.purpleAccent),
              const SizedBox(width: 10),
              const Text('تعميم الخطاب',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('نطاق التعميم:',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: targetGroup,
                  dropdownColor: AppColors.surface,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                  items: items,
                  onChanged: (v) =>
                      setDialogState(() => targetGroup = v ?? items.first.value!),
                ),
                const SizedBox(height: 16),
                const Text('ملاحظة (اختياري):',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                TextField(
                  controller: commentController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'أضف ملاحظة للتعميم...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent),
              child: const Text('تعميم'),
            ),
          ],
        ),
      ),
    );

    if (result == true && msg.id != null) {
      setState(() => _isActionLoading = true);
      try {
        await _commService.circulateExternalCommunication(
          msg.id!,
          targetGroup,
          commentController.text.trim(),
        );
        if (mounted) {
          setState(() => _selectedMessage = null);
          _showSnackBar('تم تعميم الخطاب بنجاح ✓', isError: false);
        }
      } catch (e) {
        _showSnackBar('خطأ: $e');
      } finally {
        if (mounted) setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _acknowledgeMessage(CommunicationModel msg) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد الاطلاع',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'هل ترغب في تأكيد اطلاعك على هذا الخطاب وأرشفته؟\nلن يتم إحالته أو تعميمه.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent.shade700),
            child: const Text('نعم، اطلعت'),
          ),
        ],
      ),
    );

    if (confirm == true && msg.id != null) {
      setState(() => _isActionLoading = true);
      try {
        await _commService.acknowledgeExternalCommunication(msg.id!);
        if (mounted) {
          setState(() => _selectedMessage = null);
          _showSnackBar('تم الاطلاع والأرشفة بنجاح ✓', isError: false);
        }
      } catch (e) {
        _showSnackBar('خطأ: $e');
      } finally {
        if (mounted) setState(() => _isActionLoading = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
