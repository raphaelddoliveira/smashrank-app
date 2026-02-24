import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../shared/models/club_member_model.dart';
import '../../clubs/viewmodel/club_providers.dart';
import '../data/ranking_repository.dart';

final rankingListProvider =
    FutureProvider<List<ClubMemberModel>>((ref) async {
  final clubId = ref.watch(currentClubIdProvider);
  final sportId = ref.watch(currentSportIdProvider);
  if (clubId == null) return [];
  final repository = ref.watch(rankingRepositoryProvider);
  return repository.getRanking(clubId, sportId: sportId);
});

final rankingActionProvider =
    StateNotifierProvider<RankingActionNotifier, AsyncValue<void>>((ref) {
  return RankingActionNotifier(ref.watch(rankingRepositoryProvider));
});

class RankingActionNotifier extends StateNotifier<AsyncValue<void>> {
  final RankingRepository _repository;

  RankingActionNotifier(this._repository) : super(const AsyncData(null));

  Future<bool> toggleParticipation({
    required String clubId,
    required String sportId,
    required bool optIn,
  }) async {
    state = const AsyncLoading();
    try {
      await _repository.toggleRankingParticipation(
        clubId: clubId,
        sportId: sportId,
        optIn: optIn,
      );
      state = const AsyncData(null);
      return true;
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}
