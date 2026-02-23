import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../shared/models/club_member_model.dart';
import '../../../shared/models/court_model.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/reservation_model.dart';
import '../../../shared/models/time_slot.dart';
import '../../../shared/providers/current_player_provider.dart';
import '../../../shared/utils/slot_generator.dart';
import '../../clubs/viewmodel/club_providers.dart';
import '../data/court_repository.dart';
import '../viewmodel/reservation_viewmodel.dart';

/// Provider to load a single court by ID
final _courtProvider =
    FutureProvider.autoDispose.family<CourtModel, String>((ref, courtId) async {
  final repo = ref.watch(courtRepositoryProvider);
  return repo.getCourtById(courtId);
});

class CourtScheduleScreen extends ConsumerStatefulWidget {
  final String courtId;

  const CourtScheduleScreen({super.key, required this.courtId});

  @override
  ConsumerState<CourtScheduleScreen> createState() =>
      _CourtScheduleScreenState();
}

class _CourtScheduleScreenState extends ConsumerState<CourtScheduleScreen> {
  late DateTime _selectedDate;
  late final ScrollController _dateScrollController;

  // Generate 60 days starting from today
  late final List<DateTime> _dates;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _selectedDate = DateTime(today.year, today.month, today.day);
    _dates = List.generate(
      60,
      (i) => DateTime(today.year, today.month, today.day + i),
    );
    _dateScrollController = ScrollController();
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final courtAsync = ref.watch(_courtProvider(widget.courtId));

    return courtAsync.when(
      data: (court) => _buildContent(context, court),
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Erro: $e')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, CourtModel court) {
    // Convert DateTime.weekday (1=Mon, 7=Sun) to DB format (0=Sun, 6=Sat)
    final dbDayOfWeek =
        _selectedDate.weekday == 7 ? 0 : _selectedDate.weekday;

    final slots = generateSlots(court, dbDayOfWeek);
    final reservationsAsync = ref.watch(courtReservationsProvider(
      (courtId: court.id, date: _selectedDate),
    ));

    return Scaffold(
      appBar: AppBar(
        title: Text(court.name),
        actions: [
          IconButton(
            onPressed: _openDatePicker,
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Escolher data',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDateSelector(),
          const Divider(height: 1),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  _formatDateLabel(_selectedDate),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Text(
                  _dayOfWeekLabel(dbDayOfWeek),
                  style:
                      const TextStyle(color: AppColors.onBackgroundLight, fontSize: 13),
                ),
              ],
            ),
          ),
          Expanded(
            child: slots.isEmpty
                ? const Center(
                    child: Text(
                      'Quadra fechada neste dia',
                      style: TextStyle(color: AppColors.onBackgroundLight),
                    ),
                  )
                : reservationsAsync.when(
                    data: (reservations) => _buildSlotsList(slots, reservations),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(
                      child: Text('Erro ao carregar reservas: $err'),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        controller: _dateScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: _dates.length,
        itemBuilder: (context, index) {
          final date = _dates[index];
          final isSelected = date.year == _selectedDate.year &&
              date.month == _selectedDate.month &&
              date.day == _selectedDate.day;
          final isToday = index == 0;

          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: Container(
              width: 52,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : isToday
                        ? AppColors.primary.withAlpha(20)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isToday && !isSelected
                    ? Border.all(color: AppColors.primary.withAlpha(80))
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _dayShort(date.weekday),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.white : AppColors.onBackgroundLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : isToday
                              ? AppColors.primary
                              : AppColors.onBackground,
                    ),
                  ),
                  Text(
                    _monthShort(date.month),
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected
                          ? Colors.white
                          : AppColors.onBackgroundLight,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlotsList(
    List<TimeSlot> slots,
    List<ReservationModel> reservations,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = _selectedDate.isAtSameMomentAs(today);
    final isPast = _selectedDate.isBefore(today);
    final currentPlayer = ref.watch(currentPlayerProvider).valueOrNull;
    final currentPlayerId = currentPlayer?.id;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        final reservation = _findReservation(slot, reservations);
        final isReserved = reservation != null;

        final slotHour = int.tryParse(slot.startTime.split(':')[0]) ?? 0;
        final isSlotPast = isPast || (isToday && slotHour <= now.hour);

        final isChallenge = reservation?.isChallenge ?? false;
        final isMine = reservation != null && reservation.reservedBy == currentPlayerId;
        final isMyCandidate = reservation != null && reservation.candidateId == currentPlayerId;
        final hasOpenSlot = reservation != null &&
            reservation.isFriendly &&
            !reservation.hasOpponentDeclared &&
            !isMine;

        final statusColor = isReserved
            ? isChallenge
                ? AppColors.secondary
                : AppColors.error
            : isSlotPast
                ? AppColors.onBackgroundLight
                : AppColors.success;

        // Build subtitle for reserved slots
        String subtitle;
        if (isReserved) {
          final name = reservation.playerName ?? 'Jogador';
          if (isChallenge) {
            final opponent = reservation.opponentPlayerName;
            subtitle = opponent != null
                ? 'Desafio: $name vs $opponent'
                : 'Desafio - $name';
          } else if (reservation.hasOpponentDeclared) {
            subtitle = '$name vs ${reservation.opponentDisplayName}';
          } else {
            subtitle = '$name · Vaga aberta';
          }
        } else {
          subtitle = isSlotPast ? 'Horário passado' : 'Disponível';
        }

        // Build trailing action widget
        Widget trailing;
        if (!isReserved && !isSlotPast) {
          trailing = ElevatedButton(
            onPressed: () => _confirmReservation(slot),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              minimumSize: const Size(0, 36),
            ),
            child: const Text('Reservar', style: TextStyle(fontSize: 13)),
          );
        } else if (isMine) {
          trailing = IconButton(
            onPressed: () => _confirmCancelFromSchedule(reservation),
            icon: const Icon(Icons.close, color: AppColors.error, size: 20),
            tooltip: 'Cancelar reserva',
          );
        } else if (isMyCandidate) {
          trailing = Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.warning.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Aguardando',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.warning),
            ),
          );
        } else if (hasOpenSlot && !isSlotPast) {
          trailing = TextButton.icon(
            onPressed: () => _confirmApply(reservation),
            icon: const Icon(Icons.sports_tennis, size: 16),
            label: const Text('Quero jogar', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
            ),
          );
        } else if (isReserved) {
          trailing = Icon(
            isChallenge ? Icons.emoji_events : Icons.lock,
            color: isChallenge ? AppColors.secondary : AppColors.onBackgroundLight,
            size: 20,
          );
        } else {
          trailing = const SizedBox.shrink();
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: isChallenge
                ? BoxDecoration(
                    border: Border(
                      left: BorderSide(
                          color: AppColors.secondary, width: 3),
                    ),
                  )
                : null,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: isChallenge
                        ? Icon(Icons.emoji_events,
                            size: 22, color: statusColor)
                        : Text(
                            slot.startTime,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: statusColor,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slot.timeRange,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style:
                            TextStyle(fontSize: 12, color: statusColor),
                      ),
                    ],
                  ),
                ),
                trailing,
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmCancelFromSchedule(ReservationModel reservation) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar Reserva'),
        content: Text(
          'Cancelar sua reserva das ${reservation.timeRange}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Não'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await ref
                  .read(reservationActionProvider.notifier)
                  .cancelReservation(reservation.id);
              if (mounted) {
                if (success) {
                  SnackbarUtils.showSuccess(context, 'Reserva cancelada');
                  ref.invalidate(courtReservationsProvider(
                    (courtId: widget.courtId, date: _selectedDate),
                  ));
                  ref.invalidate(myReservationsProvider);
                  ref.invalidate(hasActiveFriendlyReservationProvider);
                } else {
                  SnackbarUtils.showError(context, 'Erro ao cancelar reserva');
                }
              }
            },
            child: const Text('Cancelar Reserva'),
          ),
        ],
      ),
    );
  }

  void _confirmApply(ReservationModel reservation) {
    final ownerName = reservation.playerName ?? 'Jogador';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Candidatar-se'),
        content: Text(
          'Deseja se candidatar para jogar com $ownerName das ${reservation.timeRange}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await ref
                  .read(reservationActionProvider.notifier)
                  .applyToReservation(reservation.id);
              if (mounted) {
                if (success) {
                  SnackbarUtils.showSuccess(context, 'Candidatura enviada!');
                  ref.invalidate(courtReservationsProvider(
                    (courtId: widget.courtId, date: _selectedDate),
                  ));
                } else {
                  SnackbarUtils.showError(context, 'Erro ao se candidatar');
                }
              }
            },
            child: const Text('Quero jogar!'),
          ),
        ],
      ),
    );
  }

  Future<void> _openDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      final dayIndex = _dates.indexWhere((d) =>
          d.year == picked.year &&
          d.month == picked.month &&
          d.day == picked.day);
      if (dayIndex >= 0) {
        _dateScrollController.animateTo(
          dayIndex * 60.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _confirmReservation(TimeSlot slot) async {
    // Check friendly reservation limit
    final hasFriendly =
        await ref.read(hasActiveFriendlyReservationProvider.future);
    if (hasFriendly && mounted) {
      SnackbarUtils.showError(
        context,
        'Você já tem uma reserva amistosa ativa. Cancele ou conclua antes de reservar outra.',
      );
      return;
    }
    if (!mounted) return;

    final courtName =
        ref.read(_courtProvider(widget.courtId)).valueOrNull?.name ?? 'Quadra';
    final clubId = ref.read(currentClubIdProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ReservationBottomSheet(
        courtName: courtName,
        date: _selectedDate,
        slot: slot,
        clubId: clubId,
        onConfirm: (opponentType, opponentId, opponentName) async {
          Navigator.of(ctx).pop();
          final success = await ref
              .read(reservationActionProvider.notifier)
              .createReservation(
                courtId: widget.courtId,
                date: _selectedDate,
                startTime: slot.startTime,
                endTime: slot.endTime,
                opponentType: opponentType,
                opponentId: opponentId,
                opponentName: opponentName,
              );

          if (mounted) {
            if (success) {
              SnackbarUtils.showSuccess(context, 'Reserva confirmada!');
              ref.invalidate(courtReservationsProvider(
                (courtId: widget.courtId, date: _selectedDate),
              ));
              ref.invalidate(myReservationsProvider);
              ref.invalidate(hasActiveFriendlyReservationProvider);
            } else {
              SnackbarUtils.showError(context, 'Erro ao reservar');
            }
          }
        },
      ),
    );
  }

  ReservationModel? _findReservation(
    TimeSlot slot,
    List<ReservationModel> reservations,
  ) {
    for (final r in reservations) {
      if (_normalizeTime(r.startTime) == slot.startTime) return r;
    }
    return null;
  }

  static String _normalizeTime(String time) {
    final parts = time.split(':');
    if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
    return time;
  }

  String _formatDateLabel(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static String _dayShort(int weekday) {
    return switch (weekday) {
      1 => 'Seg',
      2 => 'Ter',
      3 => 'Qua',
      4 => 'Qui',
      5 => 'Sex',
      6 => 'Sab',
      7 => 'Dom',
      _ => '',
    };
  }

  static String _monthShort(int month) {
    return switch (month) {
      1 => 'Jan',
      2 => 'Fev',
      3 => 'Mar',
      4 => 'Abr',
      5 => 'Mai',
      6 => 'Jun',
      7 => 'Jul',
      8 => 'Ago',
      9 => 'Set',
      10 => 'Out',
      11 => 'Nov',
      12 => 'Dez',
      _ => '',
    };
  }

  String _dayOfWeekLabel(int dow) {
    return switch (dow) {
      0 => 'Domingo',
      1 => 'Segunda-feira',
      2 => 'Terça-feira',
      3 => 'Quarta-feira',
      4 => 'Quinta-feira',
      5 => 'Sexta-feira',
      6 => 'Sábado',
      _ => '',
    };
  }
}

// ─── Reservation Bottom Sheet with Opponent Picker ───

class _ReservationBottomSheet extends ConsumerStatefulWidget {
  final String courtName;
  final DateTime date;
  final TimeSlot slot;
  final String? clubId;
  final void Function(
    OpponentType? opponentType,
    String? opponentId,
    String? opponentName,
  ) onConfirm;

  const _ReservationBottomSheet({
    required this.courtName,
    required this.date,
    required this.slot,
    required this.clubId,
    required this.onConfirm,
  });

  @override
  ConsumerState<_ReservationBottomSheet> createState() =>
      _ReservationBottomSheetState();
}

class _ReservationBottomSheetState
    extends ConsumerState<_ReservationBottomSheet> {
  // null = declarar depois, member = membro, guest = convidado
  OpponentType? _selectedType;
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
    final dateStr =
        '${widget.date.day.toString().padLeft(2, '0')}/${widget.date.month.toString().padLeft(2, '0')}';

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
              // Handle
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

              // Title
              Text(
                'Confirmar Reserva',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),

              // Summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event, color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${widget.courtName} · $dateStr · ${widget.slot.timeRange}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Opponent section
              Text(
                'Oponente (opcional)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Você pode declarar depois em "Minhas Reservas"',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.onBackgroundLight,
                ),
              ),
              const SizedBox(height: 12),

              // Opponent type chips
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Declarar depois'),
                    selected: _selectedType == null,
                    onSelected: (_) => setState(() {
                      _selectedType = null;
                      _selectedMember = null;
                    }),
                  ),
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

              // Member search (when type = member)
              if (_selectedType == OpponentType.member) ...[
                const SizedBox(height: 12),
                _buildMemberPicker(),
              ],

              const SizedBox(height: 24),

              // Confirm button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _canConfirm ? _doConfirm : null,
                  icon: const Icon(Icons.check),
                  label: const Text('Confirmar Reserva'),
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

  void _doConfirm() {
    widget.onConfirm(
      _selectedType,
      _selectedMember?.playerId,
      _selectedType == OpponentType.guest
          ? 'Convidado'
          : _selectedMember?.displayName,
    );
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
        // Search field
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

        // Member list
        membersAsync.when(
          data: (members) {
            final query = _searchQuery.toLowerCase().trim();
            final filtered = members.where((m) {
              if (!m.isActive) return false;
              // Exclude current player
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
                    onTap: () =>
                        setState(() => _selectedMember = member),
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
