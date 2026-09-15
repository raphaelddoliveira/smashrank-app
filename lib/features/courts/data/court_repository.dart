import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/error_handler.dart';
import '../../../services/supabase_service.dart';
import '../../../shared/models/court_model.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/reservation_model.dart';

final courtRepositoryProvider = Provider<CourtRepository>((ref) {
  return CourtRepository(ref.watch(supabaseClientProvider));
});

class CourtRepository {
  final SupabaseClient _client;

  CourtRepository(this._client);

  static const _reservationSelect = '''
    *,
    court:courts!court_id(name),
    player:players!reserved_by(full_name),
    opponent:players!opponent_id(full_name),
    candidate:players!candidate_id(full_name)
''';

  /// Get all active courts for a club, optionally filtered by sport
  Future<List<CourtModel>> getCourts({required String clubId, String? sportId}) async {
    try {
      var query = _client
          .from(SupabaseConstants.courtsTable)
          .select()
          .eq('club_id', clubId)
          .eq('is_active', true);
      if (sportId != null) {
        query = query.eq('sport_id', sportId);
      }
      final data = await query.order('name');
      return data.map((e) => CourtModel.fromJson(e)).toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Get all courts for a club (including inactive — for admin), optionally filtered by sport
  Future<List<CourtModel>> getAllCourts({required String clubId, String? sportId}) async {
    try {
      var query = _client
          .from(SupabaseConstants.courtsTable)
          .select()
          .eq('club_id', clubId);
      if (sportId != null) {
        query = query.eq('sport_id', sportId);
      }
      final data = await query.order('name');
      return data.map((e) => CourtModel.fromJson(e)).toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Get a single court by ID
  Future<CourtModel> getCourtById(String courtId) async {
    try {
      final data = await _client
          .from(SupabaseConstants.courtsTable)
          .select()
          .eq('id', courtId)
          .single();
      return CourtModel.fromJson(data);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Create a new court linked to a sport (with schedule config defaults)
  Future<void> createCourt({
    required String clubId,
    required String sportId,
    required String name,
    String? surfaceType,
    bool isCovered = false,
    String? notes,
  }) async {
    try {
      await _client.from(SupabaseConstants.courtsTable).insert({
        'club_id': clubId,
        'sport_id': sportId,
        'name': name,
        'surface_type': surfaceType,
        'is_covered': isCovered,
        'notes': notes,
      });
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Update an existing court
  Future<void> updateCourt(
    String courtId, {
    String? name,
    String? surfaceType,
    bool? isCovered,
    String? notes,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (surfaceType != null) updates['surface_type'] = surfaceType;
      if (isCovered != null) updates['is_covered'] = isCovered;
      if (notes != null) updates['notes'] = notes;
      await _client
          .from(SupabaseConstants.courtsTable)
          .update(updates)
          .eq('id', courtId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Update court schedule configuration
  Future<void> updateCourtSchedule(
    String courtId, {
    required int slotDurationMinutes,
    required String openingTime,
    required String closingTime,
    required List<int> operatingDays,
  }) async {
    try {
      await _client.from(SupabaseConstants.courtsTable).update({
        'slot_duration_minutes': slotDurationMinutes,
        'opening_time': openingTime,
        'closing_time': closingTime,
        'operating_days': operatingDays,
      }).eq('id', courtId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Deactivate a court (soft delete)
  Future<void> deactivateCourt(String courtId) async {
    try {
      await _client
          .from(SupabaseConstants.courtsTable)
          .update({'is_active': false})
          .eq('id', courtId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Reactivate a court
  Future<void> reactivateCourt(String courtId) async {
    try {
      await _client
          .from(SupabaseConstants.courtsTable)
          .update({'is_active': true})
          .eq('id', courtId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  // ─── Reservations ───

  /// Get reservations for a court on a specific date
  Future<List<ReservationModel>> getReservationsForDate(
    String courtId, {
    required DateTime date,
  }) async {
    try {
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final data = await _client
          .from(SupabaseConstants.courtReservationsTable)
          .select(_reservationSelect)
          .eq('court_id', courtId)
          .eq('reservation_date', dateStr)
          .eq('status', 'confirmed')
          .order('start_time');
      return data.map((e) => ReservationModel.fromJson(e)).toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Create a reservation
  Future<void> createReservation({
    required String courtId,
    required DateTime date,
    required String startTime,
    required String endTime,
    String? clubId,
    String? challengeId,
    String? notes,
    String? opponentId,
    OpponentType? opponentType,
    String? opponentName,
  }) async {
    try {
      final playerId = await _getCurrentPlayerId();
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      // Friendly (non-ranking) reservations can only be booked up to D+2.
      // Challenge reservations (challengeId != null) follow the 7-day rule and
      // admin reservations use dedicated methods, so neither is affected here.
      if (challengeId == null) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final maxDate = today
            .add(const Duration(days: AppConstants.friendlyReservationMaxDaysAhead));
        final chosenDay = DateTime(date.year, date.month, date.day);
        if (chosenDay.isAfter(maxDate)) {
          throw const ValidationException(
            'Reservas amistosas só podem ser feitas com até 2 dias de '
            'antecedência (hoje, amanhã ou depois de amanhã).',
            code: 'RESERVATION_TOO_FAR_AHEAD',
          );
        }
      }

      // Check if the slot is already taken (prevent double-booking)
      final existing = await _client
          .from(SupabaseConstants.courtReservationsTable)
          .select('id')
          .eq('court_id', courtId)
          .eq('reservation_date', dateStr)
          .eq('start_time', startTime)
          .eq('status', 'confirmed')
          .maybeSingle();
      if (existing != null) {
        throw const ValidationException(
          'Este horário já está reservado.',
          code: 'SLOT_ALREADY_BOOKED',
        );
      }

      // For friendly reservations, validate opponent doesn't already have one
      if (opponentId != null && challengeId == null && opponentType == OpponentType.member) {
        final opponentHasReservation =
            await playerHasActiveFriendlyReservation(opponentId);
        if (opponentHasReservation) {
          throw const ValidationException(
            'Este jogador já tem uma reserva amistosa ativa.',
            code: 'OPPONENT_HAS_RESERVATION',
          );
        }
      }

      await _client.from(SupabaseConstants.courtReservationsTable).insert({
        'court_id': courtId,
        'reserved_by': playerId,
        'reservation_date': dateStr,
        'start_time': startTime,
        'end_time': endTime,
        if (clubId != null) 'club_id': clubId,
        if (challengeId != null) 'challenge_id': challengeId,
        if (notes != null) 'notes': notes,
        if (opponentId != null) 'opponent_id': opponentId,
        if (opponentType != null) 'opponent_type': opponentType.name,
        if (opponentName != null) 'opponent_name': opponentName,
      });
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Cancel a reservation
  Future<void> cancelReservation(String reservationId) async {
    try {
      await _client
          .from(SupabaseConstants.courtReservationsTable)
          .update({
            'status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', reservationId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Get current player's reservations (own + as accepted opponent)
  Future<List<ReservationModel>> getMyReservations() async {
    try {
      final playerId = await _getCurrentPlayerId();
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final data = await _client
          .from(SupabaseConstants.courtReservationsTable)
          .select(_reservationSelect)
          .or('reserved_by.eq.$playerId,opponent_id.eq.$playerId')
          .eq('status', 'confirmed')
          .gte('reservation_date', dateStr)
          .order('reservation_date')
          .order('start_time');
      return data.map((e) => ReservationModel.fromJson(e)).toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Get all reservations history for current player
  Future<List<ReservationModel>> getMyReservationHistory() async {
    try {
      final playerId = await _getCurrentPlayerId();
      final data = await _client
          .from(SupabaseConstants.courtReservationsTable)
          .select(_reservationSelect)
          .eq('reserved_by', playerId)
          .order('reservation_date', ascending: false)
          .order('start_time', ascending: false)
          .limit(50);
      return data.map((e) => ReservationModel.fromJson(e)).toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Get the reservation linked to a challenge
  Future<ReservationModel?> getReservationForChallenge(
      String challengeId) async {
    try {
      final data = await _client
          .from(SupabaseConstants.courtReservationsTable)
          .select(_reservationSelect)
          .eq('challenge_id', challengeId)
          .eq('status', 'confirmed')
          .maybeSingle();
      if (data == null) return null;
      return ReservationModel.fromJson(data);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Count active friendly (non-challenge, non-administrative) reservations for current player
  /// Includes reservations where player is owner OR opponent
  Future<int> getActiveFriendlyReservationCount() async {
    try {
      final playerId = await _getCurrentPlayerId();
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final data = await _client
          .from(SupabaseConstants.courtReservationsTable)
          .select('id, reservation_date, end_time')
          .or('reserved_by.eq.$playerId,opponent_id.eq.$playerId')
          .eq('status', 'confirmed')
          .isFilter('challenge_id', null)
          .neq('reservation_type', 'administrative')
          .gte('reservation_date', dateStr);
      // Filter out today's reservations that already ended
      final active = data.where((r) {
        final date = r['reservation_date'] as String;
        if (date == dateStr) {
          return (r['end_time'] as String).compareTo(timeStr) > 0;
        }
        return true;
      }).toList();
      return active.length;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Check if a specific player has an active friendly reservation
  Future<bool> playerHasActiveFriendlyReservation(String playerId) async {
    try {
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final data = await _client
          .from(SupabaseConstants.courtReservationsTable)
          .select('id, reservation_date, end_time')
          .or('reserved_by.eq.$playerId,opponent_id.eq.$playerId')
          .eq('status', 'confirmed')
          .isFilter('challenge_id', null)
          .neq('reservation_type', 'administrative')
          .gte('reservation_date', dateStr);
      // Only count reservations that haven't ended yet
      return data.any((r) {
        final date = r['reservation_date'] as String;
        if (date == dateStr) {
          return (r['end_time'] as String).compareTo(timeStr) > 0;
        }
        return true;
      });
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Update the opponent on an existing reservation
  Future<void> updateReservationOpponent(
    String reservationId, {
    required OpponentType opponentType,
    String? opponentId,
    String? opponentName,
  }) async {
    try {
      // If adding a member as opponent, check if they already have a reservation
      if (opponentId != null && opponentType == OpponentType.member) {
        final hasReservation =
            await playerHasActiveFriendlyReservation(opponentId);
        if (hasReservation) {
          throw const ValidationException(
            'Este jogador já tem uma reserva amistosa ativa.',
            code: 'OPPONENT_HAS_RESERVATION',
          );
        }
      }

      await _client
          .from(SupabaseConstants.courtReservationsTable)
          .update({
            'opponent_type': opponentType.name,
            'opponent_id': opponentId,
            'opponent_name': opponentName,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', reservationId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Sai de uma reserva amistosa em que você é o adversário, deixando a VAGA
  /// ABERTA — o dono mantém o horário e pode chamar outra pessoa.
  ///
  /// Vai por RPC porque, ao limpar o próprio nome, a linha resultante não tem
  /// mais vínculo com quem edita e o WITH CHECK da policy rejeitaria.
  Future<void> leaveReservation(String reservationId) async {
    try {
      await _client.rpc(
        SupabaseConstants.rpcLeaveReservation,
        params: {'p_reservation_id': reservationId},
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Join an open reservation directly as opponent
  Future<void> applyToReservation(String reservationId) async {
    try {
      final playerId = await _getCurrentPlayerId();

      // Check if the player already has an active friendly reservation
      final hasReservation =
          await playerHasActiveFriendlyReservation(playerId);
      if (hasReservation) {
        throw const ValidationException(
          'Você já tem uma reserva amistosa ativa. Cancele ou conclua antes de entrar.',
          code: 'PLAYER_HAS_RESERVATION',
        );
      }

      // Verify the reservation is still open (no opponent yet) to prevent race conditions
      final current = await _client
          .from(SupabaseConstants.courtReservationsTable)
          .select('opponent_id, reserved_by')
          .eq('id', reservationId)
          .single();

      if (current['opponent_id'] != null) {
        throw const ValidationException(
          'Esta reserva já tem um oponente.',
          code: 'RESERVATION_FULL',
        );
      }

      if (current['reserved_by'] == playerId) {
        throw const ValidationException(
          'Você não pode entrar na sua própria reserva.',
          code: 'SELF_JOIN',
        );
      }

      // Get player name
      final playerData = await _client
          .from(SupabaseConstants.playersTable)
          .select('full_name')
          .eq('id', playerId)
          .single();

      final playerName = playerData['full_name'] as String? ?? 'Jogador';

      // Set as opponent — filter by opponent_id IS NULL to prevent race condition
      await _client
          .from(SupabaseConstants.courtReservationsTable)
          .update({
            'opponent_id': playerId,
            'opponent_type': 'member',
            'opponent_name': playerName,
            'candidate_id': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', reservationId)
          .isFilter('opponent_id', null);

      // Get reservation details for notification
      final res = await _client
          .from(SupabaseConstants.courtReservationsTable)
          .select('reserved_by, court_id, reservation_date, club_id, court:courts!court_id(name)')
          .eq('id', reservationId)
          .single();

      final courtName = (res['court'] as Map<String, dynamic>?)?['name'] ?? 'Quadra';

      await _client.from(SupabaseConstants.notificationsTable).insert({
        'player_id': res['reserved_by'],
        'type': 'general',
        'title': 'Vaga preenchida!',
        'body': '$playerName entrou na sua reserva de $courtName dia ${res['reservation_date']}',
        'data': {'reservation_id': reservationId},
        if (res['club_id'] != null) 'club_id': res['club_id'],
      });
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Get upcoming reservations for a specific player in a club (admin use)
  Future<List<ReservationModel>> getPlayerClubReservations(
    String playerId, {
    required String clubId,
  }) async {
    try {
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Get courts for this club
      final courts = await _client
          .from(SupabaseConstants.courtsTable)
          .select('id')
          .eq('club_id', clubId);
      final courtIds = courts.map((c) => c['id'] as String).toList();
      if (courtIds.isEmpty) return [];

      final data = await _client
          .from(SupabaseConstants.courtReservationsTable)
          .select(_reservationSelect)
          .inFilter('court_id', courtIds)
          .or('reserved_by.eq.$playerId,opponent_id.eq.$playerId')
          .eq('status', 'confirmed')
          .gte('reservation_date', dateStr)
          .order('reservation_date')
          .order('start_time');
      return data.map((e) => ReservationModel.fromJson(e)).toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Admin cancel a reservation (via RPC with permission check)
  Future<void> adminCancelReservation({
    required String reservationId,
    required String adminAuthId,
  }) async {
    try {
      await _client.rpc('admin_cancel_reservation', params: {
        'p_admin_auth_id': adminAuthId,
        'p_reservation_id': reservationId,
      });
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Admin: update reservation (change court, date, time) preserving players/challenge
  Future<void> adminUpdateReservation({
    required String reservationId,
    required String courtId,
    required DateTime date,
    required String startTime,
    required String endTime,
  }) async {
    try {
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      // Evita sobrepor outra reserva confirmada na mesma quadra/data/horário
      // (o update é direto, então não passa pela checagem do RPC de criação).
      int toMin(String t) {
        final p = t.split(':');
        return int.parse(p[0]) * 60 + (p.length > 1 ? int.parse(p[1]) : 0);
      }

      final newStart = toMin(startTime);
      final newEnd = toMin(endTime);
      final existing = await _client
          .from(SupabaseConstants.courtReservationsTable)
          .select('id, start_time, end_time')
          .eq('court_id', courtId)
          .eq('reservation_date', dateStr)
          .eq('status', 'confirmed')
          .neq('id', reservationId);
      for (final r in existing) {
        final rs = toMin(r['start_time'] as String);
        final re = toMin(r['end_time'] as String);
        if (newStart < re && rs < newEnd) {
          throw const ValidationException(
              'Já existe uma reserva nesse horário nesta quadra.');
        }
      }

      // Update the reservation directly (RLS allows admin)
      await _client
          .from(SupabaseConstants.courtReservationsTable)
          .update({
            'court_id': courtId,
            'reservation_date': dateStr,
            'start_time': startTime,
            'end_time': endTime,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', reservationId);

      // If linked to a challenge, update the challenge's chosen_date and court_id too
      final reservation = await _client
          .from(SupabaseConstants.courtReservationsTable)
          .select('challenge_id')
          .eq('id', reservationId)
          .single();
      final challengeId = reservation['challenge_id'] as String?;
      if (challengeId != null) {
        final chosenDateTimeLocal = DateTime(
          date.year,
          date.month,
          date.day,
          int.parse(startTime.split(':')[0]),
          int.parse(startTime.split(':')[1]),
        );
        await _client
            .from(SupabaseConstants.challengesTable)
            .update({
              'court_id': courtId,
              'chosen_date': chosenDateTimeLocal.toUtc().toIso8601String(),
            })
            .eq('id', challengeId);
      }
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Admin: create reservation for two club members
  Future<String> adminCreateReservation({
    required String player1Id,
    required String player2Id,
    required String courtId,
    required DateTime date,
    required String startTime,
    required String endTime,
    required String clubId,
  }) async {
    try {
      final authId = _client.auth.currentUser!.id;
      final result = await _client.rpc(
        SupabaseConstants.rpcAdminCreateReservation,
        params: {
          'p_admin_auth_id': authId,
          'p_player1_id': player1Id,
          'p_player2_id': player2Id,
          'p_court_id': courtId,
          'p_reservation_date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
          'p_start_time': startTime,
          'p_end_time': endTime,
          'p_club_id': clubId,
        },
      );
      return result as String;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Admin: create reservation for a club member + guest (non-member)
  /// Uses direct INSERT (allowed by RLS for admins).
  Future<String> adminCreateReservationWithGuest({
    required String hostPlayerId,
    required String guestName,
    required String courtId,
    required DateTime date,
    required String startTime,
    required String endTime,
    required String clubId,
  }) async {
    try {
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final inserted = await _client
          .from(SupabaseConstants.courtReservationsTable)
          .insert({
            'court_id': courtId,
            'reserved_by': hostPlayerId,
            'reservation_date': dateStr,
            'start_time': startTime,
            'end_time': endTime,
            'club_id': clubId,
            'opponent_type': 'guest',
            'opponent_name': guestName,
          })
          .select('id')
          .single();
      return inserted['id'] as String;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Admin: get all club reservations (confirmed, today+)
  Future<List<ReservationModel>> getClubReservations({required String clubId}) async {
    try {
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      // Get all courts for this club
      final courts = await _client
          .from(SupabaseConstants.courtsTable)
          .select('id')
          .eq('club_id', clubId);
      final courtIds = courts.map((c) => c['id'] as String).toList();
      if (courtIds.isEmpty) return [];

      final data = await _client
          .from(SupabaseConstants.courtReservationsTable)
          .select(_reservationSelect)
          .inFilter('court_id', courtIds)
          .eq('status', 'confirmed')
          .gte('reservation_date', dateStr)
          .order('reservation_date')
          .order('start_time');
      return data.map((e) => ReservationModel.fromJson(e)).toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Admin: create administrative reservation (blocks court with title/reason)
  Future<String> adminCreateAdministrativeReservation({
    required String courtId,
    required DateTime date,
    required String startTime,
    required String endTime,
    required String title,
    required String clubId,
  }) async {
    try {
      final authId = _client.auth.currentUser!.id;
      final result = await _client.rpc(
        SupabaseConstants.rpcAdminCreateAdministrativeReservation,
        params: {
          'p_admin_auth_id': authId,
          'p_court_id': courtId,
          'p_reservation_date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
          'p_start_time': startTime,
          'p_end_time': endTime,
          'p_title': title,
          'p_club_id': clubId,
        },
      );
      return result as String;
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
