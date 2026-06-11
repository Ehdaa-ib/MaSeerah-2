import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// Bottom nav bar with Home, Active Journeys, Profile. Used by LandingPage and ProfileScreen.
class AppBottomNav extends StatelessWidget {
  final VoidCallback onHomeTap;
  final VoidCallback onActiveJourneysTap;
  final VoidCallback onProfileTap;
  final int selectedIndex;

  const AppBottomNav({
    super.key,
    required this.onHomeTap,
    required this.onActiveJourneysTap,
    required this.onProfileTap,
    this.selectedIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.beige,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                color: AppColors.brown,
                isSelected: selectedIndex == 0,
                onTap: onHomeTap,
              ),
              _ActiveJourneysNavItem(
                isSelected: selectedIndex == 1,
                onTap: onActiveJourneysTap,
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                color: AppColors.brown,
                isSelected: selectedIndex == 2,
                onTap: onProfileTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveJourneysNavItem extends StatelessWidget {
  const _ActiveJourneysNavItem({required this.isSelected, required this.onTap});

  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final labelColor = isSelected ? AppColors.orange : AppColors.brown;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 48,
            width: 100,
            child: Image.asset(
              'images/active journeys.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            'Active Journeys',
            style: TextStyle(fontSize: 12, color: labelColor),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = isSelected ? AppColors.orange : color;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: labelColor)),
        ],
      ),
    );
  }
}
