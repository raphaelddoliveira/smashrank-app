import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../shared/models/challenge_model.dart';
import '../../../shared/models/match_model.dart';
import '../data/challenge_repository.dart';

final challengeDetailProvider =
    FutureProvider.autoDispose.family<ChallengeModel, String>((ref, challengeId) async {
  final repository = ref.watch(challengeRepositoryProvider);
  return repository.getChallenge(challengeId);
});

final challengeMatchProvider =
    FutureProvider.autoDispose.family<MatchModel?, String>((ref, challengeId) async {
  final repository = ref.watch(challengeRepositoryProvider);
  return repository.getMatchForChallenge(challengeId);
});

final challengeActionProvider =
    StateNotifierProvider<ChallengeActionNotifier, AsyncValue<void>>((ref) {
  return ChallengeActionNotifier(ref.watch(challengeRepositoryProvider));
});

class ChallengeActionNotifier extends StateNotifier<AsyncValue<void>> {
  final ChallengeRepository _repository;

  ChallengeActionNotifier(this._repository)
      : super(const AsyncData(null));

  Future<bool> selectCourtAndDate(
    String challengeId, {
    required String courtId,
    required DateTime date,
    required String startTime,
    required String endTime,
    required String clubId,
  }) async {
    state = const AsyncLoading();
    try {
      await _repository.selectCourtAndDate(
        challengeId,
        courtId: courtId,
        date: date,
        startTime: startTime,
        endTime: endTime,
        clubId: clubId,
      );
      state = const AsyncData(null);
      return true;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> acceptChallenge(String challengeId) async {
    state = const AsyncLoading();
    try {
      await _repository.acceptChallenge(challengeId);
      state = const AsyncData(null);
      return true;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> declineChallenge(String challengeId) async {
    state = const AsyncLoading();
    try {
      await _repository.declineChallenge(challengeId);
      state = const AsyncData(null);
      return true;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> recordResult({
    required String challengeId,
    required String winnerId,
    required String loserId,
    required List<SetScore> sets,
    required int winnerSets,
    required int loserSets,
    bool superTiebreak = false,
  }) async {
    state = const AsyncLoading();
    try {
      await _repository.recordResult(
        challengeId: challengeId,
        winnerId: winnerId,
        loserId: loserId,
        sets: sets,
        winnerSets: winnerSets,
        loserSets: loserSets,
        superTiebreak: superTiebreak,
      );
      state = const AsyncData(null);
      return true;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> recordWo({
    required String challengeId,
    required String winnerId,
    required String loserId,
  }) async {
    state = const AsyncLoading();
    try {
      await _repository.recordWo(
        challengeId: challengeId,
        winnerId: winnerId,
        loserId: loserId,
      );
      state = const AsyncData(null);
      return true;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> requestWeatherExtension(String challengeId) async {
    state = const AsyncLoading();
    try {
      await _repository.requestWeatherExtension(challengeId);
      state = const AsyncData(null);
      return true;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> cancelChallenge(String challengeId) async {
    state = const AsyncLoading();
    try {
      await _repository.cancelChallenge(challengeId);
      state = const AsyncData(null);
      return true;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> confirmResult(String challengeId) async {
    state = const AsyncLoading();
    try {
      await _repository.confirmResult(challengeId);
      state = const AsyncData(null);
      return true;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> disputeResult(String challengeId) async {
    state = const AsyncLoading();
    try {
      await _repository.disputeResult(challengeId);
      state = const AsyncData(null);
      return true;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> annulChallenge(String challengeId) async {
    state = const AsyncLoading();
    try {
      await _repository.annulChallenge(challengeId);
      state = const AsyncData(null);
      return true;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> adminEditResult({
    required String challengeId,
    required String winnerId,
    required String loserId,
    required List<SetScore> sets,
    required int winnerSets,
    required int loserSets,
    bool superTiebreak = false,
  }) async {
    state = const AsyncLoading();
    try {
      await _repository.adminEditResult(
        challengeId: challengeId,
        winnerId: winnerId,
        loserId: loserId,
        sets: sets,
        winnerSets: winnerSets,
        loserSets: loserSets,
        superTiebreak: superTiebreak,
      );
      state = const AsyncData(null);
      return true;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}
