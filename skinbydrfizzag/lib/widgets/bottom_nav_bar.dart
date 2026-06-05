import 'package:flutter/material.dart';
import '../constants/colors.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final int unreadCount;
  final bool isAdmin;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.unreadCount = 0,
    this.isAdmin = false,
  });

  static const _userItems = <_NavItem>[
    _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
    _NavItem(Icons.spa_outlined, Icons.spa, 'Procedures'),
    _NavItem(Icons.shopping_bag_outlined, Icons.shopping_bag, 'Shop'),
    _NavItem(Icons.chat_bubble_outline, Icons.chat_bubble, 'Chat'),
    _NavItem(Icons.person_outline, Icons.person, 'Profile'),
  ];

  static const _adminItems = <_NavItem>[
    _NavItem(Icons.people_alt_outlined, Icons.people_alt, 'Users'),
    _NavItem(
      Icons.medical_services_outlined,
      Icons.medical_services,
      'Procedures',
    ),
    _NavItem(
      Icons.calendar_month_outlined,
      Icons.calendar_month,
      'Appointments',
    ),
    _NavItem(Icons.chat_outlined, Icons.chat, 'Chats'),
    _NavItem(Icons.info_outline, Icons.info, 'About'),
  ];

  @override
  Widget build(BuildContext context) {
    final items = isAdmin ? _adminItems : _userItems;
    final chatTabIndex = isAdmin ? 3 : 3;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: List.generate(items.length, (i) {
            final isSelected = i == currentIndex;
            return _NavButton(
              item: items[i],
              isSelected: isSelected,
              onTap: () => onTap(i),
              badgeCount: i == chatTabIndex ? unreadCount : 0,
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final int badgeCount;

  const _NavButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primarySoft : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      isSelected ? item.activeIcon : item.icon,
                      size: 22,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        right: -8,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AppColors.surface,
                              width: 1.5,
                            ),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            badgeCount > 9 ? '9+' : '$badgeCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: SizedBox(
                    height: 13,
                    width: double.infinity,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          item.label,
                          maxLines: 1,
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
