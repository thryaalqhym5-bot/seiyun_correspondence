import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/services/template_service.dart';

class AddTemplateDialog extends StatefulWidget {
  const AddTemplateDialog({super.key});

  @override
  State<AddTemplateDialog> createState() => _AddTemplateDialogState();
}

class _AddTemplateDialogState extends State<AddTemplateDialog> {
  final TextEditingController templateIdController = TextEditingController();
  final TextEditingController templateNameController = TextEditingController();
  final TextEditingController versionController = TextEditingController();
  
  final TemplateService _templateService = TemplateService();

  String selectedTemplateType = 'outgoing';
  bool isActive = true;
  PlatformFile? selectedDocxFile;
  PlatformFile? selectedPdfFile;
  bool isUploading = false;

  Future<void> pickDocxFile() async {
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['docx']);
    if (result != null) setState(() => selectedDocxFile = result.files.first);
  }

  Future<void> pickPdfFile() async {
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result != null) setState(() => selectedPdfFile = result.files.first);
  }

  Future<void> handleSave() async {
    final templateId = templateIdController.text.trim();
    final templateName = templateNameController.text.trim();
    final versionText = versionController.text.trim();

    if (templateId.isEmpty || templateName.isEmpty || selectedDocxFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أكملي معرف القالب واسم القالب واختاري ملف Word')));
      return;
    }

    setState(() => isUploading = true);

    try {
      final exists = await _templateService.checkTemplateExists(templateId);
      if (exists) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('معرف القالب موجود مسبقاً!'), backgroundColor: Colors.redAccent));
        setState(() => isUploading = false);
        return;
      }

      final docxUrl = await _templateService.uploadFile(selectedDocxFile!, 'templates/docx');
      if (docxUrl == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ أثناء رفع ملف Word')));
        setState(() => isUploading = false);
        return;
      }

      String? pdfUrl;
      if (selectedPdfFile != null) {
        pdfUrl = await _templateService.uploadFile(selectedPdfFile!, 'templates/pdf');
      }

      final version = int.tryParse(versionText) ?? 1;

      await _templateService.addTemplate(
        templateId: templateId,
        templateName: templateName,
        selectedTemplateType: selectedTemplateType,
        version: version,
        isActive: isActive,
        docxUrl: docxUrl,
        pdfUrl: pdfUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة القالب بنجاح')));
        Navigator.pop(context, true); // True means success
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
      title: const Text('إضافة قالب جديد', style: TextStyle(color: Colors.white)),
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
              CustomTextField(controller: templateIdController, labelText: 'معرف القالب'),
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
                title: const Text('ملف الوورد (.docx) المرجعي', style: TextStyle(color: Colors.white)),
                subtitle: Text(selectedDocxFile?.name ?? 'لم يتم الاختيار', style: TextStyle(color: selectedDocxFile != null ? Colors.greenAccent : Colors.redAccent)),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, foregroundColor: Colors.white),
                  onPressed: pickDocxFile,
                  child: const Text('اختيار'),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('معاينة PDF (اختياري)', style: TextStyle(color: Colors.white)),
                subtitle: Text(selectedPdfFile?.name ?? 'لم يتم الاختيار', style: const TextStyle(color: Colors.white54)),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white10, foregroundColor: Colors.white),
                  onPressed: pickPdfFile,
                  child: const Text('اختيار'),
                ),
              ),
              const SizedBox(height: 12),
              CustomTextField(controller: versionController, labelText: 'الإصدار (رقمي)', keyboardType: TextInputType.number),
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
          child: const Text('حفظ ورفع'),
        ),
      ],
    );
  }
}
