import 'package:flutter/material.dart';

class CommentDialog extends StatefulWidget {
  final Future<void> Function(String comment) onSave;

  const CommentDialog({super.key, required this.onSave});

  @override
  State<CommentDialog> createState() => _CommentDialogState();
}

class _CommentDialogState extends State<CommentDialog> {
  final TextEditingController commentController = TextEditingController();
  bool isSaving = false;

  Future<void> _handleSave() async {
    final comment = commentController.text.trim();
    if (comment.isEmpty) return;

    setState(() => isSaving = true);
    try {
      await widget.onSave(comment);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة التعليق')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة تعليق'),
      content: TextField(
        controller: commentController,
        maxLines: 4,
        decoration: const InputDecoration(
          labelText: 'اكتبي التعليق',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        if (isSaving) const CircularProgressIndicator(),
        if (!isSaving)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
        if (!isSaving)
          ElevatedButton(
            onPressed: _handleSave,
            child: const Text('حفظ'),
          ),
      ],
    );
  }
}
