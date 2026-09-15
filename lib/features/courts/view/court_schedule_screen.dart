import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../shared/models/club_member_model.dart';
import '../../../shared/models/court_model.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/models/reservation_model.dart';
import '../../../shared/models/time_slot.dart';
import '../../../shared/providers/current_player_provider.dart';
import '../../../shared/utils/slot_generator.dart';
import '../../challenges/viewmodel/challenge_detail_viewmodel.dart';
import '../../challenges/viewmodel/challenge_list_viewmodel.dart';
import '../../clubs/viewmodel/club_providers.dart';
import '../data/court_repository.dart';
import '../viewmodel/courts_viewmodel.dart';
import '../viewmodel/reservation_viewmodel.dart';

/// Provider to load a single court by ID
final _courtProvider =
    FutureProvider.autoDispose.family<CourtModel, String>((ref, courtId) async {
  final repo = ref.watch(courtRepositoryProvider);
  return repo.getCourtById(courtId);
});

class CourtScheduleScreen extends ConsumerStatefulWidget {
  final String courtId;
  final bool isAdminMode;
  final DateTime? maxDate;
  final String? editingReservationId;

  const CourtScheduleScreen({super.key, required this.courtId, this.isAdminMode = false, this.maxDate, this.editingReservationId});

  @override
  ConsumerState<CourtScheduleScreen> createState() =>
      _CourtScheduleScreenState();
}

class _CourtScheduleScreenState extends ConsumerState<CourtScheduleScreen> {
  late DateTime _selectedDate;
  // Quadra atualmente exibida. Começa na quadra recebida, mas o ADM pode
  // trocar (ex.: mover uma reserva para outra quadra).
  late String _courtId;
  late final ScrollController _dateScrollController;

  // Generate 60 days starting from today
  late final List<DateTime> _dates;

  @override
  void initState() {
    super.initState();
    _courtId = widget.courtId;
    final today = DateTime.now();
    _selectedDate = DateTime(today.year, today.month, today.day);
    // Effective max date:
    // - explicit maxDate (e.g. editing) always wins;
    // - friendly (non-admin) reservations are capped at D+2;
    // - admin reservations have no cap.
    final DateTime? maxDate = widget.maxDate != null
        ? DateTime(widget.maxDate!.year, widget.maxDate!.month, widget.maxDate!.day)
        : widget.isAdminMode
            ? null
            : DateTime(today.year, today.month,
                today.day + AppConstants.friendlyReservationMaxDaysAhead);
    _dates = List.generate(60, (i) => DateTime(today.year, today.month, today.day + i))
        .where((d) => maxDate == null || !d.isAfter(maxDate))
        .toList();
    _dateScrollController = ScrollController();
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final courtAsync = ref.watch(_courtProvider(_courtId));

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
    // Admin no fluxo de jogador: aqui a reserva é PARA VOCÊ. Para reservar
    // por outros jogadores, use o Painel Admin → Reservas.
    final isAdmin = !widget.isAdminMode &&
        (ref.watch(isClubAdminProvider).valueOrNull ?? false);

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
          if (widget.isAdminMode)
            _buildAdminBar(court)
          else if (isAdmin)
            _buildPlayerModeAdminHint(context),
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

  /// Barra do modo ADM: trocar de quadra e, ao editar, instruir como mover.
  Widget _buildAdminBar(CourtModel court) {
    final isEditing = widget.editingReservationId != null;
    return Container(
      color: AppColors.primary.withAlpha(15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isEditing)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Editando reserva: escolha a quadra e a data e toque em um '
                'horário livre para mover. Os jogadores são mantidos.',
                style:
                    TextStyle(fontSize: 12, color: AppColors.onBackgroundLight),
              ),
            ),
          OutlinedButton.icon(
            onPressed: _pickCourt,
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: Text('Trocar quadra (atual: ${court.name})'),
          ),
        ],
      ),
    );
  }

  /// Aviso para admins no fluxo de jogador: a reserva aqui é PARA VOCÊ.
  Widget _buildPlayerModeAdminHint(BuildContext context) {
    return Container(
      color: AppColors.secondary.withAlpha(20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              'Aqui a reserva é PARA VOCÊ. Para reservar por outros jogadores, '
              'use o Painel Admin → Reservas.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          TextButton.icon(
            onPressed: () => context.push('/admin/reservations'),
            icon: const Icon(Icons.admin_panel_settings, size: 16),
            label: const Text('Abrir Painel Admin'),
          ),
        ],
      ),
    );
  }

  /// Abre um seletor com as quadras do clube e troca a quadra exibida.
  Future<void> _pickCourt() async {
    final List<CourtModel> courts;
    try {
      courts = await ref.read(courtsListProvider.future);
    } catch (_) {
      return;
    }
    if (!mounted || courts.isEmpty) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Escolher quadra',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            ...courts.map(
              (c) => ListTile(
                leading: Icon(
                  Icons.sports_tennis,
                  color: c.id == _courtId ? AppColors.primary : null,
                ),
                title: Text(c.name),
                trailing: c.id == _courtId
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, c.id),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null && selected != _courtId && mounted) {
      setState(() => _courtId = selected);
    }
  }

  Widget _buildDateSelector() {
    return SizedBox(
      height: 80,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
        ),
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

        final slotParts = slot.startTime.split(':');
        final slotHour = int.tryParse(slotParts[0]) ?? 0;
        final slotMinute = slotParts.length > 1 ? (int.tryParse(slotParts[1]) ?? 0) : 0;
        final isSlotPast = isPast || (isToday && (slotHour < now.hour || (slotHour == now.hour && slotMinute <= now.minute)));

        final isChallenge = reservation?.isChallenge ?? false;
        final isMine = reservation != null && reservation.reservedBy == currentPlayerId;
        // O adversário declarado também está jogando: sem isso ele via cadeado
        // e não conseguia desmarcar o próprio jogo (relatado no grupo em
        // 15/09 — Fábio reservou, Guilherme era o adversário e ficou preso).
        final isOpponent = reservation != null &&
            reservation.opponentType == OpponentType.member &&
            reservation.opponentId == currentPlayerId;
        final isParticipant = isMine || isOpponent;
        final hasOpenSlot = reservation != null &&
            reservation.isFriendly &&
            !reservation.hasOpponentDeclared &&
            !isParticipant;

        final isAdminReservation = reservation?.isAdministrative ?? false;
        final statusColor = isReserved
            ? isAdminReservation
                ? AppColors.warning
                : isChallenge
                    ? AppColors.secondary
                    : AppColors.error
            : isSlotPast
                ? AppColors.onBackgroundLight
                : AppColors.success;

        // Build subtitle for reserved slots
        String subtitle;
        if (isReserved) {
          if (reservation.isAdministrative) {
            subtitle = reservation.administrativeTitle;
          } else {
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
        } else if (isOpponent && !isChallenge) {
          // Adversário sai do jogo e devolve a vaga; quem criou mantém o
          // horário. Cancelar a reserva inteira continua sendo do dono.
          trailing = IconButton(
            onPressed: () => _confirmLeaveReservation(reservation),
            icon: const Icon(Icons.exit_to_app, color: AppColors.error, size: 20),
            tooltip: 'Sair da reserva',
          );
        } else if (isParticipant && !isChallenge) {
          // Só reserva amistosa pode ser cancelada aqui. Desafio de ranking
          // não — só admin, pelo detalhe do desafio ou painel admin.
          trailing = IconButton(
            onPressed: () => _confirmCancelFromSchedule(reservation),
            icon: const Icon(Icons.close, color: AppColors.error, size: 20),
            tooltip: 'Cancelar reserva',
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

  /// Adversário sai do jogo e devolve a vaga — a reserva continua de pé no
  /// nome de quem criou, com a vaga aberta pra outro jogador entrar.
  void _confirmLeaveReservation(ReservationModel reservation) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair da Reserva'),
        content: Text(
          'Sair do jogo das ${reservation.timeRange}?\n\n'
          'O horário continua reservado para ${reservation.playerName ?? 'quem criou'}, '
          'e a vaga fica aberta para outro jogador entrar.',
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
                  .leaveReservation(reservation.id);
              if (mounted) {
                if (success) {
                  SnackbarUtils.showSuccess(
                      context, 'Você saiu do jogo. A vaga ficou aberta.');
                  ref.invalidate(courtReservationsProvider(
                    (courtId: _courtId, date: _selectedDate),
                  ));
                  ref.invalidate(myReservationsProvider);
                  ref.invalidate(hasActiveFriendlyReservationProvider);
                } else {
                  SnackbarUtils.showError(context, 'Erro ao sair da reserva');
                }
              }
            },
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }

  void _confirmCancelFromSchedule(ReservationModel reservation) {
    final isChallenge = reservation.isChallenge;
    // Jogador não pode cancelar desafio de ranking (nem pela reserva) — só admin.
    if (isChallenge && !(ref.read(isClubAdminProvider).valueOrNull ?? false)) {
      SnackbarUtils.showError(
          context, 'Só um administrador pode cancelar um desafio de ranking.');
      return;
    }
    final message = isChallenge
        ? 'Esta reserva está vinculada a um desafio. '
            'Ao cancelar a reserva, o desafio também será cancelado. '
            'Deseja continuar?'
        : 'Cancelar sua reserva das ${reservation.timeRange}?';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isChallenge ? 'Cancelar Reserva e Desafio' : 'Cancelar Reserva'),
        content: Text(message),
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

              if (success && isChallenge) {
                await ref
                    .read(challengeActionProvider.notifier)
                    .cancelChallenge(reservation.challengeId!);
              }

              if (mounted) {
                if (success) {
                  SnackbarUtils.showSuccess(
                    context,
                    isChallenge
                        ? 'Reserva e desafio cancelados'
                        : 'Reserva cancelada',
                  );
                  ref.invalidate(courtReservationsProvider(
                    (courtId: _courtId, date: _selectedDate),
                  ));
                  ref.invalidate(myReservationsProvider);
                  ref.invalidate(hasActiveFriendlyReservationProvider);
                  if (isChallenge) {
                    ref.invalidate(activeChallengesProvider);
                  }
                } else {
                  SnackbarUtils.showError(context, 'Erro ao cancelar reserva');
                }
              }
            },
            child: Text(isChallenge ? 'Cancelar Ambos' : 'Cancelar Reserva'),
          ),
        ],
      ),
    );
  }

  void _confirmApply(ReservationModel reservation) async {
    // Check if player already has an active friendly reservation
    final hasFriendly =
        await ref.read(hasActiveFriendlyReservationProvider.future);
    if (hasFriendly && mounted) {
      SnackbarUtils.showError(
        context,
        'Você já tem uma reserva amistosa ativa. Cancele ou conclua antes de se candidatar.',
      );
      return;
    }
    if (!mounted) return;

    final ownerName = reservation.playerName ?? 'Jogador';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Entrar na reserva'),
        content: Text(
          'Deseja entrar na reserva de $ownerName das ${reservation.timeRange}?',
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
                  SnackbarUtils.showSuccess(context, 'Você entrou na reserva!');
                  ref.invalidate(courtReservationsProvider(
                    (courtId: _courtId, date: _selectedDate),
                  ));
                  ref.invalidate(myReservationsProvider);
                  ref.invalidate(hasActiveFriendlyReservationProvider);
                } else {
                  final errorState = ref.read(reservationActionProvider);
                  final msg = errorState.error?.toString() ?? 'Erro ao entrar na reserva';
                  SnackbarUtils.showError(context, msg);
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
    if (widget.isAdminMode) {
      _confirmAdminReservation(slot);
      return;
    }

    final isEditing = widget.editingReservationId != null;

    // Check friendly reservation limit (skip when editing — player already has one)
    if (!isEditing) {
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
    }

    final courtName =
        ref.read(_courtProvider(_courtId)).valueOrNull?.name ?? 'Quadra';
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
        isEditing: isEditing,
        onConfirm: (opponentType, opponentId, opponentName) async {
          Navigator.of(ctx).pop();

          // When editing, cancel old reservation first
          if (isEditing) {
            await ref
                .read(reservationActionProvider.notifier)
                .cancelReservation(widget.editingReservationId!);
          }

          final success = await ref
              .read(reservationActionProvider.notifier)
              .createReservation(
                courtId: _courtId,
                date: _selectedDate,
                startTime: slot.startTime,
                endTime: slot.endTime,
                opponentType: opponentType,
                opponentId: opponentId,
                opponentName: opponentName,
              );

          if (mounted) {
            if (success) {
              SnackbarUtils.showSuccess(
                context,
                isEditing ? 'Reserva alterada!' : 'Reserva confirmada!',
              );
              ref.invalidate(courtReservationsProvider(
                (courtId: _courtId, date: _selectedDate),
              ));
              ref.invalidate(myReservationsProvider);
              ref.invalidate(hasActiveFriendlyReservationProvider);
              if (isEditing) context.pop();
            } else {
              final errorState = ref.read(reservationActionProvider);
              final msg = errorState.error?.toString() ?? 'Erro desconhecido';
              SnackbarUtils.showError(context, msg);
            }
          }
        },
      ),
    );
  }

  void _confirmAdminEdit(TimeSlot slot) async {
    final reservationId = widget.editingReservationId!;
    final courtName =
        ref.read(_courtProvider(_courtId)).valueOrNull?.name ?? 'Quadra';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alterar reserva?'),
        content: Text(
          'Mover para $courtName em ${_formatDateLabel(_selectedDate)} das ${slot.startTime}-${slot.endTime}?\n\nOs jogadores/desafio serão mantidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(courtRepositoryProvider).adminUpdateReservation(
            reservationId: reservationId,
            courtId: _courtId,
            date: _selectedDate,
            startTime: slot.startTime,
            endTime: slot.endTime,
          );
      if (mounted) {
        SnackbarUtils.showSuccess(context, 'Reserva alterada!');
        ref.invalidate(courtReservationsProvider(
          (courtId: _courtId, date: _selectedDate),
        ));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Erro: $e');
      }
    }
  }

  void _confirmAdminReservation(TimeSlot slot) {
    final isEditing = widget.editingReservationId != null;

    // If editing, just update the reservation (keep players/challenge)
    if (isEditing) {
      _confirmAdminEdit(slot);
      return;
    }

    final courtName =
        ref.read(_courtProvider(_courtId)).valueOrNull?.name ?? 'Quadra';
    final clubId = ref.read(currentClubIdProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AdminReservationBottomSheet(
        courtName: courtName,
        date: _selectedDate,
        slot: slot,
        clubId: clubId,
        onConfirmPlayers: (player1Id, player2Id) async {
          Navigator.of(ctx).pop();
          try {
            await ref.read(courtRepositoryProvider).adminCreateReservation(
              player1Id: player1Id,
              player2Id: player2Id,
              courtId: _courtId,
              date: _selectedDate,
              startTime: slot.startTime,
              endTime: slot.endTime,
              clubId: clubId!,
            );
            if (mounted) {
              SnackbarUtils.showSuccess(context, 'Reserva criada!');
              ref.invalidate(courtReservationsProvider(
                (courtId: _courtId, date: _selectedDate),
              ));
            }
          } catch (e) {
            if (mounted) {
              SnackbarUtils.showError(context, 'Erro: $e');
            }
          }
        },
        onConfirmGuest: (hostPlayerId, guestName) async {
          Navigator.of(ctx).pop();
          try {
            await ref
                .read(courtRepositoryProvider)
                .adminCreateReservationWithGuest(
                  hostPlayerId: hostPlayerId,
                  guestName: guestName,
                  courtId: _courtId,
                  date: _selectedDate,
                  startTime: slot.startTime,
                  endTime: slot.endTime,
                  clubId: clubId!,
                );
            if (mounted) {
              SnackbarUtils.showSuccess(context, 'Reserva criada!');
              ref.invalidate(courtReservationsProvider(
                (courtId: _courtId, date: _selectedDate),
              ));
            }
          } catch (e) {
            if (mounted) {
              SnackbarUtils.showError(context, 'Erro: $e');
            }
          }
        },
        onConfirmAdministrative: (title) async {
          Navigator.of(ctx).pop();
          try {
            await ref.read(courtRepositoryProvider).adminCreateAdministrativeReservation(
              courtId: _courtId,
              date: _selectedDate,
              startTime: slot.startTime,
              endTime: slot.endTime,
              title: title,
              clubId: clubId!,
            );
            if (mounted) {
              SnackbarUtils.showSuccess(context, 'Reserva administrativa criada!');
              ref.invalidate(courtReservationsProvider(
                (courtId: _courtId, date: _selectedDate),
              ));
            }
          } catch (e) {
            if (mounted) {
              SnackbarUtils.showError(context, 'Erro: $e');
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
    final slotStart = _timeToMinutes(slot.startTime);
    final slotEnd = _timeToMinutes(slot.endTime);
    for (final r in reservations) {
      final rStart = _timeToMinutes(_normalizeTime(r.startTime));
      final rEnd = _timeToMinutes(_normalizeTime(r.endTime));
      // Check for any overlap between slot and reservation
      if (slotStart < rEnd && rStart < slotEnd) return r;
    }
    return null;
  }

  static int _timeToMinutes(String time) {
    final parts = time.split(':');
    return (int.tryParse(parts[0]) ?? 0) * 60 + (parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0);
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
  final bool isEditing;
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
    this.isEditing = false,
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
                widget.isEditing ? 'Alterar Reserva' : 'Confirmar Reserva',
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
                    label: const Text('Deixar vaga aberta'),
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
                  label: Text(widget.isEditing ? 'Alterar Reserva' : 'Confirmar Reserva'),
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

// ─── Admin Reservation Bottom Sheet with Two Player Pickers ───

class _AdminReservationBottomSheet extends ConsumerStatefulWidget {
  final String courtName;
  final DateTime date;
  final TimeSlot slot;
  final String? clubId;
  final void Function(String player1Id, String player2Id) onConfirmPlayers;
  final void Function(String hostPlayerId, String guestName) onConfirmGuest;
  final void Function(String title) onConfirmAdministrative;

  const _AdminReservationBottomSheet({
    required this.courtName,
    required this.date,
    required this.slot,
    required this.clubId,
    required this.onConfirmPlayers,
    required this.onConfirmGuest,
    required this.onConfirmAdministrative,
  });

  @override
  ConsumerState<_AdminReservationBottomSheet> createState() =>
      _AdminReservationBottomSheetState();
}

class _AdminReservationBottomSheetState
    extends ConsumerState<_AdminReservationBottomSheet> {
  bool _isAdministrative = false;
  ClubMemberModel? _player1;
  ClubMemberModel? _player2;
  String _searchQuery1 = '';
  String _searchQuery2 = '';
  final _searchController1 = TextEditingController();
  final _searchController2 = TextEditingController();
  final _titleController = TextEditingController();
  final _guestNameController = TextEditingController();
  bool _player2IsGuest = false;

  @override
  void dispose() {
    _searchController1.dispose();
    _searchController2.dispose();
    _titleController.dispose();
    _guestNameController.dispose();
    super.dispose();
  }

  bool get _canConfirm {
    if (_isAdministrative) return _titleController.text.trim().isNotEmpty;
    if (_player1 == null) return false;
    if (_player2IsGuest) {
      return _guestNameController.text.trim().isNotEmpty;
    }
    return _player2 != null && _player1!.playerId != _player2!.playerId;
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
                'Reserva Admin',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 16),

              // Toggle: reserva para jogadores ou administrativa
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Jogadores'), icon: Icon(Icons.people, size: 18)),
                  ButtonSegment(value: true, label: Text('Administrativa'), icon: Icon(Icons.block, size: 18)),
                ],
                selected: {_isAdministrative},
                onSelectionChanged: (v) => setState(() => _isAdministrative = v.first),
              ),
              const SizedBox(height: 16),

              if (_isAdministrative) ...[
                Text(
                  'Motivo / Título',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: 'Ex: Manutenção, Torneio, Aula...',
                    prefixIcon: const Icon(Icons.edit, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ] else ...[
                Text(
                  'Jogador 1',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                _buildPlayerPicker(
                  controller: _searchController1,
                  query: _searchQuery1,
                  selected: _player1,
                  onQueryChanged: (v) => setState(() => _searchQuery1 = v),
                  onSelected: (m) => setState(() => _player1 = m),
                  excludePlayerId: _player2?.playerId,
                ),
                const SizedBox(height: 16),
                Text(
                  'Jogador 2',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Membro'), icon: Icon(Icons.person, size: 16)),
                    ButtonSegment(value: true, label: Text('Convidado'), icon: Icon(Icons.person_add_alt_1, size: 16)),
                  ],
                  selected: {_player2IsGuest},
                  onSelectionChanged: (v) => setState(() {
                    _player2IsGuest = v.first;
                    _player2 = null;
                    _searchQuery2 = '';
                    _guestNameController.clear();
                  }),
                ),
                const SizedBox(height: 8),
                if (_player2IsGuest)
                  TextField(
                    controller: _guestNameController,
                    decoration: InputDecoration(
                      hintText: 'Nome do convidado',
                      prefixIcon: const Icon(Icons.person_outline, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (_) => setState(() {}),
                  )
                else
                  _buildPlayerPicker(
                    controller: _searchController2,
                    query: _searchQuery2,
                    selected: _player2,
                    onQueryChanged: (v) => setState(() => _searchQuery2 = v),
                    onSelected: (m) => setState(() => _player2 = m),
                    excludePlayerId: _player1?.playerId,
                  ),
                if (!_player2IsGuest &&
                    _player1 != null &&
                    _player2 != null &&
                    _player1!.playerId == _player2!.playerId)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Selecione jogadores diferentes',
                        style: TextStyle(color: AppColors.error, fontSize: 12)),
                  ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _canConfirm
                      ? () {
                          if (_isAdministrative) {
                            widget.onConfirmAdministrative(
                                _titleController.text.trim());
                          } else if (_player2IsGuest) {
                            widget.onConfirmGuest(
                              _player1!.playerId,
                              _guestNameController.text.trim(),
                            );
                          } else {
                            widget.onConfirmPlayers(
                              _player1!.playerId,
                              _player2!.playerId,
                            );
                          }
                        }
                      : null,
                  icon: Icon(_isAdministrative ? Icons.block : Icons.check),
                  label: Text(_isAdministrative ? 'Bloquear Horário' : 'Criar Reserva'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerPicker({
    required TextEditingController controller,
    required String query,
    required ClubMemberModel? selected,
    required ValueChanged<String> onQueryChanged,
    required ValueChanged<ClubMemberModel> onSelected,
    String? excludePlayerId,
  }) {
    if (widget.clubId == null) {
      return const Text('Clube não selecionado',
          style: TextStyle(color: AppColors.onBackgroundLight));
    }

    // Show selected chip if a player is picked
    if (selected != null) {
      return InputChip(
        label: Text(selected.displayName),
        avatar: CircleAvatar(
          radius: 14,
          backgroundColor: AppColors.primary,
          child: Text(
            selected.playerName[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        deleteIcon: const Icon(Icons.close, size: 16),
        onDeleted: () {
          if (selected == _player1) {
            setState(() { _player1 = null; _searchQuery1 = ''; });
          } else {
            setState(() { _player2 = null; _searchQuery2 = ''; });
          }
        },
      );
    }

    final membersAsync = ref.watch(clubMembersProvider(widget.clubId!));

    return Column(
      children: [
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Buscar jogador...',
            prefixIcon: const Icon(Icons.search, size: 20),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onChanged: onQueryChanged,
        ),
        const SizedBox(height: 8),
        membersAsync.when(
          data: (members) {
            final q = query.toLowerCase().trim();
            final filtered = members.where((m) {
              if (!m.isActive) return false;
              if (excludePlayerId != null && m.playerId == excludePlayerId) return false;
              if (q.isEmpty) return true;
              return m.playerName.toLowerCase().contains(q) ||
                  (m.playerNickname?.toLowerCase().contains(q) ?? false);
            }).toList();

            if (filtered.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Nenhum membro encontrado',
                    style: TextStyle(color: AppColors.onBackgroundLight)),
              );
            }

            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final member = filtered[index];
                  return ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primaryLight,
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
                    onTap: () => onSelected(member),
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
