class RankingHistoryModel {
  final String id;
  final String playerId;
  final String? sportId;
  final int? oldPosition;
  final int newPosition;
  final String reason;
  final String? referenceId;
  final DateTime createdAt;

  const RankingHistoryModel({
    required this.id,
    required this.playerId,
    this.sportId,
    this.oldPosition,
    required this.newPosition,
    required this.reason,
    this.referenceId,
    required this.createdAt,
  });

  int get positionChange {
    if (oldPosition == null) return 0;
    return oldPosition! - newPosition;
  }

  bool get isImprovement => positionChange > 0;
  bool get isDecline => positionChange < 0;
  bool get isUnchanged => positionChange == 0;

  String get reasonLabel => switch (reason) {
        'challenge_win' => 'Vitória em desafio',
        'challenge_loss' => 'Derrota em desafio',
        'ambulance_penalty' => 'Penalização ambulância',
        'ambulance_daily_penalty' => 'Penalização diária ambulância',
        'overdue_penalty' => 'Penalização inadimplência',
        'monthly_inactivity' => 'Inatividade mensal',
        'admin_adjustment' => 'Ajuste administrativo',
        'new_player' => 'Novo jogador',
        _ => reason,
      };

  factory RankingHistoryModel.fromJson(Map<String, dynamic> json) {
    return RankingHistoryModel(
      id: json['id'] as String,
      playerId: json['player_id'] as String,
      sportId: json['sport_id'] as String?,
      oldPosition: json['old_position'] as int?,
      newPosition: json['new_position'] as int,
      reason: json['reason'] as String,
      referenceId: json['reference_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'player_id': playerId,
      'old_position': oldPosition,
      'new_position': newPosition,
      'reason': reason,
      'reference_id': referenceId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
