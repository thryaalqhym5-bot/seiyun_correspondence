import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/models/communication_model.dart';
import '../../../../core/services/communication_service.dart';
import '../viewmodels/communications_viewmodel.dart';
import '../widgets/message_list_widget.dart';
import '../widgets/message_detail_widget.dart';

class InboxPage extends StatefulWidget {
  final bool isDelegated;
  const InboxPage({super.key, this.isDelegated = false});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  final CommunicationsViewModel _viewModel = CommunicationsViewModel();
  final CommunicationService _commService = CommunicationService();
  String? _userTitle;

  @override
  void initState() {
    super.initState();
    _loadUserTitle();
  }

  Future<void> _loadUserTitle() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        setState(() => _userTitle = doc.data()?['administrative_title'] ?? 'staff');
      }
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _onMessageSelected(CommunicationModel message) {
    _viewModel.selectMessage(message);

    // إذا كانت مراسلة خارجية مُحالة (ليست بانتظار العميد) → أرشفها تلقائياً بعد الفتح
    if (message.isExternal &&
        message.status == 'sent' &&
        message.id != null) {
      _commService.acknowledgeExternalCommunication(message.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: AppCard(
            padding: EdgeInsets.zero,
            child: Row(
              children: [
                // Right Pane (List of Messages)
                Expanded(
                  flex: 2,
                  child: StreamBuilder<List<CommunicationModel>>(
                    stream: widget.isDelegated ? _viewModel.getDelegatedInboxStream() : _viewModel.getInboxStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('خطأ: ${snapshot.error}', style: const TextStyle(color: AppColors.danger)));
                      }

                      final messages = snapshot.data ?? [];

                      return AnimatedBuilder(
                        animation: _viewModel,
                        builder: (context, child) {
                          return MessageListWidget(
                            title: widget.isDelegated ? 'صندوق التفويضات' : 'صندوق الوارد',
                            emptyIcon: Icons.inbox_outlined,
                            messages: messages,
                            selectedMessage: _viewModel.selectedMessage,
                            onSelect: _onMessageSelected,
                          );
                        },
                      );
                    },
                  ),
                ),

                // Left Pane (Details View)
                Expanded(
                  flex: 3,
                  child: AnimatedBuilder(
                    animation: _viewModel,
                    builder: (context, child) {
                      return MessageDetailWidget(
                        message: _viewModel.selectedMessage,
                        emptyIcon: Icons.mail_outline,
                        emptyText: 'اختر رسالة لعرض تفاصيلها',
                        accentColor: AppColors.primary,
                        currentUserTitle: _userTitle,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}