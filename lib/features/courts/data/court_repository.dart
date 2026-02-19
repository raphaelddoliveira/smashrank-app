import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/errors/error_handler.dart';
import '../../../services/supabase_service.dart';
import '../../../shared/models/court_model.dart';
import '../../../shared/models/court_slot_model.dart';
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

  /// Create a new court linked to a sport
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

  /// Get slots for a specific court and day of week (active only — for players)
  Future<List<CourtSlotModel>> getSlotsForCourt(
    String courtId, {
    required int dayOfWeek,
  }) async {
    try {
      final data = await _client
          .from(SupabaseConstants.courtSlotsTable)
          .select()
          .eq('court_id', courtId)
          .eq('day_of_week', dayOfWeek)
          .eq('is_active', true)
          .order('start_time');
      return data.map((e) => CourtSlotModel.fromJson(e)).toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  // ─── Slot Admin CRUD ───

  /// Get ALL slots for a court (including inactive — for admin)
  Future<List<CourtSlotModel>> getAllSlotsForCourt(String courtId) async {
    try {
      final data = await _client
          .from(SupabaseConstants.courtSlotsTable)
          .select()
          .eq('court_id', courtId)
          .order('day_of_week')
          .order('start_time');
      return data.map((e) => CourtSlotModel.fromJson(e)).toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Create a single slot
  Future<void> createSlot({
    required String courtId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
  }) async {
    try {
      await _client.from(SupabaseConstants.courtSlotsTable).insert({
        'court_id': courtId,
        'day_of_week': dayOfWeek,
        'start_time': startTime,
        'end_time': endTime,
      });
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Bulk-create slots (upsert to avoid duplicate errors)
  Future<void> bulkCreateSlots(List<Map<String, dynamic>> slots) async {
    try {
      await _client
          .from(SupabaseConstants.courtSlotsTable)
          .upsert(slots, onConflict: 'court_id,day_of_week,start_time');
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Toggle slot active status
  Future<void> toggleSlotActive(String slotId, bool isActive) async {
    try {
      await _client
          .from(SupabaseConstants.courtSlotsTable)
          .update({'is_active': isActive})
          .eq('id', slotId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Delete a slot permanently
  Future<void> deleteSlot(String slotId) async {
    try {
      await _client
          .from(SupabaseConstants.courtSlotsTable)
          .delete()
          .eq('id', slotId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Check if a slot has any reservations
  Future<bool> slotHasReservations(String slotId) async {
    try {
      final data = await _client
          .from(SupabaseConstants.courtReservationsTable)
          .select('id')
          .eq('court_slot_id', slotId)
          .limit(1);
      return data.isNotEmpty;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

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
            player:players!reserved_by(full_name)
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
    required String courtSlotId,
    required String courtId,
    required DateTime date,
    required String startTime,
    required String endTime,
    String? clubId,
    String? challengeId,
    String? notes,
  }) async {
    try {
      final playerId = await _getCurrentPlayerId();
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      await _client.from(SupabaseConstants.courtReservationsTable).insert({
        'court_slot_id': courtSlotId,
        'court_id': courtId,
        'reserved_by': playerId,
        'reservation_date': dateStr,
        'start_time': startTime,
        'end_time': endTime,
        if (clubId != null) 'club_id': clubId,
        if (challengeId != null) 'challenge_id': challengeId,
        if (notes != null) 'notes': notes,
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
            player:players!reserved_by(full_name)
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
            player:players!reserved_by(full_name)
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
