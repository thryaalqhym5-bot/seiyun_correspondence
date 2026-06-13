import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/notification_model.dart';
import '../../../../core/services/notification_service.dart';

class NotificationsDropdown extends StatefulWidget {
  const NotificationsDropdown({super.key});

  @override
  State<NotificationsDropdown> createState() => _NotificationsDropdownState();
}

class _NotificationsDropdownState extends State<NotificationsDropdown> {
  final NotificationService _notificationService = NotificationService();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  void _toggleDropdown() {
    if (_isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _closeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() => _isOpen = false);
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;
    var uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeDropdown,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            width: 350,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(-350 + size.width, size.height + 8),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                color: AppColors.surface,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    color: AppColors.surface,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('التنبيهات', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            TextButton(
                              onPressed: () {
                                _notificationService.markAllAsRead(uid);
                              },
                              child: const Text('تحديد الكل كمقروء', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: Colors.white24, height: 1),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 400),
                        child: StreamBuilder<List<NotificationModel>>(
                          stream: _notificationService.streamUnreadNotifications(uid),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            if (snapshot.hasError) {
                              return const Padding(
                                padding: EdgeInsets.all(32.0),
                                child: Center(child: Text('حدث خطأ', style: TextStyle(color: Colors.white54))),
                              );
                            }

                            final notifications = snapshot.data ?? [];

                            if (notifications.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(48.0),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.notifications_off_outlined, color: Colors.white38, size: 48),
                                      SizedBox(height: 16),
                                      Text('لا توجد تنبيهات جديدة', style: TextStyle(color: Colors.white54)),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return ListView.separated(
                              shrinkWrap: true,
                              itemCount: notifications.length,
                              separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                              itemBuilder: (context, index) {
                                final notif = notifications[index];
                                return _buildNotificationItem(notif);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(NotificationModel notif) {
    IconData icon;
    Color color;

    switch (notif.type) {
      case 'new_message':
        icon = Icons.mark_email_unread;
        color = Colors.blueAccent;
        break;
      case 'urgent':
        icon = Icons.warning_amber_rounded;
        color = Colors.redAccent;
        break;
      case 'draft_request':
        icon = Icons.edit_document;
        color = Colors.tealAccent;
        break;
      case 'returned_draft':
        icon = Icons.replay;
        color = Colors.orangeAccent;
        break;
      case 'approved':
        icon = Icons.check_circle;
        color = Colors.greenAccent;
        break;
      default:
        icon = Icons.notifications;
        color = AppColors.primary;
    }

    return InkWell(
      onTap: () {
        if (notif.id != null) {
          _notificationService.markAsRead(notif.id!);
        }
        _closeDropdown();
        // Here we could navigate based on notif.type and relatedDocId
      },
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notif.title,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.body,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    notif.createdAt != null ? timeago.format(notif.createdAt!, locale: 'ar') : '',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return CompositedTransformTarget(
      link: _layerLink,
      child: StreamBuilder<List<NotificationModel>>(
        stream: _notificationService.streamUnreadNotifications(uid),
        builder: (context, snapshot) {
          final count = snapshot.data?.length ?? 0;

          return IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: const Icon(Icons.notifications_none, color: Colors.white70, size: 20),
                ),
                if (count > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _toggleDropdown,
          );
        },
      ),
    );
  }
}
