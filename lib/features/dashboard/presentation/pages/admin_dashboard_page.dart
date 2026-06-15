import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../auth/presentation/pages/login_page.dart';
import 'colleges_page.dart';
import 'users_page.dart';
import 'templates_page.dart';
import 'admin_upload_page.dart';
import 'admin_archive_management_page.dart';
import '../../../../core/widgets/dashboard_layout.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/user_model.dart';
import '../widgets/add_user_dialog.dart';
import '../widgets/edit_user_dialog.dart';
import '../widgets/profile_settings_dialog.dart';

class AdminDashboardPage extends StatefulWidget {
  final String fullName;

  const AdminDashboardPage({
    super.key,
    required this.fullName,
  });

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final Color darkBlueBg = const Color(0xFF0A192F);
  final Color surfaceColor = AppColors.surface;
  final Color primaryAccent = Colors.blueAccent;

  int usersCount = 0;
  int collegesCount = 0;
  int templatesCount = 0;
  bool isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final usersSnap = await FirebaseFirestore.instance.collection('users').count().get();
      final collegesSnap = await FirebaseFirestore.instance.collection('colleges').count().get();
      final templatesSnap = await FirebaseFirestore.instance.collection('templates').count().get();
      
      setState(() {
        usersCount = usersSnap.count ?? 0;
        collegesCount = collegesSnap.count ?? 0;
        templatesCount = templatesSnap.count ?? 0;
        isLoadingStats = false;
      });
    } catch (e) {
      setState(() {
        isLoadingStats = false;
      });
    }
  }

  void _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  void _showDangerZone() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('تحذير خطير', style: TextStyle(color: Colors.redAccent)),
          ],
        ),
        content: const Text(
          'هل أنت متأكد من مسح جميع المخاطبات المرسلة نهائياً؟ (لتنظيف قاعدة البيانات)',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withValues(alpha: 0.2), foregroundColor: Colors.redAccent, elevation: 0),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف كل شيء'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري المسح... يرجى الانتظار')));
      try {
        final batch = FirebaseFirestore.instance.batch();
        int operationCount = 0;

        final comms = await FirebaseFirestore.instance.collection('communications').get();
        for (var doc in comms.docs) {
          final data = doc.data();
          try {
            final url = data['generated_docx_url']?.toString() ?? '';
            if (url.isNotEmpty && url.startsWith('http')) {
              await FirebaseStorage.instance.refFromURL(url).delete();
            }
          } catch (e) {}

          try {
            final trackingDocs = await doc.reference.collection('tracking').get();
            for (var tDoc in trackingDocs.docs) {
              batch.delete(tDoc.reference);
              operationCount++;
            }
          } catch (e) {}

          batch.delete(doc.reference);
          operationCount++;

          if (operationCount >= 400) {
            await batch.commit();
            operationCount = 0;
          }
        }

        // تصفير عدادات الأرشيف لجميع الملفات لتبدأ من 0 مجدداً
        try {
          final folders = await FirebaseFirestore.instance.collection('archive_folders').get();
          for (var folder in folders.docs) {
            batch.update(folder.reference, {'current_sequence': 0});
            operationCount++;
          }
        } catch (e) {}

        if (operationCount > 0) {
          await batch.commit();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم المسح وتصفير العدادات بالكامل بنجاح', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red));
        }
      }
    }
  }

  int _selectedIndex = 0;

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardContent();
      case 1:
        return const UsersPage(); // Will be refactored to datatable soon
      case 2:
        return const CollegesPage();
      case 3:
        return const TemplatesPage();
      case 4:
        return const AdminArchiveManagementPage();
      case 5:
        return const AdminUploadPage();
      default:
        return _buildDashboardContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DashboardLayout(
      selectedIndex: _selectedIndex,
      onItemSelected: (index) => setState(() => _selectedIndex = index),
      userName: widget.fullName,
      role: 'مدير النظام',
      onLogout: _handleLogout,
      onSettings: () async {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          if (doc.exists && mounted) {
            final userModel = UserModel.fromJson(doc.data()!, uid);
            showDialog(
              context: context,
              builder: (context) => ProfileSettingsDialog(currentUser: userModel),
            );
          }
        }
      },
      items: [
        SidebarItem(title: 'الرئيسية', icon: Icons.dashboard),
        SidebarItem(title: 'المستخدمين', icon: Icons.people_outline),
        SidebarItem(title: 'الكليات والأقسام', icon: Icons.account_balance_outlined),
        SidebarItem(title: 'إدارة القوالب', icon: Icons.description_outlined),
        SidebarItem(title: 'الأرشيف والصلاحيات', icon: Icons.archive_outlined),
        SidebarItem(title: 'رفع بيانات الجامعة', icon: Icons.upload_file),
      ],
      child: _buildBody(),
    );
  }

  Widget _buildDashboardContent() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'نظرة سريعة',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        if (isLoadingStats)
                          const Center(child: CircularProgressIndicator())
                        else
                          Row(
                            children: [
                              Expanded(child: _StatCard(title: 'المستخدمين', value: usersCount.toString(), icon: Icons.people, color: Colors.blueAccent)),
                              const SizedBox(width: 16),
                              Expanded(child: _StatCard(title: 'الكليات والوحدات', value: collegesCount.toString(), icon: Icons.account_balance, color: Colors.teal)),
                              const SizedBox(width: 16),
                              Expanded(child: _StatCard(title: 'القوالب', value: templatesCount.toString(), icon: Icons.description, color: Colors.orange)),
                            ],
                          ),
                        const SizedBox(height: 32),
                        const Text(
                          'الإجراءات السريعة',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              int crossAxisCount = 2;
                              if (constraints.maxWidth > 700) crossAxisCount = 3;
                              if (constraints.maxWidth > 1100) crossAxisCount = 4;
                              if (constraints.maxWidth > 1500) crossAxisCount = 5;
                              
                              return GridView(
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  mainAxisExtent: 95,
                                ),
                                children: [
                                  _ActionCard(
                                    title: 'رفع بيانات الجامعة',
                                    subtitle: 'تحديث الهيكل الإداري',
                                    icon: Icons.upload_file,
                                    color: Colors.purpleAccent,
                                    onTap: () => setState(() => _selectedIndex = 5),
                                  ),
                                  _ActionCard(
                                    title: 'إدارة الأرشيف',
                                    subtitle: 'الصلاحيات والمراسلات',
                                    icon: Icons.archive,
                                    color: Colors.tealAccent,
                                    onTap: () => setState(() => _selectedIndex = 4),
                                  ),
                                  _ActionCard(
                                    title: 'إدارة القوالب',
                                    subtitle: 'تعديل النماذج الرسمية',
                                    icon: Icons.description_outlined,
                                    color: Colors.orangeAccent,
                                    onTap: () => setState(() => _selectedIndex = 3),
                                  ),
                                  _ActionCard(
                                    title: 'تنظيف المخاطبات',
                                    subtitle: 'Danger Zone',
                                    icon: Icons.delete_forever,
                                    color: Colors.redAccent,
                                    onTap: _showDangerZone,
                                  ),
                                ],
                              );
                            }
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 40),
                  Expanded(
                    flex: 1,
                    child: _buildActivityFeed(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _StatCard(title: 'المستخدمين', value: isLoadingStats ? '...' : '$usersCount', icon: Icons.people, color: Colors.blueAccent)),
        const SizedBox(width: 24),
        Expanded(child: _StatCard(title: 'الكليات', value: isLoadingStats ? '...' : '$collegesCount', icon: Icons.account_balance, color: Colors.orangeAccent)),
        const SizedBox(width: 24),
        const Expanded(child: _StatCard(title: 'القوالب', value: 'نشط', icon: Icons.file_copy, color: Colors.purpleAccent)),
        const SizedBox(width: 24),
        const Expanded(child: _StatCard(title: 'التنبيهات', value: '0', icon: Icons.notifications_active, color: Colors.greenAccent)),
      ],
    );
  }

  Widget _buildActivityFeed() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history, color: Colors.white70),
              SizedBox(width: 8),
              Text(
                'آخر النشاطات',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: [
                _ActivityItem(title: 'تسجيل دخول ناجح', time: 'الآن', icon: Icons.login, color: Colors.greenAccent),
                _ActivityItem(title: 'تحديث بيانات المستخدمين', time: 'منذ ساعتين', icon: Icons.update, color: Colors.blueAccent),
                _ActivityItem(title: 'تم رفع قالب جديد', time: 'أمس', icon: Icons.upload, color: Colors.purpleAccent),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: const TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        transform: Matrix4.diagonal3Values(_isHovered ? 1.02 : 1.0, _isHovered ? 1.02 : 1.0, 1.0),
        decoration: BoxDecoration(
          color: const Color(0xFF112240),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isHovered ? widget.color.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05),
            width: 1.5,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.15),
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.white.withValues(alpha: 0.2), size: 14),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final String title;
  final String time;
  final IconData icon;
  final Color color;

  const _ActivityItem({required this.title, required this.time, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
                const SizedBox(height: 4),
                Text(time, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
