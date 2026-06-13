import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../services/excel_service.dart';

class AdminUploadPage extends StatefulWidget {
  const AdminUploadPage({super.key});

  @override
  State<AdminUploadPage> createState() => _AdminUploadPageState();
}

class _AdminUploadPageState extends State<AdminUploadPage> {
  final ExcelService _excelService = ExcelService();
  
  String _statusMessage = 'جاهز لرفع البيانات';
  bool _isUploading = false;
  bool _uploadSuccess = false;
  bool _isHoveringDropzone = false;
  bool _isDragging = false;
  bool _isLeadershipFile = false; // Add state for file type

  String? _selectedFilePath;
  String? _selectedFileName;
  String? _selectedFileSize;
  
  double _progressValue = 0.0;
  Timer? _progressTimer;

  int _totalColleges = 0;
  int _totalDepartments = 0;
  int _totalUsers = 0;
  DateTime? _lastUpdateDate;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final db = FirebaseFirestore.instance;
      
      final collegesSnap = await db.collection('colleges').get();
      final deptsSnap = await db.collection('departments').get();
      final usersSnap = await db.collection('allowed_users').get();

      DateTime? lastUpdate;
      if (collegesSnap.docs.isNotEmpty) {
        for (var doc in collegesSnap.docs) {
          final data = doc.data();
          if (data['updated_at'] != null) {
            final dt = (data['updated_at'] as Timestamp).toDate();
            if (lastUpdate == null || dt.isAfter(lastUpdate)) {
              lastUpdate = dt;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _totalColleges = collegesSnap.docs.length;
          _totalDepartments = deptsSnap.docs.length;
          _totalUsers = usersSnap.docs.length;
          _lastUpdateDate = lastUpdate;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (bytes.toString().length - 1) ~/ 3;
    return "${(bytes / (1024 * (i > 0 ? i : 1))).toStringAsFixed(1)} ${suffixes[i]}";
  }

  void _handleFile(String path, String name) {
    final file = File(path);
    if (!file.existsSync()) return;

    final length = file.lengthSync();
    
    // Validation: Check Extension
    if (!name.toLowerCase().endsWith('.xlsx') && !name.toLowerCase().endsWith('.csv')) {
      _showErrorSnackBar('صيغة الملف غير مدعومة. يرجى رفع ملف Excel (.xlsx) أو ملف نصي (.csv) فقط.');
      return;
    }

    // Validation: Check Size (Max 10MB)
    if (length > 10 * 1024 * 1024) {
      _showErrorSnackBar('حجم الملف كبير جداً. الحد الأقصى هو 10 ميجابايت.');
      return;
    }

    setState(() {
      _selectedFilePath = path;
      _selectedFileName = name;
      _selectedFileSize = _formatFileSize(length);
      _statusMessage = 'تم التحقق من الملف بنجاح. جاهز للرفع.';
      _uploadSuccess = false;
      _isUploading = false;
      _progressValue = 0.0;
    });
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv'],
    );

    if (result != null && result.files.single.path != null) {
      _handleFile(result.files.single.path!, result.files.single.name);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Text(message, style: const TextStyle(color: Colors.white)),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      )
    );
  }

  Future<void> _confirmAndStartUpload() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF112240),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
            SizedBox(width: 8),
            Text('تأكيد التحديث', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          _isLeadershipFile 
            ? 'سيتم استيراد القيادات والمناصب وتحديث الصلاحيات للمراكز والكليات بناءً على الملف.\n\nهل تريد المتابعة؟'
            : 'سيتم تحديث بيانات الجامعة الحالية (الكليات، الأقسام، والمستخدمين) واستبدالها بالبيانات الجديدة.\n\nهل تريد المتابعة حقاً؟',
          style: const TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black, elevation: 0),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('نعم، تحديث البيانات', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _startUpload();
    }
  }

  void _startFakeProgress() {
    _progressValue = 0.0;
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_progressValue < 0.85) {
          _progressValue += 0.05;
        }
      });
    });
  }

  Future<void> _startUpload() async {
    if (_selectedFilePath == null) return;

    setState(() {
      _isUploading = true;
      _statusMessage = 'جاري التهيئة ومعالجة الملف...';
      _uploadSuccess = false;
    });

    _startFakeProgress();

    // Small delay for UX
    await Future.delayed(const Duration(milliseconds: 800));

    try {
      if (_isLeadershipFile) {
        await _excelService.importLeadershipExcel(
          filePath: _selectedFilePath!,
          onProgress: (String message) {
            if (mounted) {
              setState(() {
                _statusMessage = message;
              });
            }
          },
        );
      } else {
        await _excelService.uploadExcelFile(
          filePath: _selectedFilePath!,
          onProgress: (String message) {
            if (mounted) {
              setState(() {
                _statusMessage = message;
              });
            }
          },
        );
      }

      _progressTimer?.cancel();

      if (mounted) {
        setState(() {
          _progressValue = 1.0;
          _isUploading = false;
          _uploadSuccess = true;
          _statusMessage = 'تم تحديث قاعدة البيانات بنجاح!';
        });
      }
    } catch (e) {
      _progressTimer?.cancel();
      if (mounted) {
        setState(() {
          _isUploading = false;
          _statusMessage = 'حدث خطأ غير متوقع أثناء الرفع.';
        });
        _showErrorSnackBar('خطأ تقني: $e');
      }
    }
  }

  Future<void> _startCleanDuplicates() async {
    setState(() {
      _isUploading = true;
      _statusMessage = 'جاري بدء عملية التنظيف...';
      _uploadSuccess = false;
    });

    _startFakeProgress();

    try {
      await _excelService.cleanDuplicates((message) {
        if (mounted) {
          setState(() {
            _statusMessage = message;
          });
        }
      });

      _progressTimer?.cancel();

      if (mounted) {
        setState(() {
          _progressValue = 1.0;
          _isUploading = false;
          _uploadSuccess = true;
        });
      }
    } catch (e) {
      _progressTimer?.cancel();
      if (mounted) {
        setState(() {
          _isUploading = false;
          _statusMessage = 'حدث خطأ غير متوقع أثناء التنظيف.';
        });
        _showErrorSnackBar('خطأ تقني: $e');
      }
    }
  }

  void _reset() {
    setState(() {
      _selectedFilePath = null;
      _selectedFileName = null;
      _selectedFileSize = null;
      _isUploading = false;
      _uploadSuccess = false;
      _progressValue = 0.0;
      _statusMessage = 'جاهز لرفع البيانات';
    });
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
              // Navigation Header (Lighter visually)
              const Text(
                'تحديث السجلات',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              
              const SizedBox(height: 40),

              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main Upload Area
                    Expanded(
                      flex: 2,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          const Text(
                            'تحديث قاعدة البيانات المركزية',
                            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isLeadershipFile 
                              ? 'قم برفع ملف (القيادات العليا والعمداء) لتعيين المناصب والصلاحيات وإنشاء المراكز المستقلة.'
                              : 'قم برفع ملف Excel (الهيكل والأكاديميين) لتحديث بيانات كليات وأقسام وأعضاء هيئة التدريس بالجامعة.',
                            style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              ChoiceChip(
                                label: const Text('الملف 1: الهيكل والأكاديميين'),
                                selected: !_isLeadershipFile,
                                onSelected: (val) {
                                  if (val) setState(() { _isLeadershipFile = false; _reset(); });
                                },
                                selectedColor: Colors.purpleAccent.withValues(alpha: 0.2),
                                labelStyle: TextStyle(color: !_isLeadershipFile ? Colors.purpleAccent : Colors.white70, fontWeight: FontWeight.bold),
                                backgroundColor: surfaceColor,
                              ),
                              const SizedBox(width: 16),
                              ChoiceChip(
                                label: const Text('الملف 2: القيادات والمناصب'),
                                selected: _isLeadershipFile,
                                onSelected: (val) {
                                  if (val) setState(() { _isLeadershipFile = true; _reset(); });
                                },
                                selectedColor: Colors.orangeAccent.withValues(alpha: 0.2),
                                labelStyle: TextStyle(color: _isLeadershipFile ? Colors.orangeAccent : Colors.white70, fontWeight: FontWeight.bold),
                                backgroundColor: surfaceColor,
                              ),
                              const Spacer(),
                              ElevatedButton.icon(
                                onPressed: _isUploading ? null : _startCleanDuplicates,
                                icon: const Icon(Icons.cleaning_services, size: 18),
                                label: const Text('تنظيف الحسابات المكررة', style: TextStyle(fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                                  foregroundColor: Colors.redAccent,
                                  elevation: 0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          
                          // DropTarget Widget (Native Drag & Drop)
                          DropTarget(
                            onDragDone: (detail) {
                              if (_isUploading) return;
                              setState(() => _isDragging = false);
                              if (detail.files.isNotEmpty) {
                                _handleFile(detail.files.first.path, detail.files.first.name);
                              }
                            },
                            onDragEntered: (detail) => setState(() => _isDragging = true),
                            onDragExited: (detail) => setState(() => _isDragging = false),
                            child: MouseRegion(
                              onEnter: (_) => setState(() => _isHoveringDropzone = true),
                              onExit: (_) => setState(() => _isHoveringDropzone = false),
                              child: GestureDetector(
                                onTap: _isUploading ? null : _pickFile,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
                                  decoration: BoxDecoration(
                                    color: _isDragging 
                                        ? Colors.blueAccent.withValues(alpha: 0.1) 
                                        : (_isHoveringDropzone ? Colors.purpleAccent.withValues(alpha: 0.05) : surfaceColor.withValues(alpha: 0.5)),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: _isDragging 
                                          ? Colors.blueAccent 
                                          : (_isHoveringDropzone ? Colors.purpleAccent : Colors.white.withValues(alpha: 0.15)),
                                      width: _isDragging ? 3 : 2,
                                    ),
                                    boxShadow: _isDragging 
                                        ? [BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 5)] 
                                        : [],
                                  ),
                                  child: Center(
                                    child: _isDragging
                                        ? _buildDraggingState()
                                        : (_selectedFileName == null ? _buildEmptyState() : _buildSelectedState()),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 24),

                          // Feedback and Progress Section
                          if (_isUploading || _uploadSuccess || _statusMessage != 'جاهز لرفع البيانات')
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: _uploadSuccess ? Colors.greenAccent.withValues(alpha: 0.05) : surfaceColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _uploadSuccess ? Colors.green.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (_uploadSuccess)
                                        const Icon(Icons.check_circle, color: Colors.greenAccent, size: 28)
                                      else if (_isUploading)
                                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.purpleAccent, strokeWidth: 2))
                                      else
                                        const Icon(Icons.info_outline, color: Colors.blueAccent, size: 28),
                                        
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          _statusMessage,
                                          style: TextStyle(color: _uploadSuccess ? Colors.greenAccent : Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      if (_isUploading)
                                        Text(
                                          '${(_progressValue * 100).toInt()}%',
                                          style: const TextStyle(color: Colors.purpleAccent, fontSize: 16, fontWeight: FontWeight.bold),
                                        )
                                    ],
                                  ),
                                  if (_isUploading || _uploadSuccess) ...[
                                    const SizedBox(height: 20),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: _progressValue,
                                        backgroundColor: const Color(0xFF0A192F),
                                        color: _uploadSuccess ? Colors.greenAccent : Colors.purpleAccent,
                                        minHeight: 8,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            
                          const SizedBox(height: 24),
                          
                          // Action Buttons
                          if (_selectedFileName != null && !_uploadSuccess)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: _isUploading ? null : _reset,
                                  child: const Text('إلغاء', style: TextStyle(color: Colors.white54, fontSize: 16)),
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton.icon(
                                  onPressed: _isUploading ? null : _confirmAndStartUpload,
                                  icon: const Icon(Icons.cloud_upload, color: Colors.white),
                                  label: const Text('تأكيد الرفع الآن', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purpleAccent,
                                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    disabledBackgroundColor: Colors.purpleAccent.withValues(alpha: 0.3),
                                  ),
                                ),
                              ],
                            ),
                          
                          if (_uploadSuccess)
                             Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _reset,
                                  icon: const Icon(Icons.refresh, color: Colors.white),
                                  label: const Text('تحديث ملف آخر', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: surfaceColor,
                                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                     ),
                    ),
                    const SizedBox(width: 60),
                    
                    // Right Side: Context / Info Area
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'سجل التحديثات',
                            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Container(
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
                                    Icon(Icons.history, color: Colors.blueAccent),
                                    SizedBox(width: 12),
                                    Text('آخر عملية رفع', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const Divider(color: Colors.white10, height: 32),
                                _buildInfoRow('تاريخ التحديث:', _lastUpdateDate != null ? '${_lastUpdateDate!.year}/${_lastUpdateDate!.month}/${_lastUpdateDate!.day}' : 'غير متوفر'),
                                const SizedBox(height: 16),
                                _buildInfoRow('بواسطة:', 'مدير النظام (أنت)'),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
                                  ),
                                  child: _isLoadingStats 
                                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                                    : Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Row(
                                            children: [
                                              Icon(Icons.analytics_outlined, color: Colors.blueAccent, size: 20),
                                              SizedBox(width: 8),
                                              Text('إحصائيات النظام الحالية', style: TextStyle(color: Colors.blueAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Text('• $_totalColleges كلية مسجلة', style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.8)),
                                          Text('• $_totalDepartments قسم مفعل', style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.8)),
                                          Text('• $_totalUsers مستخدم مسجل', style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.8)),
                                        ],
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDraggingState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.download_rounded,
          size: 80,
          color: Colors.blueAccent.withValues(alpha: 0.8),
        ),
        const SizedBox(height: 24),
        const Text(
          'أفلت الملف هنا...',
          style: TextStyle(color: Colors.blueAccent, fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.cloud_upload_outlined,
          size: 64,
          color: _isHoveringDropzone ? Colors.purpleAccent : Colors.white54,
        ),
        const SizedBox(height: 16),
        const Text(
          'اسحب الملف وأفلته هنا',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('أو ', style: TextStyle(color: Colors.white54, fontSize: 16)),
            Text('تصفح ملفاتك', style: TextStyle(color: Colors.purpleAccent.shade200, fontSize: 16, fontWeight: FontWeight.bold, decoration: TextDecoration.underline, decorationColor: Colors.purpleAccent.shade200)),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectedState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.greenAccent.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.insert_drive_file, size: 48, color: Colors.greenAccent),
        ),
        const SizedBox(height: 24),
        Text(
          _selectedFileName!,
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(_selectedFileSize ?? 'Unknown', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: const Text('حوالي 248 سجل للتحديث', style: TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        if (!_isUploading && !_uploadSuccess) ...[
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.sync, size: 18),
            label: const Text('تغيير الملف', style: TextStyle(fontSize: 15)),
            style: TextButton.styleFrom(foregroundColor: Colors.white70),
          )
        ]
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14))),
        Expanded(
          child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}
