import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../shared/models/court_slot_model.dart';
import '../data/court_repository.dart';
import '../viewmodel/court_slots_admin_viewmodel.dart';
import '../viewmodel/reservation_viewmodel.dart';

class _DayConfig {
  bool enabled = false;
  TimeOfDay startTime;
  TimeOfDay endTime;

  _DayConfig()
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
  bool _isSaving = false;
  bool _configLoaded = false;

  @override
  void initState() {
    super.initState();
    for (final day in _dayOrder) {
      _dayConfigs[day] = _DayConfig();
    }
  }

  /// Derive config from existing slots (called once when data loads)
  void _loadConfigFromSlots(List<CourtSlotModel> slots) {
    if (_configLoaded) return;

    if (slots.isNotEmpty) {
      // Detect duration from first active slot
      final activeSlots = slots.where((s) => s.isActive).toList();
      if (activeSlots.isNotEmpty) {
        final firstSlot = activeSlots.first;
        final startParts = firstSlot.startTime.split(':');
        final endParts = firstSlot.endTime.split(':');
        final startMin = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
        final endMin = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
        final detected = endMin - startMin;
        if (detected > 0) _slotDurationMinutes = detected;
      }

      // Group active slots by day
      final grouped = <int, List<CourtSlotModel>>{};
      for (final slot in activeSlots) {
        grouped.putIfAbsent(slot.dayOfWeek, () => []).add(slot);
      }

      // Configure each day from existing slots
      for (final day in _dayOrder) {
        final daySlots = grouped[day];
        if (daySlots != null && daySlots.isNotEmpty) {
          daySlots.sort((a, b) => a.startTime.compareTo(b.startTime));
          final firstStart = daySlots.first.startTime.split(':');
          final lastEnd = daySlots.last.endTime.split(':');
          _dayConfigs[day]!.enabled = true;
          _dayConfigs[day]!.startTime = TimeOfDay(
            hour: int.parse(firstStart[0]),
            minute: int.parse(firstStart[1]),
          );
          _dayConfigs[day]!.endTime = TimeOfDay(
            hour: int.parse(lastEnd[0]),
            minute: int.parse(lastEnd[1]),
          );
        }
      }
    } else {
      // No slots: default Mon-Sat enabled
      for (final day in _dayOrder) {
        _dayConfigs[day]!.enabled = day != 0;
      }
    }

    _configLoaded = true;
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

  List<Map<String, dynamic>> _buildNewSlots() {
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
    return slots;
  }

  Future<void> _saveConfiguration() async {
    setState(() => _isSaving = true);

    try {
      final slots = _buildNewSlots();
      await ref.read(courtRepositoryProvider).saveSlotConfiguration(
        widget.courtId,
        slots,
      );
      ref.invalidate(allCourtSlotsProvider(widget.courtId));
      // Invalidate schedule providers so they refetch fresh data
      for (int day = 0; day < 7; day++) {
        ref.invalidate(courtSlotsProvider(
          (courtId: widget.courtId, dayOfWeek: day),
        ));
      }
      if (mounted) {
        SnackbarUtils.showSuccess(context, 'Configuração salva! $_totalSlots horários.');
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, 'Erro ao salvar: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final slotsAsync = ref.watch(allCourtSlotsProvider(widget.courtId));

    // Load config from existing slots once
    slotsAsync.whenData((slots) {
      if (!_configLoaded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _loadConfigFromSlots(slots));
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.courtName} - Horários'),
      ),
      bottomNavigationBar: _buildSaveBar(),
      body: slotsAsync.when(
        data: (_) => _configLoaded
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildDurationSelector(),
                  const SizedBox(height: 12),
                  ..._dayOrder.map(_buildDayRow),
                ],
              )
            : const Center(child: CircularProgressIndicator()),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
      ),
    );
  }

  Widget _buildSaveBar() {
    final total = _totalSlots;
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.access_time, size: 16, color: AppColors.onBackgroundMedium),
                const SizedBox(width: 6),
                Text(
                  '$total horários no total',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.onBackgroundMedium,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: !_isSaving ? _saveConfiguration : null,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Salvando...' : 'Salvar Configuração'),
              ),
            ),
          ],
        ),
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
                    time: config.startTime,
                    onChanged: (t) => setState(() => config.startTime = t),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('até', style: TextStyle(color: AppColors.onBackgroundLight)),
                  ),
                  _buildTimePicker(
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

  static String _formatTimeOfDay(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
