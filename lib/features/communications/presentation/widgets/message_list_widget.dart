import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/communication_model.dart';

class MessageListWidget extends StatefulWidget {
  final List<CommunicationModel> messages;
  final CommunicationModel? selectedMessage;
  final Function(CommunicationModel) onSelect;
  final String title;
  final IconData emptyIcon;

  const MessageListWidget({
    super.key,
    required this.messages,
    required this.selectedMessage,
    required this.onSelect,
    required this.title,
    required this.emptyIcon,
  });

  @override
  State<MessageListWidget> createState() => _MessageListWidgetState();
}

class _MessageListWidgetState extends State<MessageListWidget> {
  String _searchQuery = '';

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
    final filteredMessages = widget.messages.where((msg) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return msg.subject.toLowerCase().contains(query) ||
             msg.body.toLowerCase().contains(query) ||
             msg.senderName.toLowerCase().contains(query) ||
             msg.targetName.toLowerCase().contains(query) ||
             (msg.id?.toLowerCase().contains(query) ?? false);
    }).toList();

    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (value) => setState(() => _searchQuery = value),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'بحث في الرسائل (العنوان، المحتوى، المرسل)...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredMessages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(widget.emptyIcon, size: 64, color: Colors.white.withValues(alpha: 0.2)),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? '${widget.title} فارغ' : 'لا توجد نتائج مطابقة لبحثك',
                          style: const TextStyle(color: Colors.white54, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: filteredMessages.length,
                    separatorBuilder: (_, __) => Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
                    itemBuilder: (context, index) {
                      final message = filteredMessages[index];
                      final isSelected = widget.selectedMessage?.id == message.id;
                      final isUrgent = message.priority == 'urgent';

                      final displayName = message.type == 'outgoing' ? 'إلى: ${message.targetName}' : message.senderName;
                      final accentColor = message.type == 'outgoing' ? AppColors.success : AppColors.primary;

                      final isUnread = !message.isRead && message.type != 'outgoing';

                      return Material(
                        color: isSelected ? accentColor.withValues(alpha: 0.1) : Colors.transparent,
                        child: InkWell(
                          onTap: () => widget.onSelect(message),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        displayName,
                                        style: TextStyle(
                                          color: isSelected ? accentColor : Colors.white,
                                          fontWeight: isSelected ? FontWeight.bold : (isUnread ? FontWeight.w900 : FontWeight.normal),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isUnread) ...[
                                      const SizedBox(width: 8),
                                      _buildBadge('جديد', Colors.blueAccent),
                                    ],
                                    if (isUrgent) ...[
                                      const SizedBox(width: 8),
                                      _buildBadge('عاجل', AppColors.danger),
                                    ],
                                    if (message.parentCommId != null && message.parentCommId!.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.tealAccent.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.3)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.reply, size: 10, color: Colors.tealAccent),
                                            SizedBox(width: 3),
                                            Text('رد', style: TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ],
                                    if (message.isExternal) ...[
                                      const SizedBox(width: 6),
                                      _buildBadge('خارجي', Colors.orangeAccent),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  message.subject,
                                  style: TextStyle(color: isSelected ? Colors.white : (isUnread ? Colors.white : Colors.white70), fontSize: 14, fontWeight: isUnread ? FontWeight.w900 : FontWeight.normal),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'اضغط لعرض التفاصيل',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
