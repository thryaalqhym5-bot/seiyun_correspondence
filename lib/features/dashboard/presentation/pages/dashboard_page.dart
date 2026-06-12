import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  final String fullName;
  final String role;

  const DashboardPage({
    super.key,
    required this.fullName,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اللوحة الرئيسية'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'مرحبًا، $fullName',
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 12),
            Text(
              'الدور: $role',
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}