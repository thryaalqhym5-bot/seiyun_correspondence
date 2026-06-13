import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/communication_model.dart';
import '../../../../core/services/word_service.dart';
import '../../../../core/services/communication_service.dart';
import '../pages/create_communication_page.dart';

class MessageDetailWidget extends StatelessWidget {
  final CommunicationModel? message;
  final IconData emptyIcon;
  final String emptyText;
  final Color accentColor;
  final String? currentUserTitle;
  final bool isOutgoing;
  final List<Widget>? customActions;
  final VoidCallback? onReply;

  const MessageDetailWidget({
    super.key,
    required this.message,
    required this.emptyIcon,
    required this.emptyText,
    required this.accentColor,
    this.currentUserTitle,
    this.isOutgoing = false,
    this.customActions,
    this.onReply,
  });

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (message == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 80, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            Text(emptyText, style: const TextStyle(color: Colors.white54, fontSize: 18)),
          ],
        ),
      );
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    final effectiveIsOutgoing = isOutgoing || (message!.senderId == currentUser?.uid);
    final isExternal = message!.isExternal;
    final userLabel = isExternal ? 'الجهة المرسلة' : (effectiveIsOutgoing ? 'المرسل إليه' : 'المرسل');
    final userName = effectiveIsOutgoing ? message!.targetName : message!.senderName;
    final userIcon = isExternal ? Icons.business : (effectiveIsOutgoing ? Icons.outbox : Icons.person);

    return Container(
      color: AppColors.surface2.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Details Header
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        message!.subject,
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Row(
                      children: [
                        if (isExternal)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _buildBadge('وارد خارجي', Colors.orangeAccent),
                          ),
                        _buildBadge(message!.status, AppColors.success),
                        const SizedBox(width: 8),
                        // زر الرد يظهر للمراسلات الواردة، أو إذا كان هناك إجراء مخصص (مثل حائط التذكيرات)
                        if (!effectiveIsOutgoing || onReply != null)
                          IconButton(
                            icon: const Icon(Icons.reply, color: Colors.tealAccent),
                            onPressed: () {
                              if (onReply != null) {
                                onReply!();
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CreateCommunicationPage(
                                    replyTo: message,
                                    isExternalReply: isExternal,
                                  ),
                                ),
                              );
                            },
                            tooltip: 'رد على المخاطبة',
                          ),
                        IconButton(
                          icon: const Icon(Icons.push_pin_outlined, color: Colors.orangeAccent),
                          onPressed: () => _showAddWallReminderDialog(context),
                          tooltip: 'تعليق في حائط التذكيرات',
                        ),
                        IconButton(
                          icon: const Icon(Icons.print_outlined, color: Colors.white70),
                          onPressed: () {
                            if (isExternal) {
                              _openExternalDocument(context);
                            } else {
                              WordService.openCommunicationPdf(
                                context,
                                message!.toJson(),
                                message!.id ?? '',
                                message!.subject,
                              );
                            }
                          },
                          tooltip: isExternal ? 'عرض الوثيقة الأصلية' : 'طباعة / معاينة PDF',
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: accentColor.withValues(alpha: 0.2),
                          child: Icon(userIcon, color: accentColor),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                userLabel,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // عرض المرجع والتاريخ للمراسلات الخارجية
                    if (isExternal && message!.referenceNumber != null && message!.referenceNumber!.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tag, size: 14, color: Colors.white.withValues(alpha: 0.3)),
                          const SizedBox(width: 4),
                          Text('المرجع: ${message!.referenceNumber}',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                        ],
                      ),
                    if (isExternal && message!.documentDate != null && message!.documentDate!.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today, size: 14, color: Colors.white.withValues(alpha: 0.3)),
                          const SizedBox(width: 4),
                          Text('تاريخ الخطاب: ${message!.documentDate}',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          // شريط ربط الرد بالأصل
          if (message!.parentCommId != null && message!.parentCommId!.isNotEmpty)
            _buildThreadLinkBanner(context),
          // شريط عرض الردود على هذه المراسلة
          _buildRepliesBanner(),
          // Details Body
          Expanded(
            child: isExternal
                ? _buildExternalDocumentView()
                : _buildInternalMessageBody(context, effectiveIsOutgoing),
          ),
        ],
      ),
    );
  }

  /// شريط يُظهر أن هذه الرسالة رد على مراسلة أخرى مع رابط للأصل
  Widget _buildThreadLinkBanner(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('communications')
          .doc(message!.parentCommId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }
        final parentData = snapshot.data!.data() as Map<String, dynamic>;
        final parentSubject = parentData['subject'] ?? 'مخاطبة';
        final parentRef = parentData['reference_number'] ?? '';

        return InkWell(
          onTap: () {
            // عرض تفاصيل المراسلة الأصلية في Dialog
            _showOriginalMessageDialog(context, snapshot.data!);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.tealAccent.withValues(alpha: 0.05),
              border: Border(
                bottom: BorderSide(color: Colors.tealAccent.withValues(alpha: 0.1)),
                top: BorderSide(color: Colors.tealAccent.withValues(alpha: 0.1)),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.reply, size: 16, color: Colors.tealAccent),
                const SizedBox(width: 8),
                const Text('هذه رد على: ', style: TextStyle(color: Colors.tealAccent, fontSize: 13)),
                Expanded(
                  child: Text(
                    parentRef.isNotEmpty ? '$parentSubject (مرجع: $parentRef)' : parentSubject,
                    style: const TextStyle(
                      color: Colors.tealAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.open_in_new, size: 14, color: Colors.tealAccent),
              ],
            ),
          ),
        );
      },
    );
  }

  /// شريط يُظهر عدد الردود على هذه المراسلة
  Widget _buildRepliesBanner() {
    if (message!.id == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('communications')
          .where('parent_comm_id', isEqualTo: message!.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final replies = snapshot.data!.docs;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.05),
            border: Border(
              bottom: BorderSide(color: Colors.amber.withValues(alpha: 0.1)),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.forum_outlined, size: 16, color: Colors.amber),
              const SizedBox(width: 8),
              Text(
                'يوجد ${replies.length} رد على هذه المخاطبة',
                style: const TextStyle(color: Colors.amber, fontSize: 13),
              ),
              const Spacer(),
              // عرض آخر رد
              Text(
                'آخر رد: ${(replies.last.data() as Map<String, dynamic>)['subject'] ?? ''}',
                style: TextStyle(color: Colors.amber.withValues(alpha: 0.6), fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  /// عرض المراسلة الأصلية في نافذة
  void _showOriginalMessageDialog(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.6,
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withValues(alpha: 0.05),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.article_outlined, color: Colors.tealAccent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('المخاطبة الأصلية', style: TextStyle(color: Colors.tealAccent, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            data['subject'] ?? '',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              // Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoRow('المرسل', data['sender_name'] ?? ''),
                      _infoRow('المستقبل', data['target_name'] ?? ''),
                      if (data['reference_number'] != null && (data['reference_number'] as String).isNotEmpty)
                        _infoRow('المرجع', data['reference_number']),
                      _infoRow('الحالة', data['status'] ?? ''),
                      const Divider(color: Colors.white10, height: 32),
                      const Text('المحتوى:', style: TextStyle(color: Colors.white54, fontSize: 13)),
                      const SizedBox(height: 8),
                      Text(
                        (data['body'] ?? '').toString().isEmpty
                            ? 'لا يوجد محتوى نصي.'
                            : data['body'],
                        style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.6),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text('$label:', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  /// عرض محتوى المراسلة الداخلية (النص + زر معاينة Word)
  Widget _buildInternalMessageBody(BuildContext context, bool effectiveIsOutgoing) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('محتوى الرسالة:', style: TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 16),
          Text(
            message!.body.isEmpty ? 'لا يوجد محتوى نصي. قم بفتح الملف المرفق.' : message!.body,
            style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.6),
          ),
          const SizedBox(height: 48),
          // Action Buttons
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                onPressed: () {
                  WordService.openCommunicationPdf(
                    context,
                    message!.toJson(),
                    message!.id ?? '',
                    message!.subject,
                  );
                },
                icon: const Icon(Icons.visibility),
                label: const Text('معاينة الوثيقة (PDF)'),
              ),
              if (!effectiveIsOutgoing || onReply != null) ...[
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    if (onReply != null) onReply!();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateCommunicationPage(replyTo: message),
                      ),
                    );
                  },
                  icon: const Icon(Icons.reply),
                  label: const Text('رد'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                ),
              ],
              if (customActions != null) ...[
                if (!effectiveIsOutgoing) const SizedBox(width: 16),
                ...customActions!,
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// عرض الوثيقة الخارجية مباشرة (PDF أو صورة) بدون تحويل
  Widget _buildExternalDocumentView() {
    String? fileUrl = message!.generatedDocxUrl;
    if (fileUrl == null || fileUrl.isEmpty) {
      if (message!.attachments != null && message!.attachments!.isNotEmpty) {
        fileUrl = message!.attachments!.first['url'] as String?;
      }
    }
    
    if (fileUrl == null || fileUrl.isEmpty) {
      return const Center(
        child: Text('لا يوجد ملف مرفق لهذه المراسلة',
            style: TextStyle(color: Colors.white54, fontSize: 16)),
      );
    }

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
                  child: CircularProgressIndicator(color: Colors.orangeAccent));
            },
            errorBuilder: (ctx, err, stack) => const Center(
              child: Text('فشل في تحميل الصورة',
                  style: TextStyle(color: Colors.white54)),
            ),
          ),
        ),
      );
    }

    // نوع غير مدعوم
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.insert_drive_file_outlined, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          const Text('هذا النوع من الملفات لا يدعم المعاينة المباشرة',
              style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }

  /// فتح الوثيقة الخارجية ملء الشاشة
  void _openExternalDocument(BuildContext context) {
    String? fileUrl = message!.generatedDocxUrl;
    if (fileUrl == null || fileUrl.isEmpty) {
      if (message!.attachments != null && message!.attachments!.isNotEmpty) {
        fileUrl = message!.attachments!.first['url'] as String?;
      }
    }
    
    if (fileUrl == null || fileUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد ملف مرفق'), backgroundColor: Colors.red),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: const Color(0xFF0A192F),
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              message!.subject,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              if (message!.referenceNumber != null && message!.referenceNumber!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: Text(
                      'المرجع: ${message!.referenceNumber}',
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ),
                ),
            ],
          ),
          body: _buildExternalDocumentView(),
        ),
      ),
    );
  }

  void _showAddWallReminderDialog(BuildContext context) {
    if (message?.id == null) return;
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
              hintText: 'اكتب تذكيرك هنا (مثلاً: متابعة القرار خلال أسبوع)',
              hintStyle: const TextStyle(color: Colors.white54),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
              focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.orangeAccent)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
              onPressed: isSaving ? null : () async {
                if (noteController.text.trim().isEmpty) return;
                setStateDialog(() => isSaving = true);
                try {
                  final service = CommunicationService();
                  await service.addWallReminder(message!.id!, message!.subject, noteController.text.trim());
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة التذكير لحائطك بنجاح')));
                  }
                } catch (e) {
                  setStateDialog(() => isSaving = false);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
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
}

