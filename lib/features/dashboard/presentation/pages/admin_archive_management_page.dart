import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/services/archive_service.dart';

class AdminArchiveManagementPage extends StatefulWidget {
  const AdminArchiveManagementPage({super.key});

  @override
  State<AdminArchiveManagementPage> createState() => _AdminArchiveManagementPageState();
}

class _AdminArchiveManagementPageState extends State<AdminArchiveManagementPage> {
  final ArchiveService _archiveService = ArchiveService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  static const darkBlueBg = Color(0xFF0A192F);
  static const surfaceColor = Color(0xFF112240);

  @override
  void dispose() {
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBlueBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // العنوان
              const Text('إدارة الأرشيف والصلاحيات',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 6),
              const Text('لوحة التحكم المركزية بدواليب الأرشيف — معايير ISO 15489',
                  style: TextStyle(fontSize: 14, color: Colors.white54)),
              const SizedBox(height: 20),

              // شريط الإحصائيات
              _buildStatisticsBar(),
              const SizedBox(height: 20),

              // حقل البحث
              TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'بحث عن كلية أو قسم...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white38),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white38),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          })
                      : null,
                  filled: true,
                  fillColor: surfaceColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
              ),
              const SizedBox(height: 20),

              // القائمة الرئيسية
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: RawScrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    thumbColor: Colors.blueAccent.withValues(alpha: 0.6),
                    thickness: 6,
                    radius: const Radius.circular(8),
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          _buildEntitiesSection('الكليات (Colleges)', 'colleges', 'name'),
                          const SizedBox(height: 28),
                          _buildEntitiesSection('الأقسام والمراكز (Departments)', 'departments', 'name'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================
  // شريط الإحصائيات
  // =====================================================
  Widget _buildStatisticsBar() {
    return FutureBuilder<Map<String, int>>(
      future: _archiveService.getArchiveStatistics(),
      builder: (context, snap) {
        final stats = snap.data ?? {};
        return Row(
          children: [
            _statCard(Icons.folder_copy, stats['total_folders'] ?? 0, 'المجلدات', Colors.blueAccent),
            const SizedBox(width: 12),
            _statCard(Icons.archive, stats['total_archived'] ?? 0, 'مؤرشفة', Colors.greenAccent),
            const SizedBox(width: 12),
            _statCard(Icons.account_balance, stats['total_colleges'] ?? 0, 'الكليات', Colors.orangeAccent),
            const SizedBox(width: 12),
            _statCard(Icons.domain, stats['total_departments'] ?? 0, 'الأقسام', Colors.purpleAccent),
          ],
        );
      },
    );
  }

  Widget _statCard(IconData icon, int count, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.white54)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // قسم الكليات / الأقسام
  // =====================================================
  Widget _buildEntitiesSection(String title, String collectionName, String nameField) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(title, style: const TextStyle(color: Colors.blueAccent, fontSize: 15, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        FutureBuilder<QuerySnapshot>(
          future: _firestore.collection(collectionName).get(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            var docs = snapshot.data!.docs;
            if (_searchQuery.isNotEmpty) {
              docs = docs.where((d) {
                final name = ((d.data() as Map<String, dynamic>)[nameField] ?? '').toString();
                return name.contains(_searchQuery);
              }).toList();
            }
            if (docs.isEmpty) return const Text('لا توجد نتائج', style: TextStyle(color: Colors.white54));

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                return _EntityArchiveTile(
                  entityId: docs[index].id,
                  entityName: data[nameField] ?? 'غير معروف',
                  entityType: collectionName == 'colleges' ? 'college' : 'department',
                );
              },
            );
          },
        ),
      ],
    );
  }
}

// =====================================================
// بطاقة الجهة (كلية/قسم) مع أرشيفاتها
// =====================================================
class _EntityArchiveTile extends StatefulWidget {
  final String entityId;
  final String entityName;
  final String entityType;

  const _EntityArchiveTile({required this.entityId, required this.entityName, required this.entityType});

  @override
  State<_EntityArchiveTile> createState() => _EntityArchiveTileState();
}

class _EntityArchiveTileState extends State<_EntityArchiveTile> {
  final ArchiveService _archiveService = ArchiveService();
  bool _isExpanded = false;

  void _addCustomFolder() async {
    final nameCtrl = TextEditingController();
    final numCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF112240),
        title: const Text('إضافة ملف أرشيف جديد', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'اسم الملف (مثال: شؤون الموظفين)',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: numCtrl,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'رقم الملف',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إنشاء')),
        ],
      ),
    );

    if (confirm == true && nameCtrl.text.isNotEmpty) {
      final num = int.tryParse(numCtrl.text) ?? DateTime.now().millisecondsSinceEpoch % 1000;
      await _archiveService.addCustomFolder(
        entityId: widget.entityId,
        entityType: widget.entityType,
        folderName: nameCtrl.text.trim(),
        folderNumber: num,
      );
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          title: Text(widget.entityName, style: const TextStyle(color: Colors.white, fontSize: 15)),
          leading: Icon(
            widget.entityType == 'college' ? Icons.account_balance : Icons.domain,
            color: Colors.white54, size: 22,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isExpanded)
                IconButton(
                  icon: const Icon(Icons.create_new_folder, color: Colors.blueAccent, size: 20),
                  onPressed: _addCustomFolder,
                  tooltip: 'إضافة ملف مخصص',
                ),
              Icon(_isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white54),
            ],
          ),
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
              if (_isExpanded) {
                _archiveService.ensureDefaultFoldersExist(entityId: widget.entityId, entityType: widget.entityType);
              }
            });
          },
        ),
        if (_isExpanded)
          Container(
            padding: const EdgeInsets.only(right: 48, left: 12, bottom: 12),
            child: StreamBuilder<QuerySnapshot>(
              stream: _archiveService.getFoldersForEntity(widget.entityId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Text('لا توجد ملفات', style: TextStyle(color: Colors.white54));
                }
                final folders = snapshot.data!.docs;
                return Column(
                  children: folders.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return _FolderSettingRow(
                      folderId: doc.id,
                      folderName: data['folder_name'] ?? 'بدون اسم',
                      folderType: data['folder_type'] ?? 'custom',
                      folderNumber: data['folder_number'] ?? 0,
                      currentSequence: data['current_sequence'] ?? 0,
                      isDefault: data['is_default'] == true,
                      allowedViewers: List<String>.from(data['allowed_viewers'] ?? []),
                      entityId: widget.entityId,
                      entityType: widget.entityType,
                      onRefresh: () => setState(() {}),
                    );
                  }).toList(),
                );
              },
            ),
          ),
      ],
    );
  }
}

// =====================================================
// صف المجلد المحسّن (Enterprise Folder Row)
// =====================================================
class _FolderSettingRow extends StatefulWidget {
  final String folderId;
  final String folderName;
  final String folderType;
  final int folderNumber;
  final int currentSequence;
  final bool isDefault;
  final List<String> allowedViewers;
  final String entityId;
  final String entityType;
  final VoidCallback onRefresh;

  const _FolderSettingRow({
    required this.folderId,
    required this.folderName,
    required this.folderType,
    required this.folderNumber,
    required this.currentSequence,
    required this.isDefault,
    required this.allowedViewers,
    required this.entityId,
    required this.entityType,
    required this.onRefresh,
  });

  @override
  State<_FolderSettingRow> createState() => _FolderSettingRowState();
}

class _FolderSettingRowState extends State<_FolderSettingRow> {
  final ArchiveService _archiveService = ArchiveService();

  IconData get _icon {
    switch (widget.folderType) {
      case 'incoming': return Icons.move_to_inbox;
      case 'outgoing': return Icons.outbox;
      case 'external_incoming': return Icons.public;
      default: return Icons.folder;
    }
  }

  Color get _color {
    switch (widget.folderType) {
      case 'incoming': return Colors.greenAccent;
      case 'outgoing': return Colors.orangeAccent;
      case 'external_incoming': return Colors.amber;
      default: return Colors.blueAccent;
    }
  }

  // ============ حوار إعادة التسمية ============
  void _showRenameDialog() async {
    final ctrl = TextEditingController(text: widget.folderName);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF112240),
        title: const Text('إعادة تسمية الملف', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'الاسم الجديد',
            labelStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (confirmed == true && ctrl.text.trim().isNotEmpty) {
      await _archiveService.renameFolder(widget.folderId, ctrl.text.trim());
      widget.onRefresh();
    }
  }

  // ============ حوار تعديل رقم الملف ============
  void _showEditNumberDialog() async {
    final ctrl = TextEditingController(text: widget.folderNumber.toString());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF112240),
        title: const Text('تعديل رقم الملف', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('رقم الملف يؤثر على الرقم المرجعي للمراسلات', style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'الرقم الجديد',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (confirmed == true) {
      final num = int.tryParse(ctrl.text.trim());
      if (num != null) {
        await _archiveService.updateFolderNumber(widget.folderId, num);
        widget.onRefresh();
      }
    }
  }

  // ============ حوار إعادة تعيين العداد ============
  void _showResetSequenceDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF112240),
        title: const Text('⚠️ إعادة تعيين العداد', style: TextStyle(color: Colors.amber)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('هل أنت متأكد من إعادة تعيين العداد التسلسلي؟', style: TextStyle(color: Colors.white, fontSize: 15)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('العداد الحالي: ${widget.currentSequence}', style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 4),
                    const Text('سيتم إعادة الترقيم من 1', style: TextStyle(color: Colors.amber)),
                    const Text('المراسلات السابقة لن تتأثر', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إعادة تعيين', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _archiveService.resetFolderSequence(widget.folderId);
      widget.onRefresh();
    }
  }

  // ============ حوار الصلاحيات المحسّن ============
  void _showPermissionsDialog() async {
    // جلب منسوبي الجهة فقط (الكلية أو القسم) بدلاً من جميع المسجلين
    final fieldName = widget.entityType == 'college' ? 'college_id' : 'dept_id';
    final usersSnap = await FirebaseFirestore.instance
        .collection('users')
        .where(fieldName, isEqualTo: widget.entityId)
        .get();
    final users = usersSnap.docs;
    List<String> currentSelected = List.from(widget.allowedViewers);
    String filterText = '';

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          final filtered = users.where((u) {
            if (filterText.isEmpty) return true;
            final name = (u.data()['full_name'] ?? '').toString();
            return name.contains(filterText);
          }).toList();

          return AlertDialog(
            backgroundColor: const Color(0xFF112240),
            title: Text('صلاحيات: ${widget.folderName}', style: const TextStyle(color: Colors.white, fontSize: 16)),
            content: SizedBox(
              width: 420,
              height: 450,
              child: Column(
                children: [
                  const Text('إذا لم تختر أي شخص، الملف متاح لجميع قيادات الجهة.',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 10),
                  // فلتر البحث
                  TextField(
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'بحث عن مستخدم...',
                      hintStyle: const TextStyle(color: Colors.white30),
                      prefixIcon: const Icon(Icons.search, color: Colors.white30, size: 18),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onChanged: (v) => setStateSB(() => filterText = v.trim()),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final u = filtered[index];
                        final d = u.data();
                        final uid = u.id;
                        return CheckboxListTile(
                          title: Text(d['full_name'] ?? uid, style: const TextStyle(color: Colors.white, fontSize: 14)),
                          subtitle: Text(d['administrative_title'] ?? 'staff', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                          value: currentSelected.contains(uid),
                          activeColor: Colors.blueAccent,
                          dense: true,
                          onChanged: (val) {
                            setStateSB(() {
                              if (val == true) { currentSelected.add(uid); } else { currentSelected.remove(uid); }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  await FirebaseFirestore.instance.collection('archive_folders').doc(widget.folderId).update({
                    'allowed_viewers': currentSelected,
                  });
                  Navigator.pop(ctx);
                  widget.onRefresh();
                },
                child: const Text('حفظ الصلاحيات'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============ حوار الحذف ============
  void _showDeleteDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF112240),
        title: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white)),
        content: Text('هل أنت متأكد من حذف "${widget.folderName}" نهائياً؟', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('archive_folders').doc(widget.folderId).delete();
      widget.onRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRestricted = widget.allowedViewers.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          // أيقونة الملف
          Icon(_icon, color: _color, size: 20),
          const SizedBox(width: 10),

          // اسم الملف
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.folderName, style: const TextStyle(color: Colors.white, fontSize: 14)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // رقم الملف
                    _badge('#${widget.folderNumber}', Colors.blueAccent),
                    const SizedBox(width: 6),
                    // العداد
                    _badge('التسلسل: ${widget.currentSequence}', Colors.tealAccent),
                    const SizedBox(width: 6),
                    // عدد المراسلات
                    FutureBuilder<int>(
                      future: _archiveService.getFolderDocumentCount(widget.folderId),
                      builder: (_, snap) => _badge('${snap.data ?? 0} مراسلة', Colors.white54),
                    ),
                    if (isRestricted) ...[
                      const SizedBox(width: 6),
                      _badge('مقيّد', Colors.redAccent),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // أزرار الإجراءات
          _actionBtn(Icons.edit, 'تسمية', _showRenameDialog),
          _actionBtn(Icons.tag, 'رقم', _showEditNumberDialog),
          _actionBtn(Icons.refresh, 'عداد', _showResetSequenceDialog),
          _actionBtn(Icons.security, 'صلاحيات', _showPermissionsDialog),
          if (!widget.isDefault)
            _actionBtn(Icons.delete_outline, 'حذف', _showDeleteDialog, color: Colors.redAccent),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w500)),
    );
  }

  Widget _actionBtn(IconData icon, String tooltip, VoidCallback onTap, {Color color = Colors.white54}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
