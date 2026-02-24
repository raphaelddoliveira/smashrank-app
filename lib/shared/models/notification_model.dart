import 'enums.dart';

class NotificationModel {
  final String id;
  final String playerId;
  final NotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.playerId,
    required this.type,
    required this.title,
    required this.body,
    this.data = const {},
    this.isRead = false,
    required this.createdAt,
  });

  IconLabel get iconLabel => switch (type) {
        NotificationType.challengeReceived => (icon: 'sports_tennis', color: 0xFFFF9800),
        NotificationType.datesProposed => (icon: 'calendar_month', color: 0xFF2196F3),
        NotificationType.dateChosen => (icon: 'event_available', color: 0xFF4CAF50),
        NotificationType.matchResult => (icon: 'scoreboard', color: 0xFF4CAF50),
        NotificationType.rankingChange => (icon: 'emoji_events', color: 0xFFFFD700),
        NotificationType.ambulanceActivated => (icon: 'local_hospital', color: 0xFFE53935),
        NotificationType.ambulanceExpired => (icon: 'healing', color: 0xFF9C27B0),
        NotificationType.paymentDue => (icon: 'payment', color: 0xFFFF9800),
        NotificationType.paymentOverdue => (icon: 'warning', color: 0xFFE53935),
        NotificationType.woWarning => (icon: 'timer_off', color: 0xFFE53935),
        NotificationType.monthlyChallengeWarning => (icon: 'notifications_active', color: 0xFFFF9800),
        NotificationType.courtSelected => (icon: 'event_note', color: 0xFF2196F3),
        NotificationType.challengeAccepted => (icon: 'check_circle', color: 0xFF4CAF50),
        NotificationType.challengeDeclined => (icon: 'cancel', color: 0xFFE53935),
        NotificationType.general => (icon: 'info', color: 0xFF2196F3),
      };

  /// Get the challenge_id from data if present (for navigation)
  String? get challengeId => data['challenge_id'] as String?;

  /// Get the club_id from data if present (for navigation)
  String? get clubId => data['club_id'] as String?;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      playerId: json['player_id'] as String,
      type: NotificationType.fromString(json['type'] as String),
      title: json['title'] as String,
      body: json['body'] as String,
      data: (json['data'] as Map<String, dynamic>?) ?? {},
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

typedef IconLabel = ({String icon, int color});
