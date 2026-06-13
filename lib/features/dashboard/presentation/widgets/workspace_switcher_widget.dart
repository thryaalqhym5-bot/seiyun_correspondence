import 'package:flutter/material.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WorkspaceSwitcherWidget extends StatefulWidget {
  final UserModel user;
  final int activeIndex;
  final ValueChanged<int> onWorkspaceChanged;

  const WorkspaceSwitcherWidget({
    super.key,
    required this.user,
    required this.activeIndex,
    required this.onWorkspaceChanged,
  });

  @override
  State<WorkspaceSwitcherWidget> createState() => _WorkspaceSwitcherWidgetState();
}

class _WorkspaceSwitcherWidgetState extends State<WorkspaceSwitcherWidget> {
  Map<String, String> collegeNames = {};

  @override
  void initState() {
    super.initState();
    _loadCollegeNames();
  }

  Future<void> _loadCollegeNames() async {
    if (widget.user.collegeIds.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance.collection('colleges').where(FieldPath.documentId, whereIn: widget.user.collegeIds).get();
      final Map<String, String> names = {};
      for (var doc in snap.docs) {
        names[doc.id] = doc.data()['name'] ?? doc.id;
      }
      if (mounted) setState(() => collegeNames = names);
    } catch (e) {
      // Ignored
    }
  }

  String _getTitleLabel(String title) {
    const titles = {
      'university_president': 'رئيس الجامعة',
      'university_vp': 'نائب رئيس الجامعة',
      'general_secretary': 'أمين عام الجامعة',
      'dean': 'عميد الكلية',
      'vice_dean': 'نائب العميد',
      'vice_dean_student': 'نائب لشؤون الطلاب',
      'vice_dean_academic': 'نائب للشؤون الأكاديمية',
      'vice_dean_postgraduate': 'نائب للدراسات العليا',
      'center_director': 'مدير مركز',
      'vice_director': 'نائب مدير مركز',
      'general_director': 'مدير عام',
      'head_of_department': 'رئيس القسم',
      'secretary': 'سكرتير',
      'staff': 'موظف',
      'none': 'موظف'
    };
    return titles[title] ?? 'موظف';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.user.affiliations.length <= 1) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: widget.activeIndex >= widget.user.affiliations.length ? 0 : widget.activeIndex,
          dropdownColor: AppColors.surface,
          icon: const Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: Icon(Icons.swap_horiz, color: AppColors.primary),
          ),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          items: widget.user.affiliations.asMap().entries.map((entry) {
            final index = entry.key;
            final aff = entry.value;
            final cName = collegeNames[aff.collegeId] ?? 'جاري التحميل...';
            final tName = _getTitleLabel(aff.administrativeTitle);
            return DropdownMenuItem<int>(
              value: index,
              child: Text('بصفتك: $tName - $cName', style: const TextStyle(fontSize: 14)),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null && val != widget.activeIndex) {
              widget.onWorkspaceChanged(val);
            }
          },
        ),
      ),
    );
  }
}
