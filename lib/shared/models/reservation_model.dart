import 'enums.dart';

class ReservationModel {
  final String id;
  final String? courtSlotId;
  final String courtId;
  final String reservedBy;
  final DateTime reservationDate;
  final String startTime;
  final String endTime;
  final ReservationStatus status;
  final String? challengeId;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Opponent fields
  final String? opponentId;
  final OpponentType? opponentType;
  final String? opponentName;

  // Candidate field
  final String? candidateId;

  // Joined fields
  final String? courtName;
  final String? playerName;
  final String? opponentPlayerName;
  final String? candidatePlayerName;

  const ReservationModel({
    required this.id,
    this.courtSlotId,
    required this.courtId,
    required this.reservedBy,
    required this.reservationDate,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.challengeId,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.opponentId,
    this.opponentType,
    this.opponentName,
    this.candidateId,
    this.courtName,
    this.playerName,
    this.opponentPlayerName,
    this.candidatePlayerName,
  });

  bool get isConfirmed => status == ReservationStatus.confirmed;
  bool get isCancelled => status == ReservationStatus.cancelled;
  bool get isPast => reservationDate.isBefore(DateTime.now());
  bool get isChallenge => challengeId != null;
  bool get isFriendly => challengeId == null;
  bool get hasOpponentDeclared => opponentType != null;
  bool get hasCandidate => candidateId != null;

  String get opponentDisplayName {
    if (opponentType == null) return 'Não declarado';
    if (opponentType == OpponentType.guest) {
      return opponentName ?? 'Convidado';
    }
    return opponentPlayerName ?? opponentName ?? 'Membro';
  }

  String get timeRange {
    final start = _formatTime(startTime);
    final end = _formatTime(endTime);
    return '$start - $end';
  }

  String get formattedDate {
    final d = reservationDate;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  static String _formatTime(String time) {
    final parts = time.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return time;
  }

  factory ReservationModel.fromJson(Map<String, dynamic> json) {
    final court = json['court'] as Map<String, dynamic>?;
    final player = json['player'] as Map<String, dynamic>?;
    final opponent = json['opponent'] as Map<String, dynamic>?;
    final candidate = json['candidate'] as Map<String, dynamic>?;

    return ReservationModel(
      id: json['id'] as String,
      courtSlotId: json['court_slot_id'] as String?,
      courtId: json['court_id'] as String,
      reservedBy: json['reserved_by'] as String,
      reservationDate: DateTime.parse(json['reservation_date'] as String),
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      status: ReservationStatus.fromString(json['status'] as String),
      challengeId: json['challenge_id'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      opponentId: json['opponent_id'] as String?,
      opponentType: json['opponent_type'] != null
          ? OpponentType.fromString(json['opponent_type'] as String)
          : null,
      opponentName: json['opponent_name'] as String?,
      candidateId: json['candidate_id'] as String?,
      courtName: court?['name'] as String?,
      playerName: player?['full_name'] as String?,
      opponentPlayerName: opponent?['full_name'] as String?,
      candidatePlayerName: candidate?['full_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (courtSlotId != null) 'court_slot_id': courtSlotId,
      'court_id': courtId,
      'reserved_by': reservedBy,
      'reservation_date': '${reservationDate.year}-${reservationDate.month.toString().padLeft(2, '0')}-${reservationDate.day.toString().padLeft(2, '0')}',
      'start_time': startTime,
      'end_time': endTime,
      'status': status.name,
      if (challengeId != null) 'challenge_id': challengeId,
      if (notes != null) 'notes': notes,
      if (opponentId != null) 'opponent_id': opponentId,
      if (opponentType != null) 'opponent_type': opponentType!.name,
      if (opponentName != null) 'opponent_name': opponentName,
    };
  }
}
