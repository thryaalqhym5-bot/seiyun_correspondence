import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/models/communication_model.dart';

class GlobalTrackingViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<CommunicationModel> _allCommunications = [];
  List<CommunicationModel> get allCommunications => _allCommunications;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  GlobalTrackingViewModel() {
    _fetchGlobalData();
  }

  void _fetchGlobalData() {
    _firestore
        .collection('communications')
        .orderBy('created_at', descending: true)
        .snapshots()
        .listen((snapshot) {
      _allCommunications = snapshot.docs
          .map((doc) => CommunicationModel.fromJson(doc.data(), doc.id))
          .toList();
      
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
      _errorMessage = error.toString();
      _isLoading = false;
      notifyListeners();
    });
  }

  int get totalActive => _allCommunications.where((c) => c.status != 'archived' && c.status != 'published' && c.status != 'acknowledged').length;
  
  int get totalCompleted => _allCommunications.where((c) => c.status == 'archived' || c.status == 'published' || c.status == 'acknowledged').length;

  int get totalDelayed {
    final now = DateTime.now();
    return _allCommunications.where((c) {
      if (c.status == 'archived' || c.status == 'published' || c.status == 'acknowledged') return false;
      if (c.createdAt == null) return false;
      final diff = now.difference(c.createdAt!).inDays;
      return diff >= 3;
    }).length;
  }
}
