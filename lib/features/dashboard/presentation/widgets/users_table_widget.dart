import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/user_model.dart';
import '../viewmodels/admin_viewmodel.dart';
import 'edit_user_dialog.dart';

class UsersTableWidget extends StatelessWidget {
  final List<UserModel> users;
  final AdminViewModel viewModel;

  const UsersTableWidget({
    super.key,
    required this.users,
    required this.viewModel,
  });

  void _showEditUserDialog(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => EditUserDialog(docId: user.uid ?? user.email, data: user.toJson()),
    );
  }

  void _showDeleteDialog(BuildContext context, UserModel user) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.danger),
              SizedBox(width: 8),
              Text('تأكيد الحذف', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: const Text('هل أنت متأكد من حذف هذا المستخدم؟ لا يمكن التراجع عن هذا الإجراء.', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger.withValues(alpha: 0.2), foregroundColor: AppColors.danger, elevation: 0),
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await viewModel.deleteUser(user.uid ?? user.email);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف المستخدم بنجاح')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء الحذف: $e')));
                  }
                }
              },
              child: const Text('حذف نهائي'),
            ),
          ],
        );
      },
    );
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'admin': return 'مدير نظام';
      case 'president': return 'رئيس الجامعة';
      case 'vp_student_affairs': return 'نائب شؤون الطلاب';
      case 'vp_academic_affairs': return 'نائب الشؤون الأكاديمية';
      case 'vp_postgraduate_studies': return 'نائب الدراسات العليا';
      case 'secretary_general': return 'الأمين العام';
      case 'executive_secretary': return 'سكرتير تنفيذي / مدير مكتب';
      case 'staff': 
      default: return 'موظف';
    }
  }

  String _getTitleLabel(String title) {
    switch (title) {
      case 'university_president': return 'رئيس الجامعة';
      case 'university_vp': return 'نائب رئيس الجامعة';
      case 'general_secretary': return 'أمين عام الجامعة';
      case 'dean': return 'عميد';
      case 'vice_dean': return 'نائب عميد';
      case 'vice_dean_student': return 'نائب عميد لشؤون الطلاب';
      case 'vice_dean_academic': return 'نائب عميد للشؤون الأكاديمية';
      case 'vice_dean_postgraduate': return 'نائب عميد للدراسات العليا';
      case 'center_director': return 'مدير مركز';
      case 'vice_director': return 'نائب مدير مركز';
      case 'general_director': return 'مدير عام';
      case 'head_of_department': return 'رئيس قسم';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ScrollController scrollController = ScrollController();
    
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_alt_outlined, size: 80, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 24),
            const Text('لم يتم العثور على نتائج تطابق البحث.', style: TextStyle(color: Colors.white54, fontSize: 18)),
          ],
        ),
      );
    }

    return RawScrollbar(
      controller: scrollController,
      thumbVisibility: true,
      thumbColor: AppColors.primary.withValues(alpha: 0.5),
      thickness: 6,
      radius: const Radius.circular(8),
      child: SingleChildScrollView(
        controller: scrollController,
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppColors.surface2.withValues(alpha: 0.5)),
            dataRowMinHeight: 70,
            horizontalMargin: 24,
            columnSpacing: 40,
            columns: const [
              DataColumn(label: Text('الاسم', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('البريد الإلكتروني', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('الصلاحية والمناصب', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('الحالة', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('الإجراءات', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold))),
            ],
            rows: users.map((user) {
              final userMap = user.toJson();
              final role = _getRoleLabel(user.role);
              final rawTitle = userMap['raw_title']?.toString() ?? '';
              final defaultTitle = _getTitleLabel(userMap['administrative_title'] ?? 'staff');
              final primaryTitle = rawTitle.isNotEmpty ? rawTitle : defaultTitle;
              final secondaryTitle = _getTitleLabel(userMap['secondary_administrative_title'] ?? 'none');
              
              List<String> titles = [role];
              if (primaryTitle.isNotEmpty) titles.add(primaryTitle);
              if (secondaryTitle.isNotEmpty) titles.add(secondaryTitle);

              return DataRow(
                cells: [
                  DataCell(
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: user.isActive ? AppColors.primary.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15),
                          child: Text(
                            user.fullName.isNotEmpty ? user.fullName[0] : 'U',
                            style: TextStyle(color: user.isActive ? AppColors.primary : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(user.fullName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  DataCell(Text(user.email, style: const TextStyle(color: Colors.white70))),
                  DataCell(
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                          ),
                          child: Text(role, style: const TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        if (primaryTitle.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                            ),
                            child: Text(primaryTitle, style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        if (secondaryTitle.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                            ),
                            child: Text(secondaryTitle, style: const TextStyle(color: Colors.purple, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: user.isActive ? AppColors.success.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: user.isActive ? AppColors.success.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        user.isActive ? 'نشط' : 'معطل',
                        style: TextStyle(color: user.isActive ? AppColors.success : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: user.isActive,
                          activeThumbColor: AppColors.success,
                          onChanged: (val) => viewModel.toggleUserStatus(user.uid ?? user.email, user.isActive),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                          onPressed: () => _showEditUserDialog(context, user),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                          onPressed: () => _showDeleteDialog(context, user),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
