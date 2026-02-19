import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/date_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/challenge_model.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/providers/current_player_provider.dart';
import '../../clubs/view/club_selector_widget.dart';
import '../viewmodel/challenge_list_viewmodel.dart';

class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: clubAppBarTitle('Desafios', context, ref),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Ativos'),
              Tab(text: 'Histórico'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => context.push('/challenges/create'),
          child: const Icon(Icons.add),
        ),
        body: const TabBarView(
          children: [
            _ActiveChallengesTab(),
            _HistoryChallengesTab(),
          ],
        ),
      ),
    );
  }
}

class _ActiveChallengesTab extends ConsumerWidget {
  const _ActiveChallengesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengesAsync = ref.watch(activeChallengesProvider);
    final currentPlayer = ref.watch(currentPlayerProvider);
    final playerId = currentPlayer.valueOrNull?.id;

    return challengesAsync.when(
      data: (challenges) {
        if (challenges.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flash_on, size: 64, color: AppColors.onBackgroundLight),
                SizedBox(height: 16),
                Text(
                  'Nenhum desafio ativo',
                  style: TextStyle(fontSize: 16, color: AppColors.onBackgroundLight),
                ),
                SizedBox(height: 8),
                Text(
                  'Toque no + para criar um desafio',
                  style: TextStyle(fontSize: 13, color: AppColors.onBackgroundLight),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(activeChallengesProvider),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: challenges.length,
            itemBuilder: (context, index) => _ChallengeListTile(
              challenge: challenges[index],
              currentPlayerId: playerId ?? '',
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Erro: $error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(activeChallengesProvider),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryChallengesTab extends ConsumerWidget {
  const _HistoryChallengesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(challengeHistoryProvider);
    final currentPlayer = ref.watch(currentPlayerProvider);
    final playerId = currentPlayer.valueOrNull?.id;

    return historyAsync.when(
      data: (challenges) {
        if (challenges.isEmpty) {
          return const Center(
            child: Text(
              'Nenhum desafio finalizado',
              style: TextStyle(fontSize: 16, color: AppColors.onBackgroundLight),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(challengeHistoryProvider),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: challenges.length,
            itemBuilder: (context, index) => _ChallengeListTile(
              challenge: challenges[index],
              currentPlayerId: playerId ?? '',
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
    );
  }
}

class _ChallengeListTile extends StatelessWidget {
  final ChallengeModel challenge;
  final String currentPlayerId;

  const _ChallengeListTile({
    required this.challenge,
    required this.currentPlayerId,
  });

  @override
  Widget build(BuildContext context) {
    final isChallenger = challenge.isChallenger(currentPlayerId);
    final opponentName = isChallenger
        ? (challenge.challengedName ?? 'Oponente')
        : (challenge.challengerName ?? 'Oponente');
    final opponentPosition = isChallenger
        ? challenge.challengedPosition
        : challenge.challengerPosition;

    final statusColor = switch (challenge.status) {
      ChallengeStatus.pending => AppColors.challengePending,
      ChallengeStatus.datesProposed => AppColors.challengePending,
      ChallengeStatus.scheduled => AppColors.challengeScheduled,
      ChallengeStatus.completed => AppColors.challengeCompleted,
      _ => AppColors.challengeWo,
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () => context.push('/challenges/${challenge.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),

              // Challenge info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isChallenger ? 'Você desafiou' : 'Desafiado por',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.onBackgroundMedium,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$opponentName (#$opponentPosition)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            challenge.statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          challenge.createdAt.timeAgo(),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.onBackgroundLight),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Result indicator for finished challenges
              if (challenge.isFinished && challenge.winnerId != null)
                Icon(
                  challenge.didWin(currentPlayerId)
                      ? Icons.emoji_events
                      : Icons.close,
                  color: challenge.didWin(currentPlayerId)
                      ? AppColors.gold
                      : AppColors.error,
                  size: 24,
                ),

              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios, color: AppColors.onBackgroundLight, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
