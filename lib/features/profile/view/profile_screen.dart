import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/club_member_model.dart';
import '../../../features/auth/data/auth_repository.dart';
import '../../../shared/providers/current_player_provider.dart';
import '../../clubs/view/club_selector_widget.dart';
import '../../clubs/viewmodel/club_providers.dart';
import '../../ranking/viewmodel/ranking_list_viewmodel.dart';
import 'widgets/profile_header.dart';
import 'widgets/stats_card.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerAsync = ref.watch(currentPlayerProvider);
    final clubMember = ref.watch(currentClubMemberProvider);
    final myClubs = ref.watch(myClubsProvider);

    return Scaffold(
      appBar: AppBar(
        title: clubAppBarTitle('Meu Perfil', context, ref),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar perfil',
            onPressed: () => context.push(RouteNames.editProfile),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sair'),
                  content: const Text('Deseja realmente sair da sua conta?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sair'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await ref.read(authRepositoryProvider).signOut();
              }
            },
          ),
        ],
      ),
      body: playerAsync.when(
        data: (player) {
          if (player == null) {
            return const Center(child: Text('Jogador não encontrado'));
          }

          final member = clubMember.valueOrNull;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ProfileHeader(player: player),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: StatsCard(
                        label: 'Posição',
                        value: '#${member?.rankingPosition ?? '-'}',
                        icon: Icons.emoji_events,
                        color: AppColors.gold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatsCard(
                        label: 'Desafios/Mês',
                        value: '${member?.challengesThisMonth ?? 0}',
                        icon: Icons.flash_on,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: StatsCard(
                        label: 'Status',
                        value: player.status.label,
                        icon: Icons.circle,
                        color: player.isActive
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatsCard(
                        label: 'Mensalidade',
                        value: player.feeStatus.label,
                        icon: Icons.payments,
                        color: player.hasFeeOverdue
                            ? AppColors.error
                            : AppColors.success,
                      ),
                    ),
                  ],
                ),

                // Club-specific status indicators
                if (member != null) ...[
                  const SizedBox(height: 24),
                  if (member.isOnCooldown)
                    _buildInfoTile(
                      icon: Icons.timer,
                      title: 'Cooldown ativo',
                      subtitle: 'Aguarde para desafiar novamente',
                      color: AppColors.warning,
                    ),
                  if (member.isProtected)
                    _buildInfoTile(
                      icon: Icons.shield,
                      title: 'Proteção ativa',
                      subtitle: 'Você está protegido de novos desafios',
                      color: AppColors.info,
                    ),
                  if (member.isOnAmbulance)
                    _buildInfoTile(
                      icon: Icons.local_hospital,
                      title: 'Ambulância ativa',
                      subtitle: 'Você está em pausa no ranking',
                      color: AppColors.ambulanceActive,
                    ),
                  const SizedBox(height: 8),
                  _RankingToggleCard(member: member),
                ],

                // Clubs section
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Meus Clubes',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const SizedBox(height: 8),
                myClubs.when(
                  data: (clubs) {
                    if (clubs.isEmpty) {
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.groups_outlined, color: AppColors.onBackgroundLight),
                          title: const Text('Nenhum clube'),
                          subtitle: const Text('Crie ou entre em um clube'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () => context.push('/clubs/create'),
                        ),
                      );
                    }
                    return Column(
                      children: clubs.map((club) => Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withAlpha(25),
                            backgroundImage: club.avatarUrl != null
                                ? NetworkImage(club.avatarUrl!)
                                : null,
                            child: club.avatarUrl == null
                                ? const Icon(Icons.groups, color: AppColors.primary, size: 20)
                                : null,
                          ),
                          title: Text(club.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: club.description != null
                              ? Text(club.description!, maxLines: 1, overflow: TextOverflow.ellipsis)
                              : null,
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () => context.push('/clubs/${club.id}/manage'),
                        ),
                      )).toList(),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}

class _RankingToggleCard extends ConsumerWidget {
  final ClubMemberModel member;

  const _RankingToggleCard({required this.member});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionState = ref.watch(rankingActionProvider);
    final isLoading = actionState is AsyncLoading;

    return Card(
      child: SwitchListTile(
        secondary: Icon(
          Icons.leaderboard,
          color: member.isInRanking ? AppColors.primary : AppColors.onBackgroundLight,
        ),
        title: const Text('Participar do Ranking'),
        subtitle: Text(
          member.isInRanking
              ? 'Posição atual: #${member.rankingPosition}'
              : 'Você está fora do ranking',
        ),
        value: member.rankingOptIn,
        onChanged: isLoading
            ? null
            : (value) => _onToggle(context, ref, value),
      ),
    );
  }

  Future<void> _onToggle(BuildContext context, WidgetRef ref, bool optIn) async {
    // Confirmation dialog when opting out
    if (!optIn) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sair do Ranking'),
          content: const Text(
            'Ao sair do ranking, seus desafios ativos serão cancelados automaticamente. '
            'Deseja continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sair do Ranking'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final clubId = ref.read(currentClubIdProvider);
    final sportId = ref.read(currentSportIdProvider);
    if (clubId == null || sportId == null) return;

    final success = await ref.read(rankingActionProvider.notifier).toggleParticipation(
      clubId: clubId,
      sportId: sportId,
      optIn: optIn,
    );

    if (success) {
      ref.invalidate(currentClubMemberProvider);
      ref.invalidate(rankingListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(optIn ? 'Você entrou no ranking!' : 'Você saiu do ranking.'),
          ),
        );
      }
    } else {
      if (context.mounted) {
        final error = ref.read(rankingActionProvider);
        final message = error is AsyncError && error.error is AppException
            ? (error.error as AppException).message
            : 'Erro ao alterar participação no ranking';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }
}
