import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/communication_service.dart';
import '../../../communications/presentation/pages/pdf_view_page.dart';
import '../../../communications/presentation/pages/official_letter_view_page.dart';

class WallRemindersWidget extends StatelessWidget {
  const WallRemindersWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final CommunicationService communicationService = CommunicationService();

    return StreamBuilder<QuerySnapshot>(
      stream: communicationService.getUserRemindersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink(); // Hide if no reminders
        }

        final reminders = snapshot.data!.docs;

        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2A45), // Distinct luxury color
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3), width: 1.5), // Gold accent
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ]
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.push_pin, color: Color(0xFFD4AF37), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'حائط التذكيرات (Wall Posts)',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${reminders.length}',
                      style: const TextStyle(color: Color(0xFF071224), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 130, // Horizontal scroll
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: reminders.length,
                  itemBuilder: (context, index) {
                    final data = reminders[index].data() as Map<String, dynamic>;
                    final docId = reminders[index].id;
                    final note = data['note_text'] ?? '';
                    final title = data['communication_title'] ?? 'بدون عنوان';
                    final commId = data['communication_id'] ?? '';

                    return _ReminderCard(
                      reminderId: docId,
                      note: note,
                      title: title,
                      commId: commId,
                      communicationService: communicationService,
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
}

class _ReminderCard extends StatefulWidget {
  final String reminderId;
  final String note;
  final String title;
  final String commId;
  final CommunicationService communicationService;

  const _ReminderCard({
    required this.reminderId,
    required this.note,
    required this.title,
    required this.commId,
    required this.communicationService,
  });

  @override
  State<_ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends State<_ReminderCard> {
  bool _isHovered = false;

  void _openCommunication() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('communications').doc(widget.commId).get();
      if (!doc.exists) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('المخاطبة لم تعد موجودة')));
        return;
      }
      
      final data = doc.data()!;
      final generatedUrl = data['generated_docx_url']?.toString() ?? '';
      final attachments = data['attachments'] as List<dynamic>?;
      
      if (mounted) {
        if (generatedUrl.isNotEmpty && generatedUrl.endsWith('.pdf')) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => PdfViewPage(
            pdfUrl: generatedUrl,
            title: data['subject'] ?? 'خطاب',
            communicationId: widget.commId,
            attachments: attachments,
          )));
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (_) => OfficialLetterViewPage(
            communicationId: widget.commId,
          )));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _openCommunication,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 280,
          margin: const EdgeInsets.only(left: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isHovered ? const Color(0xFFD4AF37).withValues(alpha: 0.1) : const Color(0xFF0F1E38),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered ? const Color(0xFFD4AF37) : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.description_outlined, color: Colors.white54, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 20),
                    tooltip: 'تحديد كمنجز وحذف',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      widget.communicationService.deleteWallReminder(widget.reminderId);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنجاز الملاحظة وإزالتها')));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Text(
                  widget.note,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
