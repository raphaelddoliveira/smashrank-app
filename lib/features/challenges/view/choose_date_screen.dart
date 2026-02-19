import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/date_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../viewmodel/challenge_detail_viewmodel.dart';
import '../viewmodel/challenge_list_viewmodel.dart';

class ChooseDateScreen extends ConsumerStatefulWidget {
  final String challengeId;
  final List<DateTime> proposedDates;

  const ChooseDateScreen({
    super.key,
    required this.challengeId,
    required this.proposedDates,
  });

  @override
  ConsumerState<ChooseDateScreen> createState() => _ChooseDateScreenState();
}

class _ChooseDateScreenState extends ConsumerState<ChooseDateScreen> {
  int? _selectedIndex;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escolher Data'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: AppColors.info),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Escolha uma das datas propostas pelo desafiado para realizar o jogo.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.onBackgroundMedium),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(widget.proposedDates.length, (index) {
              final date = widget.proposedDates[index];
              final isSelected = _selectedIndex == index;
              final isPast = date.isBefore(DateTime.now());

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  elevation: isSelected ? 3 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.transparent,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: isPast
                        ? null
                        : () => setState(() => _selectedIndex = index),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: isPast
                                ? AppColors.onBackgroundLight
                                : isSelected
                                    ? AppColors.primary
                                    : AppColors.onBackgroundLight,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Opção ${index + 1}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isPast
                                        ? AppColors.onBackgroundLight
                                        : AppColors.onBackgroundLight,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  date.formattedDateTime,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isPast
                                        ? AppColors.onBackgroundLight
                                        : null,
                                    decoration: isPast
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                if (date.isToday)
                                  const Text(
                                    'Hoje',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                if (date.isTomorrow)
                                  const Text(
                                    'Amanhã',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.info,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (isPast)
                            const Text(
                              'Expirada',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.onBackgroundLight),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            const Spacer(),
            ElevatedButton.icon(
              onPressed:
                  _selectedIndex != null && !_isSubmitting ? _confirmDate : null,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check),
              label: Text(_isSubmitting ? 'Confirmando...' : 'Confirmar Data'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDate() async {
    if (_selectedIndex == null) return;

    final chosenDate = widget.proposedDates[_selectedIndex!];

    setState(() => _isSubmitting = true);

    final success = await ref
        .read(challengeActionProvider.notifier)
        .chooseDate(widget.challengeId, chosenDate);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      SnackbarUtils.showSuccess(context, 'Data confirmada! Jogo agendado.');
      ref.invalidate(challengeDetailProvider(widget.challengeId));
      ref.invalidate(activeChallengesProvider);
      context.pop();
    } else {
      SnackbarUtils.showError(context, 'Erro ao confirmar data');
    }
  }
}
