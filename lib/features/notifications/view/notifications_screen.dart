import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/date_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/notification_model.dart';
import '../../clubs/view/club_selector_widget.dart';
import '../viewmodel/notification_viewmodel.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: clubAppBarTitle('Notificações', context, ref),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              ref.read(notificationActionProvider.notifier).markAllAsRead();
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadCountProvider);
            },
            icon: const Icon(Icons.done_all),
            tooltip: 'Marcar todas como lidas',
          ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: AppColors.onBackgroundLight),
                  SizedBox(height: 16),
                  Text(
                    'Nenhuma notificação',
                    style: TextStyle(fontSize: 16, color: AppColors.onBackgroundLight),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadCountProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: notifications.length,
              itemBuilder: (context, index) => _NotificationTile(
                notification: notifications[index],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Erro: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(notificationsProvider),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final NotificationModel notification;

  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iconData = _getIconData(notification.iconLabel.icon);
    final iconColor = Color(notification.iconLabel.color);

    return Container(
      color: notification.isRead ? null : AppColors.secondarySurface,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withAlpha(25),
          child: Icon(iconData, color: iconColor, size: 20),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight:
                notification.isRead ? FontWeight.normal : FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.body,
              style: const TextStyle(fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              notification.createdAt.timeAgo(),
              style: const TextStyle(fontSize: 11, color: AppColors.onBackgroundLight),
            ),
          ],
        ),
        trailing: notification.isRead
            ? null
            : Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                ),
              ),
        onTap: () {
          if (!notification.isRead) {
            ref
                .read(notificationActionProvider.notifier)
                .markAsRead(notification.id);
            ref.invalidate(notificationsProvider);
            ref.invalidate(unreadCountProvider);
          }
          _navigateToDestination(context, notification);
        },
      ),
    );
  }

  void _navigateToDestination(BuildContext context, NotificationModel n) {
    final challengeId = n.challengeId;

    switch (n.type) {
      case NotificationType.challengeReceived:
      case NotificationType.datesProposed:
      case NotificationType.dateChosen:
      case NotificationType.matchResult:
      case NotificationType.woWarning:
      case NotificationType.courtSelected:
      case NotificationType.challengeAccepted:
      case NotificationType.challengeDeclined:
        if (challengeId != null) {
          context.push('/challenges/$challengeId');
        }
      case NotificationType.rankingChange:
      case NotificationType.ambulanceActivated:
      case NotificationType.ambulanceExpired:
        context.go('/ranking');
      case NotificationType.paymentDue:
      case NotificationType.paymentOverdue:
        context.go('/profile');
      case NotificationType.monthlyChallengeWarning:
        context.go('/challenges');
      case NotificationType.general:
        if (challengeId != null) {
          context.push('/challenges/$challengeId');
        } else if (notification.clubId != null) {
          context.push('/clubs/${notification.clubId}/manage');
        }
    }
  }

  IconData _getIconData(String name) {
    return switch (name) {
      'sports_tennis' => Icons.sports_tennis,
      'calendar_month' => Icons.calendar_month,
      'event_available' => Icons.event_available,
      'scoreboard' => Icons.scoreboard,
      'emoji_events' => Icons.emoji_events,
      'local_hospital' => Icons.local_hospital,
      'healing' => Icons.healing,
      'payment' => Icons.payment,
      'warning' => Icons.warning,
      'timer_off' => Icons.timer_off,
      'notifications_active' => Icons.notifications_active,
      'event_note' => Icons.event_note,
      'check_circle' => Icons.check_circle,
      'cancel' => Icons.cancel,
      _ => Icons.info,
    };
  }
}
