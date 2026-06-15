import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/communications_repository.dart';
import 'package:intl/intl.dart';

class TrackingTimelineDialog extends StatelessWidget {
  final String commId;

  const TrackingTimelineDialog({super.key, required this.commId});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2C2C2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'مسار المعاملة (سجل التدقيق)',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 32),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: CommunicationsRepository().getTrackingStream(commId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('حدث خطأ: \${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
                  }
                  final trackingEntries = snapshot.data ?? [];
                  if (trackingEntries.isEmpty) {
                    return const Center(child: Text('لا توجد حركات مسجلة لهذه المعاملة.', style: TextStyle(color: Colors.white54)));
                  }

                  return ListView.builder(
                    itemCount: trackingEntries.length,
                    itemBuilder: (context, index) {
                      final entry = trackingEntries[index];
                      final action = entry['action'] as String? ?? 'غير معروف';
                      final fromName = entry['from_name'] as String? ?? 'مجهول';
                      final toName = entry['to_name'] as String? ?? '';
                      final comment = entry['comment'] as String? ?? '';
                      final timestamp = entry['timestamp']?.toDate();
                      final dateStr = timestamp != null ? DateFormat('yyyy-MM-dd hh:mm a', 'ar').format(timestamp) : 'تاريخ غير متوفر';

                      String actionLabel = action;
                      IconData actionIcon = Icons.info_outline;
                      Color iconColor = Colors.blueAccent;

                      switch (action) {
                        case 'send':
                        case 'approve_and_send':
                          actionLabel = 'إرسال';
                          actionIcon = Icons.send;
                          iconColor = Colors.greenAccent;
                          break;
                        case 'forward':
                          actionLabel = 'توجيه / إحالة';
                          actionIcon = Icons.forward;
                          iconColor = Colors.orangeAccent;
                          break;
                        case 'return_to_secretary':
                          actionLabel = 'إعادة للتعديل';
                          actionIcon = Icons.reply;
                          iconColor = Colors.redAccent;
                          break;
                        case 'acknowledge_circular':
                        case 'acknowledge_external':
                          actionLabel = 'علم بالاستلام';
                          actionIcon = Icons.done_all;
                          iconColor = Colors.blue;
                          break;
                        case 'publish':
                          actionLabel = 'نشر تعميم';
                          actionIcon = Icons.campaign;
                          iconColor = Colors.amberAccent;
                          break;
                        case 'review_external':
                          actionLabel = 'مراجعة مراسلة خارجية';
                          actionIcon = Icons.visibility;
                          iconColor = Colors.purpleAccent;
                          break;
                        case 'circulate_external':
                          actionLabel = 'تعميم مراسلة خارجية';
                          actionIcon = Icons.campaign;
                          iconColor = Colors.amber;
                          break;
                        case 'external_archive':
                        case 'archive':
                          actionLabel = 'أرشفة';
                          actionIcon = Icons.archive;
                          iconColor = Colors.grey;
                          break;
                        case 'read':
                          actionLabel = 'قراءة';
                          actionIcon = Icons.mark_email_read;
                          iconColor = Colors.blueGrey;
                          break;
                        case 'forward_external':
                          actionLabel = 'توجيه مراسلة خارجية';
                          actionIcon = Icons.forward;
                          iconColor = Colors.orangeAccent;
                          break;
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: iconColor.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(actionIcon, color: iconColor, size: 20),
                                ),
                                if (index != trackingEntries.length - 1)
                                  Container(
                                    width: 2,
                                    height: 40,
                                    color: Colors.white24,
                                    margin: const EdgeInsets.symmetric(vertical: 4),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(actionLabel, style: TextStyle(color: iconColor, fontWeight: FontWeight.bold, fontSize: 16)),
                                        Text(dateStr, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text('بواسطة: $fromName', style: const TextStyle(color: Colors.white, fontSize: 14)),
                                    if (toName.isNotEmpty)
                                      Text('إلى: $toName', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                    if (comment.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text('ملاحظة: $comment', style: const TextStyle(color: Colors.amberAccent, fontSize: 13)),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
