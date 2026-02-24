import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/date_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../viewmodel/ranking_history_viewmodel.dart';
import 'widgets/ranking_chart.dart';
import 'widgets/ranking_position_change.dart';

class RankingHistoryScreen extends ConsumerWidget {
  final String playerId;
  final String playerName;

  const RankingHistoryScreen({
    super.key,
    required this.playerId,
    required this.playerName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(rankingHistoryProvider(playerId));
    final playerAsync = ref.watch(playerClubMemberProvider(playerId));

    return Scaffold(
      appBar: AppBar(
        title: Text(playerName),
      ),
      body: historyAsync.when(
        data: (history) {
          return CustomScrollView(
            slivers: [
              // Player summary card
              SliverToBoxAdapter(
                child: playerAsync.when(
                  data: (member) {
                    final pos = member?.rankingPosition ?? 0;
                    return _PlayerSummaryCard(
                      position: pos,
                      totalChanges: history.length,
                      bestPosition: history.isEmpty
                          ? pos
                          : history
                              .where((e) => e.newPosition != null)
                              .map((e) => e.newPosition!)
                              .fold(pos, (a, b) => a < b ? a : b),
                    );
                  },
                  loading: () => const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ),

              // Chart
              if (history.length >= 2)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Evolucao no Ranking',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Posição mais baixa = melhor',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.onBackgroundLight,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        RankingChart(history: history),
                      ],
                    ),
                  ),
                ),

              // Timeline header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Histórico de Alterações',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ),

              // Timeline list
              if (history.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'Nenhuma alteração de ranking registrada',
                      style: TextStyle(color: AppColors.onBackgroundLight),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final entry = history[index];
                      final isFirst = index == 0;
                      final isLast = index == history.length - 1;

                      return _TimelineEntry(
                        reasonLabel: entry.reasonLabel,
                        oldPosition: entry.oldPosition,
                        newPosition: entry.newPosition,
                        positionChange: entry.positionChange,
                        createdAt: entry.createdAt,
                        isFirst: isFirst,
                        isLast: isLast,
                      );
                    },
                    childCount: history.length,
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
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Erro ao carregar histórico: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(rankingHistoryProvider(playerId)),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerSummaryCard extends StatelessWidget {
  final int position;
  final int totalChanges;
  final int bestPosition;

  const _PlayerSummaryCard({
    required this.position,
    required this.totalChanges,
    required this.bestPosition,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _SummaryItem(
              label: 'Posição Atual',
              value: '#$position',
              icon: Icons.emoji_events,
              color: AppColors.secondary,
            ),
            _SummaryItem(
              label: 'Melhor Posição',
              value: '#$bestPosition',
              icon: Icons.star,
              color: AppColors.gold,
            ),
            _SummaryItem(
              label: 'Alterações',
              value: '$totalChanges',
              icon: Icons.swap_vert,
              color: AppColors.info,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.onBackgroundLight,
                fontSize: 11,
              ),
        ),
      ],
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  final String reasonLabel;
  final int? oldPosition;
  final int? newPosition;
  final int positionChange;
  final DateTime createdAt;
  final bool isFirst;
  final bool isLast;

  const _TimelineEntry({
    required this.reasonLabel,
    required this.oldPosition,
    required this.newPosition,
    required this.positionChange,
    required this.createdAt,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = positionChange > 0
        ? AppColors.rankUp
        : positionChange < 0
            ? AppColors.rankDown
            : AppColors.rankSame;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline line + dot
          SizedBox(
            width: 48,
            child: Column(
              children: [
                // Top line
                Expanded(
                  child: Container(
                    width: isFirst ? 0 : 2,
                    color: AppColors.divider,
                  ),
                ),
                // Dot
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: dotColor.withAlpha(60),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                // Bottom line
                Expanded(
                  child: Container(
                    width: isLast ? 0 : 2,
                    color: AppColors.divider,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 16, 8),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reasonLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              newPosition == null
                                  ? '#$oldPosition → Fora'
                                  : oldPosition != null
                                      ? '#$oldPosition → #$newPosition'
                                      : 'Posição: #$newPosition',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.onBackgroundMedium),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              createdAt.timeAgo(),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.onBackgroundLight,
                                    fontSize: 11,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      RankingPositionChange(change: positionChange),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
