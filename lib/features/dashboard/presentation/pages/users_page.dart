import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/models/user_model.dart';
import '../viewmodels/admin_viewmodel.dart';
import '../widgets/users_table_widget.dart';
import '../widgets/add_user_dialog.dart';
import 'admin_upload_page.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final AdminViewModel _viewModel = AdminViewModel();
  String searchQuery = '';
  final TextEditingController searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late Stream<List<UserModel>> _usersStream;

  @override
  void initState() {
    super.initState();
    _usersStream = _viewModel.getUsersStream();
  }

  @override
  void dispose() {
    searchController.dispose();
    _scrollController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _showAddUserDialog() async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AddUserDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Relies on DashboardLayout background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'إدارة المستخدمين',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surface2,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUploadPage())),
                        icon: const Icon(Icons.upload_file, size: 18),
                        label: const Text('رفع Excel', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _showAddUserDialog,
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('إضافة مستخدم', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 32),

              // Data Table Card
              Expanded(
                child: StreamBuilder<List<UserModel>>(
                  stream: _usersStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('حدث خطأ: ${snapshot.error}', style: const TextStyle(color: AppColors.danger)));
                    }

                    final allUsers = snapshot.data ?? [];
                    
                    return AnimatedBuilder(
                      animation: _viewModel,
                      builder: (context, child) {
                        final filteredUsers = allUsers.where((user) {
                          final name = user.fullName.toLowerCase();
                          final email = user.email.toLowerCase();
                          return name.contains(searchQuery) || email.contains(searchQuery);
                        }).toList();

                        return AppCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Toolbar
                              Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${filteredUsers.length} مستخدم',
                                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 300,
                                      child: TextField(
                                        controller: searchController,
                                        style: const TextStyle(color: Colors.white, fontSize: 14),
                                        decoration: InputDecoration(
                                          hintText: 'ابحث بالاسم أو القسم...',
                                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                                          prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
                                          filled: true,
                                          fillColor: AppColors.surface2,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                        ),
                                        onChanged: (val) => setState(() => searchQuery = val.toLowerCase()),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1, color: Colors.white10),
                              
                              // DataTable Widget
                              Expanded(
                                child: UsersTableWidget(
                                  users: filteredUsers,
                                  viewModel: _viewModel,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}