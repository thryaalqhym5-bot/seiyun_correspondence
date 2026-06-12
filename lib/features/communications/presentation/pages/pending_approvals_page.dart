import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/models/communication_model.dart';
import '../viewmodels/communications_viewmodel.dart';
import '../widgets/message_list_widget.dart';
import '../widgets/draft_detail_widget.dart';

class PendingApprovalsPage extends StatefulWidget {
  const PendingApprovalsPage({super.key});

  @override
  State<PendingApprovalsPage> createState() => _PendingApprovalsPageState();
}

class _PendingApprovalsPageState extends State<PendingApprovalsPage> {
  final CommunicationsViewModel _viewModel = CommunicationsViewModel();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _onMessageSelected(CommunicationModel message) {
    _viewModel.selectMessage(message);
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
                    stream: _viewModel.getPendingApprovalStream(),
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
                            title: 'مجهزة للاعتماد',
                            emptyIcon: Icons.checklist_rtl,
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
                      return DraftDetailWidget(
                        message: _viewModel.selectedMessage,
                        emptyIcon: Icons.edit_document,
                        emptyText: 'اختر مسودة لمراجعتها واعتمادها',
                        accentColor: const Color(0xFFD4AF37),
                        onActionComplete: () {
                          _viewModel.selectMessage(_viewModel.selectedMessage!); // Refresh
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
    );
  }
}
