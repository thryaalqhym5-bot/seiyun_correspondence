import 'dart:typed_data';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/signature_setup_dialog.dart';
import '../../../communications/presentation/pages/pending_approval_page.dart';
import 'delegation_management_page.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../communications/presentation/pages/user_archive_page.dart';
import '../../../communications/presentation/pages/create_communication_page.dart';
import '../../../communications/presentation/pages/inbox_page.dart';
import '../../../communications/presentation/pages/outbox_page.dart';
import '../widgets/wall_reminders_widget.dart';
import '../../../communications/presentation/pages/circulars_page.dart';
import '../../../communications/presentation/pages/secretary_dispatch_page.dart';
import '../../../communications/presentation/pages/returned_drafts_page.dart';
import 'secretary_external_archive_page.dart';
import '../../../../core/widgets/dashboard_layout.dart';
import '../../../communications/presentation/pages/external_inbox_page.dart';
import '../../../communications/data/communications_repository.dart';
import 'academic_vp_emails_page.dart';
import '../../../../core/services/communication_service.dart';
import '../../../../core/models/communication_model.dart';
import 'college_members_page.dart';

class StaffDashboardPage extends StatefulWidget {
  final String fullName;

  const StaffDashboardPage({
    super.key,
    required this.fullName,
  });

  @override
  State<StaffDashboardPage> createState() => _StaffDashboardPageState();
}

class _StaffDashboardPageState extends State<StaffDashboardPage> {
  final Color darkBlueBg = const Color(0xFF0A192F);
  final Color surfaceColor = const Color(0xFF112240);
  final Color primaryAccent = Colors.blueAccent;

  int inboxCount = 0;
  int outboxCount = 0;
  int archiveCount = 0;
  int pendingCount = 0;
  String userTitle = 'staff';
  String userCollegeId = '';
  bool isLoadingStats = true;
  String? signatureUrl; // إضافة متغير التوقيع
  List<Map<String, dynamic>> recentActivities = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.email != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
        final uData = userDoc.data() ?? {};
        final title = uData['administrative_title'] ?? 'staff';
        final collegeId = uData['college_id'] ?? '';

        final inboxSnap = await FirebaseFirestore.instance
            .collection('communications')
            .where('current_rcv_id', isEqualTo: currentUser.uid)
            .get();

        final outboxSnap = await FirebaseFirestore.instance
            .collection('communications')
            .where('sender_id', isEqualTo: currentUser.uid)
            .get();

        
        int pending = 0;
        int archived = 0;
        int inboxToday = 0;
        int outboxToday = 0;

        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day);

        for (var doc in inboxSnap.docs) {
          final data = doc.data();
          final status = data['status'] ?? '';
          if (status == 'archived' || status == 'مؤرشف') archived++;
          if (status == 'pending' || status == 'قيد المعالجة' || status == 'قيد الانتظار' || status == '') pending++;
          
          final Timestamp? timestamp = data['sent_at'] as Timestamp? ?? data['created_at'] as Timestamp?;
          if (timestamp != null && timestamp.toDate().isAfter(startOfDay)) {
            inboxToday++;
          }
        }
        for (var doc in outboxSnap.docs) {
          final data = doc.data();
          final status = data['status'] ?? '';
          if (status == 'archived' || status == 'مؤرشف') archived++;
          
          final Timestamp? timestamp = data['sent_at'] as Timestamp? ?? data['created_at'] as Timestamp?;
          if (timestamp != null && timestamp.toDate().isAfter(startOfDay)) {
            outboxToday++;
          }
        }

        if (mounted) {
          setState(() {
            userTitle = title;
            userCollegeId = collegeId;
            signatureUrl = uData['signature_url']; // قراءة التوقيع
            inboxCount = inboxToday;
            outboxCount = outboxToday;
            pendingCount = pending;
            archiveCount = archived;
            isLoadingStats = false;

            // Populate Activity Feed
            var allDocs = [...inboxSnap.docs, ...outboxSnap.docs];
            
            // Remove duplicates (since a user might send to themselves)
            final seenIds = <String>{};
            final uniqueDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            for (var doc in allDocs) {
              if (seenIds.add(doc.id)) {
                uniqueDocs.add(doc);
              }
            }

            uniqueDocs.sort((a, b) {
              final ta = a.data()['created_at'] as Timestamp?;
              final tb = b.data()['created_at'] as Timestamp?;
              if (ta == null && tb == null) return 0;
              if (ta == null) return 1;
              if (tb == null) return -1;
              return tb.compareTo(ta);
            });
            
            recentActivities = uniqueDocs.take(5).map((doc) => doc.data()).toList();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingStats = false;
        });
      }
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

  int _selectedIndex = 0;

  Widget _buildBody(List<SidebarItem> items) {
    if (_selectedIndex >= items.length) return _buildDashboardContent();
    final title = items[_selectedIndex].title;
    
    switch (title) {
      case 'الرئيسية':
        return _buildDashboardContent();
      case 'إنشاء مخاطبة':
        return const CreateCommunicationPage();
      case 'الوارد':
        return const InboxPage();
      case 'الصادر':
        return const OutboxPage();
      case 'التعاميم والقرارات':
        return const CircularsPage();
      case 'رسائل جاهزة للإرسال':
      case 'مجهزة للاعتماد':
        return const PendingApprovalPage();
      case 'مسودات معادة للتعديل':
        return const ReturnedDraftsPage();
      case 'الأرشيف':
        return const UserArchivePage();
      case 'أرشفة وارد خارجي':
        return const SecretaryExternalArchivePage();
      case 'وارد خارجي':
        return const ExternalInboxPage();
      case 'تفعيل إيميلات الأكاديميين':
        return const AcademicVpEmailsPage();
      case 'إدارة أعضاء الكلية':
        return CollegeMembersPage(collegeId: userCollegeId);
      case 'إدارة التفويض والصلاحيات':
        return const DelegationManagementPage(); // You might need to import this if not imported
      case 'بريد جاهز للتصدير':
        return const SecretaryDispatchPage();
      default:
        return _buildDashboardContent();
    }
  }

  List<SidebarItem> _getSidebarItems() {
    List<SidebarItem> items = [
      SidebarItem(title: 'الرئيسية', icon: Icons.dashboard),
      SidebarItem(title: 'إنشاء مخاطبة', icon: Icons.create),
      SidebarItem(title: 'الوارد', icon: Icons.inbox),
      SidebarItem(title: 'الصادر', icon: Icons.send),
    ];

    if (userTitle != 'secretary') {
      items.add(SidebarItem(title: 'التعاميم والقرارات', icon: Icons.campaign_outlined));
    }

    if (userTitle != 'staff') {
      items.add(SidebarItem(title: 'الأرشيف', icon: Icons.archive));
    }
    
    if (userTitle == 'secretary') {
      items.add(SidebarItem(title: 'أرشفة وارد خارجي', icon: Icons.move_to_inbox));
      items.add(SidebarItem(title: 'بريد جاهز للتصدير', icon: Icons.outbox));
      items.add(SidebarItem(title: 'مسودات معادة للتعديل', icon: Icons.edit_note));
    }

    if (['dean', 'vice_dean', 'vice_dean_student', 'vice_dean_academic', 'vice_dean_postgraduate', 'center_director', 'vice_director', 'general_director', 'head_of_department', 'university_president', 'university_vp', 'general_secretary'].contains(userTitle)) {
      items.add(SidebarItem(title: 'مجهزة للاعتماد', icon: Icons.checklist_rtl));
      items.add(SidebarItem(title: 'وارد خارجي', icon: Icons.markunread_mailbox_outlined));
      items.add(SidebarItem(title: 'إدارة التفويض والصلاحيات', icon: Icons.supervised_user_circle));
    }

    if (userTitle == 'university_vp_academic') {
      items.add(SidebarItem(title: 'تفعيل إيميلات الأكاديميين', icon: Icons.manage_accounts_outlined));
    }

    if (userTitle == 'vice_dean_academic') {
      items.add(SidebarItem(title: 'إدارة أعضاء الكلية', icon: Icons.people_alt_outlined));
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final items = _getSidebarItems();

    return DashboardLayout(
      selectedIndex: _selectedIndex,
      onItemSelected: (index) => setState(() => _selectedIndex = index),
      userName: widget.fullName,
      role: userTitle,
      onLogout: _handleLogout,
      items: items,
      child: _buildBody(items),
    );
  }

  Widget _buildDashboardContent() {
    if (userTitle == 'secretary') {
      return _buildSecretaryDashboardContent();
    } else if (userTitle == 'staff') {
      return _buildStaffDashboardContent();
    } else {
      return _buildGenericDashboardContent();
    }
  }

  Widget _buildSecretaryDashboardContent() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            const WallRemindersWidget(),
            const SizedBox(height: 24),

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
                          'مساحة عمل السكرتارية',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              int crossAxisCount = 1;
                              if (constraints.maxWidth > 500) crossAxisCount = 2;
                              if (constraints.maxWidth > 900) crossAxisCount = 3;
                              if (constraints.maxWidth > 1400) crossAxisCount = 4;
                              return GridView.count(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: constraints.maxWidth < 500 ? 3.0 : 1.8,
                                children: [
                              _ActionCard(
                                title: 'بريد جاهز للتصدير',
                                subtitle: 'بانتظار التصدير والأرشفة',
                                icon: Icons.outbox,
                                color: Colors.orangeAccent,
                                isPrimary: true,
                                onTap: () => setState(() => _selectedIndex = _getSidebarItems().indexWhere((i) => i.title == 'بريد جاهز للتصدير')),
                              ),
                              _ActionCard(
                                title: 'البريد الوارد',
                                subtitle: 'فرز وإحالة للمدير',
                                icon: Icons.move_to_inbox,
                                color: Colors.blueAccent,
                                onTap: () => setState(() => _selectedIndex = 2),
                              ),
                              _ActionCard(
                                title: 'المسودات المعادة',
                                subtitle: 'تحتاج إلى تعديل',
                                icon: Icons.edit_note,
                                color: Colors.redAccent,
                                onTap: () => setState(() => _selectedIndex = _getSidebarItems().indexWhere((i) => i.title == 'مسودات معادة للتعديل')),
                              ),
                              _ActionCard(
                                title: 'تتبع الصادر',
                                subtitle: 'متابعة الخطابات المرسلة',
                                icon: Icons.outbox,
                                color: Colors.greenAccent,
                                onTap: () => setState(() => _selectedIndex = 3),
                              ),
                              _ActionCard(
                                title: 'إنشاء مخاطبة',
                                subtitle: 'صياغة خطاب جديد',
                                icon: Icons.add_box,
                                color: Colors.tealAccent,
                                onTap: () => setState(() => _selectedIndex = 1),
                              ),
                            ],
                          );
                         },
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

  Widget _buildStaffDashboardContent() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            const WallRemindersWidget(),
            const SizedBox(height: 24),

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
                          'الإجراءات',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              int crossAxisCount = 1;
                              if (constraints.maxWidth > 500) crossAxisCount = 2;
                              if (constraints.maxWidth > 900) crossAxisCount = 3;
                              if (constraints.maxWidth > 1400) crossAxisCount = 4;
                              return GridView.count(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: constraints.maxWidth < 500 ? 3.0 : 1.8,
                                children: [
                              _ActionCard(
                                title: 'التعاميم الجديدة',
                                subtitle: 'آخر التعاميم والقرارات',
                                icon: Icons.campaign,
                                color: Colors.purpleAccent,
                                isPrimary: true,
                                onTap: () => setState(() => _selectedIndex = _getSidebarItems().indexWhere((i) => i.title == 'التعاميم والقرارات')),
                              ),
                              _ActionCard(
                                title: 'المهام والطلبات (الصادر)',
                                subtitle: 'متابعة طلباتك المرفوعة',
                                icon: Icons.outbox,
                                color: Colors.orangeAccent,
                                onTap: () => setState(() => _selectedIndex = 3),
                              ),
                              _ActionCard(
                                title: 'الوارد',
                                subtitle: 'الرسائل المستلمة',
                                icon: Icons.move_to_inbox,
                                color: Colors.blueAccent,
                                onTap: () => setState(() => _selectedIndex = 2),
                              ),
                              _ActionCard(
                                title: 'إنشاء طلب',
                                subtitle: 'رفع طلب جديد',
                                icon: Icons.add_box,
                                color: Colors.tealAccent,
                                onTap: () => setState(() => _selectedIndex = 1),
                              ),
                            ],
                          );
                         },
                        ),
                       ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 40),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        Expanded(child: _buildActivityFeed()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenericDashboardContent() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          const WallRemindersWidget(),
          const SizedBox(height: 32),
          Wrap(
            spacing: 40,
            runSpacing: 40,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              SizedBox(
                width: 800,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الإجراءات السريعة',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        int crossAxisCount = 2;
                        if (constraints.maxWidth > 600) crossAxisCount = 3;
                        if (constraints.maxWidth > 900) crossAxisCount = 4;
                        if (constraints.maxWidth > 1400) crossAxisCount = 5;

                        return GridView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            mainAxisExtent: 95,
                          ),
                          children: [
                              _ActionCard(
                                title: 'إنشاء مخاطبة',
                                subtitle: 'صياغة وإرسال معاملة جديدة',
                                icon: Icons.add_box_outlined,
                                color: Colors.blueAccent,
                                isPrimary: true,
                                onTap: () => setState(() => _selectedIndex = 1),
                              ),
                              _ActionCard(
                                title: 'الوارد',
                                subtitle: 'المعاملات المستلمة',
                                icon: Icons.move_to_inbox_outlined,
                                color: Colors.greenAccent,
                                onTap: () => setState(() => _selectedIndex = 2),
                              ),
                              _ActionCard(
                                title: 'الصادر',
                                subtitle: 'المعاملات المرسلة',
                                icon: Icons.outbox_outlined,
                                color: Colors.orangeAccent,
                                onTap: () => setState(() => _selectedIndex = 3),
                              ),
                              if (userTitle != 'staff')
                                _ActionCard(
                                  title: 'الأرشيف',
                                  subtitle: 'السجلات والوثائق المحفوظة',
                                  icon: Icons.archive_outlined,
                                  color: Colors.purpleAccent,
                                  onTap: () => setState(() => _selectedIndex = _getSidebarItems().indexWhere((i) => i.title == 'الأرشيف')),
                                ),
                              if (['dean', 'vice_dean', 'vice_dean_student', 'vice_dean_academic', 'vice_dean_postgraduate', 'center_director', 'vice_director', 'general_director', 'head_of_department', 'university_president', 'university_vp', 'general_secretary'].contains(userTitle))
                                _ActionCard(
                                  title: 'مجهزة للاعتماد',
                                  subtitle: 'مسودات بانتظار موافقتك',
                                  icon: Icons.checklist_rtl,
                                  color: Colors.orangeAccent,
                                  isPrimary: true,
                                  onTap: () => setState(() => _selectedIndex = _getSidebarItems().indexWhere((i) => i.title == 'مجهزة للاعتماد')),
                                ),
                              if (['dean', 'vice_dean', 'vice_dean_student', 'vice_dean_academic', 'vice_dean_postgraduate', 'center_director', 'vice_director', 'general_director', 'head_of_department', 'university_president', 'university_vp', 'general_secretary'].contains(userTitle))
                                _ExternalInboxCard(
                                  onTap: () => setState(() => _selectedIndex = _getSidebarItems().indexWhere((i) => i.title == 'وارد خارجي')),
                                ),
                              if (['dean', 'vice_dean', 'vice_dean_student', 'vice_dean_academic', 'vice_dean_postgraduate', 'center_director', 'vice_director', 'general_director', 'head_of_department', 'university_president', 'university_vp', 'general_secretary'].contains(userTitle))
                                _ActionCard(
                                  title: 'طلب صياغة',
                                  subtitle: 'توجيه السكرتير بصياغة مسودة',
                                  icon: Icons.edit_document,
                                  color: Colors.tealAccent,
                                  onTap: () => _showDraftRequestDialog(),
                                ),
                              if (['dean', 'vice_dean', 'vice_dean_student', 'vice_dean_academic', 'vice_dean_postgraduate', 'center_director', 'vice_director', 'general_director', 'head_of_department', 'university_president', 'university_vp', 'general_secretary'].contains(userTitle))
                                _ActionCard(
                                  title: 'تفويض الصلاحيات',
                                  subtitle: 'إدارة نوابك ومفوضيك',
                                  icon: Icons.groups,
                                  color: Colors.blueGrey,
                                  onTap: () => setState(() => _selectedIndex = _getSidebarItems().indexWhere((i) => i.title == 'إدارة التفويض والصلاحيات')),
                                ),
                              if (userTitle == 'university_vp_academic')
                                _ActionCard(
                                  title: 'تفعيل الحسابات',
                                  subtitle: 'إضافة إيميلات الأكاديميين',
                                  icon: Icons.manage_accounts_outlined,
                                  color: Colors.pinkAccent,
                                  onTap: () => setState(() => _selectedIndex = _getSidebarItems().indexWhere((i) => i.title == 'تفعيل إيميلات الأكاديميين')),
                                ),
                              if (userTitle == 'vice_dean_academic')
                                _ActionCard(
                                  title: 'إدارة أعضاء الكلية',
                                  subtitle: 'تعديل وحذف الأعضاء',
                                  icon: Icons.people_alt_outlined,
                                  color: Colors.lightBlueAccent,
                                  onTap: () => setState(() => _selectedIndex = _getSidebarItems().indexWhere((i) => i.title == 'إدارة أعضاء الكلية')),
                                ),
                            ],
                          );
                        }
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: 350,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildActivityFeed(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureCard() {
    final bool hasSignature = signatureUrl != null && signatureUrl!.isNotEmpty;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hasSignature ? Colors.green.withValues(alpha: 0.5) : Colors.orange.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: hasSignature ? Colors.green.withValues(alpha: 0.05) : Colors.orange.withValues(alpha: 0.05),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasSignature ? Icons.verified : Icons.warning_amber_rounded,
                color: hasSignature ? Colors.greenAccent : Colors.orangeAccent,
              ),
              const SizedBox(width: 8),
              Text(
                'التوقيع الإلكتروني',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            hasSignature 
                ? 'تم إعداد توقيعك بنجاح. سيتم إرفاقه تلقائياً في مراسلاتك الصادرة.' 
                : 'لم تقم بإعداد توقيعك بعد. يرجى إعداده لتتمكن من ختم مراسلاتك الرسمية.',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _handleSetupSignature(hasSignature),
              icon: Icon(hasSignature ? Icons.edit : Icons.draw),
              label: Text(hasSignature ? 'تعديل التوقيع' : 'إعداد التوقيع الآن'),
              style: ElevatedButton.styleFrom(
                backgroundColor: hasSignature ? AppColors.background : AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: hasSignature ? const BorderSide(color: AppColors.border) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSetupSignature(bool requirePin) async {
    // 1. Verify PIN if modifying existing signature
    if (requirePin) {
      final pinController = TextEditingController();
      final enteredPin = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('أمان التعديل', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: pinController,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'أدخل الرمز السري (PIN) لتعديل توقيعك'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(onPressed: () => Navigator.pop(context, pinController.text.trim()), child: const Text('تأكيد')),
          ],
        ),
      );

      if (enteredPin == null || enteredPin.isEmpty) return;

      // Verify PIN from Firestore
      final currentUser = FirebaseAuth.instance.currentUser;
      final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      final dbPin = doc.data()?['pin'] ?? doc.data()?['pin_code'];
      
      final enteredHashed = sha256.convert(utf8.encode(enteredPin)).toString();
      bool isMatch = false;

      if (dbPin != null) {
        final dbPinStr = dbPin.toString().trim();
        if (dbPinStr.length == 64) {
          isMatch = (enteredHashed == dbPinStr);
        } else {
          isMatch = (enteredPin == dbPinStr);
          if (isMatch) {
            await doc.reference.update({'pin': enteredHashed});
          }
        }
      }

      if (!isMatch) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرمز السري خاطئ!'), backgroundColor: Colors.red));
        return;
      }
    }

    // 2. Open Signature Pad Dialog
    if (!mounted) return;
    
    final dynamic signatureBytes = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SignatureSetupDialog(),
    );

    if (signatureBytes != null && signatureBytes is Uint8List) {
      // 3. Upload to Firebase Storage and update Firestore
      setState(() => isLoadingStats = true);
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        
        final storageRef = FirebaseStorage.instance.ref().child('signatures/${currentUser!.uid}.png');
        await storageRef.putData(signatureBytes, SettableMetadata(contentType: 'image/png'));
        final url = await storageRef.getDownloadURL();
        
        await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
          'signature_url': url,
        });
        
        if (mounted) {
          setState(() {
            signatureUrl = url;
            isLoadingStats = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ التوقيع بنجاح!'), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) {
          setState(() => isLoadingStats = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء حفظ التوقيع: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Widget _buildHeader() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 16,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الرئيسية / مساحة العمل', style: TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 8),
            Text(
              'مرحباً، ${widget.fullName}',
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Row(
          children: [
            // Search Bar Placeholder
            Container(
              width: 250,
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.search, color: Colors.white38, size: 20),
                  SizedBox(width: 8),
                  Text('البحث العالمي...', style: TextStyle(color: Colors.white38, fontSize: 13)),
                ],
              ),
            ),
            _buildNotificationsBell(),
            const SizedBox(width: 16),
            PopupMenuButton<String>(
              offset: const Offset(0, 50),
              tooltip: 'خيارات المستخدم',
              onSelected: (value) {
                if (value == 'signature') {
                  _handleSetupSignature(signatureUrl != null);
                } else if (value == 'logout') {
                  _handleLogout();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'signature',
                  child: Row(
                    children: [
                      Icon(Icons.draw, color: signatureUrl != null ? Colors.green : Colors.blueAccent),
                      const SizedBox(width: 8),
                      Text(signatureUrl != null ? 'تعديل التوقيع' : 'إعداد التوقيع'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      Text('تسجيل الخروج'),
                    ],
                  ),
                ),
              ],
              child: Container(
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: primaryAccent.withValues(alpha: 0.5), width: 2)),
                child: const CircleAvatar(radius: 20, backgroundColor: Color(0xFF112240), child: Icon(Icons.person, color: Colors.white70, size: 20)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotificationsBell() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('communications')
          .where('status', isEqualTo: 'draft_requested')
          .where('current_rcv_id', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final count = docs.length;

        return PopupMenuButton<DocumentSnapshot>(
          tooltip: 'التنبيهات وطلبات الصياغة',
          offset: const Offset(0, 50),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: surfaceColor, shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
                child: const Icon(Icons.notifications_none, color: Colors.white70, size: 20),
              ),
              if (count > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          itemBuilder: (context) {
            if (docs.isEmpty) {
              return [const PopupMenuItem(enabled: false, child: Text('لا توجد تنبيهات'))];
            }
            return docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return PopupMenuItem<DocumentSnapshot>(
                value: doc,
                child: ListTile(
                  leading: const Icon(Icons.edit_document, color: Colors.blueAccent),
                  title: Text(data['subject'] ?? 'بدون عنوان', style: const TextStyle(fontSize: 14)),
                  subtitle: Text('من: ${data['sender_name'] ?? 'المدير'}', style: const TextStyle(fontSize: 12)),
                  contentPadding: EdgeInsets.zero,
                ),
              );
            }).toList();
          },
          onSelected: (doc) {
            final data = doc.data() as Map<String, dynamic>;
            final draft = CommunicationModel.fromJson(data, doc.id);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreateCommunicationPage(draftToEdit: draft),
              ),
            );
          },
        );
      },
    );
  }

  void _showDraftRequestDialog() {
    final subjectController = TextEditingController();
    final instructionsController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            backgroundColor: surfaceColor,
            title: const Text('طلب صياغة خطاب', style: TextStyle(color: Colors.white)),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: subjectController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'موضوع الخطاب (العنوان)'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: instructionsController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'التوجيهات والملاحظات للسكرتير'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: isSubmitting ? null : () async {
                  if (subjectController.text.isEmpty || instructionsController.text.isEmpty) return;
                  setStateSB(() => isSubmitting = true);
                  try {
                    await CommunicationService().requestDraftFromSecretary(
                      subjectController.text.trim(),
                      instructionsController.text.trim()
                    );
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم توجيه الطلب للسكرتير بنجاح'), backgroundColor: Colors.green));
                  } catch (e) {
                    setStateSB(() => isSubmitting = false);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
                  }
                },
                child: isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('إرسال الطلب'),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _StatCard(title: 'وارد اليوم', value: isLoadingStats ? '...' : '$inboxCount', icon: Icons.move_to_inbox, color: Colors.blueAccent)),
        const SizedBox(width: 24),
        Expanded(child: _StatCard(title: 'صادر اليوم', value: isLoadingStats ? '...' : '$outboxCount', icon: Icons.outbox, color: Colors.greenAccent)),
        const SizedBox(width: 24),
        Expanded(child: _StatCard(title: 'معاملات معلقة', value: isLoadingStats ? '...' : '$pendingCount', icon: Icons.pending_actions, color: Colors.orangeAccent)),
        const SizedBox(width: 24),
        Expanded(child: _StatCard(title: 'مكتملة ومؤرشفة', value: isLoadingStats ? '...' : '$archiveCount', icon: Icons.check_circle_outline, color: Colors.purpleAccent)),
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
              Text('آخر المعاملات', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          isLoadingStats 
              ? const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: Colors.blueAccent)))
              : recentActivities.isEmpty
                  ? const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('لا توجد نشاطات حديثة', style: TextStyle(color: Colors.white54))))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: recentActivities.length,
                      itemBuilder: (context, index) {
                        final data = recentActivities[index];
                        final subject = data['subject'] ?? 'بدون عنوان';
                        final timestamp = data['created_at'] as Timestamp?;
                        final timeStr = timestamp != null 
                            ? '${timestamp.toDate().year}/${timestamp.toDate().month}/${timestamp.toDate().day}'
                            : 'غير معروف';
                        
                        final priority = data['priority'] ?? 'normal';
                        final color = priority == 'urgent' ? Colors.redAccent : Colors.blueAccent;
                        final icon = priority == 'urgent' ? Icons.warning_amber_rounded : Icons.mark_email_unread;

                        return _ActivityItem(
                          title: subject,
                          time: timeStr,
                          icon: icon,
                          color: color,
                        );
                      },
                    ),
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
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: const TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
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
  final bool isPrimary;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.isPrimary = false,
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
          color: widget.isPrimary ? widget.color.withValues(alpha: 0.1) : const Color(0xFF112240),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: widget.isPrimary 
                ? widget.color.withValues(alpha: 0.5) 
                : (_isHovered ? widget.color.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05)),
            width: widget.isPrimary ? 2 : 1.5,
          ),
          boxShadow: _isHovered
              ? [BoxShadow(color: widget.color.withValues(alpha: 0.15), blurRadius: 20, spreadRadius: 2)]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.icon, color: widget.color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.title, 
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle, 
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.white.withValues(alpha: 0.2), size: 16),
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
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
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

/// بطاقة الوارد الخارجي مع عداد التنبيهات الحي
class _ExternalInboxCard extends StatelessWidget {
  final VoidCallback onTap;
  const _ExternalInboxCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final repo = CommunicationsRepository();
    return StreamBuilder<int>(
      stream: repo.getUnreadExternalCount(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF112240),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: count > 0
                      ? Colors.orangeAccent.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.05),
                  width: count > 0 ? 1.5 : 1,
                ),
                boxShadow: count > 0
                    ? [
                        BoxShadow(
                          color: Colors.orangeAccent.withValues(alpha: 0.1),
                          blurRadius: 12,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.markunread_mailbox_outlined,
                            color: Colors.orangeAccent, size: 32),
                      ),
                      if (count > 0)
                        Positioned(
                          top: -6,
                          right: -6,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              count > 9 ? '9+' : count.toString(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('وارد خارجي',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(
                          count > 0
                              ? '$count خطاب جديد بانتظار المراجعة'
                              : 'لا توجد خطابات جديدة',
                          style: TextStyle(
                              color: count > 0
                                  ? Colors.orangeAccent
                                  : Colors.white54,
                              fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios,
                      color: Colors.white.withValues(alpha: 0.2), size: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}