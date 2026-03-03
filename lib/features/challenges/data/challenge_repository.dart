import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/errors/error_handler.dart';
import '../../../services/supabase_service.dart';
import '../../../shared/models/challenge_model.dart';
import '../../../shared/models/club_member_model.dart';
import '../../../shared/models/h2h_model.dart';
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
    challenged:players!challenged_id(full_name, avatar_url),
    court:courts!court_id(name)
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
  /// Auto-expires challenges where all proposed dates have passed.
  Future<List<ChallengeModel>> getActiveChallenges({required String clubId, String? sportId}) async {
    try {
      final playerId = await _getCurrentPlayerId();
      var query = _client
          .from(SupabaseConstants.challengesTable)
          .select(_selectWithJoins)
          .eq('club_id', clubId)
          .or('challenger_id.eq.$playerId,challenged_id.eq.$playerId')
          .inFilter('status', ['pending', 'dates_proposed', 'scheduled', 'pending_result']);
      if (sportId != null) {
        query = query.eq('sport_id', sportId);
      }
      final data = await query.order('created_at', ascending: false);
      final challenges = data.map((e) => ChallengeModel.fromJson(e)).toList();

      // Auto-expire challenges where court date has passed (or legacy: all proposed dates passed)
      final active = <ChallengeModel>[];
      for (final c in challenges) {
        if (c.isCourtDateExpired || c.allProposedDatesExpired) {
          _expireDatesProposedChallenge(c.id, c.challengerId, c.challengedId, clubId);
        } else {
          active.add(c);
        }
      }
      return active;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Expire a challenge where all proposed dates have passed (no ranking change)
  Future<void> _expireDatesProposedChallenge(
    String challengeId,
    String challengerId,
    String challengedId,
    String clubId,
  ) async {
    try {
      await _client
          .from(SupabaseConstants.challengesTable)
          .update({
            'status': 'expired',
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', challengeId);

      // Notify both players
      await _client.from(SupabaseConstants.notificationsTable).insert([
        {
          'player_id': challengerId,
          'type': 'general',
          'title': 'Desafio Expirado',
          'body': 'Todas as datas propostas já passaram. O desafio foi encerrado sem alteração no ranking.',
          'data': {'challenge_id': challengeId},
          'club_id': clubId,
        },
        {
          'player_id': challengedId,
          'type': 'general',
          'title': 'Desafio Expirado',
          'body': 'Todas as datas propostas já passaram. O desafio foi encerrado sem alteração no ranking.',
          'data': {'challenge_id': challengeId},
          'club_id': clubId,
        },
      ]);
    } catch (_) {
      // Silent fail for background expiration
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

  /// Challenger selects a court + date/time and auto-creates a reservation.
  /// Status: pending -> dates_proposed (court selected, awaiting acceptance)
  Future<void> selectCourtAndDate(
    String challengeId, {
    required String courtId,
    required DateTime date,
    required String startTime,
    required String endTime,
    required String clubId,
  }) async {
    try {
      final playerId = await _getCurrentPlayerId();

      // 1. Get the challenged player ID for opponent info + notification
      final challenge = await _client
          .from(SupabaseConstants.challengesTable)
          .select('challenged_id')
          .eq('id', challengeId)
          .single();
      final challengedId = challenge['challenged_id'] as String;

      // 2. Create the court reservation linked to this challenge
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      await _client.from(SupabaseConstants.courtReservationsTable).insert({
        'court_id': courtId,
        'reserved_by': playerId,
        'reservation_date': dateStr,
        'start_time': startTime,
        'end_time': endTime,
        'club_id': clubId,
        'challenge_id': challengeId,
        'opponent_id': challengedId,
        'opponent_type': 'member',
      });

      // 3. Build chosen_date with time info
      final chosenDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        int.parse(startTime.split(':')[0]),
        int.parse(startTime.split(':')[1]),
      );

      // 4. Update challenge status
      await _client
          .from(SupabaseConstants.challengesTable)
          .update({
            'status': 'dates_proposed',
            'court_id': courtId,
            'chosen_date': chosenDateTime.toIso8601String(),
            'dates_proposed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', challengeId);

      // 5. Notify challenged player
      await _client.from(SupabaseConstants.notificationsTable).insert({
        'player_id': challengedId,
        'type': 'court_selected',
        'title': 'Quadra Reservada para Desafio',
        'body': 'Seu oponente reservou uma quadra. Aceite ou recuse o horário!',
        'data': {'challenge_id': challengeId},
        'club_id': clubId,
      });
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Challenged player accepts the court/date selection.
  /// Status: dates_proposed -> scheduled
  Future<void> acceptChallenge(String challengeId) async {
    try {
      final challenge = await _client
          .from(SupabaseConstants.challengesTable)
          .select('challenger_id, chosen_date, club_id')
          .eq('id', challengeId)
          .single();

      final chosenDate =
          DateTime.parse(challenge['chosen_date'] as String);

      await _client
          .from(SupabaseConstants.challengesTable)
          .update({
            'status': 'scheduled',
            'date_chosen_at': DateTime.now().toIso8601String(),
            'play_deadline': chosenDate
                .add(const Duration(days: 7))
                .toIso8601String(),
          })
          .eq('id', challengeId);

      await _client.from(SupabaseConstants.notificationsTable).insert({
        'player_id': challenge['challenger_id'],
        'type': 'challenge_accepted',
        'title': 'Desafio Aceito!',
        'body': 'Seu oponente aceitou o desafio. Jogo confirmado!',
        'data': {'challenge_id': challengeId},
        'club_id': challenge['club_id'],
      });
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Challenged player declines the court/date selection.
  /// Status: dates_proposed -> pending (challenger picks again)
  Future<void> declineChallenge(String challengeId) async {
    try {
      final challenge = await _client
          .from(SupabaseConstants.challengesTable)
          .select('challenger_id, club_id')
          .eq('id', challengeId)
          .single();

      // 1. Cancel linked reservation(s)
      final reservations = await _client
          .from(SupabaseConstants.courtReservationsTable)
          .select('id')
          .eq('challenge_id', challengeId)
          .eq('status', 'confirmed');

      for (final r in reservations) {
        await _client
            .from(SupabaseConstants.courtReservationsTable)
            .update({
              'status': 'cancelled',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', r['id']);
      }

      // 2. Reset challenge to pending
      await _client
          .from(SupabaseConstants.challengesTable)
          .update({
            'status': 'pending',
            'court_id': null,
            'chosen_date': null,
            'dates_proposed_at': null,
          })
          .eq('id', challengeId);

      // 3. Notify challenger
      await _client.from(SupabaseConstants.notificationsTable).insert({
        'player_id': challenge['challenger_id'],
        'type': 'challenge_declined',
        'title': 'Horário Recusado',
        'body':
            'Seu oponente recusou o horário proposto. Escolha outro!',
        'data': {'challenge_id': challengeId},
        'club_id': challenge['club_id'],
      });
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Submit match result (pending opponent confirmation)
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
      final playerId = await _getCurrentPlayerId();
      await _client.rpc(
        'submit_challenge_result',
        params: {
          'p_challenge_id': challengeId,
          'p_submitter_id': playerId,
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

  /// Confirm match result (opponent confirms → ranking updates)
  Future<void> confirmResult(String challengeId) async {
    try {
      final playerId = await _getCurrentPlayerId();
      await _client.rpc(
        'confirm_challenge_result',
        params: {
          'p_challenge_id': challengeId,
          'p_confirmer_id': playerId,
        },
      );
      // Mark the linked court reservation as completed
      await _completeReservationForChallenge(challengeId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Dispute match result (opponent contests → back to scheduled)
  Future<void> disputeResult(String challengeId) async {
    try {
      final playerId = await _getCurrentPlayerId();
      await _client.rpc(
        'dispute_challenge_result',
        params: {
          'p_challenge_id': challengeId,
          'p_disputer_id': playerId,
        },
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Record WO (walkover) via RPC
  Future<void> recordWo({
    required String challengeId,
    required String winnerId,
    required String loserId,
  }) async {
    try {
      await _client.rpc(
        'record_wo',
        params: {
          'p_challenge_id': challengeId,
          'p_winner_id': winnerId,
          'p_loser_id': loserId,
        },
      );
      // Mark the linked court reservation as completed
      await _completeReservationForChallenge(challengeId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Mark the court reservation linked to a challenge as completed
  Future<void> _completeReservationForChallenge(String challengeId) async {
    try {
      await _client
          .from(SupabaseConstants.courtReservationsTable)
          .update({
            'status': 'completed',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('challenge_id', challengeId);
    } catch (_) {
      // Silent fail — reservation might not exist
    }
  }

  /// Cancel a challenge (and its linked reservation, if any)
  Future<void> cancelChallenge(String challengeId) async {
    try {
      final playerId = await _getCurrentPlayerId();

      final challenge = await _client
          .from(SupabaseConstants.challengesTable)
          .select('challenger_id, challenged_id, club_id')
          .eq('id', challengeId)
          .single();

      // Cancel linked reservation(s)
      final reservations = await _client
          .from(SupabaseConstants.courtReservationsTable)
          .select('id')
          .eq('challenge_id', challengeId)
          .eq('status', 'confirmed');

      for (final r in reservations) {
        await _client
            .from(SupabaseConstants.courtReservationsTable)
            .update({
              'status': 'cancelled',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', r['id']);
      }

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

  /// Admin: annul a completed challenge (reverts ranking)
  Future<void> annulChallenge(String challengeId) async {
    try {
      final playerId = await _getCurrentPlayerId();
      await _client.rpc(
        'admin_annul_challenge',
        params: {
          'p_challenge_id': challengeId,
          'p_admin_id': playerId,
        },
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Admin: edit result of a completed challenge
  Future<void> adminEditResult({
    required String challengeId,
    required String winnerId,
    required String loserId,
    required List<SetScore> sets,
    required int winnerSets,
    required int loserSets,
    bool superTiebreak = false,
  }) async {
    try {
      final playerId = await _getCurrentPlayerId();
      await _client.rpc(
        'admin_edit_challenge_result',
        params: {
          'p_challenge_id': challengeId,
          'p_admin_id': playerId,
          'p_new_winner_id': winnerId,
          'p_new_loser_id': loserId,
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

  /// Get head-to-head stats between two players
  Future<H2HModel> getH2HStats(
    String player1Id,
    String player2Id, {
    required String clubId,
    String? sportId,
  }) async {
    try {
      // Get player names
      final players = await _client
          .from(SupabaseConstants.playersTable)
          .select('id, full_name')
          .inFilter('id', [player1Id, player2Id]);

      String? p1Name, p2Name;
      for (final p in players) {
        if (p['id'] == player1Id) p1Name = p['full_name'] as String?;
        if (p['id'] == player2Id) p2Name = p['full_name'] as String?;
      }

      // Get completed challenges between the two players with match data
      var query = _client
          .from(SupabaseConstants.challengesTable)
          .select('id, challenger_id, challenged_id, winner_id, loser_id, status, completed_at, created_at, match:${SupabaseConstants.matchesTable}!challenge_id(winner_sets, loser_sets, sets)')
          .eq('club_id', clubId)
          .inFilter('status', ['completed', 'wo_challenger', 'wo_challenged'])
          .or('and(challenger_id.eq.$player1Id,challenged_id.eq.$player2Id),and(challenger_id.eq.$player2Id,challenged_id.eq.$player1Id)');

      if (sportId != null) {
        query = query.eq('sport_id', sportId);
      }

      final data = await query.order('completed_at', ascending: false);

      // Flatten match join (Supabase returns array for 1-to-many, pick first)
      final rows = data.map<Map<String, dynamic>>((row) {
        final matchList = row['match'] as List<dynamic>?;
        return {
          ...row,
          'match': matchList != null && matchList.isNotEmpty
              ? matchList.first as Map<String, dynamic>
              : null,
        };
      }).toList();

      return H2HModel.fromQueryResults(
        player1Id: player1Id,
        player2Id: player2Id,
        player1Name: p1Name,
        player2Name: p2Name,
        rows: rows,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Get match history for a specific player (completed, WO)
  Future<List<ChallengeModel>> getPlayerMatchHistory({
    required String playerId,
    required String clubId,
    String? sportId,
    int limit = 20,
  }) async {
    try {
      var query = _client
          .from(SupabaseConstants.challengesTable)
          .select(_selectWithJoins)
          .eq('club_id', clubId)
          .or('challenger_id.eq.$playerId,challenged_id.eq.$playerId')
          .inFilter('status', ['completed', 'wo_challenger', 'wo_challenged']);
      if (sportId != null) {
        query = query.eq('sport_id', sportId);
      }
      final data = await query.order('completed_at', ascending: false).limit(limit);
      return data.map((e) => ChallengeModel.fromJson(e)).toList();
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
