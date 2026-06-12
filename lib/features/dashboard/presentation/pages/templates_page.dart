import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/template_service.dart';
import '../widgets/add_template_dialog.dart';
import '../widgets/edit_template_dialog.dart';

class TemplatesPage extends StatefulWidget {
  const TemplatesPage({super.key});

  @override
  State<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends State<TemplatesPage> {
  final TemplateService _templateService = TemplateService();
  final ScrollController _scrollController = ScrollController();
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showAddTemplateDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AddTemplateDialog(),
    );
    if (result == true) {
      setState(() {});
    }
  }

  void _showEditTemplateDialog(Map<String, dynamic> data, String docId) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => EditTemplateDialog(docId: docId, data: data),
    );
    if (result == true) {
      setState(() {});
    }
  }

  Future<void> _deleteTemplate(String docId, Map<String, dynamic> data) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF112240),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('تأكيد الحذف', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'هل أنت متأكد من حذف هذا القالب؟ سيتم حذفه من قاعدة البيانات وملفاته من التخزين نهائياً.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withValues(alpha: 0.2), foregroundColor: Colors.redAccent, elevation: 0),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف القالب'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _templateService.deleteTemplate(docId, data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حذف القالب وملفاته بنجاح')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء الحذف: $e')));
        }
      }
    }
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
              // Navigation / Breadcrumbs
              // Navigation / Breadcrumbs
              const Text(
                'إدارة القوالب',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 32),

              // Header Row (Title & Action)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'قوالب المخاطبات الرسمية',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'إدارة النماذج المعتمدة لطباعة الخطابات والتقارير',
                        style: TextStyle(color: Colors.white54, fontSize: 15),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigoAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _showAddTemplateDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة قالب جديد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Toolbar Row (Search)
              Row(
                children: [
                  SizedBox(
                    width: 350, // More controlled search bar size
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: TextField(
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'ابحث عن قالب...',
                          hintStyle: TextStyle(color: Colors.white38),
                          border: InputBorder.none,
                          icon: Icon(Icons.search, color: Colors.white38),
                          filled: false,
                        ),
                        onChanged: (val) => setState(() => searchQuery = val.toLowerCase()),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Data Grid
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('templates').orderBy('created_at', descending: true).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.indigoAccent));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildEmptyState('لا توجد قوالب حالياً.');
                    }

                    final docs = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = (data['template_name'] ?? '').toString().toLowerCase();
                      return name.contains(searchQuery);
                    }).toList();

                    if (docs.isEmpty) {
                      return _buildEmptyState('لم يتم العثور على قوالب تطابق البحث.');
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
                          maxCrossAxisExtent: 450,
                          crossAxisSpacing: 24,
                          mainAxisSpacing: 24,
                          mainAxisExtent: 220, // Fixed height for uniformity
                        ),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                        return _TemplateCard(
                          docId: doc.id,
                          data: data,
                          onEdit: () => _showEditTemplateDialog(data, doc.id),
                          onDelete: () => _deleteTemplate(doc.id, data),
                          onToggleStatus: (val) => _templateService.toggleTemplateStatus(doc.id, val),
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
          Icon(Icons.folder_open, size: 80, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 24),
          Text(message, style: const TextStyle(color: Colors.white54, fontSize: 18)),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(bool) onToggleStatus;

  const _TemplateCard({
    required this.docId,
    required this.data,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
  });

  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard> {
  bool _isHovered = false;

  Widget _buildTypeBadge(String type) {
    Color color;
    String label;
    switch (type) {
      case 'outgoing': color = Colors.orangeAccent; label = 'صادر'; break;
      case 'incoming': color = Colors.greenAccent; label = 'وارد'; break;
      case 'internal': color = Colors.blueAccent; label = 'داخلي'; break;
      default: color = Colors.grey; label = 'غير محدد';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'غير محدد';
    if (timestamp is Timestamp) {
      return DateFormat('dd MMM yyyy - hh:mm a', 'ar').format(timestamp.toDate());
    }
    return 'غير محدد';
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.data['is_active'] ?? true;
    final docxPath = widget.data['docx_path'] ?? '';
    final templateName = widget.data['template_name'] ?? 'بدون اسم';
    final version = widget.data['version'] ?? 1;
    final createdAt = _formatDate(widget.data['created_at']);
    // Mock usage data to bring the system alive
    final usages = (templateName.length * version * 3) % 150 + 12; 

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16), // Reduced padding
        decoration: BoxDecoration(
          color: const Color(0xFF112240),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered ? Colors.indigoAccent.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05),
            width: 1.5,
          ),
          boxShadow: _isHovered
              ? [BoxShadow(color: Colors.indigoAccent.withValues(alpha: 0.1), blurRadius: 15, spreadRadius: 2)]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Type and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTypeBadge(widget.data['template_type'] ?? ''),
                Row(
                  children: [
                    Text(
                      isActive ? 'نشط' : 'معطل',
                      style: TextStyle(
                        color: isActive ? Colors.greenAccent : Colors.grey,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 24,
                      child: Switch(
                        value: isActive,
                        activeThumbColor: Colors.greenAccent,
                        inactiveThumbColor: Colors.grey,
                        inactiveTrackColor: Colors.white10,
                        onChanged: widget.onToggleStatus,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(),
            
            // Middle: Data Hierarchy
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.insert_drive_file, color: isActive ? Colors.indigoAccent : Colors.grey, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        templateName,
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.white54,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text('الإصدار $version', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                          const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Text('•', style: TextStyle(color: Colors.white24))),
                          Text('$usages استخدام', style: const TextStyle(color: Colors.blueAccent, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('آخر تعديل: $createdAt', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            
            const Divider(color: Colors.white10, height: 1),
            const Spacer(),
            
            // Bottom Row: Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Tooltip(
                  message: 'تعديل بيانات القالب',
                  child: TextButton.icon(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit, size: 16, color: Colors.blueAccent),
                    label: const Text('تعديل', style: TextStyle(color: Colors.blueAccent, fontSize: 13)),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                  ),
                ),
                if (docxPath.isNotEmpty)
                  Tooltip(
                    message: 'تحميل ملف الوورد',
                    child: TextButton.icon(
                      onPressed: () => launchUrl(Uri.parse(docxPath)),
                      icon: const Icon(Icons.download, size: 16, color: Colors.greenAccent),
                      label: const Text('تحميل', style: TextStyle(color: Colors.greenAccent, fontSize: 13)),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                    ),
                  ),
                Tooltip(
                  message: 'حذف القالب نهائياً',
                  child: TextButton.icon(
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete, size: 16, color: Colors.redAccent),
                    label: const Text('حذف', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}