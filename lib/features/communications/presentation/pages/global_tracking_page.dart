import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/global_tracking_viewmodel.dart';

class GlobalTrackingPage extends StatelessWidget {
  const GlobalTrackingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GlobalTrackingViewModel(),
      child: Consumer<GlobalTrackingViewModel>(
        builder: (context, vm, child) {
          return Scaffold(
            backgroundColor: const Color(0xFF0F172A), // Dark blue command center
            appBar: AppBar(
              backgroundColor: const Color(0xFF0F172A),
              title: const Text(
                'التتبع الشامل (Command Center)',
                style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold),
              ),
              iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
              elevation: 0,
            ),
            body: vm.isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
                : vm.errorMessage != null
                    ? Center(child: Text('خطأ: ${vm.errorMessage}', style: const TextStyle(color: Colors.red)))
                    : Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildStatsRow(vm),
                            const SizedBox(height: 24),
                            Expanded(child: _buildTrackingList(vm)),
                          ],
                        ),
                      ),
          );
        },
      ),
    );
  }

  Widget _buildStatsRow(GlobalTrackingViewModel vm) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _StatCard(title: 'جاري العمل', count: vm.totalActive, color: Colors.blueAccent),
        _StatCard(title: 'متأخرة (> 3 أيام)', count: vm.totalDelayed, color: Colors.redAccent),
        _StatCard(title: 'مكتملة', count: vm.totalCompleted, color: Colors.green),
      ],
    );
  }

  Widget _buildTrackingList(GlobalTrackingViewModel vm) {
    final activeItems = vm.allCommunications.where((c) => 
      c.status != 'archived' && c.status != 'published' && c.status != 'acknowledged'
    ).toList();

    return ListView.builder(
      itemCount: activeItems.length,
      itemBuilder: (context, index) {
        final comm = activeItems[index];
        final now = DateTime.now();
        final isDelayed = comm.createdAt != null && now.difference(comm.createdAt!).inDays >= 3;

        return Card(
          color: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: isDelayed ? Colors.redAccent : const Color(0xFFD4AF37).withValues(alpha: 0.3),
              width: isDelayed ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(
              comm.subject,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('من: ${comm.senderName} ➔ إلى: ${comm.targetName}', style: const TextStyle(color: Colors.white70)),
                Text('الحالة: ${comm.status}', style: TextStyle(color: isDelayed ? Colors.redAccent : Colors.orangeAccent)),
              ],
            ),
            trailing: isDelayed
                ? const Icon(Icons.warning_amber_rounded, color: Colors.redAccent)
                : const Icon(Icons.check_circle_outline, color: Colors.green),
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final int count;
  final Color color;

  const _StatCard({required this.title, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text(count.toString(), style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
