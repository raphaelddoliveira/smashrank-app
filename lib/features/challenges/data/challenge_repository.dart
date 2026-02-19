import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/errors/error_handler.dart';
import '../../../services/supabase_service.dart';
import '../../../shared/models/challenge_model.dart';
import '../../../shared/models/club_member_model.dart';
import '../../../shared/models/match_model.dart';

final challengeRepositoryProvider = Provider<ChallengeRepository>((ref) {
  return ChallengeRepository(ref.watch(supabaseClientProvider));
});

class ChallengeRepository {
  final SupabaseClient _client;

  ChallengeRepository(this._client);

  static const _selectWithJoins = '''
    *,
    challenger:players!challenger_id(full_name, avatar_url),
    challenged:players!challenged_id(full_name, avatar_url)
  ''';

  /// Create a challenge via RPC
  Future<String> createChallenge(String challengedId, {required String clubId, required String sportId}) async {
    try {
      final authId = _client.auth.currentUser!.id;
      final result = await _client.rpc(
        SupabaseConstants.rpcCreateChallenge,
        params: {
          'p_challenger_auth_id': authId,
          'p_challenged_id': challengedId,
          'p_club_id': clubId,
          'p_sport_id': sportId,
        },
      );
      return result as String;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Get only active challenges for current player in a club + sport
  Future<List<ChallengeModel>> getActiveChallenges({required String clubId, String? sportId}) async {
    try {
      final playerId = await _getCurrentPlayerId();
      var query = _client
          .from(SupabaseConstants.challengesTable)
          .select(_selectWithJoins)
          .eq('club_id', clubId)
          .or('challenger_id.eq.$playerId,challenged_id.eq.$playerId')
          .inFilter('status', ['pending', 'dates_proposed', 'scheduled']);
      if (sportId != null) {
        query = query.eq('sport_id', sportId);
      }
      final data = await query.order('created_at', ascending: false);
      return data.map((e) => ChallengeModel.fromJson(e)).toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Get challenge history for current player in a club + sport
  Future<List<ChallengeModel>> getChallengeHistory({required String clubId, String? sportId}) async {
    try {
      final playerId = await _getCurrentPlayerId();
      var query = _client
          .from(SupabaseConstants.challengesTable)
          .select(_selectWithJoins)
          .eq('club_id', clubId)
          .or('challenger_id.eq.$playerId,challenged_id.eq.$playerId')
          .inFilter('status', [
            'completed', 'wo_challenger', 'wo_challenged', 'expired', 'cancelled'
          ]);
      if (sportId != null) {
        query = query.eq('sport_id', sportId);
      }
      final data = await query.order('completed_at', ascending: false).limit(50);
      return data.map((e) => ChallengeModel.fromJson(e)).toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Get a single challenge by ID
  Future<ChallengeModel> getChallenge(String challengeId) async {
    try {
      final data = await _client
          .from(SupabaseConstants.challengesTable)
          .select(_selectWithJoins)
          .eq('id', challengeId)
          .single();
      return ChallengeModel.fromJson(data);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Challenged player proposes 3 dates
  Future<void> proposeDates(
    String challengeId, {
    required DateTime date1,
    required DateTime date2,
    required DateTime date3,
  }) async {
    try {
      final challenge = await _client
          .from(SupabaseConstants.challengesTable)
          .select('challenger_id, club_id')
          .eq('id', challengeId)
          .single();

      await _client
          .from(SupabaseConstants.challengesTable)
          .update({
            'status': 'dates_proposed',
            'proposed_date_1': date1.toIso8601String(),
            'proposed_date_2': date2.toIso8601String(),
            'proposed_date_3': date3.toIso8601String(),
            'dates_proposed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', challengeId);

      await _client.from(SupabaseConstants.notificationsTable).insert({
        'player_id': challenge['challenger_id'],
        'type': 'dates_proposed',
        'title': 'Datas Propostas',
        'body': 'Seu oponente propos 3 datas para o desafio. Escolha uma!',
        'data': {'challenge_id': challengeId},
        'club_id': challenge['club_id'],
      });
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Challenger chooses one of the 3 proposed dates
  Future<void> chooseDate(String challengeId, DateTime chosenDate) async {
    try {
      final challenge = await _client
          .from(SupabaseConstants.challengesTable)
          .select('challenged_id, club_id')
          .eq('id', challengeId)
          .single();

      await _client
          .from(SupabaseConstants.challengesTable)
          .update({
            'status': 'scheduled',
            'chosen_date': chosenDate.toIso8601String(),
            'date_chosen_at': DateTime.now().toIso8601String(),
            'play_deadline': chosenDate
                .add(const Duration(days: 7))
                .toIso8601String(),
          })
          .eq('id', challengeId);

      await _client.from(SupabaseConstants.notificationsTable).insert({
        'player_id': challenge['challenged_id'],
        'type': 'date_chosen',
        'title': 'Data Confirmada',
        'body': 'A data do seu desafio foi confirmada. Confira os detalhes!',
        'data': {'challenge_id': challengeId},
        'club_id': challenge['club_id'],
      });
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Record match result via RPC
  Future<void> recordResult({
    required String challengeId,
    required String winnerId,
    required String loserId,
    required List<SetScore> sets,
    required int winnerSets,
    required int loserSets,
    bool superTiebreak = false,
  }) async {
    try {
      await _client.rpc(
        SupabaseConstants.rpcSwapRanking,
        params: {
          'p_challenge_id': challengeId,
          'p_winner_id': winnerId,
          'p_loser_id': loserId,
          'p_sets': sets.map((s) => s.toJson()).toList(),
          'p_winner_sets': winnerSets,
          'p_loser_sets': loserSets,
          'p_super_tiebreak': superTiebreak,
        },
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Cancel a challenge
  Future<void> cancelChallenge(String challengeId) async {
    try {
      final playerId = await _getCurrentPlayerId();

      final challenge = await _client
          .from(SupabaseConstants.challengesTable)
          .select('challenger_id, challenged_id, club_id')
          .eq('id', challengeId)
          .single();

      await _client
          .from(SupabaseConstants.challengesTable)
          .update({
            'status': 'cancelled',
            'cancelled_at': DateTime.now().toIso8601String(),
          })
          .eq('id', challengeId);

      final otherPlayerId = challenge['challenger_id'] == playerId
          ? challenge['challenged_id']
          : challenge['challenger_id'];

      await _client.from(SupabaseConstants.notificationsTable).insert({
        'player_id': otherPlayerId,
        'type': 'general',
        'title': 'Desafio Cancelado',
        'body': 'Um desafio em que você participava foi cancelado.',
        'data': {'challenge_id': challengeId},
        'club_id': challenge['club_id'],
      });
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Request weather extension (+2 days) for a scheduled challenge
  Future<void> requestWeatherExtension(String challengeId) async {
    try {
      final playerId = await _getCurrentPlayerId();

      final challenge = await _client
          .from(SupabaseConstants.challengesTable)
          .select('challenger_id, challenged_id, club_id, weather_extension_days, play_deadline')
          .eq('id', challengeId)
          .single();

      final currentExtension = challenge['weather_extension_days'] as int? ?? 0;
      final currentDeadline = DateTime.parse(challenge['play_deadline'] as String);

      await _client
          .from(SupabaseConstants.challengesTable)
          .update({
            'weather_extension_days': currentExtension + 2,
            'play_deadline': currentDeadline.add(const Duration(days: 2)).toIso8601String(),
          })
          .eq('id', challengeId);

      // Notify the other player
      final otherPlayerId = challenge['challenger_id'] == playerId
          ? challenge['challenged_id']
          : challenge['challenger_id'];

      await _client.from(SupabaseConstants.notificationsTable).insert({
        'player_id': otherPlayerId,
        'type': 'general',
        'title': 'Adiamento por Chuva',
        'body': 'O prazo do desafio foi estendido em +2 dias devido a chuva. Total: +${currentExtension + 2} dias.',
        'data': {'challenge_id': challengeId},
        'club_id': challenge['club_id'],
      });
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Get match result for a challenge
  Future<MatchModel?> getMatchForChallenge(String challengeId) async {
    try {
      final data = await _client
          .from(SupabaseConstants.matchesTable)
          .select()
          .eq('challenge_id', challengeId)
          .maybeSingle();
      if (data == null) return null;
      return MatchModel.fromJson(data);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Get eligible opponents from club_members (filtered by sport)
  Future<List<ClubMemberModel>> getEligibleOpponents({
    required String clubId,
    required String sportId,
    bool rulePositionGapEnabled = true,
  }) async {
    try {
      final playerId = await _getCurrentPlayerId();

      final myMember = await _client
          .from('club_members')
          .select('ranking_position')
          .eq('club_id', clubId)
          .eq('sport_id', sportId)
          .eq('player_id', playerId)
          .eq('status', 'active')
          .single();

      final myPosition = myMember['ranking_position'] as int;

      var query = _client
          .from('club_members')
          .select('*, player:players(full_name, nickname, avatar_url, email, phone)')
          .eq('club_id', clubId)
          .eq('sport_id', sportId)
          .eq('status', 'active')
          .neq('player_id', playerId)
          .lt('ranking_position', myPosition);

      // Only apply position gap filter if rule is enabled
      if (rulePositionGapEnabled) {
        final minPosition = myPosition - 2;
        query = query.gte('ranking_position', minPosition < 1 ? 1 : minPosition);
      }

      final opponents = await query.order('ranking_position');

      return opponents.map((e) => ClubMemberModel.fromJson(e)).toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Validate if a challenge can be created
  Future<Map<String, dynamic>> validateChallenge(
    String challengedId, {
    required String clubId,
    required String sportId,
  }) async {
    try {
      final playerId = await _getCurrentPlayerId();
      final result = await _client.rpc(
        SupabaseConstants.rpcValidateChallenge,
        params: {
          'p_challenger_id': playerId,
          'p_challenged_id': challengedId,
          'p_club_id': clubId,
          'p_sport_id': sportId,
        },
      );
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<String> _getCurrentPlayerId() async {
    final authId = _client.auth.currentUser!.id;
    final data = await _client
        .from(SupabaseConstants.playersTable)
        .select('id')
        .eq('auth_id', authId)
        .single();
    return data['id'] as String;
  }
}
