import 'package:flutter/material.dart';
import '../../../../core/models/communication_model.dart';
import '../../data/communications_repository.dart';

class CommunicationsViewModel extends ChangeNotifier {
  final CommunicationsRepository _repository = CommunicationsRepository();

  CommunicationModel? _selectedMessage;
  
  CommunicationModel? get selectedMessage => _selectedMessage;

  Stream<List<CommunicationModel>> getInboxStream() {
    return _repository.getInboxStream();
  }

  Stream<List<CommunicationModel>> getOutboxStream() {
    return _repository.getOutboxStream();
  }

  Stream<List<CommunicationModel>> getCircularsStream() {
    return _repository.getCircularsStream();
  }

  Stream<List<CommunicationModel>> getPendingApprovalStream() {
    return _repository.getPendingApprovalStream();
  }

  Stream<List<CommunicationModel>> getReturnedDraftsStream() {
    return _repository.getReturnedDraftsStream();
  }

  Stream<List<CommunicationModel>> getExternalInboxStream() {
    return _repository.getExternalInboxStream();
  }

  Stream<List<CommunicationModel>> getPendingDispatchStream(String collegeId) {
    return _repository.getPendingDispatchStream(collegeId);
  }

  void selectMessage(CommunicationModel message) {
    _selectedMessage = message;
    notifyListeners();
  }

  void clearSelection() {
    _selectedMessage = null;
    notifyListeners();
  }
}
