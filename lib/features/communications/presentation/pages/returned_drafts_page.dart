import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/models/communication_model.dart';
import '../viewmodels/communications_viewmodel.dart';
import '../widgets/message_list_widget.dart';
import '../widgets/returned_draft_detail_widget.dart';

class ReturnedDraftsPage extends StatefulWidget {
  const ReturnedDraftsPage({super.key});

  @override
  State<ReturnedDraftsPage> createState() => _ReturnedDraftsPageState();
}

class _ReturnedDraftsPageState extends State<ReturnedDraftsPage> {
  final CommunicationsViewModel _viewModel = CommunicationsViewModel();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
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
                    stream: _viewModel.getReturnedDraftsStream(),
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
                            title: 'مسودات معادة للتعديل',
                            emptyIcon: Icons.edit_note,
                            messages: messages,
                            selectedMessage: _viewModel.selectedMessage,
                            onSelect: _viewModel.selectMessage,
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
                      return ReturnedDraftDetailWidget(
                        message: _viewModel.selectedMessage,
                        emptyIcon: Icons.undo,
                        emptyText: 'اختر مسودة لعرض ملاحظات الإرجاع',
                        accentColor: AppColors.danger,
                        onActionComplete: () => _viewModel.clearSelection(),
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
