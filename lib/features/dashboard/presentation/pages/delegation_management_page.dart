import 'package:flutter/material.dart';
import '../../../../core/services/delegation_service.dart';

class DelegationManagementPage extends StatefulWidget {
  const DelegationManagementPage({Key? key}) : super(key: key);

  @override
  _DelegationManagementPageState createState() => _DelegationManagementPageState();
}

class _DelegationManagementPageState extends State<DelegationManagementPage> {
  final DelegationService _delegationService = DelegationService();
  final _notesController = TextEditingController();
  String? _selectedDelegateeId;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 3));
  bool _isLoading = false;

  Future<void> _createDelegation() async {
    if (_selectedDelegateeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء اختيار الشخص المفوض')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _delegationService.createDelegation(
        delegateeId: _selectedDelegateeId!,
        startDate: _startDate,
        endDate: _endDate,
        notes: _notesController.text,
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تفويض الصلاحيات بنجاح')));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('تفويض الصلاحيات', style: TextStyle(color: Color(0xFFD4AF37))),
        backgroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الشخص المفوض إليه:', style: TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(
                hintText: 'أدخل المعرف الخاص بالموظف (UID)',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              style: const TextStyle(color: Colors.white),
              onChanged: (val) => _selectedDelegateeId = val,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('تاريخ البدء', style: TextStyle(color: Colors.white)),
                    subtitle: Text('${_startDate.toLocal()}'.split(' ')[0], style: const TextStyle(color: Color(0xFFD4AF37))),
                    onTap: () async {
                      final d = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime.now(), lastDate: DateTime(2030));
                      if (d != null) setState(() => _startDate = d);
                    },
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: const Text('تاريخ الانتهاء', style: TextStyle(color: Colors.white)),
                    subtitle: Text('${_endDate.toLocal()}'.split(' ')[0], style: const TextStyle(color: Color(0xFFD4AF37))),
                    onTap: () async {
                      final d = await showDatePicker(context: context, initialDate: _endDate, firstDate: DateTime.now(), lastDate: DateTime(2030));
                      if (d != null) setState(() => _endDate = d);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText: 'ملاحظات (مثال: تفويض خلال فترة السفر)',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
                onPressed: _isLoading ? null : _createDelegation,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text('تأكيد التفويض', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
