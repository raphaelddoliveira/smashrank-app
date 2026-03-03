import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/club_member_model.dart';
import '../../clubs/viewmodel/club_providers.dart';
import '../../ranking/data/ranking_repository.dart';

/// Loads ranked members for a given sport in the current club
final adminRankingMembersProvider =
    FutureProvider.family<List<ClubMemberModel>, String>((ref, sportId) async {
  final clubId = ref.watch(currentClubIdProvider);
  if (clubId == null) return [];
  final repo = ref.watch(rankingRepositoryProvider);
  return repo.getRanking(clubId, sportId: sportId);
});

/// Notifier for the save action
final adminRankingSaveProvider =
    StateNotifierProvider<AdminRankingSaveNotifier, AsyncValue<void>>((ref) {
  return AdminRankingSaveNotifier(ref.watch(rankingRepositoryProvider));
});

class AdminRankingSaveNotifier extends StateNotifier<AsyncValue<void>> {
  final RankingRepository _repository;

  AdminRankingSaveNotifier(this._repository) : super(const AsyncData(null));

  Future<bool> saveRanking({
    required String clubId,
    required String sportId,
    required List<ClubMemberModel> orderedMembers,
  }) async {
    state = const AsyncLoading();
    try {
      final rankingOrder = orderedMembers
          .asMap()
          .entries
          .map((e) => {
                'member_id': e.value.id,
                'new_position': e.key + 1,
              })
          .toList();

      await _repository.adminReorderRanking(
        clubId: clubId,
        sportId: sportId,
        rankingOrder: rankingOrder,
      );
      state = const AsyncData(null);
      return true;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return false;
    }
  }
}
