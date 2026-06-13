import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/services/user_service.dart';
import '../widgets/edit_user_dialog.dart';

class DepartmentUsersPage extends StatefulWidget {
  final String deptId;
  final String deptName;

  const DepartmentUsersPage({
    super.key,
    required this.deptId,
    required this.deptName,
  });

  @override
  State<DepartmentUsersPage> createState() => _DepartmentUsersPageState();
}

class _DepartmentUsersPageState extends State<DepartmentUsersPage> {
  final UserService _userService = UserService();
  final ScrollController _scrollController = ScrollController();
  String searchQuery = '';
  late Stream<QuerySnapshot> _usersStream;

  @override
  void initState() {
    super.initState();
    _usersStream = FirebaseFirestore.instance
        .collection('allowed_users')
        .where('dept_ids', arrayContains: widget.deptId)
        .snapshots();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showEditUserDialog(Map<String, dynamic> data, String docId) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => EditUserDialog(docId: docId, data: data),
    );
    if (result == true) {
      setState(() {});
    }
  }

  void _showDeleteDialog(String email) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF112240),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('تأكيد الحذف', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: const Text('هل أنت متأكد من حذف هذا العضو من القسم؟', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withValues(alpha: 0.2), foregroundColor: Colors.redAccent, elevation: 0),
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await _userService.deleteUser(email);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف العضو بنجاح')));
                  }
                } catch (e) {
                  if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    const darkBlueBg = Color(0xFF0A192F);
    const surfaceColor = Color(0xFF112240);

    return Scaffold(
      backgroundColor: darkBlueBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Breadcrumbs
              Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.arrow_back, color: Colors.white54, size: 18),
                          SizedBox(width: 8),
                          Text('العودة للأقسام', style: TextStyle(color: Colors.white54, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '/  أعضاء ${widget.deptName}',
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'أعضاء ${widget.deptName}',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Toolbar (Counters & Search)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: _usersStream,
                    builder: (context, snapshot) {
                      final count = snapshot.data?.docs.length ?? 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$count عضو',
                          style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      );
                    },
                  ),
                  
                  SizedBox(
                    width: 300,
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: TextField(
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'ابحث بالاسم أو البريد...',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                          border: InputBorder.none,
                          icon: Icon(Icons.search, color: Colors.white38, size: 18),
                          filled: false,
                        ),
                        onChanged: (val) => setState(() => searchQuery = val.toLowerCase()),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Data Grid
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _usersStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildEmptyState('لا يوجد أعضاء مسجلين في هذا القسم.');
                    }

                    // الحصول على جميع المستندات
                    var allDocs = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = (data['full_name'] ?? '').toString().toLowerCase();
                      final email = (data['email'] ?? '').toString().toLowerCase();
                      return name.contains(searchQuery) || email.contains(searchQuery);
                    }).toList();

                    // ترتيب الأعضاء بحيث يكون رئيس القسم في المقدمة
                    allDocs.sort((a, b) {
                      final titleA = (a.data() as Map<String, dynamic>)['administrative_title']?.toString().toLowerCase() ?? '';
                      final titleB = (b.data() as Map<String, dynamic>)['administrative_title']?.toString().toLowerCase() ?? '';
                      
                      final isHeadA = titleA.contains('رئيس') || titleA == 'head_of_department';
                      final isHeadB = titleB.contains('رئيس') || titleB == 'head_of_department';

                      if (isHeadA && !isHeadB) return -1;
                      if (!isHeadA && isHeadB) return 1;
                      return 0; // احتفاظ بالترتيب للآخرين
                    });

                    if (allDocs.isEmpty) {
                      return _buildEmptyState('لم يتم العثور على نتائج تطابق البحث.');
                    }

                    return RawScrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      trackVisibility: true,
                      thumbColor: Colors.blueAccent.withValues(alpha: 0.8),
                      trackColor: Colors.white.withValues(alpha: 0.05),
                      thickness: 8,
                      radius: const Radius.circular(8),
                      interactive: true,
                      child: GridView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(right: 16),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 380, // Compact width
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          mainAxisExtent: 180, // Compact height
                        ),
                        itemCount: allDocs.length,
                        itemBuilder: (context, index) {
                          final doc = allDocs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final title = data['administrative_title']?.toString().toLowerCase() ?? '';
                          final isHead = title.contains('رئيس') || title == 'head_of_department';
                          
                          return _CompactUserCard(
                            email: doc.id,
                            data: data,
                            isHeadOfDept: isHead,
                            onEdit: () => _showEditUserDialog(data, doc.id),
                            onDelete: () => _showDeleteDialog(doc.id),
                            onToggleStatus: (val) => _userService.toggleUserStatus(doc.id, val),
                          );
                        },
                      ),
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

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_alt_outlined, size: 80, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 24),
          Text(message, style: const TextStyle(color: Colors.white54, fontSize: 18)),
        ],
      ),
    );
  }
}

class _CompactUserCard extends StatefulWidget {
  final String email;
  final Map<String, dynamic> data;
  final bool isHeadOfDept;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(bool) onToggleStatus;

  const _CompactUserCard({
    required this.email,
    required this.data,
    required this.isHeadOfDept,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
  });

  @override
  State<_CompactUserCard> createState() => _CompactUserCardState();
}

class _CompactUserCardState extends State<_CompactUserCard> {
  bool _isHovered = false;

  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'م';
    var parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'م';
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
    final isActive = widget.data['is_active'] ?? true;
    final fullName = widget.data['full_name'] ?? 'بدون اسم';
    final role = _getRoleLabel(widget.data['role'] ?? 'staff');
    
    final rawTitle = widget.data['raw_title']?.toString() ?? '';
    final defaultTitle = _getTitleLabel(widget.data['administrative_title'] ?? 'staff');
    final primaryTitle = rawTitle.isNotEmpty ? rawTitle : defaultTitle;
    final secondaryTitle = _getTitleLabel(widget.data['secondary_administrative_title'] ?? 'none');
    
    List<String> titles = [role];
    if (primaryTitle.isNotEmpty) titles.add(primaryTitle);
    if (secondaryTitle.isNotEmpty) titles.add(secondaryTitle);
    
    final formattedTitles = titles.join(' • ');

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isHovered ? const Color(0xFF1A2D4F) : const Color(0xFF112240),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isHeadOfDept 
                ? Colors.greenAccent.withValues(alpha: 0.5) // تمييز رئيس القسم بلون أخضر
                : (_isHovered ? Colors.blueAccent.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05)),
            width: widget.isHeadOfDept ? 2.0 : 1.5,
          ),
          boxShadow: _isHovered || widget.isHeadOfDept
              ? [BoxShadow(color: (widget.isHeadOfDept ? Colors.greenAccent : Colors.blueAccent).withValues(alpha: 0.1), blurRadius: 10, spreadRadius: 1)]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Section: Info
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: widget.isHeadOfDept 
                          ? Colors.greenAccent.withValues(alpha: 0.15) 
                          : (isActive ? Colors.blueAccent.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15)),
                      child: Text(
                        _getInitials(fullName),
                        style: TextStyle(
                            color: widget.isHeadOfDept ? Colors.greenAccent : (isActive ? Colors.blueAccent : Colors.grey), 
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    if (widget.isHeadOfDept)
                      Positioned(
                        bottom: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                          child: const Icon(Icons.star, color: Colors.white, size: 10),
                        ),
                      )
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: TextStyle(color: isActive ? Colors.white : Colors.white70, fontSize: 15, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formattedTitles,
                        style: TextStyle(color: widget.isHeadOfDept ? Colors.greenAccent.withValues(alpha: 0.8) : Colors.white54, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Middle Section: Email
            Text(widget.email, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const Spacer(),
            
            // Bottom Section: Actions
            Row(
              children: [
                TextButton.icon(
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.edit, size: 14, color: Colors.blueAccent),
                  label: const Text('تعديل', style: TextStyle(color: Colors.blueAccent, fontSize: 12)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                ),
                const SizedBox(width: 16),
                TextButton.icon(
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete, size: 14, color: Colors.redAccent),
                  label: const Text('حذف', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                ),
                const Spacer(),
                Text(
                  isActive ? 'نشط' : 'معطل',
                  style: TextStyle(color: isActive ? Colors.greenAccent : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  height: 20,
                  width: 32,
                  child: FittedBox(
                    fit: BoxFit.fill,
                    child: Switch(
                      value: isActive,
                      activeThumbColor: Colors.greenAccent,
                      inactiveThumbColor: Colors.grey,
                      inactiveTrackColor: Colors.white10,
                      onChanged: widget.onToggleStatus,
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
