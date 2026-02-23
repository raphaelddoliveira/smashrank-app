import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../shared/models/court_model.dart';
import '../../../shared/models/reservation_model.dart';
import '../../../shared/models/time_slot.dart';
import '../../../shared/utils/slot_generator.dart';
import '../../clubs/viewmodel/club_providers.dart';
import '../../courts/viewmodel/reservation_viewmodel.dart';
import '../viewmodel/challenge_court_selection_viewmodel.dart';
import '../viewmodel/challenge_detail_viewmodel.dart';
import '../viewmodel/challenge_list_viewmodel.dart';

class ChallengeCourtSelectionScreen extends ConsumerStatefulWidget {
  final String challengeId;

  const ChallengeCourtSelectionScreen({
    super.key,
    required this.challengeId,
  });

  @override
  ConsumerState<ChallengeCourtSelectionScreen> createState() =>
      _ChallengeCourtSelectionScreenState();
}

class _ChallengeCourtSelectionScreenState
    extends ConsumerState<ChallengeCourtSelectionScreen> {
  late DateTime _selectedDate;
  late final List<DateTime> _dates;
  late final ScrollController _dateScrollController;

  CourtModel? _selectedCourt;
  TimeSlot? _selectedSlot;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _selectedDate = DateTime(today.year, today.month, today.day + 1);
    _dates = List.generate(
      60,
      (i) => DateTime(today.year, today.month, today.day + 1 + i),
    );
    _dateScrollController = ScrollController();
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    super.dispose();
  }

  int get _dbDayOfWeek =>
      _selectedDate.weekday == 7 ? 0 : _selectedDate.weekday;

  @override
  Widget build(BuildContext context) {
    final courtsAsync = ref.watch(challengeCourtsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Escolher Quadra e Horário')),
      bottomNavigationBar:
          _selectedSlot != null ? _buildConfirmBar() : null,
      body: courtsAsync.when(
        data: (courts) {
          if (courts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhuma quadra disponível para este esporte.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.onBackgroundLight),
                ),
              ),
            );
          }

          // Auto-select first court
          _selectedCourt ??= courts.first;

          return Column(
            children: [
              _buildInfoCard(),
              _buildCourtChips(courts),
              const Divider(height: 1),
              _buildDateSelector(),
              const Divider(height: 1),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      _formatDateLabel(_selectedDate),
                      style:
                          Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const Spacer(),
                    Text(
                      _dayOfWeekLabel(_dbDayOfWeek),
                      style: const TextStyle(
                        color: AppColors.onBackgroundLight,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildSlotsList()),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Card(
        color: AppColors.primary.withAlpha(15),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.info_outline,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Escolha uma quadra, data e horário. Uma reserva será feita automaticamente.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourtChips(List<CourtModel> courts) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: courts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final court = courts[index];
          final isSelected = court.id == _selectedCourt?.id;
          return ChoiceChip(
            label: Text(court.name),
            selected: isSelected,
            onSelected: (_) {
              setState(() {
                _selectedCourt = court;
                _selectedSlot = null;
              });
            },
          );
        },
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

          return GestureDetector(
            onTap: () => setState(() {
              _selectedDate = date;
              _selectedSlot = null;
            }),
            child: Container(
              width: 52,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _dayShort(date.weekday),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : AppColors.onBackgroundLight,
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

  Widget _buildSlotsList() {
    final court = _selectedCourt;
    if (court == null) {
      return const Center(child: Text('Selecione uma quadra'));
    }

    final slots = generateSlots(court, _dbDayOfWeek);

    if (slots.isEmpty) {
      return const Center(
        child: Text(
          'Quadra fechada neste dia',
          style: TextStyle(color: AppColors.onBackgroundLight),
        ),
      );
    }

    final reservationsAsync = ref.watch(courtReservationsProvider(
      (courtId: court.id, date: _selectedDate),
    ));

    return reservationsAsync.when(
      data: (reservations) =>
          _buildSlotsListContent(slots, reservations),
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro: $e')),
    );
  }

  Widget _buildSlotsListContent(
    List<TimeSlot> slots,
    List<ReservationModel> reservations,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        final reservation = _findReservation(slot, reservations);
        final isReserved = reservation != null;
        final isSelected = _selectedSlot == slot;

        final statusColor = isReserved
            ? AppColors.error
            : isSelected
                ? AppColors.primary
                : AppColors.success;

        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          shape: isSelected
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppColors.primary, width: 2),
                )
              : null,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: isReserved
                ? null
                : () => setState(() => _selectedSlot = slot),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
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
                      child: Text(
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
                          isReserved
                              ? 'Reservado'
                              : isSelected
                                  ? 'Selecionado'
                                  : 'Disponível',
                          style: TextStyle(
                              fontSize: 12, color: statusColor),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle,
                        color: AppColors.primary),
                  if (isReserved)
                    const Icon(Icons.lock,
                        color: AppColors.onBackgroundLight, size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConfirmBar() {
    final slot = _selectedSlot!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_formatDateLabel(_selectedDate)} • ${slot.timeRange}',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.onBackgroundMedium,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _confirmSelection,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(
                    _isSaving ? 'Reservando...' : 'Confirmar Reserva'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSelection() async {
    final slot = _selectedSlot;
    final court = _selectedCourt;
    if (slot == null || court == null) return;

    final clubId = ref.read(currentClubIdProvider);
    if (clubId == null) return;

    setState(() => _isSaving = true);
    try {
      final success = await ref
          .read(challengeActionProvider.notifier)
          .selectCourtAndDate(
            widget.challengeId,
            courtId: court.id,
            date: _selectedDate,
            startTime: slot.startTime,
            endTime: slot.endTime,
            clubId: clubId,
          );

      if (mounted) {
        if (success) {
          SnackbarUtils.showSuccess(
              context, 'Quadra reservada! Aguardando confirmação.');
          ref.invalidate(
              challengeDetailProvider(widget.challengeId));
          ref.invalidate(activeChallengesProvider);
          context.pop();
        } else {
          final errorState = ref.read(challengeActionProvider);
          final msg = errorState is AsyncError
              ? errorState.error.toString()
              : 'Erro ao reservar quadra';
          SnackbarUtils.showError(context, msg);
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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

  static String _dayShort(int weekday) => switch (weekday) {
        1 => 'Seg',
        2 => 'Ter',
        3 => 'Qua',
        4 => 'Qui',
        5 => 'Sex',
        6 => 'Sab',
        7 => 'Dom',
        _ => '',
      };

  static String _monthShort(int month) => switch (month) {
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

  String _dayOfWeekLabel(int dow) => switch (dow) {
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
