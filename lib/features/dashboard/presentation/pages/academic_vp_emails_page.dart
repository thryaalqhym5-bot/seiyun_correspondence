import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AcademicVpEmailsPage extends StatefulWidget {
  const AcademicVpEmailsPage({super.key});

  @override
  State<AcademicVpEmailsPage> createState() => _AcademicVpEmailsPageState();
}

class _AcademicVpEmailsPageState extends State<AcademicVpEmailsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // فلتر اختياري إذا أردنا إظهار من تم تفعيلهم أيضاً
  bool _showOnlyInactive = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// دالة تفتح نافذة (Dialog) لإضافة أو تعديل الإيميل للأكاديمي
  Future<void> _showAddEmailDialog(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['full_name'] ?? 'بدون اسم';
    final currentEmails = List<String>.from(data['emails'] ?? []);
    
    // نستخدم أول إيميل إن وجد كقيمة مبدئية في الحقل
    final TextEditingController emailController = TextEditingController(
      text: currentEmails.isNotEmpty ? currentEmails.first : '',
    );
    
    bool isLoading = false;
    String? errorText;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF112240),
              title: const Text(
                'تفعيل حساب أكاديمي',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'أدخل البريد الإلكتروني (جيميل) الخاص بـ:\n$name',
                      style: const TextStyle(color: Colors.white70, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'example@gmail.com',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        errorText: errorText,
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                          final email = emailController.text.trim().toLowerCase();
                          if (email.isEmpty || !email.contains('@')) {
                            setStateDialog(() => errorText = 'يرجى إدخال بريد إلكتروني صحيح');
                            return;
                          }

                          setStateDialog(() {
                            isLoading = true;
                            errorText = null;
                          });

                          try {
                            // نقوم بتحديث الحساب، ونضيف الإيميل للمصفوفة
                            // ونجعل الحساب فعالاً
                            await FirebaseFirestore.instance
                                .collection('allowed_users')
                                .doc(doc.id)
                                .update({
                              'emails': FieldValue.arrayUnion([email]),
                              'is_active': true,
                            });
                            
                            if (mounted) Navigator.pop(context);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تم إضافة الإيميل وتفعيل الحساب بنجاح'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            setStateDialog(() => errorText = 'حدث خطأ: $e');
                          } finally {
                            setStateDialog(() => isLoading = false);
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('حفظ وتفعيل'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // جلب جميع الأكاديميين من كلية محددة أو الكل حسب الصلاحيات
    // بما أن النائب الأكاديمي للجامعة لديه صلاحية على جميع الأكاديميين في النظام
    // سنقوم بجلب أصحاب الـ role = faculty_member
    
    Query query = FirebaseFirestore.instance
        .collection('allowed_users')
        .where('role', isEqualTo: 'faculty_member');
        
    if (_showOnlyInactive) {
      query = query.where('is_active', isEqualTo: false);
    }

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تفعيل حسابات أعضاء هيئة التدريس',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'من خلال هذه الشاشة يمكنك إضافة الإيميلات للأكاديميين لتتمكن من تفعيل دخولهم للنظام.',
            style: TextStyle(fontSize: 16, color: Colors.white54),
          ),
          const SizedBox(height: 24),
          
          // شريط البحث والفلتر
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.toLowerCase();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'ابحث باسم الأكاديمي أو الكلية...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF112240),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF112240),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Checkbox(
                      value: _showOnlyInactive,
                      activeColor: Colors.blueAccent,
                      onChanged: (val) {
                        setState(() {
                          _showOnlyInactive = val ?? true;
                        });
                      },
                    ),
                    const Text('إظهار غير المفعلين فقط', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // قائمة الأكاديميين
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('حدث خطأ: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
                }
                
                final docs = snapshot.data?.docs ?? [];
                
                // تطبيق فلتر البحث محلياً
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['full_name'] ?? '').toString().toLowerCase();
                  final title = (data['administrative_title'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) || title.contains(_searchQuery);
                }).toList();
                
                if (filteredDocs.isEmpty) {
                  return const Center(
                    child: Text(
                      'لا يوجد أكاديميين يطابقون معايير البحث.',
                      style: TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    
                    final name = data['full_name'] ?? 'غير معروف';
                    final title = data['administrative_title'] ?? '';
                    final isActive = data['is_active'] ?? false;
                    final emails = List<String>.from(data['emails'] ?? []);
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF112240),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        leading: CircleAvatar(
                          backgroundColor: isActive ? Colors.greenAccent.withValues(alpha: 0.2) : Colors.redAccent.withValues(alpha: 0.2),
                          child: Icon(
                            isActive ? Icons.check : Icons.person_off,
                            color: isActive ? Colors.greenAccent : Colors.redAccent,
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            children: [
                              Icon(Icons.badge_outlined, size: 14, color: Colors.white54),
                              const SizedBox(width: 4),
                              Text(title, style: const TextStyle(color: Colors.white54)),
                              const SizedBox(width: 16),
                              if (emails.isNotEmpty) ...[
                                const Icon(Icons.email_outlined, size: 14, color: Colors.blueAccent),
                                const SizedBox(width: 4),
                                Text(emails.first, style: const TextStyle(color: Colors.blueAccent)),
                              ],
                            ],
                          ),
                        ),
                        trailing: ElevatedButton.icon(
                          onPressed: () => _showAddEmailDialog(doc),
                          icon: Icon(isActive ? Icons.edit : Icons.add_circle_outline, size: 18),
                          label: Text(isActive ? 'تعديل الإيميل' : 'إضافة إيميل وتفعيل'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isActive ? Colors.transparent : Colors.blueAccent,
                            foregroundColor: isActive ? Colors.blueAccent : Colors.white,
                            side: isActive ? const BorderSide(color: Colors.blueAccent) : null,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
