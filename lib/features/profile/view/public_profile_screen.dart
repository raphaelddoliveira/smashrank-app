import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/extensions/date_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/challenge_model.dart';
import '../../../shared/providers/current_player_provider.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../clubs/viewmodel/club_providers.dart';
import '../../ranking/viewmodel/ranking_history_viewmodel.dart';
import '../../ranking/view/widgets/ranking_chart.dart';
import '../viewmodel/public_profile_viewmodel.dart';
import 'widgets/stats_card.dart';

class PublicProfileScreen extends ConsumerWidget {
  final String playerId;

  const PublicProfileScreen({super.key, required this.playerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerAsync = ref.watch(publicPlayerProvider(playerId));
    final memberAsync = ref.watch(playerClubMemberProvider(playerId));
    final historyAsync = ref.watch(rankingHistoryProvider(playerId));
    final matchesAsync = ref.watch(playerMatchHistoryProvider(playerId));
    final currentPlayer = ref.watch(currentPlayerProvider).valueOrNull;
    final currentMember = ref.watch(currentClubMemberProvider).valueOrNull;
    final isOwnProfile = currentPlayer?.id == playerId;

    return Scaffold(
      appBar: AppBar(
        title: playerAsync.when(
          data: (player) => Text(player.fullName),
          loading: () => const Text('Perfil'),
          error: (_, _) => const Text('Perfil'),
        ),
      ),
      body: playerAsync.when(
        data: (player) {
          final member = memberAsync.valueOrNull;
          final history = historyAsync.valueOrNull ?? [];
          final matches = matchesAsync.valueOrNull ?? [];

          // Calculate W/L from matches
          int wins = 0;
          int losses = 0;
          for (final m in matches) {
            if (m.winnerId == playerId) {
              wins++;
            } else if (m.loserId == playerId) {
              losses++;
            }
          }

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // Header: Avatar + Name + Bio
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: Column(
                        children: [
                          // Avatar
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.secondaryGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.secondary.withAlpha(60),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.background,
                              ),
                              child: CircleAvatar(
                                radius: 48,
                                backgroundColor: AppColors.surfaceVariant,
                                backgroundImage: player.avatarUrl != null
                                    ? CachedNetworkImageProvider(
                                        player.avatarUrl!)
                                    : null,
                                child: player.avatarUrl == null
                                    ? Text(
                                        player.fullName.isNotEmpty
                                            ? player.fullName[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(fontSize: 36),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            player.fullName,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (player.nickname != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '"${player.nickname}"',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppColors.onBackgroundMedium,
                                    fontStyle: FontStyle.italic,
                                  ),
                            ),
                          ],
                          if (player.bio != null &&
                              player.bio!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              player.bio!,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                      color: AppColors.onBackgroundMedium),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Stats Row
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: StatsCard(
                              label: 'Posicao',
                              value:
                                  '#${member?.rankingPosition ?? '-'}',
                              icon: Icons.emoji_events,
                              color: AppColors.gold,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatsCard(
                              label: 'Vitorias',
                              value: '$wins',
                              icon: Icons.check_circle,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatsCard(
                              label: 'Derrotas',
                              value: '$losses',
                              icon: Icons.cancel,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Playing style card
                  if (player.dominantHand != null ||
                      player.backhandType != null ||
                      player.preferredSurface != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Estilo de Jogo',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                          fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                if (player.dominantHand != null)
                                  _StyleRow(
                                    icon: Icons.back_hand,
                                    label: 'Mao dominante',
                                    value: player.dominantHand!.label,
                                  ),
                                if (player.backhandType != null)
                                  _StyleRow(
                                    icon: Icons.sports_tennis,
                                    label: 'Backhand',
                                    value: player.backhandType!.label,
                                  ),
                                if (player.preferredSurface != null)
                                  _StyleRow(
                                    icon: Icons.grid_on,
                                    label: 'Superficie',
                                    value: player.preferredSurface!,
                                  ),
                                _StyleRow(
                                  icon: Icons.calendar_today,
                                  label: 'Membro desde',
                                  value:
                                      '${player.createdAt.day.toString().padLeft(2, '0')}/${player.createdAt.month.toString().padLeft(2, '0')}/${player.createdAt.year}',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Ranking evolution chart
                  if (history.length >= 2)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Evolucao no Ranking',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                          fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Posicao mais baixa = melhor',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color:
                                              AppColors.onBackgroundLight),
                                ),
                                const SizedBox(height: 8),
                                RankingChart(history: history),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Recent matches
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Text(
                        'Partidas Recentes',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  if (matches.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'Nenhuma partida registrada',
                            style: TextStyle(
                                color: AppColors.onBackgroundLight),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final match = matches[index];
                            return _MatchTile(
                              challenge: match,
                              playerId: playerId,
                            );
                          },
                          childCount: matches.length,
                        ),
                      ),
                    ),

                  // Bottom padding when no matches
                  if (matches.isNotEmpty)
                    const SliverToBoxAdapter(child: SizedBox.shrink())
                  else
                    const SliverToBoxAdapter(
                        child: SizedBox(height: 60)),
                ],
              ),

              // Challenge button (fixed at bottom)
              if (!isOwnProfile &&
                  member != null &&
                  member.isInRanking &&
                  currentMember != null &&
                  currentMember.isInRanking)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  child: GradientButton(
                    onPressed: () {
                      context.push(
                        '/challenges/create',
                        extra: {'challengedId': playerId},
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.sports_tennis,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Desafiar',
                          style: GoogleFonts.spaceGrotesk(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
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
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Erro ao carregar perfil: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(publicPlayerProvider(playerId)),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StyleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StyleRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.onBackgroundLight),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
                color: AppColors.onBackgroundMedium, fontSize: 13),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  final ChallengeModel challenge;
  final String playerId;

  const _MatchTile({
    required this.challenge,
    required this.playerId,
  });

  @override
  Widget build(BuildContext context) {
    final isWinner = challenge.winnerId == playerId;
    final isWo = challenge.isWo;
    final opponentName = challenge.challengerId == playerId
        ? challenge.challengedName
        : challenge.challengerName;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/challenges/${challenge.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // W/L indicator
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isWinner
                      ? AppColors.success.withAlpha(25)
                      : AppColors.error.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    isWo
                        ? 'WO'
                        : isWinner
                            ? 'V'
                            : 'D',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isWinner ? AppColors.success : AppColors.error,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Opponent + date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'vs ${opponentName ?? 'Jogador'}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      challenge.completedAt?.timeAgo() ?? '',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.onBackgroundLight),
                    ),
                  ],
                ),
              ),
              // Status chip
              if (!isWo)
                Text(
                  isWinner ? 'Vitoria' : 'Derrota',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isWinner ? AppColors.success : AppColors.error,
                  ),
                )
              else
                Text(
                  isWinner ? 'WO (V)' : 'WO (D)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isWinner ? AppColors.success : AppColors.error,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
