import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../shared/models/challenge_model.dart';
import '../../../shared/models/match_model.dart';
import '../data/challenge_repository.dart';

final challengeDetailProvider =
    FutureProvider.family<ChallengeModel, String>((ref, challengeId) async {
  final repository = ref.watch(challengeRepositoryProvider);
  return repository.getChallenge(challengeId);
});

final challengeMatchProvider =
    FutureProvider.family<MatchModel?, String>((ref, challengeId) async {
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

  Future<bool> proposeDates(
    String challengeId, {
    required DateTime date1,
    required DateTime date2,
    required DateTime date3,
  }) async {
    state = const AsyncLoading();
    try {
      await _repository.proposeDates(
        challengeId,
        date1: date1,
        date2: date2,
        date3: date3,
      );
      state = const AsyncData(null);
      return true;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> chooseDate(String challengeId, DateTime chosenDate) async {
    state = const AsyncLoading();
    try {
      await _repository.chooseDate(challengeId, chosenDate);
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
}
