import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../shared/models/club_member_model.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/reservation_model.dart';
import '../../../shared/providers/current_player_provider.dart';
import '../../clubs/viewmodel/club_providers.dart';
import '../viewmodel/reservation_viewmodel.dart';

class MyReservationsScreen extends ConsumerWidget {
  const MyReservationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservationsAsync = ref.watch(myReservationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Reservas'),
      ),
      body: reservationsAsync.when(
        data: (reservations) {
          if (reservations.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today,
                      size: 64, color: AppColors.onBackgroundLight),
                  SizedBox(height: 16),
                  Text(
                    'Nenhuma reserva ativa',
                    style: TextStyle(
                        fontSize: 16, color: AppColors.onBackgroundLight),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Reserve um horário na aba Reservas',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.onBackgroundLight),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myReservationsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: reservations.length,
              itemBuilder: (context, index) => _ReservationCard(
                reservation: reservations[index],
              ),
            ),
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
                onPressed: () => ref.invalidate(myReservationsProvider),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReservationCard extends ConsumerWidget {
  final ReservationModel reservation;

  const _ReservationCard({required this.reservation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final resDate = DateTime(
      reservation.reservationDate.year,
      reservation.reservationDate.month,
      reservation.reservationDate.day,
    );
    final isToday = resDate == today;
    final isTomorrow = resDate == today.add(const Duration(days: 1));

    final accentColor =
        reservation.isChallenge ? AppColors.secondary : AppColors.primary;
    final accentDark =
        reservation.isChallenge ? AppColors.secondaryDark : AppColors.primaryDark;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: reservation.isChallenge
            ? BoxDecoration(
                border: Border(
                  left: BorderSide(color: AppColors.secondary, width: 4),
                ),
              )
            : null,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: accentColor.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  if (reservation.isChallenge)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Icon(Icons.emoji_events,
                          size: 14, color: accentDark),
                    ),
                  Text(
                    reservation.reservationDate.day
                        .toString()
                        .padLeft(2, '0'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: accentDark,
                    ),
                  ),
                  Text(
                    '${reservation.reservationDate.month.toString().padLeft(2, '0')}/${reservation.reservationDate.year}',
                    style: TextStyle(
                      fontSize: 10,
                      color: accentDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reservation.courtName ?? 'Local',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 14, color: AppColors.onBackgroundLight),
                      const SizedBox(width: 4),
                      Text(
                        reservation.timeRange,
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.onBackgroundLight),
                      ),
                    ],
                  ),
                  // Opponent info
                  if (reservation.hasOpponentDeclared ||
                      reservation.isFriendly) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          reservation.hasOpponentDeclared
                              ? Icons.person
                              : Icons.person_outline,
                          size: 14,
                          color: reservation.hasOpponentDeclared
                              ? AppColors.onBackgroundMedium
                              : AppColors.warning,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'vs ${reservation.opponentDisplayName}',
                            style: TextStyle(
                              fontSize: 12,
                              color: reservation.hasOpponentDeclared
                                  ? AppColors.onBackgroundMedium
                                  : AppColors.warning,
                              fontStyle: reservation.hasOpponentDeclared
                                  ? FontStyle.normal
                                  : FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Badges row
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (isToday || isTomorrow)
                        _Badge(
                          label: isToday ? 'Hoje' : 'Amanhã',
                          color:
                              isToday ? AppColors.warning : AppColors.info,
                        ),
                      if (reservation.isChallenge)
                        _Badge(
                          label: 'Ranking',
                          color: AppColors.secondary,
                          icon: Icons.emoji_events,
                        ),
                      if (!reservation.hasOpponentDeclared &&
                          reservation.isFriendly)
                        GestureDetector(
                          onTap: () => _showDeclareOpponentSheet(
                              context, ref, reservation),
                          child: _Badge(
                            label: 'Declarar oponente',
                            color: AppColors.warning,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () =>
                  _confirmCancel(context, ref, reservation),
              icon: const Icon(Icons.close, color: AppColors.error),
              tooltip: 'Cancelar reserva',
            ),
          ],
        ),
      ),
    );
  }

  void _showDeclareOpponentSheet(
    BuildContext context,
    WidgetRef ref,
    ReservationModel reservation,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _DeclareOpponentSheet(
        reservationId: reservation.id,
        clubId: ref.read(currentClubIdProvider),
      ),
    );
  }

  void _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    ReservationModel reservation,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar Reserva'),
        content: Text(
          'Cancelar reserva de ${reservation.courtName ?? 'local'} '
          'em ${reservation.formattedDate} das ${reservation.timeRange}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Não'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await ref
                  .read(reservationActionProvider.notifier)
                  .cancelReservation(reservation.id);

              if (context.mounted) {
                if (success) {
                  SnackbarUtils.showSuccess(context, 'Reserva cancelada');
                  ref.invalidate(myReservationsProvider);
                  ref.invalidate(hasActiveFriendlyReservationProvider);
                } else {
                  SnackbarUtils.showError(
                      context, 'Erro ao cancelar reserva');
                }
              }
            },
            child: const Text('Cancelar Reserva'),
          ),
        ],
      ),
    );
  }
}

// ─── Badge Widget ───

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _Badge({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Declare Opponent Bottom Sheet ───

class _DeclareOpponentSheet extends ConsumerStatefulWidget {
  final String reservationId;
  final String? clubId;

  const _DeclareOpponentSheet({
    required this.reservationId,
    required this.clubId,
  });

  @override
  ConsumerState<_DeclareOpponentSheet> createState() =>
      _DeclareOpponentSheetState();
}

class _DeclareOpponentSheetState
    extends ConsumerState<_DeclareOpponentSheet> {
  OpponentType _selectedType = OpponentType.member;
  ClubMemberModel? _selectedMember;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Declarar Oponente',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),

              // Type chips
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Membro'),
                    selected: _selectedType == OpponentType.member,
                    onSelected: (_) => setState(() {
                      _selectedType = OpponentType.member;
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('Convidado'),
                    selected: _selectedType == OpponentType.guest,
                    onSelected: (_) => setState(() {
                      _selectedType = OpponentType.guest;
                      _selectedMember = null;
                    }),
                  ),
                ],
              ),

              // Member search
              if (_selectedType == OpponentType.member) ...[
                const SizedBox(height: 12),
                _buildMemberPicker(),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _canConfirm ? _doConfirm : null,
                  icon: const Icon(Icons.check),
                  label: const Text('Confirmar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _canConfirm {
    if (_selectedType == OpponentType.member && _selectedMember == null) {
      return false;
    }
    return true;
  }

  void _doConfirm() async {
    final success = await ref
        .read(reservationActionProvider.notifier)
        .updateOpponent(
          widget.reservationId,
          opponentType: _selectedType,
          opponentId: _selectedType == OpponentType.member
              ? _selectedMember?.playerId
              : null,
          opponentName: _selectedType == OpponentType.guest
              ? 'Convidado'
              : _selectedMember?.displayName,
        );

    if (mounted) {
      Navigator.of(context).pop();
      if (success) {
        SnackbarUtils.showSuccess(context, 'Oponente declarado!');
        ref.invalidate(myReservationsProvider);
      } else {
        SnackbarUtils.showError(context, 'Erro ao declarar oponente');
      }
    }
  }

  Widget _buildMemberPicker() {
    if (widget.clubId == null) {
      return const Text('Clube não selecionado',
          style: TextStyle(color: AppColors.onBackgroundLight));
    }

    final membersAsync = ref.watch(clubMembersProvider(widget.clubId!));
    final currentPlayer = ref.watch(currentPlayerProvider).valueOrNull;

    return Column(
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Buscar membro...',
            prefixIcon: const Icon(Icons.search, size: 20),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onChanged: (v) => setState(() => _searchQuery = v),
        ),
        const SizedBox(height: 8),
        membersAsync.when(
          data: (members) {
            final query = _searchQuery.toLowerCase().trim();
            final filtered = members.where((m) {
              if (!m.isActive) return false;
              if (currentPlayer != null && m.playerId == currentPlayer.id) {
                return false;
              }
              if (query.isEmpty) return true;
              return m.playerName.toLowerCase().contains(query) ||
                  (m.playerNickname?.toLowerCase().contains(query) ?? false);
            }).toList();

            if (filtered.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Nenhum membro encontrado',
                    style: TextStyle(color: AppColors.onBackgroundLight)),
              );
            }

            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final member = filtered[index];
                  final isSelected =
                      _selectedMember?.playerId == member.playerId;
                  return ListTile(
                    dense: true,
                    selected: isSelected,
                    selectedTileColor: AppColors.primary.withAlpha(15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: isSelected
                          ? AppColors.primary
                          : AppColors.primaryLight,
                      child: Text(
                        member.playerName[0].toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    title: Text(
                      member.displayName,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: member.rankingPosition != null
                        ? Text('#${member.rankingPosition}',
                            style: const TextStyle(fontSize: 12))
                        : null,
                    trailing: isSelected
                        ? const Icon(Icons.check_circle,
                            color: AppColors.primary, size: 20)
                        : null,
                    onTap: () => setState(() => _selectedMember = member),
                  );
                },
              ),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Erro: $e'),
        ),
      ],
    );
  }
}
