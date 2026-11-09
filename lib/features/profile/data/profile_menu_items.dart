import 'package:flutter/material.dart';

import '../../../../app/routes/route_names.dart';

/// One row in the Profile menu list.
class ProfileMenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  const ProfileMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });
}

class ProfileMenuItems {
  ProfileMenuItems._();

  static const List<ProfileMenuItem> all = [
    ProfileMenuItem(
      icon: Icons.badge_outlined,
      title: 'View Profile',
      subtitle: 'Photo, stats, portfolio & work history',
      route: RouteNames.profile,
    ),
    ProfileMenuItem(
      icon: Icons.dashboard_outlined,
      title: 'Overview',
      subtitle: 'Profile summary at a glance',
      route: RouteNames.overview,
    ),
    ProfileMenuItem(
      icon: Icons.insert_chart_outlined,
      title: 'Stats',
      subtitle: 'Earnings, jobs and hours',
      route: RouteNames.stats,
    ),
    ProfileMenuItem(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Wallet',
      subtitle: 'Balance, connects & activity',
      route: RouteNames.wallet,
    ),
    ProfileMenuItem(
      icon: Icons.payments_outlined,
      title: 'Transactions',
      subtitle: 'Balance, withdrawals & history',
      route: RouteNames.transactions,
    ),
    ProfileMenuItem(
      icon: Icons.notifications_none,
      title: 'Notifications',
      subtitle: 'Alerts & reminders',
      route: RouteNames.notifications,
    ),
    ProfileMenuItem(
      icon: Icons.assignment_outlined,
      title: 'Proposals',
      subtitle: 'Sent proposals and their status',
      route: RouteNames.proposals,
    ),
    ProfileMenuItem(
      icon: Icons.summarize_outlined,
      title: 'Your Reports',
      subtitle: 'Downloadable account reports',
      route: RouteNames.yourReports,
    ),
    ProfileMenuItem(
      icon: Icons.workspace_premium_outlined,
      title: 'Membership Plan',
      subtitle: 'Pricing tiers and their benefits',
      route: RouteNames.membershipPlan,
    ),
    ProfileMenuItem(
      icon: Icons.settings_outlined,
      title: 'Settings',
      subtitle: 'App preferences',
      route: RouteNames.settings,
    ),
  ];
}
