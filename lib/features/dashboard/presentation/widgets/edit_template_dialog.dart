import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/services/template_service.dart';

class EditTemplateDialog extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const EditTemplateDialog({super.key, required this.docId, required this.data});

  @override
  State<EditTemplateDialog> createState() => _EditTemplateDialogState();
}

class _EditTemplateDialogState extends State<EditTemplateDialog> {
  late final TextEditingController templateIdController;
  late final TextEditingController templateNameController;
  late final TextEditingController versionController;

  final TemplateService _templateService = TemplateService();

  late String selectedTemplateType;
  late bool isActive;
  PlatformFile? selectedDocxFile;
  PlatformFile? selectedPdfFile;
  bool isUploading = false;

  @override
  void initState() {
    super.initState();
    templateIdController = TextEditingController(text: widget.data['template_id'] ?? widget.docId);
    templateNameController = TextEditingController(text: widget.data['template_name'] ?? '');
    versionController = TextEditingController(text: (widget.data['version'] ?? 1).toString());
    selectedTemplateType = widget.data['template_type'] ?? 'outgoing';
    isActive = widget.data['is_active'] ?? true;
  }

  Future<void> pickDocxFile() async {
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['docx']);
    if (result != null) setState(() => selectedDocxFile = result.files.first);
  }

  Future<void> pickPdfFile() async {
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result != null) setState(() => selectedPdfFile = result.files.first);
  }

  Future<void> handleSave() async {
    final templateName = templateNameController.text.trim();
    final versionText = versionController.text.trim();

    if (templateName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال اسم القالب')));
      return;
    }

    setState(() => isUploading = true);

    try {
      final existingDocxUrl = widget.data['docx_path'] ?? '';
      String docxUrl = existingDocxUrl;

      if (selectedDocxFile != null) {
        final newDocxUrl = await _templateService.uploadFile(selectedDocxFile!, 'templates/docx');
        if (newDocxUrl != null) {
          docxUrl = newDocxUrl;
          if (existingDocxUrl.isNotEmpty) {
            await _templateService.deleteFileEconomically(existingDocxUrl);
          }
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ أثناء رفع ملف Word')));
          setState(() => isUploading = false);
          return;
        }
      }

      final existingPdfUrl = widget.data['pdf_preview_path'] ?? '';
      String pdfUrl = existingPdfUrl;

      if (selectedPdfFile != null) {
        final newPdfUrl = await _templateService.uploadFile(selectedPdfFile!, 'templates/pdf');
        if (newPdfUrl != null) {
          pdfUrl = newPdfUrl;
          if (existingPdfUrl.isNotEmpty) {
            await _templateService.deleteFileEconomically(existingPdfUrl);
          }
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ أثناء رفع ملف PDF')));
          setState(() => isUploading = false);
          return;
        }
      }

      final version = int.tryParse(versionText) ?? 1;

      await _templateService.editTemplate(
        docId: widget.docId,
        templateName: templateName,
        selectedTemplateType: selectedTemplateType,
        version: version,
        isActive: isActive,
        docxUrl: docxUrl,
        pdfUrl: pdfUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تعديل القالب بنجاح')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  @override
  void dispose() {
    templateIdController.dispose();
    templateNameController.dispose();
    versionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF112240),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      title: const Text('تعديل القالب', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.indigoAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Text('ملاحظة: المتغيرات المتاحة في ملف Word هي:\n{{date}}, {{sender_name}}, {{body_text}}', style: TextStyle(color: Colors.indigoAccent, fontSize: 13)),
              ),
              const SizedBox(height: 16),
              CustomTextField(controller: templateIdController, labelText: 'معرف القالب', readOnly: true),
              const SizedBox(height: 12),
              CustomTextField(controller: templateNameController, labelText: 'اسم القالب'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedTemplateType,
                dropdownColor: const Color(0xFF112240),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'نوع القالب',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                items: const [
                  DropdownMenuItem(value: 'outgoing', child: Text('صادر (outgoing)')),
                  DropdownMenuItem(value: 'incoming', child: Text('وارد (incoming)')),
                  DropdownMenuItem(value: 'internal', child: Text('داخلي (internal)')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => selectedTemplateType = value);
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('تغيير ملف Word (.docx)', style: TextStyle(color: Colors.white)),
                subtitle: Text(selectedDocxFile?.name ?? 'الاحتفاظ بالملف الحالي', style: const TextStyle(color: Colors.white54)),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, foregroundColor: Colors.white),
                  onPressed: pickDocxFile,
                  child: const Text('اختيار'),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('تغيير معاينة PDF', style: TextStyle(color: Colors.white)),
                subtitle: Text(selectedPdfFile?.name ?? 'الاحتفاظ بالملف الحالي', style: const TextStyle(color: Colors.white54)),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, foregroundColor: Colors.white),
                  onPressed: pickPdfFile,
                  child: const Text('اختيار'),
                ),
              ),
              const SizedBox(height: 12),
              CustomTextField(controller: versionController, labelText: 'الإصدار', keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              SwitchListTile(
                value: isActive,
                title: const Text('القالب مفعل', style: TextStyle(color: Colors.white)),
                contentPadding: EdgeInsets.zero,
                activeThumbColor: Colors.indigoAccent,
                inactiveThumbColor: Colors.white38,
                inactiveTrackColor: Colors.white10,
                onChanged: (value) => setState(() => isActive = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (isUploading) const CircularProgressIndicator(color: Colors.indigoAccent),
        if (!isUploading) TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
        if (!isUploading) ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, foregroundColor: Colors.white),
          onPressed: handleSave,
          child: const Text('حفظ التعديلات'),
        ),
      ],
    );
  }
}
