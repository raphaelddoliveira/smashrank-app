import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../features/clubs/viewmodel/club_providers.dart';
import '../../features/notifications/viewmodel/notification_viewmodel.dart';
import '../../services/push_notification_service.dart';
import 'floating_nav_bar.dart';

class AppScaffold extends ConsumerWidget {
  final Widget child;

  const AppScaffold({super.key, required this.child});

  static const _tabs = [
    RouteNames.ranking,
    RouteNames.challenges,
    RouteNames.courts,
    RouteNames.notifications,
    RouteNames.profile,
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i])) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = _currentIndex(context);
    final unreadAsync = ref.watch(unreadCountProvider);
    // Activate realtime listener for notifications
    ref.watch(notificationRealtimeProvider);
    // Activate web push notifications
    ref.watch(pushNotificationProvider);
    final isAdmin = ref.watch(isClubAdminProvider);
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    // Auto-select first club if none selected
    final clubId = ref.watch(currentClubIdProvider);
    final myClubs = ref.watch(myClubsProvider);
    if (clubId == null && myClubs.valueOrNull != null && myClubs.valueOrNull!.isNotEmpty) {
      Future.microtask(() {
        ref.read(currentClubIdProvider.notifier).state = myClubs.valueOrNull!.first.id;
      });
    }

    // Auto-select first sport if none selected
    final sportId = ref.watch(currentSportIdProvider);
    final clubSports = ref.watch(clubSportsProvider);
    if (clubId != null && sportId == null && clubSports.valueOrNull != null && clubSports.valueOrNull!.isNotEmpty) {
      Future.microtask(() {
        ref.read(currentSportIdProvider.notifier).state = clubSports.valueOrNull!.first.sportId;
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          // Main content with bottom padding for floating nav
          Padding(
            padding: EdgeInsets.only(
              bottom: FloatingNavBar.navHeight + FloatingNavBar.navMargin * 2 + bottomPadding,
            ),
            child: child,
          ),

          // Floating glass navbar
          FloatingNavBar(
            currentIndex: currentIndex,
            onTap: (index) => context.go(_tabs[index]),
            notificationCount: unreadAsync.valueOrNull ?? 0,
          ),

          // Admin FAB - positioned above the navbar
          if (isAdmin && currentIndex == 0)
            Positioned(
              right: 20,
              bottom: FloatingNavBar.navHeight + FloatingNavBar.navMargin * 2 + bottomPadding + 12,
              child: FloatingActionButton.small(
                onPressed: () => context.push('/admin'),
                backgroundColor: AppColors.secondary,
                child: const Icon(Icons.admin_panel_settings, size: 20),
              ),
            ),
        ],
      ),
    );
  }
}
