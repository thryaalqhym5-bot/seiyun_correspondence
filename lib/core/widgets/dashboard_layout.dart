import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';

class DashboardLayout extends StatefulWidget {
  final Widget child;
  final int selectedIndex;
  final Function(int) onItemSelected;
  final String userName;
  final String role;
  final VoidCallback onLogout;
  final List<SidebarItem> items;

  const DashboardLayout({
    super.key,
    required this.child,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.userName,
    required this.role,
    required this.onLogout,
    required this.items,
  });

  @override
  State<DashboardLayout> createState() => _DashboardLayoutState();
}

class _DashboardLayoutState extends State<DashboardLayout> {
  bool _isHovered(int index) => _hoveredIndex == index;
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
          final idx = widget.items.indexWhere((item) => item.title == 'إنشاء مخاطبة');
          if (idx != -1) widget.onItemSelected(idx);
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          // يمكن التراجع للشاشة الرئيسية إذا ضغط Esc
          widget.onItemSelected(0);
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: Row(
        children: [
          // Sidebar
          Container(
            width: 260,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.9),
              border: Border(
                left: BorderSide(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            child: Column(
              children: [
                // Logo Area
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.account_balance, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'جامعة سيئون',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Divider(color: Colors.white10),
                ),
                const SizedBox(height: 16),

                // Menu Items
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: widget.items.length,
                    itemBuilder: (context, index) {
                      final item = widget.items[index];
                      final isSelected = widget.selectedIndex == index;

                      return MouseRegion(
                        onEnter: (_) => setState(() => _hoveredIndex = index),
                        onExit: (_) => setState(() => _hoveredIndex = null),
                        child: GestureDetector(
                          onTap: () => widget.onItemSelected(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? AppColors.primary.withValues(alpha: 0.15) 
                                  : (_isHovered(index) ? Colors.white.withValues(alpha: 0.05) : Colors.transparent),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? AppColors.primary.withValues(alpha: 0.3) : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  item.icon,
                                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: TextStyle(
                                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                      fontSize: 15,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ).animate().fade(delay: (index * 50).ms, duration: 300.ms).slideX(begin: -0.2, end: 0, duration: 300.ms, curve: Curves.easeOut);
                    },
                  ),
                ),

                // Bottom Profile Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.white10),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                        child: Text(
                          widget.userName.isNotEmpty ? widget.userName[0] : 'U',
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.userName,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.role,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, color: AppColors.danger, size: 20),
                        onPressed: widget.onLogout,
                        tooltip: 'تسجيل الخروج',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Main Content Area
          Expanded(
            child: widget.child,
          ),
        ],
      ),
    )));
  }
}

class SidebarItem {
  final String title;
  final IconData icon;

  SidebarItem({required this.title, required this.icon});
}
