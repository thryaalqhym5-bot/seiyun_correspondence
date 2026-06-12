import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/college_add_user_dialog.dart';

class CollegeMembersPage extends StatefulWidget {
  final String collegeId;

  const CollegeMembersPage({super.key, required this.collegeId});

  @override
  State<CollegeMembersPage> createState() => _CollegeMembersPageState();
}

class _CollegeMembersPageState extends State<CollegeMembersPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddUserDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CollegeAddUserDialog(collegeId: widget.collegeId),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.collegeId.isEmpty) {
      return const Center(child: Text('الكلية غير محددة', style: TextStyle(color: Colors.white54)));
    }

    final query = FirebaseFirestore.instance
        .collection('allowed_users')
        .where('college_id', isEqualTo: widget.collegeId);

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'إدارة أعضاء الكلية',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'إضافة وعرض أعضاء الكلية (موظفين، أكاديميين)',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _showAddUserDialog,
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('إضافة مستخدم للكلية', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            onChanged: (val) {
              setState(() {
                _searchQuery = val.toLowerCase();
              });
            },
            decoration: InputDecoration(
              hintText: 'ابحث باسم العضو أو الإيميل...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF112240),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('حدث خطأ: ${snapshot.error}', style: const TextStyle(color: AppColors.danger)));
                }

                final docs = snapshot.data?.docs ?? [];

                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['full_name'] ?? '').toString().toLowerCase();
                  final title = (data['administrative_title'] ?? '').toString().toLowerCase();
                  final role = (data['role'] ?? '').toString().toLowerCase();
                  final emailList = List<String>.from(data['emails'] ?? []);
                  final emailsStr = emailList.join(' ').toLowerCase();

                  return name.contains(_searchQuery) ||
                         title.contains(_searchQuery) ||
                         role.contains(_searchQuery) ||
                         emailsStr.contains(_searchQuery);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(
                    child: Text('لا يوجد أعضاء يطابقون معايير البحث.', style: TextStyle(color: Colors.white54, fontSize: 16)),
                  );
                }

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    
                    final name = data['full_name'] ?? 'غير معروف';
                    final title = data['administrative_title'] ?? '';
                    final role = data['role'] ?? 'user';
                    final emails = List<String>.from(data['emails'] ?? []);
                    final String displayEmail = emails.isNotEmpty ? emails.first : 'لا يوجد إيميل';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF112240),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        leading: CircleAvatar(
                          backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
                          child: const Icon(Icons.person, color: Colors.blueAccent),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            children: [
                              const Icon(Icons.badge_outlined, size: 14, color: Colors.white54),
                              const SizedBox(width: 4),
                              Text(title, style: const TextStyle(color: Colors.white54)),
                              const SizedBox(width: 16),
                              const Icon(Icons.email_outlined, size: 14, color: Colors.blueAccent),
                              const SizedBox(width: 4),
                              Text(displayEmail, style: const TextStyle(color: Colors.blueAccent)),
                              const SizedBox(width: 16),
                              const Icon(Icons.security, size: 14, color: Colors.greenAccent),
                              const SizedBox(width: 4),
                              Text(role, style: const TextStyle(color: Colors.greenAccent)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
