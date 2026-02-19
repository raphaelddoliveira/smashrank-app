import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../viewmodel/challenge_detail_viewmodel.dart';
import '../viewmodel/challenge_list_viewmodel.dart';

class ProposeDatesScreen extends ConsumerStatefulWidget {
  final String challengeId;

  const ProposeDatesScreen({super.key, required this.challengeId});

  @override
  ConsumerState<ProposeDatesScreen> createState() => _ProposeDatesScreenState();
}

class _ProposeDatesScreenState extends ConsumerState<ProposeDatesScreen> {
  DateTime? _date1;
  DateTime? _date2;
  DateTime? _date3;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Propor Datas'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 20, color: AppColors.info),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Proponha 3 datas e horários para o desafio. '
                            'O desafiante escolherá uma delas.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.onBackgroundMedium),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _DatePickerCard(
              number: 1,
              selectedDate: _date1,
              onDateSelected: (date) => setState(() => _date1 = date),
            ),
            const SizedBox(height: 12),
            _DatePickerCard(
              number: 2,
              selectedDate: _date2,
              onDateSelected: (date) => setState(() => _date2 = date),
            ),
            const SizedBox(height: 12),
            _DatePickerCard(
              number: 3,
              selectedDate: _date3,
              onDateSelected: (date) => setState(() => _date3 = date),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed:
                  _date1 != null && _date2 != null && _date3 != null && !_isSubmitting
                      ? _submitDates
                      : null,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
              label: Text(_isSubmitting ? 'Enviando...' : 'Enviar Datas'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitDates() async {
    if (_date1 == null || _date2 == null || _date3 == null) return;

    setState(() => _isSubmitting = true);

    final success =
        await ref.read(challengeActionProvider.notifier).proposeDates(
              widget.challengeId,
              date1: _date1!,
              date2: _date2!,
              date3: _date3!,
            );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      SnackbarUtils.showSuccess(context, 'Datas propostas com sucesso!');
      ref.invalidate(challengeDetailProvider(widget.challengeId));
      ref.invalidate(activeChallengesProvider);
      context.pop();
    } else {
      SnackbarUtils.showError(context, 'Erro ao propor datas');
    }
  }
}

class _DatePickerCard extends StatelessWidget {
  final int number;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const _DatePickerCard({
    required this.number,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final hasDate = selectedDate != null;

    return Card(
      elevation: hasDate ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasDate ? AppColors.primary.withAlpha(100) : Colors.transparent,
        ),
      ),
      child: InkWell(
        onTap: () => _pickDateTime(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor:
                    hasDate ? AppColors.primary : AppColors.surfaceVariant,
                child: Text(
                  '$number',
                  style: TextStyle(
                    color: hasDate ? Colors.white : AppColors.onBackgroundLight,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Opção $number',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.onBackgroundLight),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasDate
                          ? _formatDateTime(selectedDate!)
                          : 'Toque para selecionar',
                      style: TextStyle(
                        fontWeight:
                            hasDate ? FontWeight.w600 : FontWeight.normal,
                        color: hasDate ? null : AppColors.onBackgroundLight,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                hasDate ? Icons.check_circle : Icons.calendar_month,
                color: hasDate ? AppColors.success : AppColors.onBackgroundLight,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateTime(BuildContext context) async {
    final now = DateTime.now();
    final initialDate = selectedDate ?? now.add(const Duration(days: 1));

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      helpText: 'Selecione a data',
      cancelText: 'Cancelar',
      confirmText: 'OK',
    );

    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: selectedDate != null
          ? TimeOfDay.fromDateTime(selectedDate!)
          : const TimeOfDay(hour: 18, minute: 0),
      helpText: 'Selecione o horário',
      cancelText: 'Cancelar',
      confirmText: 'OK',
    );

    if (time == null) return;

    final dateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    onDateSelected(dateTime);
  }

  String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year as $hour:$minute';
  }
}
