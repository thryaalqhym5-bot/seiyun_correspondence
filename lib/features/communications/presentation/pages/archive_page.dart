import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/word_service.dart';

class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key});

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  bool _isLoading = true;
  String _error = '';
  List<Map<String, dynamic>> _allArchived = [];
  List<Map<String, dynamic>> _filteredArchived = [];

  String _searchQuery = '';
  String _selectedType = 'all';
  String _selectedStatus = 'all';
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadArchive();
  }

  Future<void> _loadArchive() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.email == null) {
        throw 'لا يوجد مستخدم مسجل دخول';
      }

      // 1. Get current user's role from allowed_users
      final userDoc = await FirebaseFirestore.instance.collection('allowed_users').doc(currentUser.email).get();
      if (!userDoc.exists) throw 'بيانات المستخدم غير موجودة في الصلاحيات';
      
      final userData = userDoc.data()!;
      final userTitle = userData['administrative_title'] ?? 'staff';
      final userDeptId = userData['dept_id'] ?? '';
      final userCollegeId = userData['college_id'] ?? '';

      // 2. Fetch allowed_users to map emails to colleges/departments for fast lookup
      final allowedUsersSnap = await FirebaseFirestore.instance.collection('allowed_users').get();
      Map<String, String> emailToCollege = {};
      Map<String, String> emailToDept = {};
      for (var doc in allowedUsersSnap.docs) {
        final data = doc.data();
        emailToCollege[doc.id] = data['college_id'] ?? '';
        emailToDept[doc.id] = data['dept_id'] ?? '';
      }

      // 3. Fetch all archived communications
      final commSnap = await FirebaseFirestore.instance
          .collection('communications')
          .where('status', isEqualTo: 'archived')
          .get();

      List<Map<String, dynamic>> allowedDocs = [];

      for (var doc in commSnap.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        
        final senderDept = data['sender_dept_id'] ?? '';
        final currentDept = data['current_dept_id'] ?? '';
        final targetEmail = data['target_id'] ?? '';
        final targetDept = emailToDept[targetEmail] ?? '';
        final targetCollege = emailToCollege[targetEmail] ?? '';
        
        bool canView = false;
        
        final deanRoles = ['dean', 'center_director', 'general_director'];
        final viceDeanRoles = ['vice_dean', 'vice_dean_student', 'vice_dean_academic', 'vice_dean_postgraduate', 'vice_director'];

        if (userTitle == 'university_president') {
          canView = true;
        } else if (deanRoles.contains(userTitle) || viceDeanRoles.contains(userTitle)) {
          bool senderInCollege = false;
          for (var uDoc in allowedUsersSnap.docs) {
             if (uDoc.data()['dept_id'] == senderDept && uDoc.data()['college_id'] == userCollegeId) {
                senderInCollege = true; break;
             }
          }
          if (senderInCollege || targetCollege == userCollegeId) {
             canView = true;
          }
        } else if (userTitle == 'head_of_department') {
          if (senderDept == userDeptId || currentDept == userDeptId || targetDept == userDeptId) {
            canView = true;
          }
        } else {
          // Staff
          if (data['sender_id'] == currentUser.uid || data['current_rcv_id'] == currentUser.email || data['current_rcv_id'] == currentUser.uid) {
            canView = true;
          }
        }

        if (canView) {
          allowedDocs.add(data);
        }
      }

      // Sort locally to avoid Firebase Index requirements
      allowedDocs.sort((a, b) {
        final timestampA = a['archived_at'] as Timestamp?;
        final timestampB = b['archived_at'] as Timestamp?;
        if (timestampA == null && timestampB == null) return 0;
        if (timestampA == null) return 1;
        if (timestampB == null) return -1;
        return timestampB.compareTo(timestampA); // Descending
      });

      setState(() {
        _allArchived = allowedDocs;
        _isLoading = false;
      });
      
      _applyFilters();

    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredArchived = _allArchived.where((doc) {
        final subject = (doc['subject'] ?? '').toString().toLowerCase();
        final senderName = (doc['sender_name'] ?? '').toString().toLowerCase();
        final targetName = (doc['target_name'] ?? '').toString().toLowerCase();
        final type = doc['type'] ?? 'outgoing';
        
        // Search filter
        bool matchesSearch = _searchQuery.isEmpty ||
            subject.contains(_searchQuery.toLowerCase()) ||
            senderName.contains(_searchQuery.toLowerCase()) ||
            targetName.contains(_searchQuery.toLowerCase());
            
        // Type filter
        bool matchesType = _selectedType == 'all' || type == _selectedType;
            
        // Status filter
        bool matchesStatus = _selectedStatus == 'all' || (doc['status'] == _selectedStatus);

        // Date filter
        Timestamp? ts = doc['archived_at'] ?? doc['created_at'];
        DateTime? date = ts?.toDate();
        final matchesDate = _selectedDate == null ||
            (date != null &&
             date.year == _selectedDate!.year &&
             date.month == _selectedDate!.month &&
             date.day == _selectedDate!.day);
             
        return matchesSearch && matchesType && matchesStatus && matchesDate;
      }).toList();
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.orangeAccent,
              onPrimary: Colors.white,
              surface: Color(0xFF112240),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _applyFilters();
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'غير معروف';
    final dt = timestamp.toDate();
    return '${dt.year}/${dt.month}/${dt.day}';
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const darkBlueBg = Color(0xFF0A192F);

    return Scaffold(
      backgroundColor: darkBlueBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('الأرشيف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Filter section
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF112240),
            child: Column(
              children: [
                TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'ابحث بالاسم أو العنوان...',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search, color: Colors.orangeAccent),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) {
                    _searchQuery = val;
                    _applyFilters();
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedType,
                        dropdownColor: const Color(0xFF112240),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('جميع الأنواع')),
                          DropdownMenuItem(value: 'outgoing', child: Text('صادر خارجي')),
                          DropdownMenuItem(value: 'incoming', child: Text('وارد خارجي')),
                          DropdownMenuItem(value: 'internal', child: Text('مذكرة داخلية')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedType = val);
                            _applyFilters();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedStatus,
                        dropdownColor: const Color(0xFF112240),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('جميع الحالات')),
                          DropdownMenuItem(value: 'مؤرشفة', child: Text('مؤرشفة')),
                          DropdownMenuItem(value: 'قيد المعالجة', child: Text('قيد المعالجة')),
                          DropdownMenuItem(value: 'مكتملة', child: Text('مكتملة')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedStatus = val);
                            _applyFilters();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _selectDate(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Colors.orangeAccent, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _selectedDate == null ? 'التاريخ' : '${_selectedDate!.year}/${_selectedDate!.month}/${_selectedDate!.day}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            if (_selectedDate != null) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  setState(() => _selectedDate = null);
                                  _applyFilters();
                                },
                                child: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.orangeAccent))
                : _error.isNotEmpty
                    ? Center(child: Text('خطأ: $_error', style: const TextStyle(color: AppColors.error)))
                    : _filteredArchived.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.archive_outlined, size: 80, color: Colors.white24),
                                const SizedBox(height: 16),
                                Text(
                                  _allArchived.isEmpty ? 'لا توجد مخاطبات في الأرشيف' : 'لا توجد نتائج تطابق بحثك',
                                  style: const TextStyle(fontSize: 18, color: Colors.white54)
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredArchived.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final data = _filteredArchived[index];

                              final subject = data['subject'] ?? 'بدون عنوان';
                              final targetName = data['target_name'] ?? 'مجهول';
                              final archivedByName = data['archived_by_name'] ?? 'مجهول';
                              final archivedAt = data['archived_at'];
                              final priority = data['priority'] ?? 'normal';
                              final type = data['type'] ?? 'غير معروف';

                              final isUrgent = priority == 'urgent';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.orangeAccent.withValues(alpha: 0.2),
                                    child: const Icon(Icons.folder_open, color: Colors.orangeAccent),
                                  ),
                                  title: Text(subject, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('إلى: $targetName', style: const TextStyle(color: Colors.white70)),
                                        const SizedBox(height: 8),
                                        Text('تمت الأرشفة بواسطة: $archivedByName', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                                        Text('بتاريخ: ${_formatTimestamp(archivedAt)}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          children: [
                                            _buildBadge(type == 'internal' ? 'داخلي' : type == 'incoming' ? 'وارد' : 'صادر', Colors.blueGrey),
                                            _buildBadge('مؤرشف', Colors.orangeAccent),
                                            if (isUrgent) _buildBadge('عاجل', Colors.redAccent),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white54),
                                  onTap: () {
                                    WordService.openCommunicationPdf(context, data, data['id'], subject);
                                  },
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}