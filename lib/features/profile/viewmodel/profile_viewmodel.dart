import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/app_exception.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/player_model.dart';
import '../../../shared/providers/current_player_provider.dart';
import '../data/player_repository.dart';

final profileViewModelProvider =
    StateNotifierProvider<ProfileViewModel, AsyncValue<PlayerModel?>>((ref) {
  final player = ref.watch(currentPlayerProvider);
  return ProfileViewModel(ref.watch(playerRepositoryProvider), player);
});

class ProfileViewModel extends StateNotifier<AsyncValue<PlayerModel?>> {
  final PlayerRepository _repository;

  ProfileViewModel(this._repository, AsyncValue<PlayerModel?> initialState)
      : super(initialState);

  Future<void> updateProfile({
    required String playerId,
    required String fullName,
    String? nickname,
    String? phone,
    DateTime? dateOfBirth,
    String? bio,
    DominantHand? dominantHand,
    String? favoriteSportId,
    BackhandType? backhandType,
    String? preferredSurface,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;

    state = const AsyncLoading();
    try {
      final updated = await _repository.updatePlayer(
        playerId,
        current.copyWith(
          fullName: fullName,
          nickname: nickname,
          phone: phone,
          dateOfBirth: dateOfBirth,
          bio: bio,
          dominantHand: dominantHand,
          favoriteSportId: favoriteSportId,
          backhandType: backhandType,
          preferredSurface: preferredSurface,
        ),
      );
      state = AsyncData(updated);
    } on AppException catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> updateAvatar(String playerId, XFile file) async {
    final url = await _repository.updateAvatar(playerId, file);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.copyWith(avatarUrl: url));
    }
  }
}
