import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_colors.dart';

class InquiryPage extends StatefulWidget {
  const InquiryPage({super.key});

  @override
  State<InquiryPage> createState() => _InquiryPageState();
}

class _InquiryPageState extends State<InquiryPage> {
  final _idController = TextEditingController();
  final _hashController = TextEditingController();
  
  bool _isLoading = false;
  Map<String, dynamic>? _result;
  String? _errorMessage;
  bool _hasInitializedFromRoute = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasInitializedFromRoute) {
      _hasInitializedFromRoute = true;
      final route = ModalRoute.of(context);
      if (route != null && route.settings.name != null) {
        final name = route.settings.name!;
        if (name.contains('verify?')) {
          final uri = Uri.tryParse('https://dummy.com$name'); // Parse the path and query string
          if (uri != null && uri.queryParameters.containsKey('id')) {
            _idController.text = uri.queryParameters['id']!;
            if (uri.queryParameters.containsKey('hash')) {
              _hashController.text = uri.queryParameters['hash']!;
            }
            // Auto-trigger verification if ID is provided via URL
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _verifyDocument();
            });
          }
        }
      }
    }
  }

  Future<void> _verifyDocument() async {
    final docId = _idController.text.trim();
    final hash = _hashController.text.trim();

    if (docId.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال رقم المعاملة');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final docSnapshot = await FirebaseFirestore.instance.collection('communications').doc(docId).get();
      
      if (!docSnapshot.exists) {
        setState(() => _errorMessage = 'المعاملة غير موجودة أو رقم المعاملة غير صحيح');
        return;
      }

      final data = docSnapshot.data()!;
      
      // Verify the hash
      final documentHash = data['digital_signature'] ?? 'legacy_$docId';
      
      if (hash.isNotEmpty && hash != documentHash) {
        setState(() => _errorMessage = 'رمز التحقق غير صحيح. قد تكون هذه الوثيقة مزورة!');
        return;
      }

      // If hash is empty but doc exists, we show basic info, but warn about hash
      // If hash matches, show full verification success
      setState(() {
        _result = data;
        if (hash.isNotEmpty && hash == documentHash) {
          _result!['is_verified'] = true;
        } else {
          _result!['is_verified'] = false;
        }
      });

    } catch (e) {
      setState(() => _errorMessage = 'حدث خطأ أثناء الاتصال بقاعدة البيانات');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _parseUrl(String text) {
    if (text.contains('verify?id=')) {
      final uri = Uri.tryParse(text);
      if (uri != null && uri.queryParameters.containsKey('id')) {
        _idController.text = uri.queryParameters['id']!;
        if (uri.queryParameters.containsKey('hash')) {
          _hashController.text = uri.queryParameters['hash']!;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('استعلام عن معاملة', style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: AppColors.surface,
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.qr_code_scanner, color: AppColors.primary, size: 32),
                    SizedBox(width: 16),
                    Text(
                      'التحقق من صحة وثيقة',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'أدخل رقم المعاملة ورمز التحقق (أو قم بلصق رابط الباركود كاملاً في أي من الحقلين) للتأكد من موثوقية الخطاب وصحته.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _idController,
                  onChanged: _parseUrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'رقم المعاملة (Document ID) أو الرابط',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _hashController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'رمز التحقق (Security Hash) - اختياري',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _verifyDocument,
                    icon: const Icon(Icons.search),
                    label: const Text('تحقق من الوثيقة'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  ),
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(top: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.danger),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.danger),
                        const SizedBox(width: 16),
                        Expanded(child: Text(_errorMessage!, style: const TextStyle(color: AppColors.danger))),
                      ],
                    ),
                  ),
                if (_result != null)
                  _buildResultCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    final bool isVerified = _result!['is_verified'] ?? false;
    final senderName = _result!['sender_name'] ?? 'غير معروف';
    final subject = _result!['subject'] ?? 'بدون موضوع';
    final timestamp = _result!['timestamp'] as Timestamp?;
    final dateStr = timestamp != null ? DateFormat('yyyy/MM/dd HH:mm').format(timestamp.toDate()) : 'غير محدد';
    final status = _result!['status'] ?? '';
    
    return Container(
      margin: const EdgeInsets.only(top: 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isVerified ? AppColors.success.withValues(alpha: 0.1) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isVerified ? AppColors.success : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isVerified ? Icons.verified : Icons.info_outline,
                color: isVerified ? AppColors.success : AppColors.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                isVerified ? 'وثيقة رسمية وموثقة' : 'بيانات الوثيقة',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isVerified ? AppColors.success : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          if (isVerified) ...[
            const SizedBox(height: 8),
            const Text(
              'تم التحقق بنجاح من التوقيع الرقمي لهذه الوثيقة.',
              style: TextStyle(color: AppColors.success),
            ),
          ],
          const Divider(height: 32, color: AppColors.border),
          _buildDetailRow('الموضوع:', subject),
          const SizedBox(height: 12),
          _buildDetailRow('الجهة المرسلة:', senderName),
          const SizedBox(height: 12),
          _buildDetailRow('تاريخ الإنشاء:', dateStr),
          const SizedBox(height: 12),
          _buildDetailRow('الحالة:', _translateStatus(status)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(color: AppColors.textPrimary)),
        ),
      ],
    );
  }

  String _translateStatus(String status) {
    switch (status) {
      case 'sent': return 'مُرسلة';
      case 'read': return 'مقروءة';
      case 'archived': return 'مؤرشفة';
      case 'draft': return 'مسودة';
      case 'returned': return 'معادة للجهة المرسلة';
      default: return status;
    }
  }
}
