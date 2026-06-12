import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/services/communication_service.dart';
import '../../../../core/models/communication_model.dart';

class CreateCommunicationPage extends StatefulWidget {
  final CommunicationModel? draftToEdit;
  final CommunicationModel? replyTo;
  final bool isExternalReply;

  const CreateCommunicationPage({super.key, this.draftToEdit, this.replyTo, this.isExternalReply = false});

  @override
  State<CreateCommunicationPage> createState() => _CreateCommunicationPageState();
}

class _CreateCommunicationPageState extends State<CreateCommunicationPage> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  final _pinController = TextEditingController();
  final CommunicationService _communicationService = CommunicationService();

  String _selectedType = 'outgoing';
  String _selectedPriority = 'normal';
  String _selectedSecurityLevel = 'normal';
  String? _selectedTemplateId;
  String? _selectedTargetId;
  String? _selectedTargetName;
  String? _selectedTargetDeptId;
  bool _isCircular = false;
  String? _selectedTargetGroup;
  Map<String, dynamic>? _currentUserData;
  final List<File> _selectedAttachments = [];
  final List<Map<String, dynamic>> _draftAttachments = [];
  String? _managerNotes;

  bool _isLoading = false;

  late Future<List<DocumentSnapshot>> _usersFuture;
  late Future<QuerySnapshot> _templatesFuture;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _usersFuture = _communicationService.fetchAllowedTargets();
    _templatesFuture = FirebaseFirestore.instance.collection('templates').where('is_active', isEqualTo: true).get();

    if (widget.draftToEdit != null) {
      final draft = widget.draftToEdit!;
      _subjectController.text = draft.subject;
      if (draft.type == 'draft_request') {
        _managerNotes = draft.body;
      } else {
        _bodyController.text = draft.body;
      }
      _selectedType = draft.type == 'draft_request' ? 'internal' : draft.type;
      _selectedPriority = draft.priority;
      _selectedTemplateId = draft.templateId;
      if (draft.attachments != null) {
        _draftAttachments.addAll(List<Map<String, dynamic>>.from(draft.attachments!));
      }
      _isCircular = draft.type == 'circular' || draft.targetId == 'group'; // Best effort approximation
      if (_isCircular) {
        _selectedTargetGroup = draft.targetId;
      } else {
        _selectedTargetName = draft.targetName;
        _selectedTargetDeptId = draft.targetDeptId;
        // Fetch email for the dropdown because draft.targetId is the UID, but dropdown uses email
        FirebaseFirestore.instance.collection('users').doc(draft.targetId).get().then((doc) {
          if (doc.exists && mounted) {
            setState(() {
              _selectedTargetId = doc.data()?['email'];
            });
          }
        });
      }
    }

    // Reply mode: pre-fill subject and target
    if (widget.replyTo != null) {
      final original = widget.replyTo!;
      
      // تعبئة الموضوع تلقائياً
      if (original.referenceNumber != null && original.referenceNumber!.isNotEmpty) {
        _subjectController.text = 'رداً على كتابكم رقم ${original.referenceNumber} بشأن ${original.subject}';
      } else {
        _subjectController.text = 'رداً على مخاطبتكم بشأن ${original.subject}';
      }
      
      // للمراسلات الداخلية: تحديد المرسل الأصلي كمستقبل تلقائياً
      // للمراسلات الخارجية: لا يتم تحديد مستقبل (لأن المرسل خارج النظام)
      // الرد يمر عبر المسار العادي: سكرتير ← عميد ← طباعة بالتوقيع والختم
      if (widget.isExternalReply) {
        _selectedTargetName = original.senderName.isNotEmpty ? original.senderName : 'جهة خارجية';
        _selectedTargetId = 'external_entity';
        _selectedType = 'outgoing';
      } else if (!original.isExternal && original.senderId.isNotEmpty) {
        _selectedTargetName = original.senderName;
        FirebaseFirestore.instance.collection('users').doc(original.senderId).get().then((doc) {
          if (doc.exists && mounted) {
            setState(() {
              _selectedTargetId = doc.data()?['email'];
              _selectedTargetDeptId = doc.data()?['dept_id'] ?? '';
            });
          }
        });
      }
    }
  }

  Future<void> _loadCurrentUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data();
      if (data != null && data['administrative_title'] == 'secretary' && data['manager_id'] != null) {
        final managerDoc = await FirebaseFirestore.instance.collection('users').doc(data['manager_id']).get();
        if (managerDoc.exists) {
          data['manager_title'] = managerDoc.data()?['administrative_title'];
        }
      }
      if (mounted) setState(() { _currentUserData = data; });
    }
  }

  Future<void> _sendCommunication() async {
    if (!_formKey.currentState!.validate() || _selectedTemplateId == null) {
      _showSnackBar('يرجى إكمال جميع الحقول واختيار القالب');
      return;
    }
    if (!_isCircular && _selectedTargetId == null) {
      _showSnackBar('يرجى اختيار المستقبل');
      return;
    }
    if (_isCircular && _selectedTargetGroup == null) {
      _showSnackBar('يرجى اختيار المجموعة المستهدفة');
      return;
    }

    final enteredPin = await _showPinDialog();
    if (enteredPin == null || enteredPin.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // البحث عن الـ uid الحقيقي للمستقبل بدلاً من الإيميل
      String realTargetUid = _selectedTargetId ?? '';
      if (!_isCircular && realTargetUid.isNotEmpty) {
        final userQuery = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: realTargetUid).limit(1).get();
        if (userQuery.docs.isNotEmpty) {
          realTargetUid = userQuery.docs.first.id;
        }
      }

      await _communicationService.sendCommunication(
        subject: _subjectController.text.trim(),
        bodyText: _bodyController.text.trim(),
        selectedType: _selectedType,
        selectedPriority: _selectedPriority,
        selectedTemplateId: _selectedTemplateId!,
        selectedTargetId: _isCircular ? 'group' : realTargetUid,
        selectedTargetName: _isCircular ? _getGroupName(_selectedTargetGroup!) : (_selectedTargetName ?? 'بدون اسم'),
        selectedTargetDeptId: _isCircular ? 'group' : (_selectedTargetDeptId ?? ''),
        enteredPin: enteredPin,
        securityLevel: _selectedSecurityLevel,
        attachedFiles: _selectedAttachments,
        isCircular: _isCircular,
        targetGroup: _selectedTargetGroup,
        draftId: widget.draftToEdit?.id,
        existingAttachments: _draftAttachments,
        parentCommId: widget.replyTo?.id,
        parentRefNumber: widget.replyTo?.referenceNumber,
        isExternalOutgoing: widget.isExternalReply,
      );

      if (mounted) {
        _showSnackBar('تم إرسال المخاطبة بنجاح', isError: false);
        if (widget.draftToEdit != null) {
          Navigator.pop(context, true);
        } else {
          _subjectController.clear();
          _bodyController.clear();
          _pinController.clear();
          setState(() {
            _selectedTargetId = null;
            _selectedTargetName = null;
            _selectedTargetDeptId = null;
            _selectedTargetGroup = null;
            _selectedTemplateId = null;
            _selectedType = 'outgoing';
            _selectedPriority = 'normal';
            _selectedSecurityLevel = 'normal';
            _isCircular = false;
            _selectedAttachments.clear();
          });
        }
      }
    } catch (e) {
      _showSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'jpg', 'jpeg', 'png'],
    );
    if (result != null) {
      for (var file in result.files) {
        if (file.path != null) {
          final f = File(file.path!);
          final sizeInMb = f.lengthSync() / (1024 * 1024);
          if (sizeInMb > 10) {
            _showSnackBar('الملف ${file.name} يتجاوز الحجم المسموح (10MB)', isError: true);
            continue;
          }
          setState(() {
            _selectedAttachments.add(f);
          });
        }
      }
    }
  }

  Future<String?> _showPinDialog() async {
    _pinController.clear();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الهوية'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: TextFormField(
          controller: _pinController,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'الرمز السري (PIN)', prefixIcon: Icon(Icons.password), border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(onPressed: () => Navigator.pop(context, _pinController.text.trim()), child: const Text('تأكيد')),
        ],
      ),
    );
  }

  void _showSnackBar(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: isError ? AppColors.error : AppColors.success));
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const darkBlueBg = Color(0xFF0A192F);
    const cardColor = Color(0xFF112240);

    return Scaffold(
      backgroundColor: darkBlueBg,
      appBar: AppBar(automaticallyImplyLeading: true, title: const Text('إنشاء مخاطبة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.white), centerTitle: true),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_managerNotes != null)
            Expanded(
              flex: 1,
              child: Container(
                margin: const EdgeInsets.only(right: 24, top: 24, bottom: 24, left: 12),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardColor.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3), width: 1),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.assignment_ind, color: Colors.blueAccent),
                        SizedBox(width: 8),
                        Text('توجيهات المدير', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          _managerNotes!,
                          style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          padding: const EdgeInsets.all(24),
          child: Container(
            decoration: BoxDecoration(color: cardColor.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 0.5), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)]),
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.dark(primary: Colors.blueAccent, surface: cardColor, onSurface: Colors.white),
                  inputDecorationTheme: InputDecorationTheme(
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.03),
                    labelStyle: const TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 0.5)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 0.5)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent, width: 1)),
                  ),
                  canvasColor: cardColor,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('معلومات التوجيه', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 16),
                      _buildDropdown('نوع المخاطبة', [{'value': 'outgoing', 'label': 'صادر خارجي'}, {'value': 'incoming', 'label': 'وارد خارجي'}, {'value': 'internal', 'label': 'مذكرة داخلية'}], _selectedType, (val) => setState(() => _selectedType = val!)),
                      const SizedBox(height: 16),
                      _buildDropdown('الأولوية', [{'value': 'normal', 'label': 'عادي'}, {'value': 'urgent', 'label': 'عاجل'}, {'value': 'highly_confidential', 'label': 'هام جداً'}], _selectedPriority, (val) => setState(() => _selectedPriority = val!)),
                      const SizedBox(height: 16),
                      _buildDropdown('مستوى السرية', [{'value': 'normal', 'label': 'عادي'}, {'value': 'confidential', 'label': 'سري'}, {'value': 'top_secret', 'label': 'سري للغاية'}], _selectedSecurityLevel, (val) => setState(() => _selectedSecurityLevel = val!)),
                      const SizedBox(height: 16),
                      if (!widget.isExternalReply) ...[
                        Row(
                          children: [
                            const Text('مخاطبة عادية', style: TextStyle(color: Colors.white)),
                            Switch(
                              value: _isCircular,
                              activeThumbColor: Colors.blueAccent,
                              onChanged: (val) => setState(() { _isCircular = val; }),
                            ),
                            const Text('تعميم إداري', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _isCircular ? _buildGroupsDropdown() : _buildUsersDropdown(),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(controller: _subjectController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'عنوان المخاطبة', prefixIcon: Icon(Icons.title, color: Colors.blueAccent)), validator: (v) => v == null || v.isEmpty ? 'هذا الحقل مطلوب' : null),
                      
                      const SizedBox(height: 32),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 16),
                      
                      const Text('المحتوى والقالب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 16),
                      _buildTemplatesDropdown(),
                      const SizedBox(height: 16),
                      TextFormField(controller: _bodyController, maxLines: 8, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'نص المخاطبة (سيتم إدراجه في القالب)', prefixIcon: Icon(Icons.notes, color: Colors.blueAccent)), validator: (v) => v == null || v.isEmpty ? 'هذا الحقل مطلوب' : null),
                      const SizedBox(height: 16),
                      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.withValues(alpha: 0.2))), child: const Row(children: [Icon(Icons.info_outline, color: Colors.blue), SizedBox(width: 12), Expanded(child: Text('سيتم دمج هذا النص آلياً داخل قالب الـ Word الذي قمت باختياره لإنشاء المستند الرسمي النهائي.', style: TextStyle(color: Colors.blueAccent, height: 1.5)))])),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: _pickAttachments,
                          icon: const Icon(Icons.attach_file),
                          label: const Text('إرفاق ملفات إضافية (أقصى حجم 10MB)'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
                        ),
                      ),
                      if (_selectedAttachments.isNotEmpty || _draftAttachments.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ..._draftAttachments.map((att) => Chip(
                                  label: Text(att['name'], style: const TextStyle(fontSize: 12)),
                                  backgroundColor: Colors.white12,
                                  deleteIcon: const Icon(Icons.close, size: 16),
                                  onDeleted: () => setState(() => _draftAttachments.remove(att)),
                                )),
                              ..._selectedAttachments.map((file) {
                                final fileName = file.path.split(Platform.pathSeparator).last;
                                return Chip(
                                  label: Text(fileName, style: const TextStyle(fontSize: 12)),
                                  deleteIcon: const Icon(Icons.close, size: 16),
                                  onDeleted: () => setState(() => _selectedAttachments.remove(file)),
                                  backgroundColor: Colors.white12,
                                );
                              }),
                            ],
                          ),
                        ),
                      
                      const SizedBox(height: 32),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 24),
                      
                      Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: const Row(children: [Icon(Icons.verified_user, color: Colors.blueAccent), SizedBox(width: 12), Expanded(child: Text('عند الضغط على إرسال، سيطلب منك النظام الرمز السري (PIN) كتوقيع رقمي لاعتماد هذه المخاطبة.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)))])),
                      const SizedBox(height: 24),
                      
                      PrimaryButton(
                        onPressed: _sendCommunication,
                        label: widget.draftToEdit != null ? 'اعتماد التعديل والإرسال' : 'إرسال المخاطبة',
                        icon: Icons.send,
                        isLoading: _isLoading,
                      ),
                    ],
                  ),
                ),
              ),
            ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, List<Map<String, String>> items, String value, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(value: value, decoration: InputDecoration(labelText: label), style: const TextStyle(color: Colors.white), dropdownColor: const Color(0xFF112240), items: items.map((e) => DropdownMenuItem(value: e['value'], child: Text(e['label']!))).toList(), onChanged: onChanged);
  }

  String _getGroupName(String groupId) {
    switch (groupId) {
      case 'all_university': return 'كافة منسوبي الجامعة';
      case 'all_deans': return 'كافة عمداء الكليات';
      case 'all_college': return 'كافة منسوبي الكلية';
      case 'college_management': return 'نواب العميد ورؤساء الأقسام بالكلية';
      case 'all_department': return 'كافة منسوبي القسم';
      default: return 'مجموعة غير معروفة';
    }
  }

  Widget _buildGroupsDropdown() {
    if (_currentUserData == null) return const Center(child: CircularProgressIndicator());
    final title = _currentUserData!['administrative_title'] ?? 'staff';
    final effectiveTitle = title == 'secretary' ? (_currentUserData!['manager_title'] ?? 'staff') : title;
    
    List<Map<String, String>> groups = [];

    if (effectiveTitle == 'university_president') {
      groups = [
        {'value': 'all_university', 'label': 'كافة منسوبي الجامعة'},
        {'value': 'all_deans', 'label': 'كافة عمداء الكليات'},
        {'value': 'all_college', 'label': 'كلية محددة (سيتم إضافة الميزة لاحقاً)'},
      ];
    } else if (effectiveTitle == 'dean') {
      groups = [
        {'value': 'all_college', 'label': 'كافة منسوبي الكلية'},
        {'value': 'college_management', 'label': 'نواب العميد ورؤساء الأقسام'},
      ];
    } else if (effectiveTitle == 'vice_dean') {
      groups = [
        {'value': 'all_college', 'label': 'كافة منسوبي الكلية'},
        {'value': 'college_management', 'label': 'رؤساء الأقسام بالكلية'},
      ];
    } else if (effectiveTitle == 'head_of_department') {
      groups = [
        {'value': 'all_department', 'label': 'كافة منسوبي القسم'},
      ];
    } else {
      // Staff cannot send circulars usually, but just in case
      groups = [];
    }

    if (groups.isEmpty) {
      return const Text('عذراً، لا تملك صلاحية إصدار تعاميم', style: TextStyle(color: Colors.redAccent));
    }

    return DropdownButtonFormField<String>(
      value: groups.any((g) => g['value'] == _selectedTargetGroup) ? _selectedTargetGroup : null,
      decoration: const InputDecoration(labelText: 'المجموعة المستهدفة', prefixIcon: Icon(Icons.groups, color: Colors.blueAccent)),
      style: const TextStyle(color: Colors.white),
      dropdownColor: const Color(0xFF112240),
      items: groups.map((g) => DropdownMenuItem(value: g['value'], child: Text(g['label']!))).toList(),
      onChanged: (val) => setState(() => _selectedTargetGroup = val),
    );
  }

  Widget _buildUsersDropdown() {
    return FutureBuilder<List<DocumentSnapshot>>(
      future: _usersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final availableDocs = snapshot.data ?? [];
        return DropdownButtonFormField<String>(
          value: availableDocs.any((d) => d.id == _selectedTargetId) ? _selectedTargetId : null,
          decoration: const InputDecoration(labelText: 'المستقبل', prefixIcon: Icon(Icons.person_search, color: Colors.blueAccent)),
          style: const TextStyle(color: Colors.white),
          dropdownColor: const Color(0xFF112240),
          items: availableDocs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return DropdownMenuItem(value: doc.id, child: Text("${data['full_name']} (${data['dept_id']})"));
          }).toList(),
          onChanged: (val) {
            if (val == null) return;
            final doc = availableDocs.firstWhere((d) => d.id == val);
            final data = doc.data() as Map<String, dynamic>;
            setState(() { _selectedTargetId = val; _selectedTargetName = data['full_name']; _selectedTargetDeptId = data['dept_id']; });
          },
        );
      },
    );
  }

  Widget _buildTemplatesDropdown() {
    return FutureBuilder<QuerySnapshot>(
      future: _templatesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data?.docs ?? [];
        return DropdownButtonFormField<String>(
          value: docs.any((d) => d.id == _selectedTemplateId) ? _selectedTemplateId : null,
          decoration: const InputDecoration(labelText: 'قالب الكليشة', prefixIcon: Icon(Icons.description_outlined, color: Colors.blueAccent)),
          style: const TextStyle(color: Colors.white),
          dropdownColor: const Color(0xFF112240),
          items: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return DropdownMenuItem(value: doc.id, child: Text(data['template_name'] ?? 'قالب بدون اسم'));
          }).toList(),
          onChanged: (val) => setState(() => _selectedTemplateId = val),
        );
      },
    );
  }
}