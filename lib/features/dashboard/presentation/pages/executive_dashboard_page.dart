import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/widgets/dashboard_layout.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../communications/presentation/pages/inbox_page.dart';
import '../../../communications/presentation/pages/outbox_page.dart';
import '../../../communications/presentation/pages/user_archive_page.dart';
import '../../../communications/presentation/pages/circulars_page.dart';
import '../../../communications/presentation/pages/global_tracking_page.dart';
import '../../../communications/presentation/pages/create_communication_page.dart';
import '../../../communications/presentation/pages/pending_approvals_page.dart';
import '../widgets/wall_reminders_widget.dart';
import '../widgets/workspace_switcher_widget.dart';
import '../../../../core/models/user_model.dart';
import 'delegation_management_page.dart';
import '../../../../core/services/communication_service.dart';
import '../widgets/signature_setup_dialog.dart';
import 'academic_vp_emails_page.dart';

class ExecutiveDashboardPage extends StatefulWidget {
  final String fullName;
  final String role;

  const ExecutiveDashboardPage({
    super.key,
    required this.fullName,
    required this.role,
  });

  @override
  State<ExecutiveDashboardPage> createState() => _ExecutiveDashboardPageState();
}

class _ExecutiveDashboardPageState extends State<ExecutiveDashboardPage> {
  final Color darkBlueBg = const Color(0xFF071224); // Slightly darker for luxury
  final Color surfaceColor = const Color(0xFF0F1E38);
  final Color goldAccent = const Color(0xFFD4AF37); // Luxury Gold

  int urgentCount = 0;
  int preppedCount = 0;
  bool isLoadingStats = true;
  List<Map<String, dynamic>> urgentCommunications = [];
  UserModel? currentUserModel;
  int activeAffiliationIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
        final uData = userDoc.data() ?? {};
        final userModel = UserModel.fromJson(uData, currentUser.uid);
        
        final prefs = await SharedPreferences.getInstance();
        int savedIndex = prefs.getInt('active_affiliation_${currentUser.uid}') ?? 0;
        if (savedIndex >= userModel.affiliations.length) savedIndex = 0;

        final inboxSnap = await FirebaseFirestore.instance
            .collection('communications')
            .where('current_rcv_id', isEqualTo: currentUser.uid)
            .where('status', whereIn: ['pending', 'pending_approval', 'قيد المعالجة', 'قيد الانتظار', ''])
            .get();

        int urgent = 0;
        int prepped = 0;
        List<Map<String, dynamic>> urgents = [];

        for (var doc in inboxSnap.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          
          final priority = data['priority'] ?? 'normal';
          if (priority == 'urgent' || priority == 'عاجل') {
            urgent++;
            urgents.add(data);
          } else {
            prepped++;
          }
        }

        urgents.sort((a, b) {
          final ta = a['created_at'] as Timestamp?;
          final tb = b['created_at'] as Timestamp?;
          if (ta == null && tb == null) return 0;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return tb.compareTo(ta);
        });

        if (mounted) {
          setState(() {
            currentUserModel = userModel;
            activeAffiliationIndex = savedIndex;
            urgentCount = urgent;
            preppedCount = prepped;
            urgentCommunications = urgents.take(5).toList();
            isLoadingStats = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingStats = false);
    }
  }

  Future<void> _switchWorkspace(int newIndex) async {
    if (currentUserModel == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('active_affiliation_${FirebaseAuth.instance.currentUser!.uid}', newIndex);
    
    setState(() {
      activeAffiliationIndex = newIndex;
      _selectedIndex = 0; // Reset view
    });
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
      case 'صندوق الوارد':
        return const InboxPage();
      case 'مجهزة للاعتماد':
        return const PendingApprovalsPage();
      case 'المراسلات الصادرة':
        return const OutboxPage();
      case 'التعاميم والقرارات':
        return const CircularsPage();
      case 'الأرشيف الخاص':
        return const UserArchivePage();
      case 'تتبع شامل للمراسلات':
        return const GlobalTrackingPage();
      case 'تفعيل إيميلات الأكاديميين':
        return const AcademicVpEmailsPage();
      case 'إدارة التفويض والصلاحيات':
        return const DelegationManagementPage();
      default:
        return _buildDashboardContent();
    }
  }

  List<SidebarItem> _getSidebarItems() {
    List<SidebarItem> items = [
      SidebarItem(title: 'الرئيسية', icon: Icons.dashboard_customize),
      SidebarItem(title: 'إنشاء مخاطبة', icon: Icons.create),
      SidebarItem(title: 'صندوق الوارد', icon: Icons.inbox),
      SidebarItem(title: 'مجهزة للاعتماد', icon: Icons.checklist_rtl),
      SidebarItem(title: 'المراسلات الصادرة', icon: Icons.send),
      SidebarItem(title: 'التعاميم والقرارات', icon: Icons.campaign_outlined),
      SidebarItem(title: 'الأرشيف الخاص', icon: Icons.archive),
    ];

    if (widget.role == 'university_president' || widget.role == 'general_secretary') {
      items.add(SidebarItem(title: 'تتبع شامل للمراسلات', icon: Icons.track_changes));
    }
    
    if (widget.role == 'vp_academic_affairs') {
      items.add(SidebarItem(title: 'تفعيل إيميلات الأكاديميين', icon: Icons.manage_accounts_outlined));
    }
    
    // All executives can manage delegations
    items.add(SidebarItem(title: 'إدارة التفويض والصلاحيات', icon: Icons.supervised_user_circle));

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final items = _getSidebarItems();

    return DashboardLayout(
      selectedIndex: _selectedIndex,
      onItemSelected: (index) => setState(() => _selectedIndex = index),
      userName: widget.fullName,
      role: widget.role,
      onLogout: _handleLogout,
      items: items,
      child: Container(
        color: darkBlueBg,
        child: _buildBody(items),
      ),
    );
  }

  Widget _buildDashboardContent() {
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
            _buildStatsRow(),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'معاملات عاجلة (Quick Actions)',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 24),
                        Expanded(child: _buildUrgentActionsFeed()),
                      ],
                    ),
                  ),
                  const SizedBox(width: 40),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildExecutiveBadge(),
                        const SizedBox(height: 24),
                        Expanded(child: _buildGeneralActions()),
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
            Text('القيادة العليا / واجهة الإدارة التنفيذية', style: TextStyle(color: goldAccent.withValues(alpha: 0.8), fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'مرحباً، ${widget.fullName}',
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
                if (currentUserModel != null && currentUserModel!.affiliations.length > 1) ...[
                  const SizedBox(width: 16),
                  WorkspaceSwitcherWidget(
                    user: currentUserModel!,
                    activeIndex: activeAffiliationIndex,
                    onWorkspaceChanged: _switchWorkspace,
                  ),
                ],
              ],
            ),
          ],
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: surfaceColor, shape: BoxShape.circle, border: Border.all(color: goldAccent.withValues(alpha: 0.3))),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(Icons.notifications_active, color: goldAccent, size: 24),
                  if (urgentCount > 0)
                    Positioned(
                      right: -5,
                      top: -5,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: Text('$urgentCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            PopupMenuButton<String>(
              offset: const Offset(0, 50),
              tooltip: 'خيارات المستخدم',
              onSelected: (value) {
                if (value == 'logout') {
                  _handleLogout();
                } else if (value == 'signature') {
                  showDialog(
                    context: context,
                    builder: (context) => const SignatureSetupDialog(),
                  ).then((_) {
                    // Refresh data after signature upload if needed
                    _loadStats();
                  });
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'signature',
                  child: Row(
                    children: [
                      Icon(Icons.draw, color: Colors.blueAccent),
                      const SizedBox(width: 8),
                      const Text('إضافة توقيع'),
                    ],
                  ),
                ),
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
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: goldAccent.withValues(alpha: 0.5), width: 2)),
                child: const CircleAvatar(radius: 20, backgroundColor: Color(0xFF112240), child: Icon(Icons.person, color: Colors.white70, size: 20)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _StatCard(title: 'عاجل جداً', value: isLoadingStats ? '...' : '$urgentCount', icon: Icons.warning_amber_rounded, color: Colors.redAccent)),
        const SizedBox(width: 24),
        Expanded(child: _StatCard(title: 'مجهزة للاعتماد', value: isLoadingStats ? '...' : '$preppedCount', icon: Icons.checklist_rtl, color: goldAccent)),
        const SizedBox(width: 24),
        Expanded(child: _StatCard(title: 'أرشيف الإدارة', value: '...', icon: Icons.account_balance, color: Colors.blueAccent)),
      ],
    );
  }

  Widget _buildExecutiveBadge() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [goldAccent.withValues(alpha: 0.2), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: goldAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: goldAccent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.stars, color: goldAccent, size: 36),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الصفة القيادية', style: TextStyle(color: Colors.white54, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  widget.role == 'president' ? 'رئيس الجامعة' :
                  widget.role == 'vp_student_affairs' ? 'نائب شؤون الطلاب' :
                  widget.role == 'vp_academic_affairs' ? 'نائب الشؤون الأكاديمية' :
                  widget.role == 'vp_postgraduate_studies' ? 'نائب الدراسات العليا' :
                  widget.role == 'secretary_general' ? 'الأمين العام' : 'قيادة عليا',
                  style: TextStyle(color: goldAccent, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralActions() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('اختصارات عامة', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _ActionRow(icon: Icons.edit_document, title: 'توجيه خطاب جديد', onTap: () => setState(() => _selectedIndex = 1)), // Route to create
            const SizedBox(height: 16),
            _ActionRow(icon: Icons.assignment_add, title: 'طلب صياغة خطاب (للسكرتير)', onTap: () => _showDraftRequestDialog()),
            const SizedBox(height: 16),
            _ActionRow(icon: Icons.groups, title: 'تفويض الصلاحيات', onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DelegationManagementPage()));
            }),
            const SizedBox(height: 16),
            _ActionRow(icon: Icons.travel_explore, title: 'تتبع شامل للمعاملات', onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const GlobalTrackingPage()));
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildUrgentActionsFeed() {
    if (isLoadingStats) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)));
    }
    
    if (urgentCommunications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: Colors.greenAccent.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text('مكتبك نظيف!', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('لا توجد معاملات عاجلة تنتظر قرارك حالياً.', style: TextStyle(color: Colors.white54, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: urgentCommunications.length,
      itemBuilder: (context, index) {
        final comm = urgentCommunications[index];
        return _UrgentActionCard(
          communicationData: comm,
          onRefresh: _loadStats,
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
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                onPressed: isSubmitting ? null : () async {
                  if (subjectController.text.isEmpty || instructionsController.text.isEmpty) return;
                  setStateSB(() => isSubmitting = true);
                    try {
                      final activeAffTitle = currentUserModel != null && currentUserModel!.affiliations.isNotEmpty 
                          ? currentUserModel!.affiliations[activeAffiliationIndex].administrativeTitle 
                          : null;
                      await CommunicationService().requestDraftFromSecretary(
                        subjectController.text.trim(),
                        instructionsController.text.trim(),
                        overrideSenderTitle: activeAffTitle,
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
                  style: ElevatedButton.styleFrom(backgroundColor: goldAccent, foregroundColor: darkBlueBg),
                  child: isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('إرسال الطلب'),
              ),
            ],
          );
        }
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1E38),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ]
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: const TextStyle(color: Colors.white54, fontSize: 15)),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _ActionRow({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16))),
            Icon(Icons.arrow_forward_ios, color: Colors.white.withValues(alpha: 0.5), size: 14),
          ],
        ),
      ),
    );
  }
}

class _UrgentActionCard extends StatefulWidget {
  final Map<String, dynamic> communicationData;
  final VoidCallback onRefresh;

  const _UrgentActionCard({required this.communicationData, required this.onRefresh});

  @override
  State<_UrgentActionCard> createState() => _UrgentActionCardState();
}

class _UrgentActionCardState extends State<_UrgentActionCard> {
  bool isProcessing = false;

  Future<void> _handleQuickApprove() async {
    setState(() => isProcessing = true);
    try {
      final docId = widget.communicationData['id'];
      
      // Update communication
      await FirebaseFirestore.instance.collection('communications').doc(docId).update({
        'status': 'مؤرشف', // or accepted depending on workflow
      });

      // Add to tracking
      final user = FirebaseAuth.instance.currentUser;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      final userName = userDoc.data()?['full_name'] ?? 'مسؤول';

      await FirebaseFirestore.instance
          .collection('communications')
          .doc(docId)
          .collection('tracking')
          .add({
        'action': 'approve',
        'actor_id': user.uid,
        'from_name': userName,
        'to_name': '',
        'comment': 'تم الاعتماد السريع من القيادة العليا',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الاعتماد بنجاح')));
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  Future<void> _handleReturn() async {
    setState(() => isProcessing = true);
    try {
      final docId = widget.communicationData['id'];
      final senderId = widget.communicationData['sender_id'];
      
      await FirebaseFirestore.instance.collection('communications').doc(docId).update({
        'status': 'مرفوض',
        'current_rcv_id': senderId,
      });

      final user = FirebaseAuth.instance.currentUser;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      final userName = userDoc.data()?['full_name'] ?? 'مسؤول';

      await FirebaseFirestore.instance
          .collection('communications')
          .doc(docId)
          .collection('tracking')
          .add({
        'action': 'reject',
        'actor_id': user.uid,
        'from_name': userName,
        'to_name': '',
        'comment': 'تمت الإعادة من قبل القيادة العليا للمراجعة',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إعادة المعاملة بنجاح')));
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.communicationData['subject'] ?? 'بدون عنوان';
    final senderName = widget.communicationData['sender_name'] ?? 'غير معروف';
    final timestamp = widget.communicationData['created_at'] as Timestamp?;
    final dateStr = timestamp != null 
        ? '${timestamp.toDate().year}/${timestamp.toDate().month}/${timestamp.toDate().day}'
        : '';
    final hasSecretaryNote = widget.communicationData['secretary_note'] != null && widget.communicationData['secretary_note'].toString().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1E38),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: const Icon(Icons.priority_high, color: Colors.redAccent, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 14, color: Colors.white54),
                        const SizedBox(width: 4),
                        Text('من: $senderName', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                        const SizedBox(width: 16),
                        const Icon(Icons.access_time, size: 14, color: Colors.white54),
                        const SizedBox(width: 4),
                        Text(dateStr, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
              if (isProcessing)
                const CircularProgressIndicator(color: Color(0xFFD4AF37)),
            ],
          ),
          if (hasSecretaryNote) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  top: BorderSide(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
                  bottom: BorderSide(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
                  left: BorderSide(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
                  right: const BorderSide(color: Color(0xFFD4AF37), width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('إيجاز مدير المكتب:', style: TextStyle(color: Color(0xFFD4AF37), fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(widget.communicationData['secretary_note'], style: const TextStyle(color: Colors.white, fontSize: 14)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isProcessing ? null : _handleQuickApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('اعتماد سريع'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isProcessing ? null : _handleReturn,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.replay),
                  label: const Text('إعادة وملاحظة'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
