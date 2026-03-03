import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../shared/models/club_member_model.dart';
import '../../../shared/models/club_model.dart';
import '../../../shared/models/court_model.dart';
import '../../../shared/models/reservation_model.dart';
import '../../../shared/models/sport_model.dart';
import '../../../shared/providers/current_player_provider.dart';
import '../../courts/data/court_repository.dart';
import '../../courts/viewmodel/courts_viewmodel.dart';
import '../../ranking/viewmodel/ranking_list_viewmodel.dart';
import '../data/club_repository.dart';
import '../viewmodel/club_providers.dart';

/// Courts for a specific club (all sports, including inactive for admin view)
final _clubAllCourtsProvider = FutureProvider.family<List<CourtModel>, String>(
  (ref, clubId) async {
    final repo = ref.watch(courtRepositoryProvider);
    return repo.getAllCourts(clubId: clubId);
  },
);

class ClubManagementScreen extends ConsumerWidget {
  final String clubId;

  const ClubManagementScreen({super.key, required this.clubId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubAsync = ref.watch(currentClubProvider);
    final requestsAsync = ref.watch(clubJoinRequestsProvider(clubId));
    final isAdmin = ref.watch(isClubAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Clube'),
        centerTitle: true,
      ),
      body: clubAsync.when(
        data: (club) {
          if (club == null) {
            return const Center(child: Text('Clube não encontrado'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Club info card
              _ClubInfoCard(club: club, isAdmin: isAdmin),
              const SizedBox(height: 16),

              // Sports section (admin only)
              if (isAdmin) ...[
                _SportsSection(clubId: clubId),
                const SizedBox(height: 16),
              ],

              // Pending requests (admin only)
              if (isAdmin) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: requestsAsync.when(
                    data: (requests) {
                      final pending = requests.length;
                      return Row(
                        children: [
                          Text(
                            'Solicitações Pendentes',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (pending > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$pending',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                    loading: () => Text(
                      'Solicitações Pendentes',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    error: (_, _) => Text(
                      'Solicitações Pendentes',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                requestsAsync.when(
                  data: (requests) {
                    if (requests.isEmpty) {
                      return const Card(
                        child: ListTile(
                          leading: Icon(Icons.check_circle_outline, color: AppColors.onBackgroundLight),
                          title: Text('Nenhuma solicitação pendente'),
                        ),
                      );
                    }
                    return Column(
                      children: requests.map((req) => _RequestTile(
                        request: req,
                        onApprove: () async {
                          final player = ref.read(currentPlayerProvider).valueOrNull;
                          if (player == null) return;
                          try {
                            await ref.read(clubRepositoryProvider)
                                .approveJoinRequest(req['id'], player.authId);
                            ref.invalidate(clubJoinRequestsProvider(clubId));
                            ref.invalidate(clubMembersProvider(clubId));
                            if (context.mounted) {
                              SnackbarUtils.showSuccess(context, 'Solicitação aprovada!');
                            }
                          } catch (e) {
                            if (context.mounted) {
                              SnackbarUtils.showError(context, 'Erro ao aprovar: $e');
                            }
                          }
                        },
                        onReject: () async {
                          final player = ref.read(currentPlayerProvider).valueOrNull;
                          if (player == null) return;
                          try {
                            await ref.read(clubRepositoryProvider)
                                .rejectJoinRequest(req['id'], player.authId);
                            ref.invalidate(clubJoinRequestsProvider(clubId));
                            if (context.mounted) {
                              SnackbarUtils.showSuccess(context, 'Solicitação rejeitada');
                            }
                          } catch (e) {
                            if (context.mounted) {
                              SnackbarUtils.showError(context, 'Erro ao rejeitar: $e');
                            }
                          }
                        },
                      )).toList(),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.error_outline, color: AppColors.error),
                      title: const Text('Erro ao carregar solicitações'),
                      subtitle: Text('$e', style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Members list with search
              _MembersSection(clubId: clubId, isAdmin: isAdmin),

              // ─── Courts section ───
              const SizedBox(height: 24),
              _CourtsSection(clubId: clubId, isAdmin: isAdmin),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
      ),
    );
  }
}

// ─── Club Info Card ───

class _ClubInfoCard extends StatelessWidget {
  final ClubModel club;
  final bool isAdmin;

  const _ClubInfoCard({required this.club, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final hasCover = club.coverUrl != null && club.coverUrl!.isNotEmpty;
    final hasLogo = club.avatarUrl != null && club.avatarUrl!.isNotEmpty;

    return Card(
      child: Column(
        children: [
          // Cover image
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient:
                    hasCover ? null : AppColors.primaryGradient,
              ),
              child: hasCover
                  ? CachedNetworkImage(
                      imageUrl: club.coverUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        decoration: const BoxDecoration(
                          gradient: AppColors.primaryGradient,
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        decoration: const BoxDecoration(
                          gradient: AppColors.primaryGradient,
                        ),
                        child: const Center(
                          child: Icon(Icons.groups_rounded,
                              size: 40, color: Colors.white24),
                        ),
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.groups_rounded,
                          size: 40, color: Colors.white24),
                    ),
            ),
          ),
          // Logo + edit button row
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isAdmin) const SizedBox(width: 40),
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.surfaceVariant,
                  backgroundImage: hasLogo
                      ? CachedNetworkImageProvider(club.avatarUrl!)
                      : null,
                  child: !hasLogo
                      ? const Icon(Icons.groups_rounded,
                          size: 28, color: AppColors.onBackgroundLight)
                      : null,
                ),
                if (isAdmin)
                  SizedBox(
                    width: 40,
                    child: IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          size: 20, color: AppColors.primary),
                      onPressed: () =>
                          context.push('/clubs/${club.id}/edit'),
                      tooltip: 'Editar clube',
                    ),
                  ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              children: [
                Text(
                  club.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                  textAlign: TextAlign.center,
                ),
                if (club.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    club.description!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.onBackgroundLight,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 16),
                // Invite code
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.vpn_key_outlined,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        club.inviteCode,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: club.inviteCode));
                          SnackbarUtils.showSuccess(
                              context, 'Código copiado!');
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                // Address
                if (club.hasAddress) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 18, color: AppColors.onBackgroundLight),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          club.fullAddress!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.onBackgroundMedium,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                // Contacts
                if (club.hasContacts) ...[
                  const SizedBox(height: 12),
                  if (!club.hasAddress) ...[
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                  ],
                  if (club.phone != null && club.phone!.isNotEmpty)
                    _ContactRow(
                      icon: Icons.phone_outlined,
                      text: club.phone!,
                    ),
                  if (club.email != null && club.email!.isNotEmpty)
                    _ContactRow(
                      icon: Icons.email_outlined,
                      text: club.email!,
                    ),
                  if (club.website != null && club.website!.isNotEmpty)
                    _ContactRow(
                      icon: Icons.language_outlined,
                      text: club.website!,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ContactRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.onBackgroundLight),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.onBackgroundMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _RequestTile({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final player = request['player'] as Map<String, dynamic>?;
    final name = player?['full_name'] ?? 'Jogador';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryLight,
          child: Text(
            name[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('Aguardando aprovação'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.check_circle, color: AppColors.success),
              onPressed: onApprove,
              tooltip: 'Aprovar',
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: AppColors.error),
              onPressed: onReject,
              tooltip: 'Rejeitar',
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Members Section (with search + pagination + admin powers) ───

class _MembersSection extends ConsumerStatefulWidget {
  final String clubId;
  final bool isAdmin;

  const _MembersSection({required this.clubId, required this.isAdmin});

  @override
  ConsumerState<_MembersSection> createState() => _MembersSectionState();
}

class _MembersSectionState extends ConsumerState<_MembersSection> {
  static const _pageSize = 20;

  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<ClubMemberModel> _members = [];
  bool _isLoading = false;
  bool _hasMore = true;
  bool _initialLoaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers({bool reset = false}) async {
    if (_isLoading) return;
    if (!reset && !_hasMore) return;

    setState(() {
      _isLoading = true;
      _error = null;
      if (reset) {
        _members = [];
        _hasMore = true;
      }
    });

    try {
      final repo = ref.read(clubRepositoryProvider);
      final search = _searchQuery.trim().isEmpty ? null : _searchQuery.trim();
      final newMembers = await repo.getMembersPaginated(
        widget.clubId,
        offset: reset ? 0 : _members.length,
        limit: _pageSize,
        search: search,
      );
      if (mounted) {
        setState(() {
          if (reset) {
            _members = newMembers;
          } else {
            _members.addAll(newMembers);
          }
          // Sort alphabetically by display name (active first, then alphabetical)
          _members.sort((a, b) {
            final statusCmp = a.isActive == b.isActive ? 0 : (a.isActive ? -1 : 1);
            if (statusCmp != 0) return statusCmp;
            return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
          });
          _hasMore = newMembers.length >= _pageSize;
          _isLoading = false;
          _initialLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _initialLoaded = true;
          _error = '$e';
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _loadMembers(reset: true);
  }

  void _refresh() {
    _loadMembers(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _members.where((m) => m.isActive).length;
    final inactiveCount = _members.where((m) => !m.isActive).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            _initialLoaded
                ? 'Membros ($activeCount)${inactiveCount > 0 ? ' · $inactiveCount suspensos' : ''}'
                : 'Membros',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        // Search field
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar membro...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        // Members list
        if (_error != null && _members.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('Erro: $_error')),
          )
        else if (!_initialLoaded)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_members.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                _searchQuery.isNotEmpty ? 'Nenhum membro encontrado' : 'Nenhum membro',
                style: const TextStyle(color: AppColors.onBackgroundLight),
              ),
            ),
          )
        else ...[
          ..._members.map((member) => _MemberTile(
            member: member,
            clubId: widget.clubId,
            isAdmin: widget.isAdmin,
            onRefresh: _refresh,
          )),
          if (_hasMore)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton.icon(
                        onPressed: () => _loadMembers(),
                        icon: const Icon(Icons.expand_more, size: 20),
                        label: const Text('Carregar mais'),
                      ),
              ),
            ),
        ],
      ],
    );
  }
}

class _MemberTile extends ConsumerWidget {
  final ClubMemberModel member;
  final String clubId;
  final bool isAdmin;
  final VoidCallback onRefresh;

  const _MemberTile({
    required this.member,
    required this.clubId,
    required this.isAdmin,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSuspended = !member.isActive;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: isSuspended ? 0.6 : 1.0,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isSuspended
                ? AppColors.error.withAlpha(40)
                : AppColors.primaryLight,
            backgroundImage: member.playerAvatarUrl != null
                ? NetworkImage(member.playerAvatarUrl!)
                : null,
            child: member.playerAvatarUrl == null
                ? Text(
                    member.displayName.isNotEmpty
                        ? member.displayName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: isSuspended ? AppColors.error : Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  )
                : null,
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  member.playerName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!member.isInRanking && member.isActive) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.onBackgroundLight.withAlpha(20),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Fora do ranking',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onBackgroundLight,
                    ),
                  ),
                ),
              ],
              if (isSuspended) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error.withAlpha(25),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.error.withAlpha(60)),
                  ),
                  child: const Text(
                    'Suspenso',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            member.isClubAdmin ? 'Admin' : 'Membro',
            style: TextStyle(
              color: member.isClubAdmin ? AppColors.secondary : AppColors.onBackgroundLight,
              fontWeight: member.isClubAdmin ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          trailing: isAdmin
              ? PopupMenuButton<String>(
                  onSelected: (action) => _handleAction(context, ref, action),
                  itemBuilder: (_) => [
                    if (!isSuspended)
                      PopupMenuItem(
                        value: 'toggle_role',
                        child: Row(
                          children: [
                            Icon(
                              member.isClubAdmin ? Icons.person_outline : Icons.admin_panel_settings_outlined,
                              size: 18,
                              color: AppColors.onBackgroundMedium,
                            ),
                            const SizedBox(width: 8),
                            Text(member.isClubAdmin ? 'Tornar membro' : 'Tornar admin'),
                          ],
                        ),
                      ),
                    if (!isSuspended)
                      PopupMenuItem(
                        value: member.isInRanking ? 'ranking_off' : 'ranking_on',
                        child: Row(
                          children: [
                            Icon(
                              member.isInRanking ? Icons.leaderboard_outlined : Icons.leaderboard,
                              size: 18,
                              color: member.isInRanking ? AppColors.warning : AppColors.success,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              member.isInRanking ? 'Desativar ranking' : 'Ativar ranking',
                              style: TextStyle(
                                color: member.isInRanking ? AppColors.warning : AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (!isSuspended)
                      const PopupMenuItem(
                        value: 'reservations',
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.onBackgroundMedium),
                            SizedBox(width: 8),
                            Text('Ver reservas'),
                          ],
                        ),
                      ),
                    const PopupMenuDivider(),
                    if (isSuspended)
                      const PopupMenuItem(
                        value: 'unsuspend',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline, size: 18, color: AppColors.success),
                            SizedBox(width: 8),
                            Text('Reativar', style: TextStyle(color: AppColors.success)),
                          ],
                        ),
                      )
                    else
                      const PopupMenuItem(
                        value: 'suspend',
                        child: Row(
                          children: [
                            Icon(Icons.pause_circle_outline, size: 18, color: AppColors.warning),
                            SizedBox(width: 8),
                            Text('Suspender', style: TextStyle(color: AppColors.warning)),
                          ],
                        ),
                      ),
                    if (!isSuspended)
                      const PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: [
                            Icon(Icons.person_remove_outlined, size: 18, color: AppColors.error),
                            SizedBox(width: 8),
                            Text('Remover', style: TextStyle(color: AppColors.error)),
                          ],
                        ),
                      ),
                  ],
                )
              : null,
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, String action) {
    switch (action) {
      case 'toggle_role':
        _toggleRole(context, ref);
      case 'ranking_off':
        _confirmToggleRanking(context, ref, optIn: false);
      case 'ranking_on':
        _confirmToggleRanking(context, ref, optIn: true);
      case 'reservations':
        _showReservationsSheet(context, ref);
      case 'suspend':
        _confirmSuspend(context, ref);
      case 'unsuspend':
        _confirmUnsuspend(context, ref);
      case 'remove':
        _confirmRemove(context, ref);
    }
  }

  Future<void> _toggleRole(BuildContext context, WidgetRef ref) async {
    final newRole = member.isClubAdmin ? 'member' : 'admin';
    try {
      await ref.read(clubRepositoryProvider).updateMemberRole(member.id, newRole);
      ref.invalidate(currentClubMemberProvider);
      onRefresh();
    } catch (e) {
      if (context.mounted) {
        SnackbarUtils.showError(context, 'Erro: $e');
      }
    }
  }

  Future<void> _confirmToggleRanking(BuildContext context, WidgetRef ref, {required bool optIn}) async {
    final title = optIn ? 'Ativar ranking?' : 'Desativar ranking?';
    final body = optIn
        ? '${member.playerName} entrará no ranking na última posição.'
        : '${member.playerName} será removido do ranking. Desafios ativos serão cancelados automaticamente.';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: optIn
                ? null
                : FilledButton.styleFrom(backgroundColor: AppColors.warning),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(optIn ? 'Ativar' : 'Desativar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final player = ref.read(currentPlayerProvider).valueOrNull;
    if (player == null) return;

    try {
      await ref.read(clubRepositoryProvider).adminToggleRanking(
        memberId: member.id,
        adminAuthId: player.authId,
        optIn: optIn,
      );
      ref.invalidate(rankingListProvider);
      onRefresh();
      if (context.mounted) {
        SnackbarUtils.showSuccess(
          context,
          optIn
              ? '${member.playerName} entrou no ranking'
              : '${member.playerName} saiu do ranking',
        );
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarUtils.showError(context, 'Erro: $e');
      }
    }
  }

  void _showReservationsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollController) => _MemberReservationsSheet(
          member: member,
          clubId: clubId,
          scrollController: scrollController,
        ),
      ),
    );
  }

  Future<void> _confirmSuspend(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Suspender membro?'),
        content: Text(
          '${member.playerName} será suspenso e não poderá participar de desafios ou reservas.\n\n'
          'Você poderá reativá-lo depois.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Suspender'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(clubRepositoryProvider).suspendMember(member.id);
      onRefresh();
      if (context.mounted) {
        SnackbarUtils.showSuccess(context, '${member.playerName} foi suspenso');
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarUtils.showError(context, 'Erro ao suspender: $e');
      }
    }
  }

  Future<void> _confirmUnsuspend(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reativar membro?'),
        content: Text(
          '${member.playerName} será reativado e poderá voltar a participar normalmente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reativar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(clubRepositoryProvider).unsuspendMember(member.id);
      onRefresh();
      if (context.mounted) {
        SnackbarUtils.showSuccess(context, '${member.playerName} foi reativado');
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarUtils.showError(context, 'Erro ao reativar: $e');
      }
    }
  }

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final player = ref.read(currentPlayerProvider).valueOrNull;
    if (player == null) return;

    try {
      await ref.read(clubRepositoryProvider).removeMember(member.id, player.authId);
      ref.invalidate(rankingListProvider);
      onRefresh();
      if (context.mounted) {
        SnackbarUtils.showSuccess(context, 'Membro removido');
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarUtils.showError(context, 'Erro: $e');
      }
    }
  }
}

// ─── Member Reservations Bottom Sheet ───

class _MemberReservationsSheet extends ConsumerStatefulWidget {
  final ClubMemberModel member;
  final String clubId;
  final ScrollController scrollController;

  const _MemberReservationsSheet({
    required this.member,
    required this.clubId,
    required this.scrollController,
  });

  @override
  ConsumerState<_MemberReservationsSheet> createState() => _MemberReservationsSheetState();
}

class _MemberReservationsSheetState extends ConsumerState<_MemberReservationsSheet> {
  List<ReservationModel>? _reservations;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReservations();
  }

  Future<void> _loadReservations() async {
    try {
      final repo = ref.read(courtRepositoryProvider);
      final reservations = await repo.getPlayerClubReservations(
        widget.member.playerId,
        clubId: widget.clubId,
      );
      if (mounted) {
        setState(() {
          _reservations = reservations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _cancelReservation(ReservationModel reservation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar reserva?'),
        content: Text(
          'Cancelar reserva de ${reservation.courtName ?? 'quadra'} '
          'dia ${reservation.formattedDate} (${reservation.timeRange})?\n\n'
          '${reservation.isChallenge ? 'O desafio vinculado também será cancelado.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancelar reserva'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final player = ref.read(currentPlayerProvider).valueOrNull;
    if (player == null) return;

    try {
      await ref.read(courtRepositoryProvider).adminCancelReservation(
        reservationId: reservation.id,
        adminAuthId: player.authId,
      );
      if (mounted) {
        SnackbarUtils.showSuccess(context, 'Reserva cancelada');
      }
      _loadReservations();
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Erro: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Handle bar
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            'Reservas de ${widget.member.playerName}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Divider(height: 1),
        // Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text('Erro: $_error'))
                  : _reservations == null || _reservations!.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.calendar_today_outlined, size: 48, color: AppColors.onBackgroundLight),
                                SizedBox(height: 12),
                                Text(
                                  'Nenhuma reserva futura',
                                  style: TextStyle(color: AppColors.onBackgroundLight),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: widget.scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _reservations!.length,
                          itemBuilder: (context, index) {
                            final res = _reservations![index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: res.isChallenge
                                      ? AppColors.primary.withAlpha(25)
                                      : AppColors.secondary.withAlpha(25),
                                  child: Icon(
                                    res.isChallenge ? Icons.sports : Icons.calendar_month,
                                    size: 20,
                                    color: res.isChallenge ? AppColors.primary : AppColors.secondary,
                                  ),
                                ),
                                title: Text(
                                  res.courtName ?? 'Quadra',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  '${res.formattedDate} · ${res.timeRange}'
                                  '${res.isChallenge ? ' · Desafio' : ' · Amistoso'}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
                                  tooltip: 'Cancelar reserva',
                                  onPressed: () => _cancelReservation(res),
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}

// ─── Sports Section ───

class _SportsSection extends ConsumerWidget {
  final String clubId;

  const _SportsSection({required this.clubId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubSportsAsync = ref.watch(clubSportsProvider);
    final allSportsAsync = ref.watch(allSportsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: clubSportsAsync.when(
                  data: (sports) => Text(
                    'Esportes (${sports.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  loading: () => const Text('Esportes'),
                  error: (_, _) => const Text('Esportes'),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _showAddSportDialog(context, ref, clubSportsAsync, allSportsAsync),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Adicionar'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        clubSportsAsync.when(
          data: (clubSports) {
            if (clubSports.isEmpty) {
              return const Card(
                child: ListTile(
                  leading: Icon(Icons.sports, color: AppColors.onBackgroundLight),
                  title: Text('Nenhum esporte cadastrado'),
                  subtitle: Text('Adicione esportes ao clube'),
                ),
              );
            }
            return Column(
              children: clubSports.map((cs) {
                final sport = cs.sport;
                if (sport == null) return const SizedBox.shrink();
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withAlpha(25),
                      child: Icon(sport.iconData, size: 20, color: AppColors.primary),
                    ),
                    title: Text(
                      sport.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      _scoringLabel(sport.scoringType),
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.tune, color: AppColors.primary, size: 20),
                          tooltip: 'Regras',
                          onPressed: () => _showRulesSheet(context, ref, cs),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 20),
                          tooltip: 'Remover esporte',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Remover esporte'),
                                content: Text('Deseja remover ${sport.name} do clube?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                                    child: const Text('Remover'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              try {
                                await ref.read(clubRepositoryProvider)
                                    .removeClubSport(clubId, cs.sportId);
                                ref.invalidate(clubSportsProvider);
                                if (context.mounted) {
                                  SnackbarUtils.showSuccess(context, '${sport.name} removido');
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  SnackbarUtils.showError(context, 'Erro: $e');
                                }
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Erro: $e'),
        ),
      ],
    );
  }

  void _showAddSportDialog(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<ClubSportModel>> clubSportsAsync,
    AsyncValue<List<SportModel>> allSportsAsync,
  ) {
    final clubSports = clubSportsAsync.valueOrNull ?? [];
    final allSports = allSportsAsync.valueOrNull ?? [];
    final activeSportIds = clubSports.map((cs) => cs.sportId).toSet();
    final available = allSports.where((s) => !activeSportIds.contains(s.id)).toList();

    if (available.isEmpty) {
      SnackbarUtils.showInfo(context, 'Todos os esportes já estão adicionados');
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Adicionar esporte',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...available.map((sport) => ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.surfaceVariant,
                  child: Icon(sport.iconData, size: 18, color: AppColors.onBackgroundLight),
                ),
                title: Text(sport.name),
                subtitle: Text(_scoringLabel(sport.scoringType), style: const TextStyle(fontSize: 12)),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await ref.read(clubRepositoryProvider).addClubSport(clubId, sport.id);
                    ref.invalidate(clubSportsProvider);
                    if (context.mounted) {
                      SnackbarUtils.showSuccess(context, '${sport.name} adicionado!');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      SnackbarUtils.showError(context, 'Erro: $e');
                    }
                  }
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  void _showRulesSheet(BuildContext context, WidgetRef ref, ClubSportModel cs) {
    bool ambulance = cs.ruleAmbulanceEnabled;
    bool cooldown = cs.ruleCooldownEnabled;
    bool positionGap = cs.rulePositionGapEnabled;
    bool resultDelay = cs.ruleResultDelayEnabled;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Regras - ${cs.sport?.name ?? "Esporte"}',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Ambulância'),
                  subtitle: const Text('Permite ativar ambulância com penalização'),
                  value: ambulance,
                  onChanged: (v) => setState(() => ambulance = v),
                ),
                SwitchListTile(
                  title: const Text('Cooldown / Proteção'),
                  subtitle: const Text('48h cooldown desafiante + 24h proteção desafiado'),
                  value: cooldown,
                  onChanged: (v) => setState(() => cooldown = v),
                ),
                SwitchListTile(
                  title: const Text('Limite de posições'),
                  subtitle: const Text('Só pode desafiar até 2 posições acima'),
                  value: positionGap,
                  onChanged: (v) => setState(() => positionGap = v),
                ),
                SwitchListTile(
                  title: const Text('Bloqueio de resultado antecipado'),
                  subtitle: const Text('Só permite registrar resultado 40 min após o horário agendado'),
                  value: resultDelay,
                  onChanged: (v) => setState(() => resultDelay = v),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        await ref.read(clubRepositoryProvider).updateClubSportRules(
                          clubId: cs.clubId,
                          sportId: cs.sportId,
                          ruleAmbulanceEnabled: ambulance,
                          ruleCooldownEnabled: cooldown,
                          rulePositionGapEnabled: positionGap,
                          ruleResultDelayEnabled: resultDelay,
                        );
                        ref.invalidate(clubSportsProvider);
                        if (context.mounted) {
                          SnackbarUtils.showSuccess(context, 'Regras atualizadas!');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          SnackbarUtils.showError(context, 'Erro: $e');
                        }
                      }
                    },
                    child: const Text('Salvar'),
                  ),
                ),
              ],
            ),
          ),
        ),
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

// ─── Courts Section ───

class _CourtsSection extends ConsumerWidget {
  final String clubId;
  final bool isAdmin;

  const _CourtsSection({
    required this.clubId,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courtsAsync = ref.watch(_clubAllCourtsProvider(clubId));
    final clubSports = ref.watch(clubSportsProvider).valueOrNull ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: courtsAsync.when(
                  data: (courts) => Text(
                    'Quadras / Campos (${courts.where((c) => c.isActive).length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  loading: () => const Text('Quadras / Campos'),
                  error: (_, _) => const Text('Quadras / Campos'),
                ),
              ),
            ),
            if (isAdmin)
              TextButton.icon(
                onPressed: () => _showCourtDialog(context, ref, clubSports: clubSports),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Adicionar'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        courtsAsync.when(
          data: (courts) {
            if (courts.isEmpty) {
              return const Card(
                child: ListTile(
                  leading: Icon(Icons.sports, color: AppColors.onBackgroundLight),
                  title: Text('Nenhuma quadra/campo cadastrado'),
                  subtitle: Text('Adicione para reservas'),
                ),
              );
            }

            // Group courts by sportId
            final grouped = <String, List<CourtModel>>{};
            for (final c in courts) {
              grouped.putIfAbsent(c.sportId, () => []).add(c);
            }

            return Column(
              children: grouped.entries.map((entry) {
                final sport = clubSports
                    .where((cs) => cs.sportId == entry.key)
                    .map((cs) => cs.sport)
                    .firstOrNull;
                final config = sport?.facilityConfig;
                final sportLabel = config?.plural ?? sport?.name ?? 'Outro';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 8, bottom: 4),
                      child: Row(
                        children: [
                          if (sport != null) ...[
                            Icon(sport.iconData, size: 16, color: AppColors.onBackgroundMedium),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            sportLabel,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.onBackgroundMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...entry.value.map((court) => _CourtTile(
                      court: court,
                      isAdmin: isAdmin,
                      onEdit: () => _showCourtDialog(context, ref, court: court, clubSports: clubSports),
                      onToggleActive: () async {
                        final repo = ref.read(courtRepositoryProvider);
                        if (court.isActive) {
                          await repo.deactivateCourt(court.id);
                        } else {
                          await repo.reactivateCourt(court.id);
                        }
                        ref.invalidate(_clubAllCourtsProvider(clubId));
                        ref.invalidate(courtsListProvider);
                      },
                      onManageSlots: () => context.push(
                        '/courts/${court.id}/slots?name=${Uri.encodeComponent(court.name)}',
                      ),
                    )),
                  ],
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Erro: $e'),
        ),
      ],
    );
  }

  void _showCourtDialog(
    BuildContext context,
    WidgetRef ref, {
    CourtModel? court,
    required List<ClubSportModel> clubSports,
  }) {
    if (clubSports.isEmpty) {
      SnackbarUtils.showInfo(context, 'Adicione um esporte ao clube primeiro');
      return;
    }

    // For editing, find the sport of the court; for new, default to current or first
    final initialSportId = court?.sportId
        ?? ref.read(currentSportIdProvider)
        ?? clubSports.first.sportId;

    SportModel? findSport(String sportId) {
      return clubSports
          .where((cs) => cs.sportId == sportId)
          .map((cs) => cs.sport)
          .firstOrNull;
    }

    String selectedSportId = initialSportId;
    FacilityConfig? config = findSport(selectedSportId)?.facilityConfig;

    final nameController = TextEditingController(text: court?.name ?? '');
    final notesController = TextEditingController(text: court?.notes ?? '');
    String? selectedSurface = court?.surfaceType;
    bool isCovered = court?.isCovered ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(court == null
              ? (config?.newTitle ?? 'Novo Local')
              : (config?.editTitle ?? 'Editar Local')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sport selector (only for new courts)
                if (court == null && clubSports.length > 1)
                  DropdownButtonFormField<String>(
                    initialValue: selectedSportId,
                    decoration: const InputDecoration(labelText: 'Esporte'),
                    items: clubSports
                        .where((cs) => cs.sport != null)
                        .map((cs) => DropdownMenuItem(
                              value: cs.sportId,
                              child: Row(
                                children: [
                                  Icon(cs.sport!.iconData, size: 18),
                                  const SizedBox(width: 8),
                                  Text(cs.sport!.name),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        selectedSportId = v;
                        config = findSport(v)?.facilityConfig;
                        selectedSurface = null; // reset surface when sport changes
                      });
                    },
                  ),
                if (court == null && clubSports.length > 1)
                  const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: config?.nameLabel ?? 'Nome',
                    hintText: config?.nameHint ?? 'Ex: Local 1',
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                if (config != null && config!.surfaces.isNotEmpty)
                  DropdownButtonFormField<String>(
                    key: ValueKey('surface_$selectedSportId'),
                    initialValue: selectedSurface,
                    decoration: const InputDecoration(labelText: 'Tipo de piso'),
                    items: config!.surfaces
                        .map((s) => DropdownMenuItem(value: s.value, child: Text(s.label)))
                        .toList(),
                    onChanged: (v) => setState(() => selectedSurface = v),
                  ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: Text(config?.coveredLabel ?? 'Coberto'),
                  value: isCovered,
                  onChanged: (v) => setState(() => isCovered = v),
                  contentPadding: EdgeInsets.zero,
                ),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Observações (opcional)',
                    hintText: 'Ex: Iluminação disponível',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                final repo = ref.read(courtRepositoryProvider);
                if (court == null) {
                  await repo.createCourt(
                    clubId: clubId,
                    sportId: selectedSportId,
                    name: name,
                    surfaceType: selectedSurface,
                    isCovered: isCovered,
                    notes: notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                  );
                } else {
                  await repo.updateCourt(
                    court.id,
                    name: name,
                    surfaceType: selectedSurface,
                    isCovered: isCovered,
                    notes: notesController.text.trim().isEmpty
                        ? null
                        : notesController.text.trim(),
                  );
                }
                ref.invalidate(_clubAllCourtsProvider(clubId));
                ref.invalidate(courtsListProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(court == null ? 'Criar' : 'Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourtTile extends StatelessWidget {
  final CourtModel court;
  final bool isAdmin;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback? onManageSlots;

  const _CourtTile({
    required this.court,
    required this.isAdmin,
    required this.onEdit,
    required this.onToggleActive,
    this.onManageSlots,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: court.isActive
              ? AppColors.primary.withAlpha(25)
              : AppColors.surfaceVariant,
          child: Icon(
            court.isCovered ? Icons.roofing : Icons.wb_sunny,
            size: 20,
            color: court.isActive ? AppColors.primary : AppColors.onBackgroundLight,
          ),
        ),
        title: Text(
          court.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: court.isActive ? null : AppColors.onBackgroundLight,
          ),
        ),
        subtitle: Text(
          [
            court.surfaceLabel,
            court.isCovered ? 'Coberta' : 'Descoberta',
            if (!court.isActive) 'Inativa',
          ].join(' · '),
          style: TextStyle(
            fontSize: 12,
            color: court.isActive ? AppColors.onBackgroundMedium : AppColors.onBackgroundLight,
          ),
        ),
        trailing: isAdmin
            ? PopupMenuButton<String>(
                onSelected: (action) {
                  if (action == 'edit') onEdit();
                  if (action == 'toggle') onToggleActive();
                  if (action == 'slots') onManageSlots?.call();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Editar'),
                  ),
                  const PopupMenuItem(
                    value: 'slots',
                    child: Text('Horários'),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(
                      court.isActive ? 'Desativar' : 'Reativar',
                      style: TextStyle(
                        color: court.isActive ? AppColors.error : AppColors.success,
                      ),
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}
