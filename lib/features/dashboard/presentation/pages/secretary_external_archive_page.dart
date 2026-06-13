import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/services/archive_service.dart';
import '../../../../core/services/template_service.dart';
import '../../../../core/services/ai_service.dart';

class SecretaryExternalArchivePage extends StatefulWidget {
  const SecretaryExternalArchivePage({super.key});

  @override
  State<SecretaryExternalArchivePage> createState() => _SecretaryExternalArchivePageState();
}

class _SecretaryExternalArchivePageState extends State<SecretaryExternalArchivePage> {
  final _formKey = GlobalKey<FormState>();
  final _refController = TextEditingController();
  final _subjectController = TextEditingController();
  final _senderNameController = TextEditingController();
  final _dateController = TextEditingController();

  String? _selectedTargetId;
  String? _selectedTargetName;
  String? _selectedTargetDeptId;
  String? _selectedTargetCollegeId;

  PlatformFile? _selectedFile;
  bool _isLoading = false;
  bool _isExtracting = false;

  // الحقول التي تم تعبئتها بواسطة الذكاء الاصطناعي لتمييزها باللون الذهبي
  Set<String> _aiExtractedFields = {};

  final ArchiveService _archiveService = ArchiveService();
  final TemplateService _templateService = TemplateService();
  final AiService _aiService = AiService();

  @override
  void initState() {
    super.initState();
    _loadManagerDetails();
  }

  Future<void> _loadManagerDetails() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = userDoc.data();
      if (data != null && data['manager_id'] != null) {
        final managerId = data['manager_id'];
        final managerDoc = await FirebaseFirestore.instance.collection('users').doc(managerId).get();
        if (managerDoc.exists) {
          final mData = managerDoc.data()!;
          if (mounted) {
            setState(() {
              _selectedTargetId = managerId;
              _selectedTargetName = mData['full_name'];
              _selectedTargetDeptId = mData['dept_id'];
              _selectedTargetCollegeId = mData['college_id'];
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading manager: $e');
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFile = result.files.first;
        _aiExtractedFields.clear(); // مسح تمييز الحقول عند اختيار ملف جديد
      });
    }
  }

  bool _isSupportedForAi() {
    if (_selectedFile == null) return false;
    final extension = _selectedFile!.name.split('.').last.toLowerCase();
    return extension == 'pdf' || extension == 'jpg' || extension == 'jpeg' || extension == 'png';
  }

  Future<void> _extractMetadataWithAi() async {
    if (_selectedFile == null) return;

    setState(() {
      _isExtracting = true;
    });

    try {
      final result = await _aiService.extractDocumentMetadata(_selectedFile!);
      if (result != null) {
        setState(() {
          _subjectController.text = result['subject'] ?? '';
          _senderNameController.text = result['senderName'] ?? '';
          _refController.text = result['referenceNumber'] ?? '';
          _dateController.text = result['date'] ?? '';
          _aiExtractedFields = {'subject', 'senderName', 'referenceNumber', 'date'};
        });
        _showSnackBar('تم قراءة المستند واستخلاص البيانات بنجاح! يرجى مراجعة الحقول المظللة بالذهبي للتأكد.', isError: false);
      }
    } catch (e) {
      _showSnackBar(e.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isExtracting = false;
        });
      }
    }
  }

  Future<void> _submitExternalArchive() async {
    if (!_formKey.currentState!.validate() || _selectedTargetId == null) {
      _showSnackBar('الرجاء إكمال جميع الحقول واختيار الجهة المستقبلة');
      return;
    }

    if (_selectedFile == null) {
      _showSnackBar('الرجاء إرفاق الوثيقة (Scan)');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. رفع الملف
      final fileUrl = await _templateService.uploadFile(_selectedFile!, 'communications/external_archives');
      if (fileUrl == null) {
        throw 'فشل في رفع الوثيقة المرفقة.';
      }

      // 2. تحديد دولاب "الوارد" للمستقبل
      String entityId = _selectedTargetDeptId ?? '';
      String entityType = 'department';
      if (entityId.isEmpty) {
        entityId = _selectedTargetCollegeId ?? '';
        entityType = 'college';
      }

      if (entityId.isEmpty) {
        throw 'المستقبل المختار لا ينتمي لكلية أو قسم صالح للأرشفة.';
      }

      // التأكد من وجود ملف الوارد الخارجي وإحضار معرّفه
      await _archiveService.ensureDefaultFoldersExist(entityId: entityId, entityType: entityType);
      final receiverFolderId = await _archiveService.getExternalIncomingFolderId(entityId);

      if (receiverFolderId == null) {
        throw 'لم يتم العثور على ملف الوارد الخارجي للمستقبل.';
      }

      // توليد رقم وارد داخلي آلياً للمستقبل
      final internalRefNumber = await _archiveService.generateReferenceNumber(
        folderId: receiverFolderId,
        entityCode: 'و خ', // وارد خارجي
      );

      // 3. حفظ المخاطبة في قاعدة البيانات بحالة "مؤرشفة" لتصل للعميد جاهزة

      final commRef = FirebaseFirestore.instance.collection('communications').doc();
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await commRef.set({
        'comm_id': commRef.id,
        'sender_id': uid,
        'type': 'incoming', // وارد خارجي
        'is_external': true,
        'subject': _subjectController.text.trim(),
        'reference_number': internalRefNumber,
        'external_reference_number': _refController.text.trim(),
        'sender_name': _senderNameController.text.trim(),
        'document_date': _dateController.text.trim(), // حفظ تاريخ الخطاب المستخلص
        'target_id': _selectedTargetId,
        'target_name': _selectedTargetName,
        'current_rcv_id': _selectedTargetId, // يتوجه للعميد/المسؤول
        'current_dept_id': _selectedTargetDeptId,
        'receiver_archive_folder_id': receiverFolderId,
        'generated_docx_url': fileUrl,
        'status': 'archived', // مؤرشفة مسبقاً من السكرتير
        'is_read_by_dean': false,
        'archived_at': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
        'last_action_at': FieldValue.serverTimestamp(),
      });

      // حفظ في التتبع
      await commRef.collection('tracking').add({
        'action': 'external_archive',
        'from_id': uid, // مطلوب في صلاحيات قواعد البيانات
        'from_name': 'النظام (أرشفة السكرتارية)',
        'to_name': _selectedTargetName,
        'to_status': 'archived',
        'timestamp': FieldValue.serverTimestamp(),
        'comment': 'تمت أرشفة معاملة خارجية وتقييدها بالرقم ($internalRefNumber) وتوجيهها للمسؤول',
      });

      if (mounted) {
        _showSnackBar('تم أرشفة الوثيقة وتوجيهها للمستقبل بنجاح!', isError: false);
        _refController.clear();
        _subjectController.clear();
        _senderNameController.clear();
        _dateController.clear();
        setState(() {
          _selectedFile = null;
          _aiExtractedFields.clear();
        });
      }
    } catch (e) {
      _showSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, textDirection: TextDirection.rtl),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _refController.dispose();
    _subjectController.dispose();
    _senderNameController.dispose();
    _dateController.dispose();
    super.dispose();
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
              // Header
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
                          Text('العودة', style: TextStyle(color: Colors.white54, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'أرشفة وارد خارجي ذكي',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'ارفع المعاملات الواردة، ودع الذكاء الاصطناعي يستخلص البيانات ويملأ النموذج تلقائياً.',
                style: TextStyle(fontSize: 16, color: Colors.white54),
              ),
              const SizedBox(height: 32),

              // Main Responsive Layout
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWideScreen = constraints.maxWidth > 950;
                    
                    if (_selectedFile != null && isWideScreen) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // الجانب الأيمن: عارض المستندات التفاعلي
                          Expanded(
                            flex: 5,
                            child: _buildDocumentViewer(),
                          ),
                          const SizedBox(width: 32),
                          // الجانب الأيسر: النموذج الإداري
                          Expanded(
                            flex: 5,
                            child: SingleChildScrollView(
                              child: _buildFormCard(surfaceColor),
                            ),
                          ),
                        ],
                      );
                    } else {
                      // في الشاشات الصغيرة أو في حال عدم رفع أي ملف بعد
                      return SingleChildScrollView(
                        child: Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 800),
                            child: Column(
                              children: [
                                if (_selectedFile != null) ...[
                                  Container(
                                    height: 500,
                                    margin: const EdgeInsets.only(bottom: 24),
                                    child: _buildDocumentViewer(),
                                  ),
                                ],
                                _buildFormCard(surfaceColor),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // عارض المستندات
  Widget _buildDocumentViewer() {
    if (_selectedFile == null) return const SizedBox.shrink();
    final extension = _selectedFile!.name.split('.').last.toLowerCase();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF112240),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // شريط معلومات عارض المستند
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.black12,
            child: Row(
              children: [
                Icon(
                  extension == 'pdf' ? Icons.picture_as_pdf : Icons.image,
                  color: extension == 'pdf' ? Colors.redAccent : Colors.blueAccent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedFile!.name,
                    style: const TextStyle(color: Colors.white70, fontSize: 14, overflow: TextOverflow.ellipsis),
                  ),
                ),
                // زر حذف الملف لإعادة الرفع
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                  onPressed: () {
                    setState(() {
                      _selectedFile = null;
                      _aiExtractedFields.clear();
                    });
                  },
                  tooltip: 'إزالة الملف',
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildViewerContent(extension),
          ),
        ],
      ),
    );
  }

  Widget _buildViewerContent(String extension) {
    if (extension == 'pdf') {
      return SfPdfViewer.file(
        File(_selectedFile!.path!),
        canShowScrollHead: true,
        canShowScrollStatus: true,
      );
    } else if (extension == 'jpg' || extension == 'jpeg' || extension == 'png') {
      return InteractiveViewer(
        maxScale: 4.0,
        child: Center(
          child: Image.file(
            File(_selectedFile!.path!),
            fit: BoxFit.contain,
          ),
        ),
      );
    } else {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.insert_drive_file, size: 48, color: Colors.white30),
              const SizedBox(height: 16),
              Text(
                'الملف المختار بصيغة ($extension).\nمعاينة الملفات مدعومة فقط لملفات PDF والصور (JPG/PNG).',
                style: const TextStyle(color: Colors.white54, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
  }

  // كرت النموذج الإدخالي
  Widget _buildFormCard(Color surfaceColor) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // زر الاستخلاص بالذكاء الاصطناعي (يظهر فقط إذا كان نوع الملف مدعوماً)
            if (_selectedFile != null) ...[
              if (_isSupportedForAi()) ...[
                _buildAiExtractButton(),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'الملفات من نوع Word لا تدعم الاستخلاص التلقائي. يرجى تحويل الملف إلى PDF للحصول على القراءة الذكية.',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      )
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const Divider(color: Colors.white10),
              const SizedBox(height: 24),
            ],

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildFormField(
                    controller: _refController,
                    fieldName: 'referenceNumber',
                    labelText: 'المرجع الخارجي (مثال: و ت/123)',
                    prefixIcon: Icons.numbers,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildFormField(
                    controller: _dateController,
                    fieldName: 'date',
                    labelText: 'تاريخ الخطاب (YYYY-MM-DD)',
                    prefixIcon: Icons.calendar_today,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildFormField(
              controller: _senderNameController,
              fieldName: 'senderName',
              labelText: 'الجهة الوارد منها (مثال: وزارة التعليم العالي)',
              prefixIcon: Icons.account_balance,
            ),
            const SizedBox(height: 24),
            _buildFormField(
              controller: _subjectController,
              fieldName: 'subject',
              labelText: 'موضوع الخطاب',
              prefixIcon: Icons.subject,
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            if (_selectedTargetName != null) ...[
              const Text('الجهة المستقبلة داخل الجامعة (مديرك المباشر)', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: Colors.blueAccent),
                    const SizedBox(width: 12),
                    Text(_selectedTargetName!, style: const TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],

            // File Uploader (يظهر فقط في حال لم يتم اختيار ملف بعد)
            if (_selectedFile == null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.02),
                  border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3), style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(Icons.upload_file, size: 48, color: Colors.white.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    const Text(
                      'الرجاء إرفاق الخطاب (PDF/صورة)',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('تصفح الملفات'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blueAccent,
                        side: const BorderSide(color: Colors.blueAccent),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],

            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                onPressed: _isLoading || _isExtracting ? () {} : _submitExternalArchive,
                label: 'أرشفة الخطاب وتوجيهه',
                icon: Icons.archive,
                isLoading: _isLoading,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // بناء حقل إدخال مخصص مع إضاءة ذهبية عند استخراجه بواسطة الذكاء الاصطناعي
  Widget _buildFormField({
    required TextEditingController controller,
    required String fieldName,
    required String labelText,
    required IconData prefixIcon,
    int maxLines = 1,
  }) {
    final isExtracted = _aiExtractedFields.contains(fieldName);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: isExtracted
            ? [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.12),
                  blurRadius: 8,
                  spreadRadius: 1,
                )
              ]
            : [],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        onChanged: (val) {
          // إزالة التظليل عند تعديل المحتوى يدوياً بواسطة المستخدم
          if (_aiExtractedFields.contains(fieldName)) {
            setState(() {
              _aiExtractedFields.remove(fieldName);
            });
          }
        },
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'هذا الحقل مطلوب';
          }
          return null;
        },
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(
            color: isExtracted ? Colors.amberAccent : Colors.white70,
            fontWeight: isExtracted ? FontWeight.bold : FontWeight.normal,
          ),
          prefixIcon: Icon(
            prefixIcon,
            color: isExtracted ? Colors.amber : Colors.white70,
          ),
          filled: true,
          fillColor: isExtracted ? Colors.amber.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isExtracted ? Colors.amber.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.1),
              width: isExtracted ? 1.5 : 1.0,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isExtracted ? Colors.amber : Colors.blueAccent,
              width: 2.0,
            ),
          ),
        ),
      ),
    );
  }

  // زر القراءة بالذكاء الاصطناعي
  Widget _buildAiExtractButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.shade700,
            Colors.orange.shade600,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isExtracting ? null : _extractMetadataWithAi,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isExtracting) ...[
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'جاري تحليل المستند بالذكاء الاصطناعي...',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ] else ...[
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  const Text(
                    'استخلاص البيانات آلياً بالذكاء الاصطناعي (AI)',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

