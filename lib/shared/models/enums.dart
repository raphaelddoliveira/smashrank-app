// Enums mirroring the database enum types

enum PlayerStatus {
  active,
  inactive,
  ambulance,
  suspended;

  String get label => switch (this) {
        active => 'Ativo',
        inactive => 'Inativo',
        ambulance => 'Ambulância',
        suspended => 'Suspenso',
      };

  static PlayerStatus fromString(String value) =>
      PlayerStatus.values.firstWhere((e) => e.name == value);
}

enum PlayerRole {
  player,
  admin;

  static PlayerRole fromString(String value) =>
      PlayerRole.values.firstWhere((e) => e.name == value);
}

enum ChallengeStatus {
  pending,
  datesProposed('dates_proposed'),
  scheduled,
  pendingResult('pending_result'),
  completed,
  woChallenger('wo_challenger'),
  woChallenged('wo_challenged'),
  expired,
  cancelled,
  annulled;

  final String? _dbValue;
  const ChallengeStatus([this._dbValue]);

  String get dbValue => _dbValue ?? name;

  static ChallengeStatus fromString(String value) =>
      ChallengeStatus.values.firstWhere(
        (e) => e.dbValue == value || e.name == value,
      );

  bool get isActive =>
      this == pending ||
      this == datesProposed ||
      this == scheduled ||
      this == pendingResult;

  bool get isFinished =>
      this == completed ||
      this == woChallenger ||
      this == woChallenged ||
      this == expired ||
      this == cancelled ||
      this == annulled;
}

enum PaymentStatus {
  pending,
  paid,
  overdue;

  String get label => switch (this) {
        pending => 'Pendente',
        paid => 'Em dia',
        overdue => 'Atrasada',
      };

  static PaymentStatus fromString(String value) =>
      PaymentStatus.values.firstWhere((e) => e.name == value);
}

enum ReservationStatus {
  confirmed,
  cancelled,
  completed;

  static ReservationStatus fromString(String value) =>
      ReservationStatus.values.firstWhere((e) => e.name == value,
          orElse: () => ReservationStatus.confirmed);
}

enum ClubMemberRole {
  admin,
  member;

  static ClubMemberRole fromString(String value) =>
      ClubMemberRole.values.firstWhere((e) => e.name == value);
}

enum ClubMemberStatus {
  active,
  pending,
  inactive;

  String get label => switch (this) {
        active => 'Ativo',
        pending => 'Pendente',
        inactive => 'Inativo',
      };

  static ClubMemberStatus fromString(String value) =>
      ClubMemberStatus.values.firstWhere((e) => e.name == value);
}

enum JoinRequestStatus {
  pending,
  approved,
  rejected;

  static JoinRequestStatus fromString(String value) =>
      JoinRequestStatus.values.firstWhere((e) => e.name == value);
}

enum ScoringType {
  setsGames('sets_games'),
  setsPoints('sets_points'),
  simpleScore('simple_score');

  final String dbValue;
  const ScoringType(this.dbValue);

  static ScoringType fromString(String value) =>
      ScoringType.values.firstWhere(
        (e) => e.dbValue == value || e.name == value,
      );
}

enum NotificationType {
  challengeReceived('challenge_received'),
  datesProposed('dates_proposed'),
  dateChosen('date_chosen'),
  matchResult('match_result'),
  rankingChange('ranking_change'),
  ambulanceActivated('ambulance_activated'),
  ambulanceExpired('ambulance_expired'),
  paymentDue('payment_due'),
  paymentOverdue('payment_overdue'),
  woWarning('wo_warning'),
  monthlyChallengeWarning('monthly_challenge_warning'),
  courtSelected('court_selected'),
  challengeAccepted('challenge_accepted'),
  challengeDeclined('challenge_declined'),
  general('general');

  final String dbValue;
  const NotificationType(this.dbValue);

  static NotificationType fromString(String value) =>
      NotificationType.values.firstWhere(
        (e) => e.dbValue == value || e.name == value,
      );
}

enum OpponentType {
  member,
  guest;

  String get label => switch (this) {
        member => 'Membro',
        guest => 'Convidado',
      };

  static OpponentType fromString(String value) =>
      OpponentType.values.firstWhere((e) => e.name == value);
}

enum DominantHand {
  right,
  left;

  String get label => switch (this) {
        right => 'Destro',
        left => 'Canhoto',
      };

  static DominantHand fromString(String value) =>
      DominantHand.values.firstWhere((e) => e.name == value);
}

enum BackhandType {
  oneHanded('one_handed'),
  twoHanded('two_handed');

  final String dbValue;
  const BackhandType(this.dbValue);

  String get label => switch (this) {
        oneHanded => 'Uma mão',
        twoHanded => 'Duas mãos',
      };

  static BackhandType fromString(String value) =>
      BackhandType.values.firstWhere(
        (e) => e.dbValue == value || e.name == value,
      );
}
