import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class TrackingPage extends StatelessWidget {
  final String communicationId;
  final String title;

  const TrackingPage({
    super.key,
    required this.communicationId,
    required this.title,
  });

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dt = timestamp.toDate();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'approve':
        return 'اعتماد';
      case 'reject':
        return 'رفض';
      case 'archive':
        return 'أرشفة';
      case 'comment':
        return 'تعليق';
      case 'forward':
        return 'إحالة / تحويل';
      case 'send':
        return 'إرسال مبدئي';
      case 'read':
        return 'قراءة / استلام';
      default:
        return action;
    }
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'approve':
        return Colors.greenAccent;
      case 'reject':
        return Colors.redAccent;
      case 'archive':
        return Colors.grey;
      case 'comment':
        return Colors.orangeAccent;
      case 'forward':
        return Colors.blueAccent;
      case 'send':
        return Colors.tealAccent;
      case 'read':
        return Colors.purpleAccent;
      default:
        return Colors.white54;
    }
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'approve':
        return Icons.verified;
      case 'reject':
        return Icons.cancel;
      case 'archive':
        return Icons.archive;
      case 'comment':
        return Icons.comment;
      case 'forward':
        return Icons.shortcut;
      case 'send':
        return Icons.send;
      case 'read':
        return Icons.mark_email_read;
      default:
        return Icons.history;
    }
  }

  // دالة لتنظيف التعليقات المشوهة القديمة التي حفظت بالترميز الخاطئ
  String _cleanComment(String action, String originalComment) {
    if (originalComment.contains('ط·') || originalComment.contains('ط¸') || originalComment.contains('€')) {
      // إذا كان النص مشوهاً، نعتمد على نوع الإجراء لاستنتاج التعليق
      switch (action) {
        case 'send':
          return 'تم إنشاء وإرسال المخاطبة عبر النظام بنجاح.';
        case 'forward':
          return 'تمت إحالة المخاطبة إلى الجهة أو الشخص المعني.';
        case 'approve':
          return 'تم اعتماد المخاطبة بشكل رسمي.';
        case 'archive':
          return 'تم حفظ المخاطبة في الأرشيف.';
        case 'reject':
          return 'تم رفض المخاطبة وإعادتها.';
        case 'read':
          return 'تم استلام وفتح المخاطبة.';
        default:
          return 'تم إجراء عملية: ${_actionLabel(action)}';
      }
    }
    return originalComment;
  }

  @override
  Widget build(BuildContext context) {
    const darkBlueBg = Color(0xFF0A192F);

    return Scaffold(
      backgroundColor: darkBlueBg,
      appBar: AppBar(
        title: const Text('السجل الزمني للتتبع', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.timeline, color: Colors.blueAccent, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'تتبع مسار المخاطبة',
                  style: TextStyle(fontSize: 16, color: Colors.white54),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('communications')
                  .doc(communicationId)
                  .collection('tracking')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, trackingSnapshot) {
                if (trackingSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (trackingSnapshot.hasError) {
                  return const Center(child: Text('تعذر تحميل سجل التتبع', style: TextStyle(color: Colors.redAccent)));
                }

                final trackingDocs = trackingSnapshot.data?.docs ?? [];

                if (trackingDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.history, size: 60, color: Colors.white24),
                        SizedBox(height: 16),
                        Text('لا يوجد سجل تتبع لهذه المخاطبة بعد', style: TextStyle(color: Colors.white54)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(32),
                  itemCount: trackingDocs.length,
                  itemBuilder: (context, index) {
                    final item = trackingDocs[index].data() as Map<String, dynamic>;

                    final action = (item['action'] ?? '').toString();
                    final actionLabel = _actionLabel(action);
                    final rawComment = (item['comment'] ?? '').toString();
                    final comment = _cleanComment(action, rawComment);
                    final timestamp = item['timestamp'] as Timestamp?;
                    final fromName = (item['from_name'] ?? '').toString();
                    final toName = (item['to_name'] ?? '').toString();

                    final color = _actionColor(action);
                    final icon = _actionIcon(action);

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Timeline Connector
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
                              ),
                              child: Icon(icon, size: 24, color: color),
                            ),
                            if (index != trackingDocs.length - 1)
                              Container(
                                width: 2,
                                height: 60,
                                color: Colors.white12,
                              ),
                          ],
                        ),
                        const SizedBox(width: 24),
                        // Content Card
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        actionLabel,
                                        style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        const Icon(Icons.access_time, size: 14, color: Colors.white38),
                                        const SizedBox(width: 6),
                                        Text(
                                          _formatTimestamp(timestamp),
                                          style: const TextStyle(fontSize: 13, color: Colors.white54),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (comment.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Text(
                                      comment,
                                      style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.5),
                                    ),
                                  ),
                                if (fromName.isNotEmpty || toName.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.02),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        if (fromName.isNotEmpty)
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('المُرسل', style: TextStyle(fontSize: 11, color: Colors.white38)),
                                                const SizedBox(height: 4),
                                                Text(fromName, style: const TextStyle(fontSize: 13, color: Colors.white70)),
                                              ],
                                            ),
                                          ),
                                        if (fromName.isNotEmpty && toName.isNotEmpty)
                                          const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 16),
                                            child: Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white24),
                                          ),
                                        if (toName.isNotEmpty)
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('المُستلم', style: TextStyle(fontSize: 11, color: Colors.white38)),
                                                const SizedBox(height: 4),
                                                Text(toName, style: const TextStyle(fontSize: 13, color: Colors.white70)),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
}
