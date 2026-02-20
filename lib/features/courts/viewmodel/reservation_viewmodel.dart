import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../shared/models/court_slot_model.dart';
import '../../../shared/models/reservation_model.dart';
import '../data/court_repository.dart';

/// Provider for slots of a court on a specific day of week
final courtSlotsProvider = FutureProvider.autoDispose.family<List<CourtSlotModel>,
    ({String courtId, int dayOfWeek})>((ref, params) async {
  final repository = ref.watch(courtRepositoryProvider);
  return repository.getSlotsForCourt(
    params.courtId,
    dayOfWeek: params.dayOfWeek,
  );
});

/// Provider for reservations of a court on a specific date
final courtReservationsProvider = FutureProvider.family<List<ReservationModel>,
    ({String courtId, DateTime date})>((ref, params) async {
  final repository = ref.watch(courtRepositoryProvider);
  return repository.getReservationsForDate(
    params.courtId,
    date: params.date,
  );
});

/// Provider for current player's upcoming reservations
final myReservationsProvider =
    FutureProvider<List<ReservationModel>>((ref) async {
  final repository = ref.watch(courtRepositoryProvider);
  return repository.getMyReservations();
});

/// Provider for reservation history
final myReservationHistoryProvider =
    FutureProvider<List<ReservationModel>>((ref) async {
  final repository = ref.watch(courtRepositoryProvider);
  return repository.getMyReservationHistory();
});

/// Action notifier for creating/cancelling reservations
final reservationActionProvider =
    StateNotifierProvider<ReservationActionNotifier, AsyncValue<void>>((ref) {
  return ReservationActionNotifier(ref.watch(courtRepositoryProvider));
});

class ReservationActionNotifier extends StateNotifier<AsyncValue<void>> {
  final CourtRepository _repository;

  ReservationActionNotifier(this._repository)
      : super(const AsyncData(null));

  Future<bool> createReservation({
    required String courtSlotId,
    required String courtId,
    required DateTime date,
    required String startTime,
    required String endTime,
    String? challengeId,
  }) async {
    state = const AsyncLoading();
    try {
      await _repository.createReservation(
        courtSlotId: courtSlotId,
        courtId: courtId,
        date: date,
        startTime: startTime,
        endTime: endTime,
        challengeId: challengeId,
      );
      state = const AsyncData(null);
      return true;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> cancelReservation(String reservationId) async {
    state = const AsyncLoading();
    try {
      await _repository.cancelReservation(reservationId);
      state = const AsyncData(null);
      return true;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}
