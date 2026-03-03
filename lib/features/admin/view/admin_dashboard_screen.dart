import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../services/supabase_service.dart';
import '../../../shared/models/club_member_model.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/sport_model.dart';
import '../../clubs/data/club_repository.dart';
import '../../clubs/viewmodel/club_providers.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Painel Admin')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AdminCard(
            icon: Icons.format_list_numbered,
            title: 'Ordenar Ranking',
            subtitle: 'Reordenar posições manualmente',
            onTap: () => context.push('/admin/ranking'),
          ),
          _AdminCard(
            icon: Icons.people,
            title: 'Gerenciar Jogadores',
            subtitle: 'Status, posição, ambulância',
            onTap: () => context.push('/admin/players'),
          ),
          _AdminCard(
            icon: Icons.local_hospital,
            title: 'Ambulâncias',
            subtitle: 'Ativar/desativar ambulâncias',
            onTap: () => context.push('/admin/ambulances'),
          ),
          _AdminCard(
            icon: Icons.payment,
            title: 'Mensalidades',
            subtitle: 'Controle de pagamentos',
            onTap: () {},
          ),
          _AdminCard(
            icon: Icons.sports,
            title: 'Esportes',
            subtitle: 'Habilitar/desabilitar esportes',
            onTap: () => context.push('/admin/sports'),
          ),
        ],
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AdminCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.secondary.withAlpha(25),
          child: Icon(icon, color: AppColors.secondary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: onTap,
      ),
    );
  }
}

// ─── Admin Players Screen ───
class AdminPlayersScreen extends ConsumerWidget {
  const AdminPlayersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubId = ref.watch(currentClubIdProvider);
    if (clubId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gerenciar Jogadores')),
        body: const Center(child: Text('Selecione um clube primeiro')),
      );
    }

    final membersAsync = ref.watch(clubMembersProvider(clubId));

    return Scaffold(
      appBar: AppBar(title: const Text('Gerenciar Jogadores')),
      body: membersAsync.when(
        data: (members) => ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.surfaceVariant,
                  child: Text(
                    '#${member.rankingPosition ?? '-'}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                title: Text(member.playerName,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Row(
                  children: [
                    _ClubMemberStatusBadge(status: member.status),
                    if (member.isClubAdmin) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Admin',
                            style: TextStyle(
                                fontSize: 10, color: AppColors.secondary)),
                      ),
                    ],
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) =>
                      _handleAction(context, ref, member, action, clubId),
                  itemBuilder: (_) => [
                    if (member.isProtected)
                      const PopupMenuItem(
                          value: 'remove_protection',
                          child: Text('Remover proteção')),
                    if (member.isOnCooldown)
                      const PopupMenuItem(
                          value: 'remove_cooldown',
                          child: Text('Remover cooldown')),
                  ],
                ),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
      ),
    );
  }

  void _handleAction(
    BuildContext context,
    WidgetRef ref,
    ClubMemberModel member,
    String action,
    String clubId,
  ) async {
    final client = ref.read(supabaseClientProvider);

    if (action == 'remove_protection' || action == 'remove_cooldown') {
      final field = action == 'remove_protection'
          ? 'challenged_protection_until'
          : 'challenger_cooldown_until';
      final label =
          action == 'remove_protection' ? 'Proteção' : 'Cooldown';

      try {
        await client
            .from(SupabaseConstants.clubMembersTable)
            .update({field: null}).eq('id', member.id);

        if (context.mounted) {
          SnackbarUtils.showSuccess(
              context, '$label removido de ${member.playerName}');
          ref.invalidate(clubMembersProvider(clubId));
        }
      } catch (e) {
        if (context.mounted) {
          SnackbarUtils.showError(context, 'Erro: $e');
        }
      }
    }
  }
}

final _adminClubMembersProvider =
    FutureProvider.family<List<ClubMemberModel>, String>((ref, clubId) async {
  final client = ref.watch(supabaseClientProvider);
  final data = await client
      .from(SupabaseConstants.clubMembersTable)
      .select('*, player:players(full_name, nickname, avatar_url, email, phone)')
      .eq('club_id', clubId)
      .eq('status', 'active')
      .order('ranking_position');
  return data.map((e) => ClubMemberModel.fromJson(e)).toList();
});

// ─── Admin Ambulance Screen ───
class AdminAmbulanceScreen extends ConsumerWidget {
  const AdminAmbulanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubId = ref.watch(currentClubIdProvider);
    if (clubId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ambulâncias')),
        body: const Center(child: Text('Selecione um clube primeiro')),
      );
    }

    final membersAsync = ref.watch(_adminClubMembersProvider(clubId));

    return Scaffold(
      appBar: AppBar(title: const Text('Ambulâncias')),
      body: membersAsync.when(
        data: (members) {
          final activeMembers =
              members.where((m) => !m.ambulanceActive).toList();
          final ambulanceMembers =
              members.where((m) => m.ambulanceActive).toList();

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (ambulanceMembers.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'Ambulâncias Ativas (${ambulanceMembers.length})',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                ...ambulanceMembers.map((m) => Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0x20E53935),
                          child: Icon(Icons.local_hospital,
                              color: AppColors.ambulanceActive, size: 20),
                        ),
                        title: Text(m.playerName),
                        subtitle: Text('#${m.rankingPosition ?? '-'}'),
                        trailing: ElevatedButton(
                          onPressed: () =>
                              _deactivateAmbulance(context, ref, m, clubId),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error),
                          child: const Text('Desativar',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    )),
                const SizedBox(height: 16),
              ],
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'Jogadores Ativos (${activeMembers.length})',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              ...activeMembers.map((m) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.surfaceVariant,
                        child: Text('#${m.rankingPosition ?? '-'}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      title: Text(m.playerName),
                      trailing: OutlinedButton(
                        onPressed: () =>
                            _activateAmbulance(context, ref, m, clubId),
                        child: const Text('Ambulância',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  )),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
      ),
    );
  }

  void _activateAmbulance(
      BuildContext context, WidgetRef ref, ClubMemberModel member, String clubId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ativar Ambulância'),
        content: Text(
          'Ativar ambulância para ${member.playerName} (#${member.rankingPosition ?? '-'})?\n\n'
          'Isso irá:\n'
          '- Penalizar -3 posições\n'
          '- Ativar proteção de 10 dias\n'
          '- Após 10 dias: -1 posição/dia',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final client = ref.read(supabaseClientProvider);
                await client.rpc(
                  SupabaseConstants.rpcActivateAmbulance,
                  params: {
                    'p_player_id': member.playerId,
                    'p_club_id': clubId,
                  },
                );
                if (context.mounted) {
                  SnackbarUtils.showSuccess(
                      context, 'Ambulância ativada para ${member.playerName}');
                  ref.invalidate(_adminClubMembersProvider(clubId));
                }
              } catch (e) {
                if (context.mounted) {
                  SnackbarUtils.showError(context, 'Erro: $e');
                }
              }
            },
            child: const Text('Ativar'),
          ),
        ],
      ),
    );
  }

  void _deactivateAmbulance(
      BuildContext context, WidgetRef ref, ClubMemberModel member, String clubId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desativar Ambulância'),
        content:
            Text('Desativar ambulância de ${member.playerName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final client = ref.read(supabaseClientProvider);
                await client.rpc(
                  SupabaseConstants.rpcDeactivateAmbulance,
                  params: {
                    'p_player_id': member.playerId,
                    'p_club_id': clubId,
                  },
                );
                if (context.mounted) {
                  SnackbarUtils.showSuccess(context,
                      'Ambulância desativada para ${member.playerName}');
                  ref.invalidate(_adminClubMembersProvider(clubId));
                }
              } catch (e) {
                if (context.mounted) {
                  SnackbarUtils.showError(context, 'Erro: $e');
                }
              }
            },
            child: const Text('Desativar'),
          ),
        ],
      ),
    );
  }
}

class _ClubMemberStatusBadge extends StatelessWidget {
  final ClubMemberStatus status;

  const _ClubMemberStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      ClubMemberStatus.active => (AppColors.success, 'Ativo'),
      ClubMemberStatus.pending => (AppColors.warning, 'Pendente'),
      ClubMemberStatus.inactive => (AppColors.onBackgroundLight, 'Inativo'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ─── Admin Sports Screen ───

final _adminSportsProvider = FutureProvider<List<SportModel>>((ref) async {
  final repo = ref.watch(clubRepositoryProvider);
  return repo.getAllSportsAdmin();
});

class AdminSportsScreen extends ConsumerWidget {
  const AdminSportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sportsAsync = ref.watch(_adminSportsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Esportes')),
      body: sportsAsync.when(
        data: (sports) => ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: sports.length,
          itemBuilder: (context, index) {
            final sport = sports[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: SwitchListTile(
                secondary: CircleAvatar(
                  backgroundColor: sport.isActive
                      ? AppColors.primary.withAlpha(25)
                      : AppColors.surfaceVariant,
                  child: Icon(
                    sport.iconData,
                    color: sport.isActive ? AppColors.primary : AppColors.onBackgroundLight,
                    size: 20,
                  ),
                ),
                title: Text(
                  sport.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: sport.isActive ? null : AppColors.onBackgroundLight,
                  ),
                ),
                subtitle: Text(
                  _scoringLabel(sport.scoringType),
                  style: TextStyle(
                    fontSize: 12,
                    color: sport.isActive ? AppColors.onBackgroundMedium : AppColors.onBackgroundLight,
                  ),
                ),
                value: sport.isActive,
                onChanged: (value) async {
                  try {
                    await ref.read(clubRepositoryProvider).toggleSportActive(sport.id, value);
                    ref.invalidate(_adminSportsProvider);
                    ref.invalidate(allSportsProvider);
                  } catch (e) {
                    if (context.mounted) {
                      SnackbarUtils.showError(context, 'Erro: $e');
                    }
                  }
                },
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
      ),
    );
  }

  String _scoringLabel(String scoringType) {
    switch (scoringType) {
      case 'sets_games':
        return 'Sets e games';
      case 'sets_points':
        return 'Sets e pontos';
      case 'simple_score':
        return 'Placar simples';
      default:
        return scoringType;
    }
  }
}
