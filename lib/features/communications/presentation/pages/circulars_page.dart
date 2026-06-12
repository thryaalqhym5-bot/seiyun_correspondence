import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/models/communication_model.dart';
import '../viewmodels/communications_viewmodel.dart';
import '../widgets/message_list_widget.dart';
import '../widgets/message_detail_widget.dart';

class CircularsPage extends StatefulWidget {
  const CircularsPage({super.key});

  @override
  State<CircularsPage> createState() => _CircularsPageState();
}

class _CircularsPageState extends State<CircularsPage> {
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
                Expanded(
                  flex: 2,
                  child: StreamBuilder<List<CommunicationModel>>(
                    stream: _viewModel.getCircularsStream(),
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
                            title: 'التعاميم والقرارات',
                            emptyIcon: Icons.campaign_outlined,
                            messages: messages,
                            selectedMessage: _viewModel.selectedMessage,
                            onSelect: _viewModel.selectMessage,
                          );
                        },
                      );
                    },
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: AnimatedBuilder(
                    animation: _viewModel,
                    builder: (context, child) {
                      return MessageDetailWidget(
                        message: _viewModel.selectedMessage,
                        emptyIcon: Icons.campaign_outlined,
                        emptyText: 'اختر تعميماً لعرض محتواه',
                        accentColor: Colors.orangeAccent,
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
