abstract final class RouteNames {
  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String forgotPassword = '/auth/forgot-password';

  // Main tabs
  static const String ranking = '/ranking';
  static const String challenges = '/challenges';
  static const String courts = '/courts';
  static const String notifications = '/notifications';
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';

  // Ranking
  static const String rankingHistory = '/ranking/history/:playerId';

  // Challenges
  static const String createChallenge = '/challenges/create';
  static const String challengeDetail = '/challenges/:challengeId';
  static const String selectCourt = '/challenges/:challengeId/select-court';
  static const String recordResult = '/challenges/:challengeId/record-result';
  static const String h2h = '/challenges/:challengeId/h2h';

  // Courts
  static const String courtSchedule = '/courts/:courtId/schedule';
  static const String myReservations = '/courts/my-reservations';

  // Clubs
  static const String clubs = '/clubs';
  static const String createClub = '/clubs/create';
  static const String joinClub = '/clubs/join';
  static const String clubManagement = '/clubs/:clubId/manage';
  static const String editClub = '/clubs/:clubId/edit';

  // Admin
  static const String adminDashboard = '/admin';
  static const String adminPlayers = '/admin/players';
  static const String adminAmbulances = '/admin/ambulances';
  static const String adminSports = '/admin/sports';

  // Player public profile
  static const String playerProfile = '/players/:playerId';

  // Court slots admin
  static const String courtSlots = '/courts/:courtId/slots';
}
