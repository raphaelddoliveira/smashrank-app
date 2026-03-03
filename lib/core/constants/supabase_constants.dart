abstract final class SupabaseConstants {
  // Table names
  static const String playersTable = 'players';
  static const String rankingHistoryTable = 'ranking_history';
  static const String challengesTable = 'challenges';
  static const String matchesTable = 'matches';
  static const String ambulancesTable = 'ambulances';
  static const String courtsTable = 'courts';
  static const String courtReservationsTable = 'court_reservations';
  static const String notificationsTable = 'notifications';
  static const String monthlyFeesTable = 'monthly_fees';
  static const String whatsappLogsTable = 'whatsapp_logs';
  static const String clubsTable = 'clubs';
  static const String clubMembersTable = 'club_members';
  static const String clubJoinRequestsTable = 'club_join_requests';
  static const String sportsTable = 'sports';
  static const String clubSportsTable = 'club_sports';

  // RPC function names
  static const String rpcSwapRanking = 'swap_ranking_after_challenge';
  static const String rpcActivateAmbulance = 'activate_ambulance';
  static const String rpcDeactivateAmbulance = 'deactivate_ambulance';
  static const String rpcApplyAmbulancePenalties = 'apply_ambulance_daily_penalties';
  static const String rpcApplyOverduePenalties = 'apply_overdue_penalties';
  static const String rpcApplyInactivityPenalties = 'apply_monthly_inactivity_penalties';
  static const String rpcValidateChallenge = 'validate_challenge_creation';
  static const String rpcCreateChallenge = 'create_challenge';
  static const String rpcExpirePendingChallenges = 'expire_pending_challenges';
  static const String rpcCreateClub = 'create_club';
  static const String rpcJoinClubByCode = 'join_club_by_code';
  static const String rpcApproveJoinRequest = 'approve_join_request';
  static const String rpcRejectJoinRequest = 'reject_join_request';
  static const String rpcEnrollMemberInSport = 'enroll_member_in_sport';
  static const String rpcRemoveClubMember = 'remove_club_member';
  static const String rpcAdminReorderRanking = 'admin_reorder_ranking';

  // Storage buckets
  static const String avatarsBucket = 'avatars';
  static const String receiptsBucket = 'receipts';
  static const String clubsBucket = 'clubs';
}
