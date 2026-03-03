import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../shared/models/club_member_model.dart';
import '../../clubs/viewmodel/club_providers.dart';
import '../viewmodel/challenge_list_viewmodel.dart';
import '../viewmodel/create_challenge_viewmodel.dart';

class CreateChallengeScreen extends ConsumerStatefulWidget {
  final String? preSelectedOpponentId;

  const CreateChallengeScreen({super.key, this.preSelectedOpponentId});

  @override
  ConsumerState<CreateChallengeScreen> createState() =>
      _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends ConsumerState<CreateChallengeScreen> {
  bool _autoTriggered = false;

  void _tryAutoSelect(List<ClubMemberModel> opponents) {
    if (_autoTriggered || widget.preSelectedOpponentId == null) return;
    _autoTriggered = true;

    final opponent = opponents
        .where((o) => o.playerId == widget.preSelectedOpponentId)
        .firstOrNull;
    if (opponent == null) return;

    // Show confirmation dialog on next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _confirmChallenge(opponent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final opponentsAsync = ref.watch(eligibleOpponentsProvider);
    final createState = ref.watch(createChallengeProvider);
    final clubSport = ref.watch(currentClubSportProvider);
    final hasPositionGap = clubSport?.rulePositionGapEnabled ?? true;
    final hasCooldownRule = clubSport?.ruleCooldownEnabled ?? true;

    ref.listen(createChallengeProvider, (_, state) {
      state.whenOrNull(
        error: (error, _) {
          SnackbarUtils.showError(context, error.toString());
        },
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Desafio'),
      ),
      body: opponentsAsync.when(
        data: (opponents) {
          _tryAutoSelect(opponents);

          if (opponents.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person_off, size: 64, color: AppColors.onBackgroundLight),
                    const SizedBox(height: 16),
                    const Text(
                      'Nenhum oponente disponível',
                      style: TextStyle(fontSize: 16, color: AppColors.onBackgroundLight),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasPositionGap
                          ? 'Você só pode desafiar jogadores até 2 posições acima no ranking.'
                          : 'Você só pode desafiar jogadores acima de você no ranking.',
                      style: const TextStyle(fontSize: 13, color: AppColors.onBackgroundLight),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Selecione seu oponente',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  hasPositionGap
                      ? 'Jogadores até 2 posições acima de você'
                      : 'Todos os jogadores acima de você',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onBackgroundMedium,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: opponents.length,
                  itemBuilder: (context, index) {
                    final opponent = opponents[index];

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.surfaceVariant,
                          backgroundImage:
                              opponent.playerAvatarUrl != null
                                  ? CachedNetworkImageProvider(
                                      opponent.playerAvatarUrl!)
                                  : null,
                          child: opponent.playerAvatarUrl == null
                              ? Text(
                                  opponent.playerName.isNotEmpty
                                      ? opponent.playerName[0].toUpperCase()
                                      : '?',
                                )
                              : null,
                        ),
                        title: Text(
                          opponent.playerName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Row(
                          children: [
                            Text('#${opponent.rankingPosition}'),
                            if (opponent.playerNickname != null) ...[
                              const Text(' - '),
                              Text(
                                '"${opponent.playerNickname}"',
                                style: const TextStyle(
                                    fontStyle: FontStyle.italic),
                              ),
                            ],
                            if (hasCooldownRule && opponent.isProtected) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.shield,
                                  size: 14, color: AppColors.info),
                              const Text(
                                ' Protegido',
                                style: TextStyle(
                                    fontSize: 11, color: AppColors.info),
                              ),
                            ],
                          ],
                        ),
                        trailing: createState.isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(Icons.flash_on),
                        enabled: !(hasCooldownRule && opponent.isProtected) && !createState.isLoading,
                        onTap: (hasCooldownRule && opponent.isProtected) || createState.isLoading
                            ? null
                            : () => _confirmChallenge(opponent),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Erro: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(eligibleOpponentsProvider),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmChallenge(ClubMemberModel opponent) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Desafio'),
        content: Text(
          'Deseja desafiar ${opponent.playerName} (#${opponent.rankingPosition})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final challengeId = await ref
                  .read(createChallengeProvider.notifier)
                  .createChallenge(opponent.playerId);

              if (challengeId != null && mounted) {
                SnackbarUtils.showSuccess(context, 'Desafio criado!');
                ref.invalidate(activeChallengesProvider);
                context.pushReplacement('/challenges/$challengeId');
              }
            },
            child: const Text('Desafiar'),
          ),
        ],
      ),
    );
  }
}
