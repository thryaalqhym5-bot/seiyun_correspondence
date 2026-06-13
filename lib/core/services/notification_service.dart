import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> sendNotification({
    required String targetUserId,
    required String title,
    required String body,
    required String type,
    String? relatedDocId,
  }) async {
    try {
      final notif = NotificationModel(
        targetUserId: targetUserId,
        title: title,
        body: body,
        type: type,
        relatedDocId: relatedDocId,
        isRead: false,
      );

      await _firestore.collection('notifications').add(notif.toJson());
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  Stream<List<NotificationModel>> streamUnreadNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('target_user_id', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final docs = snapshot.docs
          .map((doc) => NotificationModel.fromJson(doc.data(), doc.id))
          .where((n) => !n.isRead)
          .toList();
      docs.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.now();
        final bDate = b.createdAt ?? DateTime.now();
        return bDate.compareTo(aDate); // descending
      });
      return docs;
    });
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'is_read': true,
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('target_user_id', isEqualTo: userId)
          .where('is_read', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'is_read': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }
}
