import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/challenge_model.dart';
import '../../../shared/models/player_model.dart';
import '../../challenges/data/challenge_repository.dart';
import '../../clubs/viewmodel/club_providers.dart';
import '../data/player_repository.dart';

/// Fetch a player's public profile data
final publicPlayerProvider =
    FutureProvider.family<PlayerModel, String>((ref, playerId) async {
  final repo = ref.watch(playerRepositoryProvider);
  return repo.getPlayer(playerId);
});

/// Fetch a player's completed match history in the current club/sport
final playerMatchHistoryProvider =
    FutureProvider.family<List<ChallengeModel>, String>(
        (ref, playerId) async {
  final clubId = ref.watch(currentClubIdProvider);
  final sportId = ref.watch(currentSportIdProvider);
  if (clubId == null) return [];
  final repo = ref.watch(challengeRepositoryProvider);
  return repo.getPlayerMatchHistory(
    playerId: playerId,
    clubId: clubId,
    sportId: sportId,
  );
});
