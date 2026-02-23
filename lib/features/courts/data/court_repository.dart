import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';
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
          .select('''
            *,
            court:courts!court_id(name),
            player:players!reserved_by(full_name),
            opponent:players!opponent_id(full_name)
''')
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

  /// Get current player's reservations
  Future<List<ReservationModel>> getMyReservations() async {
    try {
      final playerId = await _getCurrentPlayerId();
      final data = await _client
          .from(SupabaseConstants.courtReservationsTable)
          .select('''
            *,
            court:courts!court_id(name),
            player:players!reserved_by(full_name),
            opponent:players!opponent_id(full_name)
''')
          .eq('reserved_by', playerId)
          .eq('status', 'confirmed')
          .gte('reservation_date',
              '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}')
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
          .select('''
            *,
            court:courts!court_id(name),
            player:players!reserved_by(full_name),
            opponent:players!opponent_id(full_name)
''')
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
          .select('''
            *,
            court:courts!court_id(name),
            player:players!reserved_by(full_name),
            opponent:players!opponent_id(full_name)
''')
          .eq('challenge_id', challengeId)
          .eq('status', 'confirmed')
          .maybeSingle();
      if (data == null) return null;
      return ReservationModel.fromJson(data);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Count active friendly (non-challenge) reservations for current player
  Future<int> getActiveFriendlyReservationCount() async {
    try {
      final playerId = await _getCurrentPlayerId();
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final data = await _client
          .from(SupabaseConstants.courtReservationsTable)
          .select('id')
          .eq('reserved_by', playerId)
          .eq('status', 'confirmed')
          .isFilter('challenge_id', null)
          .gte('reservation_date', dateStr);
      return data.length;
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
