import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/models/communication_model.dart';

class CommunicationsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<CommunicationModel>> getInboxStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('communications')
        .where('current_rcv_id', isEqualTo: user.uid)
        .where('status', whereIn: ['sent', 'pending', 'قيد المعالجة', 'قيد الانتظار', ''])
        .snapshots()
        .map((snapshot) {
      final docs = snapshot.docs.map((doc) => CommunicationModel.fromJson(doc.data(), doc.id)).toList();
      docs.sort((a, b) {
        final dateA = a.createdAt ?? DateTime.now();
        final dateB = b.createdAt ?? DateTime.now();
        return dateB.compareTo(dateA);
      });
      return docs;
    });
  }

  Stream<List<CommunicationModel>> getPendingApprovalStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('communications')
        .where('current_rcv_id', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending_approval')
        .snapshots()
        .map((snapshot) {
      final docs = snapshot.docs.map((doc) => CommunicationModel.fromJson(doc.data(), doc.id)).toList();
      docs.sort((a, b) {
        final dateA = a.createdAt ?? DateTime.now();
        final dateB = b.createdAt ?? DateTime.now();
        return dateB.compareTo(dateA);
      });
      return docs;
    });
  }

  Stream<List<CommunicationModel>> getOutboxStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('communications')
        .where('sender_id', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      final docs = snapshot.docs.map((doc) => CommunicationModel.fromJson(doc.data(), doc.id)).toList();
      final filteredDocs = docs.where((doc) => 
          doc.status != 'draft' && 
          doc.status != 'returned_for_edit' && 
          doc.status != 'archived' && 
          doc.status != 'rejected' &&
          doc.status != 'completed' &&
          doc.isExternal != true
      ).toList();
      
      filteredDocs.sort((a, b) {
        final dateA = a.createdAt ?? DateTime.now();
        final dateB = b.createdAt ?? DateTime.now();
        return dateB.compareTo(dateA);
      });
      return filteredDocs;
    });
  }

  Stream<List<CommunicationModel>> getCircularsStream() async* {
    final user = _auth.currentUser;
    if (user == null) {
      yield [];
      return;
    }

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};
    final String role = userData['administrative_title'] ?? 'staff';
    final String collegeId = userData['college_id'] ?? '';
    final String deptId = userData['dept_id'] ?? '';

    yield* _firestore
        .collection('communications')
        .where('is_circular', isEqualTo: true)
        .where('status', isEqualTo: 'published')
        .snapshots()
        .map((snapshot) {
      final docs = snapshot.docs.map((doc) => CommunicationModel.fromJson(doc.data(), doc.id)).toList();
      
      final filteredDocs = docs.where((doc) {
        final tg = doc.targetGroup ?? '';
        
        if (tg == 'all_university') return true;
        if (tg == 'all_deans' && ['dean', 'university_president', 'university_vp', 'general_secretary'].contains(role)) return true;
        if (tg == 'all_college' && doc.senderCollegeId == collegeId) return true;
        if (tg == 'college_management' && doc.senderCollegeId == collegeId && ['dean', 'vice_dean', 'head_of_department'].contains(role)) return true;
        if (tg == 'all_department' && doc.senderDeptId == deptId) return true;
        
        return false;
      }).toList();

      filteredDocs.sort((a, b) {
        final dateA = a.createdAt ?? DateTime.now();
        final dateB = b.createdAt ?? DateTime.now();
        return dateB.compareTo(dateA);
      });
      return filteredDocs;
    });
  }

  Stream<List<CommunicationModel>> getReturnedDraftsStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('communications')
        .where('sender_id', isEqualTo: user.uid)
        .where('status', isEqualTo: 'returned_for_edit')
        .snapshots()
        .map((snapshot) {
      final docs = snapshot.docs.map((doc) => CommunicationModel.fromJson(doc.data(), doc.id)).toList();
      docs.sort((a, b) {
        final dateA = a.createdAt ?? DateTime.now();
        final dateB = b.createdAt ?? DateTime.now();
        return dateB.compareTo(dateA);
      });
      return docs;
    });
  }

  Stream<List<CommunicationModel>> getExternalInboxStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('communications')
        .where('target_id', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      final docs = snapshot.docs
          .map((doc) => CommunicationModel.fromJson(doc.data(), doc.id))
          .where((model) => 
              model.isExternal == true && 
              !['published', 'forwarded', 'replied', 'مؤرشف', 'acknowledged', 'external_reviewed', 'archived', 'completed'].contains(model.status))
          .toList();
      docs.sort((a, b) {
        final dateA = a.createdAt ?? DateTime.now();
        final dateB = b.createdAt ?? DateTime.now();
        return dateB.compareTo(dateA);
      });
      return docs;
    });
  }

  Stream<int> getUnreadExternalCount() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(0);
    
    return _firestore
        .collection('communications')
        .where('target_id', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.where((doc) {
        final data = doc.data();
        return data['is_external'] == true && data['is_read_by_dean'] == false;
      }).length;
    });
  }

  Future<void> archiveCommunication(String communicationId) async {
    await _firestore.collection('communications').doc(communicationId).update({
      'status': 'مؤرشف',
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<CommunicationModel>> getPendingDispatchStream(String collegeId) {
    if (collegeId.isEmpty) return const Stream.empty();

    return _firestore
        .collection('communications')
        .where('sender_college_id', isEqualTo: collegeId)
        .where('is_external_outgoing', isEqualTo: true)
        .where('status', isEqualTo: 'ready_for_dispatch')
        .snapshots()
        .map((snapshot) {
      final docs = snapshot.docs.map((doc) => CommunicationModel.fromJson(doc.data(), doc.id)).toList();
      docs.sort((a, b) {
        final dateA = a.createdAt ?? DateTime.now();
        final dateB = b.createdAt ?? DateTime.now();
        return dateB.compareTo(dateA);
      });
      return docs;
    });
  }
}
