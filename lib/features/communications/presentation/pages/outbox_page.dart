import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/models/communication_model.dart';
import '../viewmodels/communications_viewmodel.dart';
import '../widgets/message_list_widget.dart';
import '../widgets/message_detail_widget.dart';

class OutboxPage extends StatefulWidget {
  const OutboxPage({super.key});

  @override
  State<OutboxPage> createState() => _OutboxPageState();
}

class _OutboxPageState extends State<OutboxPage> {
  final CommunicationsViewModel _viewModel = CommunicationsViewModel();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Uses DashboardLayout background
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
                    stream: _viewModel.getOutboxStream(),
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
                            title: 'صندوق الصادر',
                            emptyIcon: Icons.outbox_outlined,
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
                      return MessageDetailWidget(
                        message: _viewModel.selectedMessage,
                        emptyIcon: Icons.send_outlined,
                        emptyText: 'اختر رسالة لعرض تفاصيلها',
                        accentColor: AppColors.success,
                        isOutgoing: true,
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