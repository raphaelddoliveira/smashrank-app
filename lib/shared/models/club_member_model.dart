import 'enums.dart';

class ClubMemberModel {
  final String id;
  final String clubId;
  final String playerId;
  final String? sportId;
  final ClubMemberRole role;
  final int? rankingPosition;
  final int challengesThisMonth;
  final DateTime? lastChallengeDate;
  final DateTime? challengerCooldownUntil;
  final DateTime? challengedProtectionUntil;
  final bool ambulanceActive;
  final DateTime? ambulanceStartedAt;
  final DateTime? ambulanceProtectionUntil;
  final bool mustBeChallengedFirst;
  final bool rankingOptIn;
  final ClubMemberStatus status;
  final DateTime joinedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined from players table
  final String playerName;
  final String? playerNickname;
  final String? playerAvatarUrl;
  final String? playerEmail;
  final String? playerPhone;

  // Joined from sports table
  final String? sportName;
  final String? sportScoringType;

  const ClubMemberModel({
    required this.id,
    required this.clubId,
    required this.playerId,
    this.sportId,
    this.role = ClubMemberRole.member,
    this.rankingPosition,
    this.challengesThisMonth = 0,
    this.lastChallengeDate,
    this.challengerCooldownUntil,
    this.challengedProtectionUntil,
    this.ambulanceActive = false,
    this.ambulanceStartedAt,
    this.ambulanceProtectionUntil,
    this.mustBeChallengedFirst = false,
    this.rankingOptIn = true,
    this.status = ClubMemberStatus.active,
    required this.joinedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.playerName,
    this.playerNickname,
    this.playerAvatarUrl,
    this.playerEmail,
    this.playerPhone,
    this.sportName,
    this.sportScoringType,
  });

  bool get isClubAdmin => role == ClubMemberRole.admin;
  bool get isActive => status == ClubMemberStatus.active;

  bool get isOnCooldown =>
      challengerCooldownUntil != null &&
      challengerCooldownUntil!.isAfter(DateTime.now());

  bool get isProtected =>
      challengedProtectionUntil != null &&
      challengedProtectionUntil!.isAfter(DateTime.now());

  bool get isOnAmbulance => ambulanceActive;

  bool get isInRanking => rankingOptIn && rankingPosition != null;

  String get displayName => playerNickname ?? playerName;

  factory ClubMemberModel.fromJson(Map<String, dynamic> json) {
    // Handle nested player data from join query
    final player = json['player'] as Map<String, dynamic>?;
    // Handle nested sport data from join query
    final sport = json['sport'] as Map<String, dynamic>?;

    return ClubMemberModel(
      id: json['id'] as String,
      clubId: json['club_id'] as String,
      playerId: json['player_id'] as String,
      sportId: json['sport_id'] as String?,
      role: ClubMemberRole.fromString(json['role'] as String),
      rankingPosition: json['ranking_position'] as int?,
      challengesThisMonth: json['challenges_this_month'] as int? ?? 0,
      lastChallengeDate: json['last_challenge_date'] != null
          ? DateTime.parse(json['last_challenge_date'] as String)
          : null,
      challengerCooldownUntil: json['challenger_cooldown_until'] != null
          ? DateTime.parse(json['challenger_cooldown_until'] as String)
          : null,
      challengedProtectionUntil: json['challenged_protection_until'] != null
          ? DateTime.parse(json['challenged_protection_until'] as String)
          : null,
      ambulanceActive: json['ambulance_active'] as bool? ?? false,
      ambulanceStartedAt: json['ambulance_started_at'] != null
          ? DateTime.parse(json['ambulance_started_at'] as String)
          : null,
      ambulanceProtectionUntil: json['ambulance_protection_until'] != null
          ? DateTime.parse(json['ambulance_protection_until'] as String)
          : null,
      mustBeChallengedFirst: json['must_be_challenged_first'] as bool? ?? false,
      rankingOptIn: json['ranking_opt_in'] as bool? ?? true,
      status: ClubMemberStatus.fromString(json['status'] as String),
      joinedAt: DateTime.parse(json['joined_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      playerName: player?['full_name'] as String? ?? json['player_name'] as String? ?? 'Jogador',
      playerNickname: player?['nickname'] as String? ?? json['player_nickname'] as String?,
      playerAvatarUrl: player?['avatar_url'] as String? ?? json['player_avatar_url'] as String?,
      playerEmail: player?['email'] as String? ?? json['player_email'] as String?,
      playerPhone: player?['phone'] as String? ?? json['player_phone'] as String?,
      sportName: sport?['name'] as String?,
      sportScoringType: sport?['scoring_type'] as String?,
    );
  }
}
