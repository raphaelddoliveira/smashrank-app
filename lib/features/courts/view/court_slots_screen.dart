import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../shared/models/court_slot_model.dart';
import '../data/court_repository.dart';
import '../viewmodel/court_slots_admin_viewmodel.dart';

class _DayConfig {
  bool enabled;
  TimeOfDay startTime;
  TimeOfDay endTime;

  _DayConfig({this.enabled = true})
      : startTime = const TimeOfDay(hour: 7, minute: 0),
        endTime = const TimeOfDay(hour: 21, minute: 0);
}

class CourtSlotsScreen extends ConsumerStatefulWidget {
  final String courtId;
  final String courtName;

  const CourtSlotsScreen({
    super.key,
    required this.courtId,
    required this.courtName,
  });

  @override
  ConsumerState<CourtSlotsScreen> createState() => _CourtSlotsScreenState();
}

class _CourtSlotsScreenState extends ConsumerState<CourtSlotsScreen> {
  static const _dayOrder = [1, 2, 3, 4, 5, 6, 0];

  static const _dayLabels = {
    0: 'Domingo',
    1: 'Segunda-feira',
    2: 'Terça-feira',
    3: 'Quarta-feira',
    4: 'Quinta-feira',
    5: 'Sexta-feira',
    6: 'Sábado',
  };

  int _slotDurationMinutes = 60;
  final Map<int, _DayConfig> _dayConfigs = {};
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    for (final day in _dayOrder) {
      _dayConfigs[day] = _DayConfig(enabled: day != 0);
    }
  }

  int _calculateSlotCount(_DayConfig config) {
    final startMinutes = config.startTime.hour * 60 + config.startTime.minute;
    final endMinutes = config.endTime.hour * 60 + config.endTime.minute;
    if (endMinutes <= startMinutes) return 0;
    return (endMinutes - startMinutes) ~/ _slotDurationMinutes;
  }

  int get _totalSlots => _dayOrder
      .where((d) => _dayConfigs[d]!.enabled)
      .map((d) => _calculateSlotCount(_dayConfigs[d]!))
      .fold(0, (a, b) => a + b);

  Future<void> _generateSlots() async {
    setState(() => _isGenerating = true);

    final slots = <Map<String, dynamic>>[];

    for (final day in _dayOrder) {
      final config = _dayConfigs[day]!;
      if (!config.enabled) continue;

      final startMinutes = config.startTime.hour * 60 + config.startTime.minute;
      final endMinutes = config.endTime.hour * 60 + config.endTime.minute;
      if (endMinutes <= startMinutes) continue;

      int minutes = startMinutes;
      while (minutes + _slotDurationMinutes <= endMinutes) {
        final sH = minutes ~/ 60;
        final sM = minutes % 60;
        final eH = (minutes + _slotDurationMinutes) ~/ 60;
        final eM = (minutes + _slotDurationMinutes) % 60;
        slots.add({
          'court_id': widget.courtId,
          'day_of_week': day,
          'start_time': '${sH.toString().padLeft(2, '0')}:${sM.toString().padLeft(2, '0')}',
          'end_time': '${eH.toString().padLeft(2, '0')}:${eM.toString().padLeft(2, '0')}',
          'is_active': true,
        });
        minutes += _slotDurationMinutes;
      }
    }

    try {
      await ref.read(courtRepositoryProvider).bulkCreateSlots(slots);
      ref.invalidate(allCourtSlotsProvider(widget.courtId));
      if (mounted) {
        SnackbarUtils.showSuccess(context, '${slots.length} horários gerados!');
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Erro ao gerar horários: $e');
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slotsAsync = ref.watch(allCourtSlotsProvider(widget.courtId));

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.courtName} - Horários'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Duration selector
          _buildDurationSelector(),
          const SizedBox(height: 12),

          // Per-day configs
          ..._dayOrder.map(_buildDayRow),
          const SizedBox(height: 16),

          // Generate button
          _buildGenerateButton(),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),

          // Existing slots
          Text(
            'Horários cadastrados',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          slotsAsync.when(
            data: (slots) => _buildSlotsList(slots),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Center(child: Text('Erro: $e')),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Duração do horário',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.timer_outlined),
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _slotDurationMinutes,
                  isDense: true,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 30, child: Text('30 minutos')),
                    DropdownMenuItem(value: 45, child: Text('45 minutos')),
                    DropdownMenuItem(value: 60, child: Text('1 hora')),
                    DropdownMenuItem(value: 75, child: Text('1h15')),
                    DropdownMenuItem(value: 90, child: Text('1h30')),
                    DropdownMenuItem(value: 120, child: Text('2 horas')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _slotDurationMinutes = v);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayRow(int day) {
    final config = _dayConfigs[day]!;
    final slotCount = config.enabled ? _calculateSlotCount(config) : 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: config.enabled ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          children: [
            Row(
              children: [
                Switch(
                  value: config.enabled,
                  onChanged: (v) => setState(() => config.enabled = v),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _dayLabels[day]!,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: config.enabled ? null : AppColors.onBackgroundLight,
                    ),
                  ),
                ),
                if (config.enabled && slotCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$slotCount horários',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            if (config.enabled) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const SizedBox(width: 48),
                  _buildTimePicker(
                    label: 'Início',
                    time: config.startTime,
                    onChanged: (t) => setState(() => config.startTime = t),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('até', style: TextStyle(color: AppColors.onBackgroundLight)),
                  ),
                  _buildTimePicker(
                    label: 'Fim',
                    time: config.endTime,
                    onChanged: (t) => setState(() => config.endTime = t),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker({
    required String label,
    required TimeOfDay time,
    required ValueChanged<TimeOfDay> onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked != null) onChanged(picked);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.onBackgroundLight.withAlpha(80)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          _formatTimeOfDay(time),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildGenerateButton() {
    final total = _totalSlots;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: total > 0 && !_isGenerating ? _generateSlots : null,
        icon: _isGenerating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.auto_awesome),
        label: Text(_isGenerating ? 'Gerando...' : 'Gerar $total Horários'),
      ),
    );
  }

  Widget _buildSlotsList(List<CourtSlotModel> slots) {
    if (slots.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Nenhum horário cadastrado ainda',
            style: TextStyle(color: AppColors.onBackgroundLight),
          ),
        ),
      );
    }

    final grouped = <int, List<CourtSlotModel>>{};
    for (final slot in slots) {
      grouped.putIfAbsent(slot.dayOfWeek, () => []).add(slot);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _dayOrder.map((day) {
        final daySlots = grouped[day];
        if (daySlots == null || daySlots.isEmpty) return const SizedBox.shrink();
        final activeCount = daySlots.where((s) => s.isActive).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 6, left: 4),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: AppColors.onBackgroundMedium),
                  const SizedBox(width: 8),
                  Text(
                    _dayLabels[day] ?? '',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$activeCount/${daySlots.length} ativos',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.onBackgroundLight,
                    ),
                  ),
                ],
              ),
            ),
            ...daySlots.map((slot) => _SlotTile(
              slot: slot,
              onToggleActive: () async {
                try {
                  await ref.read(courtRepositoryProvider).toggleSlotActive(
                    slot.id, !slot.isActive,
                  );
                  ref.invalidate(allCourtSlotsProvider(widget.courtId));
                } catch (e) {
                  if (mounted) {
                    SnackbarUtils.showError(context, 'Erro: $e');
                  }
                }
              },
              onDelete: () => _confirmDelete(slot),
            )),
          ],
        );
      }).toList(),
    );
  }

  void _confirmDelete(CourtSlotModel slot) async {
    try {
      final hasReservations = await ref.read(courtRepositoryProvider).slotHasReservations(slot.id);
      if (hasReservations) {
        if (mounted) {
          SnackbarUtils.showError(
            context,
            'Este horário possui reservas. Desative-o em vez de excluir.',
          );
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Erro: $e');
      }
      return;
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir horário?'),
        content: Text('${slot.dayLabel} ${slot.timeRange}\n\nEsta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(courtRepositoryProvider).deleteSlot(slot.id);
        ref.invalidate(allCourtSlotsProvider(widget.courtId));
        if (mounted) {
          SnackbarUtils.showSuccess(context, 'Horário excluído');
        }
      } catch (e) {
        if (mounted) {
          SnackbarUtils.showError(context, 'Erro ao excluir: $e');
        }
      }
    }
  }

  static String _formatTimeOfDay(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _SlotTile extends StatelessWidget {
  final CourtSlotModel slot;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  const _SlotTile({
    required this.slot,
    required this.onToggleActive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 48,
          height: 36,
          decoration: BoxDecoration(
            color: slot.isActive
                ? AppColors.primary.withAlpha(20)
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            slot.startTime.substring(0, 5),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: slot.isActive ? AppColors.primary : AppColors.onBackgroundLight,
            ),
          ),
        ),
        title: Text(
          slot.timeRange,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: slot.isActive ? null : AppColors.onBackgroundLight,
          ),
        ),
        subtitle: slot.isActive
            ? null
            : const Text(
                'Inativo',
                style: TextStyle(fontSize: 11, color: AppColors.error),
              ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            if (action == 'toggle') onToggleActive();
            if (action == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'toggle',
              child: Text(
                slot.isActive ? 'Desativar' : 'Reativar',
                style: TextStyle(
                  color: slot.isActive ? AppColors.error : AppColors.success,
                ),
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Excluir', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      ),
    );
  }
}
