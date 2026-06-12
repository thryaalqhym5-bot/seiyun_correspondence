import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/models/communication_model.dart';
import '../viewmodels/communications_viewmodel.dart';
import '../widgets/message_list_widget.dart';
import '../widgets/message_detail_widget.dart';

class SecretaryDispatchPage extends StatefulWidget {
  const SecretaryDispatchPage({super.key});

  @override
  State<SecretaryDispatchPage> createState() => _SecretaryDispatchPageState();
}

class _SecretaryDispatchPageState extends State<SecretaryDispatchPage> {
  final CommunicationsViewModel _viewModel = CommunicationsViewModel();
  String _collegeId = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCollegeId();
  }

  Future<void> _loadCollegeId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _collegeId = doc.data()?['college_id'] ?? '';
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsDispatched(String commId) async {
    try {
      await FirebaseFirestore.instance.collection('communications').doc(commId).update({
        'status': 'dispatched',
        'updated_at': FieldValue.serverTimestamp(),
      });
      _viewModel.clearSelection();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تصدير المخاطبة بنجاح')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: AppColors.danger));
      }
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

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
                    stream: _viewModel.getPendingDispatchStream(_collegeId),
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
                            title: 'بريد جاهز للتصدير',
                            emptyIcon: Icons.outbox,
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
                        emptyIcon: Icons.outbox,
                        emptyText: 'اختر رسالة لعرض محتواها وتصديرها',
                        accentColor: Colors.blueAccent,
                        customActions: [
                          if (_viewModel.selectedMessage != null)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              ),
                              onPressed: () => _markAsDispatched(_viewModel.selectedMessage!.id!),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('تم التصدير (أرشفة)'),
                            ),
                        ],
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
