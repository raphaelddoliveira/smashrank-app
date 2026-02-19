abstract final class AppConstants {
  // Challenge rules
  static const int maxChallengePositionsAhead = 2;
  static const Duration challengeResponseDeadline = Duration(hours: 48);
  static const Duration challengerCooldown = Duration(hours: 48);
  static const Duration challengedProtection = Duration(hours: 24);
  static const Duration gameDeadline = Duration(days: 7);
  static const Duration weatherExtension = Duration(days: 2);
  static const int minChallengesPerMonth = 1;

  // Ambulance rules
  static const int ambulanceImmediatePenalty = 3;
  static const Duration ambulanceProtectionPeriod = Duration(days: 10);
  static const int ambulanceDailyPenalty = 1;
  static const int maxAmbulanceDays = 15;

  // Payment rules
  static const int overdueDaysForPenalty = 15;
  static const int overduePositionPenalty = 10;

  // WO rules
  static const Duration woToleranceDefault = Duration(minutes: 15);
  static const Duration woToleranceAgreed = Duration(minutes: 30);

  // Match rules
  static const int bestOfSets = 3;
  static const int gamesPerSet = 6;
  static const int tiebreakMinGames = 7;

  // Deep link scheme
  static const String deepLinkScheme = 'atsranking';
  static const String deepLinkHost = 'ats.ranking.app';
}
