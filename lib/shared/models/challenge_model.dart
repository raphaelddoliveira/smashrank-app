import 'enums.dart';

class ChallengeModel {
  final String id;
  final String? sportId;
  final String challengerId;
  final String challengedId;
  final ChallengeStatus status;
  final int challengerPosition;
  final int challengedPosition;
  final DateTime? proposedDate1;
  final DateTime? proposedDate2;
  final DateTime? proposedDate3;
  final DateTime? chosenDate;
  final int weatherExtensionDays;
  final DateTime? playDeadline;
  final String? winnerId;
  final String? loserId;
  final String? woPlayerId;
  final String? resultSubmittedBy;
  final DateTime challengedAt;
  final DateTime? responseDeadline;
  final DateTime? datesProposedAt;
  final DateTime? dateChosenAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? courtId;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined fields (optional, from queries with joins)
  final String? challengerName;
  final String? challengedName;
  final String? challengerAvatarUrl;
  final String? challengedAvatarUrl;
  final String? courtName;

  const ChallengeModel({
    required this.id,
    this.sportId,
    required this.challengerId,
    required this.challengedId,
    required this.status,
    required this.challengerPosition,
    required this.challengedPosition,
    this.proposedDate1,
    this.proposedDate2,
    this.proposedDate3,
    this.chosenDate,
    this.weatherExtensionDays = 0,
    this.playDeadline,
    this.winnerId,
    this.loserId,
    this.woPlayerId,
    this.resultSubmittedBy,
    required this.challengedAt,
    this.responseDeadline,
    this.datesProposedAt,
    this.dateChosenAt,
    this.completedAt,
    this.cancelledAt,
    this.courtId,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.challengerName,
    this.challengedName,
    this.challengerAvatarUrl,
    this.challengedAvatarUrl,
    this.courtName,
  });

  bool get isActive => status.isActive;
  bool get isFinished => status.isFinished;
  bool get isWo =>
      status == ChallengeStatus.woChallenger ||
      status == ChallengeStatus.woChallenged;

  bool isParticipant(String playerId) =>
      challengerId == playerId || challengedId == playerId;

  bool isChallenger(String playerId) => challengerId == playerId;
  bool isChallenged(String playerId) => challengedId == playerId;

  bool didWin(String playerId) => winnerId == playerId;
  bool didLose(String playerId) => loserId == playerId;

  bool isResultSubmitter(String playerId) => resultSubmittedBy == playerId;

  String get statusLabel => switch (status) {
        ChallengeStatus.pending => 'Aguardando agendamento',
        ChallengeStatus.datesProposed => 'Aguardando confirmação',
        ChallengeStatus.scheduled => 'Agendado',
        ChallengeStatus.pendingResult => 'Aguardando confirmação do resultado',
        ChallengeStatus.completed => 'Finalizado',
        ChallengeStatus.woChallenger => 'WO Desafiante',
        ChallengeStatus.woChallenged => 'WO Desafiado',
        ChallengeStatus.expired => 'Expirado',
        ChallengeStatus.cancelled => 'Cancelado',
        ChallengeStatus.annulled => 'Anulado',
      };

  List<DateTime> get proposedDates => [
        ?proposedDate1,
        ?proposedDate2,
        ?proposedDate3,
      ];

  /// True when status is dates_proposed but the chosen date is in the past
  bool get isCourtDateExpired {
    if (status != ChallengeStatus.datesProposed) return false;
    if (chosenDate == null) return false;
    return chosenDate!.isBefore(DateTime.now());
  }

  /// Legacy: True when all proposed dates are in the past (old flow)
  bool get allProposedDatesExpired {
    if (status != ChallengeStatus.datesProposed) return false;
    final dates = proposedDates;
    if (dates.isEmpty) return false;
    final now = DateTime.now();
    return dates.every((d) => d.isBefore(now));
  }

  factory ChallengeModel.fromJson(Map<String, dynamic> json) {
    // Handle nested joins
    final challenger = json['challenger'] as Map<String, dynamic>?;
    final challenged = json['challenged'] as Map<String, dynamic>?;
    final court = json['court'] as Map<String, dynamic>?;

    return ChallengeModel(
      id: json['id'] as String,
      sportId: json['sport_id'] as String?,
      challengerId: json['challenger_id'] as String,
      challengedId: json['challenged_id'] as String,
      status: ChallengeStatus.fromString(json['status'] as String),
      challengerPosition: json['challenger_position'] as int,
      challengedPosition: json['challenged_position'] as int,
      proposedDate1: json['proposed_date_1'] != null
          ? DateTime.parse(json['proposed_date_1'] as String)
          : null,
      proposedDate2: json['proposed_date_2'] != null
          ? DateTime.parse(json['proposed_date_2'] as String)
          : null,
      proposedDate3: json['proposed_date_3'] != null
          ? DateTime.parse(json['proposed_date_3'] as String)
          : null,
      chosenDate: json['chosen_date'] != null
          ? DateTime.parse(json['chosen_date'] as String)
          : null,
      weatherExtensionDays: json['weather_extension_days'] as int? ?? 0,
      playDeadline: json['play_deadline'] != null
          ? DateTime.parse(json['play_deadline'] as String)
          : null,
      winnerId: json['winner_id'] as String?,
      loserId: json['loser_id'] as String?,
      woPlayerId: json['wo_player_id'] as String?,
      resultSubmittedBy: json['result_submitted_by'] as String?,
      challengedAt: DateTime.parse(json['challenged_at'] as String),
      responseDeadline: json['response_deadline'] != null
          ? DateTime.parse(json['response_deadline'] as String)
          : null,
      datesProposedAt: json['dates_proposed_at'] != null
          ? DateTime.parse(json['dates_proposed_at'] as String)
          : null,
      dateChosenAt: json['date_chosen_at'] != null
          ? DateTime.parse(json['date_chosen_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'] as String)
          : null,
      courtId: json['court_id'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      challengerName: challenger?['full_name'] as String?,
      challengedName: challenged?['full_name'] as String?,
      challengerAvatarUrl: challenger?['avatar_url'] as String?,
      challengedAvatarUrl: challenged?['avatar_url'] as String?,
      courtName: court?['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'challenger_id': challengerId,
      'challenged_id': challengedId,
      if (sportId != null) 'sport_id': sportId,
      if (courtId != null) 'court_id': courtId,
      'status': status.dbValue,
      'challenger_position': challengerPosition,
      'challenged_position': challengedPosition,
      'proposed_date_1': proposedDate1?.toIso8601String(),
      'proposed_date_2': proposedDate2?.toIso8601String(),
      'proposed_date_3': proposedDate3?.toIso8601String(),
      'chosen_date': chosenDate?.toIso8601String(),
      'weather_extension_days': weatherExtensionDays,
      'play_deadline': playDeadline?.toIso8601String(),
      'winner_id': winnerId,
      'loser_id': loserId,
      'wo_player_id': woPlayerId,
      'notes': notes,
    };
  }
}
