import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/communication_model.dart';
import '../../../../core/services/communication_service.dart';
import '../../../../core/services/word_service.dart';
import '../pages/create_communication_page.dart';

class DraftDetailWidget extends StatelessWidget {
  final CommunicationModel? message;
  final IconData emptyIcon;
  final String emptyText;
  final Color accentColor;
  final VoidCallback? onActionComplete;

  const DraftDetailWidget({
    super.key,
    required this.message,
    required this.emptyIcon,
    required this.emptyText,
    required this.accentColor,
    this.onActionComplete,
  });

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
            Text(
              emptyText,
              style: const TextStyle(color: Colors.white54, fontSize: 18),
            ),
          ],
        ),
      );
    }


    return Container(
      color: AppColors.surface2.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Details Header
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        _buildBadge(message!.status, AppColors.warning),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(color: Colors.white10),
                const SizedBox(height: 16),
                // Metadata Table
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMetaRow('المرسل:', message!.senderName),
                          const SizedBox(height: 8),
                          _buildMetaRow('المرسل إليه:', message!.targetName),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMetaRow(
                            'الأولوية:',
                            message!.priority == 'urgent' ? 'عاجل' : 'عادي',
                          ),
                          const SizedBox(height: 8),
                          _buildMetaRow(
                            'النوع:',
                            message!.type == 'outgoing' ? 'صادر' : 'داخلي',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Details Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'محتوى الرسالة:',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Text(
                      message!.body.isEmpty
                          ? 'لا يوجد محتوى نصي. قم بفتح الملف المرفق.'
                          : message!.body,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Attachments Section
                  if (message!.attachments != null &&
                      message!.attachments!.isNotEmpty) ...[
                    const Text(
                      'المرفقات:',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: message!.attachments!.map((att) {
                        final attName = att['name'] ?? 'مرفق';
                        return InkWell(
                          onTap: () async {
                            final url = att['url'] as String?;
                            if (url != null &&
                                await canLaunchUrl(Uri.parse(url))) {
                              await launchUrl(Uri.parse(url));
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('لا يمكن فتح هذا المرفق'),
                                  ),
                                );
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.attachment,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  attName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 48),
                  // Action Buttons
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37), // Gold Accent
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
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
                        label: const Text('معاينة الوثيقة (PDF)', style: TextStyle(color: Colors.black)),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CreateCommunicationPage(draftToEdit: message),
                            ),
                          );
                          if (result == true) {
                            onActionComplete?.call();
                          }
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('تعديل المسودة'),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                        onPressed: () async {
                          final notesController = TextEditingController();
                          final shouldReturn = await showDialog<bool>(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                backgroundColor: AppColors.surface,
                                title: const Text('إرجاع للسكرتير', style: TextStyle(color: Colors.white)),
                                content: TextField(
                                  controller: notesController,
                                  style: const TextStyle(color: Colors.white),
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    hintText: 'اكتب ملاحظاتك أو سبب الإرجاع هنا...',
                                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                                    filled: true,
                                    fillColor: Colors.white.withValues(alpha: 0.05),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('إلغاء', style: TextStyle(color: Colors.white70)),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('إرجاع الآن'),
                                  ),
                                ],
                              );
                            },
                          );

                          if (shouldReturn == true) {
                            try {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري إرجاع المسودة...')));
                              await CommunicationService().returnDraftToSecretary(message!.id!, notesController.text.trim());
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرجاع المسودة بنجاح')));
                                onActionComplete?.call();
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.danger));
                              }
                            }
                          }
                        },
                        icon: const Icon(Icons.undo),
                        label: const Text('إعادة للسكرتير'),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                        onPressed: () async {
                          try {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'جاري الاعتماد وتوليد الوثيقة...',
                                ),
                              ),
                            );
                            await CommunicationService().approveCommunication(
                              message!.id!,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'تم اعتماد وإصدار المخاطبة بنجاح',
                                ),
                              ),
                            );
                            onActionComplete?.call();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('خطأ: $e'),
                                backgroundColor: AppColors.danger,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.check_circle),
                        label: const Text('اعتماد وإصدار'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
