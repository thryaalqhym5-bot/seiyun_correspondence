import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/archive_service.dart';
import '../../../../data/services/local_storage_service.dart';
import 'folder_communications_page.dart';

class UserArchivePage extends StatefulWidget {
  const UserArchivePage({super.key});

  @override
  State<UserArchivePage> createState() => _UserArchivePageState();
}

class _UserArchivePageState extends State<UserArchivePage> {
  final ArchiveService _archiveService = ArchiveService();
  final LocalStorageService _localStorageService = LocalStorageService();

  String? _entityId;
  String? _entityType;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initArchive();
  }

  Future<void> _initArchive() async {
    try {
      // أولاً: محاولة من LocalStorage
      final user = await _localStorageService.getUser();
      
      String deptId = user?.deptId ?? '';
      String collegeId = user?.collegeId ?? '';
      String adminTitle = '';

      // إذا LocalStorage فارغ، نجلب من Firestore مباشرة
      if (deptId.isEmpty && collegeId.isEmpty) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          if (doc.exists) {
            final data = doc.data()!;
            deptId = data['dept_id'] ?? '';
            collegeId = data['college_id'] ?? '';
            adminTitle = data['administrative_title'] ?? '';
            debugPrint('📁 Archive: Loaded from Firestore - dept=$deptId, college=$collegeId, title=$adminTitle');
          }
        }
      } else {
        adminTitle = user?.administrativeTitle ?? '';
        debugPrint('📁 Archive: Loaded from LocalStorage - dept=$deptId, college=$collegeId');
      }

      // العميد يرى أرشيف الكلية (وليس القسم)
      final deanRoles = ['dean', 'center_director', 'general_director'];
      if (deanRoles.contains(adminTitle) && collegeId.isNotEmpty) {
        _entityId = collegeId;
        _entityType = 'college';
      } else if (deptId.isNotEmpty) {
        _entityId = deptId;
        _entityType = 'department';
      } else if (collegeId.isNotEmpty) {
        _entityId = collegeId;
        _entityType = 'college';
      }

      debugPrint('📁 Archive: entityId=$_entityId, entityType=$_entityType');

      if (_entityId != null) {
        await _archiveService.ensureDefaultFoldersExist(
          entityId: _entityId!,
          entityType: _entityType!,
        );
      }
    } catch (e) {
      debugPrint('Error init archive: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const darkBlueBg = Color(0xFF0A192F);

    return Scaffold(
      backgroundColor: darkBlueBg,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
            : _entityId == null
                ? _buildEmptyState('لم يتم التعرف على جهة العمل الخاصة بك.')
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        const Text(
                          'الأرشيف الإلكتروني',
                          style: TextStyle(color: Colors.white54, fontSize: 14),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'دواليب الأرشيف',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'إدارة جميع المراسلات الواردة والصادرة والملفات المخصصة للجهة',
                          style: TextStyle(fontSize: 16, color: Colors.white54),
                        ),
                        const SizedBox(height: 32),

                        // Folders Grid
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: _archiveService.getFoldersForEntity(_entityId!),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text('حدث خطأ: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)),
                                  ),
                                );
                              }
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
                              }
                              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                return _buildEmptyState('لا توجد ملفات في الأرشيف.');
                              }

                              final currentUid = FirebaseAuth.instance.currentUser?.uid;
                              final folders = snapshot.data!.docs.where((doc) {
                                final d = doc.data() as Map<String, dynamic>;
                                final allowed = d['allowed_viewers'] as List<dynamic>?;
                                if (allowed == null || allowed.isEmpty) return true;
                                return currentUid != null && allowed.contains(currentUid);
                              }).toList();

                              // ترتيب حسب رقم الملف
                              folders.sort((a, b) {
                                final na = ((a.data() as Map<String, dynamic>)['folder_number'] ?? 0) as int;
                                final nb = ((b.data() as Map<String, dynamic>)['folder_number'] ?? 0) as int;
                                return na.compareTo(nb);
                              });

                              if (folders.isEmpty) {
                                return _buildEmptyState('لا تملك صلاحية رؤية أي ملفات هنا.');
                              }

                              return GridView.builder(
                                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 350,
                                  crossAxisSpacing: 24,
                                  mainAxisSpacing: 24,
                                  mainAxisExtent: 180,
                                ),
                                itemCount: folders.length,
                                itemBuilder: (context, index) {
                                  final data = folders[index].data() as Map<String, dynamic>;
                                  return _FolderCard(
                                    folderId: folders[index].id,
                                    folderName: data['folder_name'] ?? 'بدون اسم',
                                    folderType: data['folder_type'] ?? 'custom',
                                    folderNumber: data['folder_number'] ?? 0,
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

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_off_outlined, size: 80, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 24),
          Text(message, style: const TextStyle(color: Colors.white54, fontSize: 18)),
        ],
      ),
    );
  }
}

class _FolderCard extends StatefulWidget {
  final String folderId;
  final String folderName;
  final String folderType;
  final int folderNumber;

  const _FolderCard({
    required this.folderId,
    required this.folderName,
    required this.folderType,
    required this.folderNumber,
  });

  @override
  State<_FolderCard> createState() => _FolderCardState();
}

class _FolderCardState extends State<_FolderCard> {
  bool _isHovered = false;

  void _openFolder() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FolderCommunicationsPage(
          folderId: widget.folderId,
          folderName: widget.folderName,
          folderType: widget.folderType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    IconData folderIcon = Icons.folder;
    Color iconColor = Colors.blueAccent;

    if (widget.folderType == 'incoming') {
      folderIcon = Icons.move_to_inbox;
      iconColor = Colors.greenAccent;
    } else if (widget.folderType == 'outgoing') {
      folderIcon = Icons.outbox;
      iconColor = Colors.orangeAccent;
    } else if (widget.folderType == 'external_incoming') {
      folderIcon = Icons.markunread_mailbox_outlined;
      iconColor = Colors.amber;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _openFolder,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF112240),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered ? iconColor.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05),
              width: 1.5,
            ),
            boxShadow: _isHovered
                ? [BoxShadow(color: iconColor.withValues(alpha: 0.1), blurRadius: 15, spreadRadius: 2)]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(folderIcon, color: iconColor, size: 32),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'ملف رقم ${widget.folderNumber}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  )
                ],
              ),
              const Spacer(),
              Text(
                widget.folderName,
                style: TextStyle(
                  color: _isHovered ? Colors.white : Colors.white.withValues(alpha: 0.9),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                'اضغط لعرض محتويات الملف',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
