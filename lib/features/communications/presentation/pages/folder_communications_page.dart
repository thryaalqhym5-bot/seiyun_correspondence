import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/word_service.dart';

class FolderCommunicationsPage extends StatefulWidget {
  final String folderId;
  final String folderName;
  final String folderType; // incoming, outgoing, custom

  const FolderCommunicationsPage({
    super.key,
    required this.folderId,
    required this.folderName,
    required this.folderType,
  });

  @override
  State<FolderCommunicationsPage> createState() => _FolderCommunicationsPageState();
}

class _FolderCommunicationsPageState extends State<FolderCommunicationsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';
  Map<String, dynamic>? _selectedCommunication;

  /// جلب المراسلات من كلا الحقلين (sender + receiver) وتوحيد النتائج
  Stream<List<QueryDocumentSnapshot>> _getCommunicationsStream() {
    // نبحث في الحقلين معاً لنضمن عدم فقدان أي مراسلة
    final senderStream = _firestore
        .collection('communications')
        .where('sender_archive_folder_id', isEqualTo: widget.folderId)
        .snapshots();

    final receiverStream = _firestore
        .collection('communications')
        .where('receiver_archive_folder_id', isEqualTo: widget.folderId)
        .snapshots();

    // نستخدم rxdart أو Filter.or، لكن لتجنب مشاكل الفهرسة، سندمج البثين يدوياً
    final controller = StreamController<List<QueryDocumentSnapshot>>();
    
    List<QueryDocumentSnapshot> senderDocs = [];
    List<QueryDocumentSnapshot> receiverDocs = [];

    void emitCombined() {
      final Map<String, QueryDocumentSnapshot> uniqueDocs = {};
      for (final doc in senderDocs) uniqueDocs[doc.id] = doc;
      for (final doc in receiverDocs) uniqueDocs[doc.id] = doc;
      controller.add(uniqueDocs.values.toList());
    }

    final sub1 = senderStream.listen((snap) {
      senderDocs = snap.docs;
      emitCombined();
    });

    final sub2 = receiverStream.listen((snap) {
      receiverDocs = snap.docs;
      emitCombined();
    });

    controller.onCancel = () {
      sub1.cancel();
      sub2.cancel();
    };

    return controller.stream;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // يعتمد على الـ Layout
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.arrow_back, color: Colors.white54, size: 18),
                              SizedBox(width: 8),
                              Text('العودة للدواليب', style: TextStyle(color: Colors.white54, fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        widget.folderName,
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: 350,
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: TextField(
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'ابحث برقم المرجع أو الموضوع...',
                          hintStyle: TextStyle(color: Colors.white38),
                          border: InputBorder.none,
                          icon: Icon(Icons.search, color: Colors.white38),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Layout Builder for Split Pane
              Expanded(
                child: StreamBuilder<List<QueryDocumentSnapshot>>(
                  stream: _getCommunicationsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return _buildEmptyState('لا توجد مخاطبات في هذا الملف.');
                    }

                    var docs = snapshot.data!.toList();
                    
                    // ترتيب من الأحدث للأقدم (client-side بدلاً من Firestore composite index)
                    docs.sort((a, b) {
                      final ta = (a.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
                      final tb = (b.data() as Map<String, dynamic>)['created_at'] as Timestamp?;
                      if (ta == null && tb == null) return 0;
                      if (ta == null) return 1;
                      if (tb == null) return -1;
                      return tb.compareTo(ta);
                    });

                    if (_searchQuery.isNotEmpty) {
                      docs = docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final ref = (data['reference_number'] ?? '').toString().toLowerCase();
                        final sub = (data['subject'] ?? '').toString().toLowerCase();
                        return ref.contains(_searchQuery) || sub.contains(_searchQuery);
                      }).toList();
                    }

                    if (docs.isEmpty) {
                      return _buildEmptyState('لم يتم العثور على نتائج.');
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        // Desktop/Tablet layout (Split Pane)
                        if (constraints.maxWidth > 800) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Inbox List
                              Expanded(
                                flex: 2,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                  ),
                                  child: ListView.separated(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    itemCount: docs.length,
                                    separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
                                    itemBuilder: (context, index) {
                                      final data = docs[index].data() as Map<String, dynamic>;
                                      final isSelected = _selectedCommunication?['id'] == docs[index].id;
                                      data['id'] = docs[index].id; // inject ID for selection check
                                      
                                      return _MailListItem(
                                        data: data,
                                        isSelected: isSelected,
                                        onTap: () {
                                          setState(() => _selectedCommunication = data);
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 24),
                              // Preview Panel
                              Expanded(
                                flex: 3,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                  ),
                                  child: _selectedCommunication == null
                                      ? Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.mail_outline, size: 80, color: Colors.white.withValues(alpha: 0.05)),
                                              const SizedBox(height: 24),
                                              const Text('اختر رسالة لعرض محتواها', style: TextStyle(color: Colors.white54, fontSize: 18)),
                                            ],
                                          ),
                                        )
                                      : _MessagePreviewPanel(data: _selectedCommunication!),
                                ),
                              ),
                            ],
                          );
                        } else {
                          // Mobile layout
                          return Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                            ),
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: docs.length,
                              separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
                              itemBuilder: (context, index) {
                                final data = docs[index].data() as Map<String, dynamic>;
                                return _MailListItem(
                                  data: data,
                                  isSelected: false,
                                  onTap: () {
                                    // Handle mobile tap (e.g. show bottom sheet or push new page)
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (context) => Container(
                                        height: MediaQuery.of(context).size.height * 0.85,
                                        decoration: const BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                        ),
                                        child: _MessagePreviewPanel(data: data),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.document_scanner_outlined, size: 80, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 24),
          Text(message, style: const TextStyle(color: Colors.white54, fontSize: 18)),
        ],
      ),
    );
  }
}

class _MailListItem extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isSelected;
  final VoidCallback onTap;

  const _MailListItem({required this.data, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final rawRef = data['reference_number'] ?? '';
    final hasRef = rawRef.toString().trim().isNotEmpty;
    final subject = data['subject'] ?? 'بدون موضوع';
    final sender = data['sender_name'] ?? 'مجهول';
    final isRead = data['is_read'] ?? true; // assume true if null
    final priority = data['priority'] ?? 'عادي';
    
    DateTime? date;
    if (data['created_at'] != null) {
      date = (data['created_at'] as Timestamp).toDate();
    }
    final dateString = date != null ? DateFormat('MMM dd, hh:mm a').format(date) : '';

    return Material(
      color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: AppColors.surface2,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 4,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      sender,
                      style: TextStyle(
                        color: isRead ? Colors.white70 : Colors.white,
                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    dateString,
                    style: TextStyle(
                      color: isRead ? Colors.white38 : AppColors.primary,
                      fontSize: 12,
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                subject,
                style: TextStyle(
                  color: isRead ? Colors.white : Colors.white,
                  fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (hasRef)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('Ref: $rawRef', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    ),
                  if (hasRef) const SizedBox(width: 8),
                   if (priority == 'عاجل' || priority == 'عاجل جداً')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                      ),
                      child: Text(priority, style: const TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  if (data['is_external'] == true) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
                      ),
                      child: const Text('خارجي', style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessagePreviewPanel extends StatelessWidget {
  final Map<String, dynamic> data;

  const _MessagePreviewPanel({required this.data});

  @override
  Widget build(BuildContext context) {
    final subject = data['subject'] ?? 'بدون موضوع';
    final sender = data['sender_name'] ?? 'مجهول';
    final target = data['target_name'] ?? 'مجهول';
    final body = data['body'] ?? data['content'] ?? '';
    final rawRef = data['reference_number'] ?? '';
    final extRef = data['external_reference_number'] ?? '';
    final hasRef = rawRef.toString().isNotEmpty;
    final hasExtRef = extRef.toString().isNotEmpty;
    final isExternal = data['is_external'] == true;
    final fileUrl = data['generated_docx_url'] ?? '';
    final commId = data['comm_id'] ?? '';
    
    DateTime? date;
    if (data['created_at'] != null) {
      date = (data['created_at'] as Timestamp).toDate();
    }
    final dateString = date != null ? DateFormat('yyyy-MM-dd hh:mm a').format(date) : '-';

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  subject,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              Row(
                children: [
                  if (isExternal)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
                      ),
                      child: const Text('وارد خارجي', style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  IconButton(
                    icon: const Icon(Icons.open_in_full, color: AppColors.primary),
                    onPressed: () => _openDocument(context, isExternal, fileUrl, commId, subject),
                    tooltip: 'عرض الوثيقة',
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                child: Icon(
                  isExternal ? Icons.business : Icons.person,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sender, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('إلى: $target', style: const TextStyle(color: Colors.white54, fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(dateString, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(height: 4),
                  if (hasRef)
                    Text('رقم القيد: $rawRef', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                  if (hasExtRef) ...[
                    const SizedBox(height: 2),
                    Text('المرجع الخارجي: $extRef', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),
          // زر معاينة الوثيقة
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () => _openDocument(context, isExternal, fileUrl, commId, subject),
            icon: Icon(isExternal ? Icons.visibility : Icons.picture_as_pdf),
            label: Text(isExternal ? 'معاينة الوثيقة الأصلية' : 'معاينة الوثيقة (PDF)'),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                body.toString().isEmpty ? 'لا يوجد نص للرسالة.' : body.toString(),
                style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openDocument(BuildContext context, bool isExternal, String fileUrl, String commId, String subject) {
    if (isExternal) {
      // عرض الملف الخارجي مباشرة ملء الشاشة
      if (fileUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يوجد ملف مرفق'), backgroundColor: Colors.red),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _ExternalDocFullScreen(fileUrl: fileUrl, subject: subject),
        ),
      );
    } else {
      // عرض الوثيقة الداخلية عبر WordService
      // نحتاج استيراد WordService
      _openInternalPdf(context, commId, subject);
    }
  }

  void _openInternalPdf(BuildContext context, String commId, String subject) {
    WordService.openCommunicationPdf(context, data, commId, subject);
  }
}

/// صفحة عرض ملء الشاشة للمستندات الخارجية في الأرشيف
class _ExternalDocFullScreen extends StatelessWidget {
  final String fileUrl;
  final String subject;

  const _ExternalDocFullScreen({required this.fileUrl, required this.subject});

  @override
  Widget build(BuildContext context) {
    final isPdf = fileUrl.toLowerCase().contains('.pdf');

    return Scaffold(
      backgroundColor: const Color(0xFF0A192F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF112240),
        title: Text(subject, style: const TextStyle(color: Colors.white, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isPdf
          ? SfPdfViewer.network(fileUrl)
          : InteractiveViewer(
              maxScale: 5.0,
              child: Center(
                child: Image.network(
                  fileUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  },
                  errorBuilder: (_, __, ___) => const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 64, color: Colors.white24),
                        SizedBox(height: 16),
                        Text('تعذر تحميل الملف', style: TextStyle(color: Colors.white54)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
