import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/errors/app_exception.dart';
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
    court:courts!court_id(name),
    match:matches!challenge_id(winner_id, loser_id, winner_sets, loser_sets, sets)
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

  /// Admin: create challenge between any two players (no rule checks)
  Future<String> adminCreateChallenge({
    required String challengerId,
    required String challengedId,
    required String clubId,
    required String sportId,
  }) async {
    try {
      final authId = _client.auth.currentUser!.id;
      final result = await _client.rpc(
        SupabaseConstants.rpcAdminCreateChallenge,
        params: {
          'p_admin_auth_id': authId,
          'p_challenger_id': challengerId,
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

  /// Get all active members in a club sport (for admin challenge creation)
  Future<List<ClubMemberModel>> getAllMembers({
    required String clubId,
    required String sportId,
  }) async {
    try {
      final members = await _client
          .from('club_members')
          .select('*, player:players(full_name, nickname, avatar_url, email, phone)')
          .eq('club_id', clubId)
          .eq('sport_id', sportId)
          .eq('status', 'active')
          .order('ranking_position');
      return members.map((e) => ClubMemberModel.fromJson(e)).toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Get only active challenges for current player in a club + sport
  /// Aplica o WO automático nos desafios cujo prazo de resposta (48h) venceu.
  /// Falha em silêncio: é manutenção de fundo, não pode quebrar a listagem.
  Future<void> _expirePendingChallenges() async {
    try {
      await _client.rpc(SupabaseConstants.rpcExpirePendingChallenges);
    } catch (e) {
      debugPrint('expire_pending_challenges falhou: $e');
    }
  }

  /// Auto-expires challenges where all proposed dates have passed.
  Future<List<ChallengeModel>> getActiveChallenges({required String clubId, String? sportId}) async {
    try {
      // Desafio sem resposta em 48h vira WO. Isso dependia de um cron na
      // Vercel que NUNCA chegou a existir em produção — desafio expirado
      // ficava 'pending' para sempre, travando o desafiado pela regra de
      // "1 desafio ativo". Rodar aqui garante que a expiração acontece
      // sempre que alguém abre a lista de desafios.
      await _expirePendingChallenges();
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
          await _expireDatesProposedChallenge(c.id, c.challengerId, c.challengedId, clubId);
        } else {
          active.add(c);
        }
      }
      return active;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Get player IDs with active challenges in the club (for ranking badges)
  Future<Set<String>> getPlayersWithActiveChallenges({required String clubId, String? sportId}) async {
    try {
      var query = _client
          .from(SupabaseConstants.challengesTable)
          .select('challenger_id, challenged_id')
          .eq('club_id', clubId)
          .inFilter('status', ['pending', 'dates_proposed', 'scheduled', 'pending_result']);
      if (sportId != null) {
        query = query.eq('sport_id', sportId);
      }
      final data = await query;
      final playerIds = <String>{};
      for (final row in data) {
        playerIds.add(row['challenger_id'] as String);
        playerIds.add(row['challenged_id'] as String);
      }
      return playerIds;
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
      // Update status first — only notify if this succeeds
      await _client
          .from(SupabaseConstants.challengesTable)
          .update({
            'status': 'expired',
            'completed_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', challengeId);

      // Notify both players (best-effort after confirmed update)
      try {
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
        // Notification failure is non-critical
      }
    } catch (e) {
      // Log expiration failure so it can be retried
      debugPrint('Failed to expire challenge $challengeId: $e');
    }
  }

  /// Get upcoming scheduled challenges for all players in a club
  Future<List<ChallengeModel>> getUpcomingChallenges({required String clubId, String? sportId}) async {
    try {
      var query = _client
          .from(SupabaseConstants.challengesTable)
          .select(_selectWithJoins)
          .eq('club_id', clubId)
          .inFilter('status', ['scheduled', 'dates_proposed'])
          .not('chosen_date', 'is', null);
      if (sportId != null) {
        query = query.eq('sport_id', sportId);
      }
      final data = await query.order('chosen_date', ascending: true).limit(20);
      return data
          .map((e) => ChallengeModel.fromJson(e))
          .where((c) => c.chosenDate != null && c.chosenDate!.isAfter(DateTime.now().toUtc().subtract(const Duration(hours: 2))))
          .toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Get challenges without a defined date (pending court selection)
  Future<List<ChallengeModel>> getPendingDateChallenges({required String clubId, String? sportId}) async {
    try {
      var query = _client
          .from(SupabaseConstants.challengesTable)
          .select(_selectWithJoins)
          .eq('club_id', clubId)
          .inFilter('status', ['pending', 'dates_proposed'])
          .isFilter('chosen_date', null);
      if (sportId != null) {
        query = query.eq('sport_id', sportId);
      }
      final data = await query.order('created_at', ascending: false).limit(20);
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
      final data = await query.order('created_at', ascending: false).limit(50);
      return data.map((e) => ChallengeModel.fromJson(e)).toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Get challenge history for ALL players in the club (timeline)
  Future<List<ChallengeModel>> getAllChallengeHistory({required String clubId, String? sportId}) async {
    try {
      var query = _client
          .from(SupabaseConstants.challengesTable)
          .select(_selectWithJoins)
          .eq('club_id', clubId)
          .inFilter('status', [
            'completed', 'wo_challenger', 'wo_challenged', 'expired', 'cancelled'
          ]);
      if (sportId != null) {
        query = query.eq('sport_id', sportId);
      }
      final data = await query.order('created_at', ascending: false).limit(100);
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
  /// Status: pending -> scheduled (no acceptance needed — challenge is automatic).
  /// Also handles RESCHEDULE: if there's already an active reservation linked
  /// to this challenge, it is cancelled before creating the new one.
  Future<void> selectCourtAndDate(
    String challengeId, {
    required String courtId,
    required DateTime date,
    required String startTime,
    required String endTime,
    required String clubId,
  }) async {
    try {
      // 1. Get challenge info: both participants + deadline calculation
      final challenge = await _client
          .from(SupabaseConstants.challengesTable)
          .select('challenger_id, challenged_id, created_at, play_deadline')
          .eq('id', challengeId)
          .single();
      final challengerId = challenge['challenger_id'] as String;
      final challengedId = challenge['challenged_id'] as String;

      // 2. Build chosen_date with time info (local time, then convert to UTC for storage)
      final chosenDateTimeLocal = DateTime(
        date.year,
        date.month,
        date.day,
        int.parse(startTime.split(':')[0]),
        int.parse(startTime.split(':')[1]),
      );

      // 3. Deadline: keep existing if rescheduling, otherwise 7 days from creation
      final existingDeadline = challenge['play_deadline'];
      final String playDeadlineIso;
      if (existingDeadline != null) {
        playDeadlineIso = existingDeadline as String;
      } else {
        final createdAt =
            DateTime.parse(challenge['created_at'] as String).toLocal();
        final deadlineDate = DateTime(
            createdAt.year, createdAt.month, createdAt.day + 7, 23, 59, 59);
        playDeadlineIso = deadlineDate.toUtc().toIso8601String();
      }

      // 3b. Enforce the play deadline: the chosen date may not be later than
      //     the deadline (7 days counting from the day after the challenge).
      //     Without this guard a player could schedule the match for any day.
      final deadlineLocal = DateTime.parse(playDeadlineIso).toLocal();
      final deadlineDay = DateTime(
          deadlineLocal.year, deadlineLocal.month, deadlineLocal.day);
      final chosenDay = DateTime(date.year, date.month, date.day);
      if (chosenDay.isAfter(deadlineDay)) {
        String fmt(DateTime d) =>
            '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
        throw ChallengeException(
          'A data escolhida (${fmt(chosenDay)}) ultrapassa o prazo para jogar '
          '(até ${fmt(deadlineDay)}). O desafio deve ser jogado em até 7 dias.',
        );
      }

      // 4. Create the NEW reservation FIRST so any conflict fails before we
      //    touch the existing state (avoids leaving challenge orphaned)
      final currentPlayerId = await _getCurrentPlayerId();
      // A reserva deve SEMPRE ligar os dois participantes reais do desafio.
      // Se quem agenda é um dos jogadores, ele fica como reserved_by; se é um
      // ADMIN (não participante), o desafiante fica como reserved_by — nunca o
      // admin, senão o nome dele apareceria no jogo e o desafiado sumiria.
      final bool callerIsParticipant =
          currentPlayerId == challengerId || currentPlayerId == challengedId;
      final String reservedBy =
          callerIsParticipant ? currentPlayerId : challengerId;
      final String opponentId =
          reservedBy == challengerId ? challengedId : challengerId;
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final newReservation = await _client
          .from(SupabaseConstants.courtReservationsTable)
          .insert({
            'court_id': courtId,
            'reserved_by': reservedBy,
            'reservation_date': dateStr,
            'start_time': startTime,
            'end_time': endTime,
            'club_id': clubId,
            'challenge_id': challengeId,
            'opponent_id': opponentId,
            'opponent_type': 'member',
          })
          .select('id')
          .single();
      final newReservationId = newReservation['id'] as String;

      // 5. Cancel any previous active reservation linked to this challenge
      //    (excludes the one we just inserted). Vai por RPC porque o UPDATE
      //    direto batia em 0 linhas quando a reserva antiga era de OUTRO
      //    participante — a RLS bloqueia sem erro e a reserva velha ficava
      //    'confirmed', deixando o desafio em duas quadras/datas.
      await _cancelOtherReservations(challengeId, keepId: newReservationId);

      // 6. Update challenge to scheduled with new court/date
      await _client
          .from(SupabaseConstants.challengesTable)
          .update({
            'status': 'scheduled',
            'court_id': courtId,
            'chosen_date': chosenDateTimeLocal.toUtc().toIso8601String(),
            'dates_proposed_at': DateTime.now().toUtc().toIso8601String(),
            'date_chosen_at': DateTime.now().toUtc().toIso8601String(),
            'play_deadline': playDeadlineIso,
          })
          .eq('id', challengeId);

      // 7. Notify both players that the match is scheduled
      final notifyIds = <String>{challengerId, challengedId}
        ..remove(currentPlayerId);
      for (final id in notifyIds) {
        await _client.from(SupabaseConstants.notificationsTable).insert({
          'player_id': id,
          'type': 'challenge_accepted',
          'title': 'Desafio Agendado!',
          'body': 'Um desafio foi agendado. Quadra e horário já definidos!',
          'data': {'challenge_id': challengeId},
          'club_id': clubId,
        });
      }
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Reschedule a challenge: cancel old reservation, reset to pending so
  /// anyone can pick a new court/date via the select-court screen.
  Future<void> rescheduleChallenge(String challengeId) async {
    try {
      final challenge = await _client
          .from(SupabaseConstants.challengesTable)
          .select('challenger_id, challenged_id, club_id')
          .eq('id', challengeId)
          .single();

      // Cancel linked reservation(s)
      await _cancelOtherReservations(challengeId);

      // Reset court/date fields but keep status as pending
      await _client
          .from(SupabaseConstants.challengesTable)
          .update({
            'status': 'pending',
            'court_id': null,
            'chosen_date': null,
            'dates_proposed_at': null,
            'date_chosen_at': null,
            'play_deadline': null,
          })
          .eq('id', challengeId);

      // Notify both players
      final playerId = await _getCurrentPlayerId();
      final challengerId = challenge['challenger_id'] as String;
      final challengedId = challenge['challenged_id'] as String;
      final notifyIds = <String>[];
      if (playerId != challengerId) notifyIds.add(challengerId);
      if (playerId != challengedId) notifyIds.add(challengedId);

      for (final id in notifyIds) {
        await _client.from(SupabaseConstants.notificationsTable).insert({
          'player_id': id,
          'type': 'general',
          'title': 'Desafio Remarcado',
          'body': 'A data do desafio foi alterada. Aguarde o novo agendamento.',
          'data': {'challenge_id': challengeId},
          'club_id': challenge['club_id'],
        });
      }
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
          .select('challenger_id, chosen_date, club_id, created_at')
          .eq('id', challengeId)
          .single();

      final chosenDateStr = challenge['chosen_date'] as String?;
      if (chosenDateStr == null) {
        throw Exception('Desafio não possui data escolhida.');
      }

      // Deadline = 7 days from challenge creation, counting from the day after
      // creation. e.g. created 13/03 → first day = 14/03 → last day = 20/03
      final createdAt = DateTime.parse(challenge['created_at'] as String).toLocal();
      final deadlineDate = DateTime(createdAt.year, createdAt.month, createdAt.day + 7, 23, 59, 59);

      await _client
          .from(SupabaseConstants.challengesTable)
          .update({
            'status': 'scheduled',
            'date_chosen_at': DateTime.now().toUtc().toIso8601String(),
            'play_deadline': deadlineDate.toUtc().toIso8601String(),
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
      await _cancelOtherReservations(challengeId);

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

  /// Submit match result (auto-completes: ranking swap + cooldowns applied immediately)
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
      // Mark the linked court reservation as completed
      await _completeReservationForChallenge(challengeId);
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
      // Só a reserva realmente ativa vira 'completed'. O UPDATE antigo pegava
      // TODAS as reservas do desafio, sem filtro de status — reserva já
      // cancelada voltava como 'completed' e o jogo reaparecia na quadra
      // antiga (bug relatado no grupo).
      await _client.rpc(
        SupabaseConstants.rpcCompleteChallengeReservation,
        params: {'p_challenge_id': challengeId},
      );
    } catch (_) {
      // Silent fail — reservation might not exist
    }
  }

  /// Cancela as reservas ativas do desafio (opcionalmente preservando uma).
  /// Roda via RPC SECURITY DEFINER: o UPDATE direto era silenciosamente
  /// barrado pela RLS quando a reserva pertencia ao outro participante.
  Future<void> _cancelOtherReservations(
    String challengeId, {
    String? keepId,
  }) async {
    await _client.rpc(
      SupabaseConstants.rpcCancelChallengeReservations,
      params: {
        'p_challenge_id': challengeId,
        'p_keep_id': keepId,
      },
    );
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
      await _cancelOtherReservations(challengeId);

      await _client
          .from(SupabaseConstants.challengesTable)
          .update({
            'status': 'cancelled',
            'cancelled_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', challengeId);

      // Notifica os participantes, menos quem cancelou. Se quem cancelou for
      // um ADMIN (não participante), ambos os jogadores são avisados.
      final notifyIds = <String>{
        challenge['challenger_id'] as String,
        challenge['challenged_id'] as String,
      }..remove(playerId);
      for (final id in notifyIds) {
        await _client.from(SupabaseConstants.notificationsTable).insert({
          'player_id': id,
          'type': 'general',
          'title': 'Desafio Cancelado',
          'body': 'Um desafio em que você participava foi cancelado.',
          'data': {'challenge_id': challengeId},
          'club_id': challenge['club_id'],
        });
      }
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

  /// Admin: submit result directly (no confirmation needed)
  Future<void> adminSubmitResult({
    required String challengeId,
    required String winnerId,
    required String loserId,
    required List<SetScore> sets,
    required int winnerSets,
    required int loserSets,
    bool superTiebreak = false,
  }) async {
    try {
      final authId = _client.auth.currentUser!.id;
      await _client.rpc(
        SupabaseConstants.rpcAdminSubmitChallengeResult,
        params: {
          'p_admin_auth_id': authId,
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

  /// Request weather extension for a scheduled challenge.
  ///
  /// Regra: 1º uso no desafio = +3 dias; a partir do 2º uso = +1 dia
  /// (mesma lógica de [ChallengeModel.nextWeatherExtensionDays]).
  /// Solicita adiamento por chuva. NÃO estica o prazo: cria um pedido que um
  /// administrador do clube precisa liberar (pedido do clube em 29/09 — tinha
  /// jogador usando a opção sem ter chovido, só pra prorrogar o jogo).
  Future<void> requestWeatherExtension(String challengeId) async {
    try {
      await _client.rpc(
        SupabaseConstants.rpcRequestWeatherExtension,
        params: {'p_challenge_id': challengeId},
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Admin do clube libera (ou recusa) um pedido de adiamento por chuva.
  /// É aqui que o prazo é de fato esticado.
  Future<void> reviewWeatherExtension(String requestId, {required bool approve}) async {
    try {
      await _client.rpc(
        SupabaseConstants.rpcReviewWeatherExtension,
        params: {'p_request_id': requestId, 'p_approve': approve},
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Pedido de chuva aguardando liberação neste desafio, se houver.
  Future<Map<String, dynamic>?> getPendingWeatherRequest(String challengeId) async {
    try {
      final data = await _client
          .from(SupabaseConstants.weatherExtensionRequestsTable)
          .select('id, requested_by, created_at')
          .eq('challenge_id', challengeId)
          .eq('status', 'pending')
          .maybeSingle();
      return data;
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

      final myPosition = myMember['ranking_position'] as int?;
      if (myPosition == null) return []; // Player has no ranking position

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
