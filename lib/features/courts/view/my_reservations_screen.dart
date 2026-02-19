import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../shared/models/reservation_model.dart';
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
                  Icon(Icons.calendar_today, size: 64, color: AppColors.onBackgroundLight),
                  SizedBox(height: 16),
                  Text(
                    'Nenhuma reserva ativa',
                    style: TextStyle(fontSize: 16, color: AppColors.onBackgroundLight),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Reserve um horário na aba Reservas',
                    style: TextStyle(fontSize: 13, color: AppColors.onBackgroundLight),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    reservation.reservationDate.day
                        .toString()
                        .padLeft(2, '0'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  Text(
                    '${reservation.reservationDate.month.toString().padLeft(2, '0')}/${reservation.reservationDate.year}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.primaryDark,
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
                            fontSize: 13, color: AppColors.onBackgroundLight),
                      ),
                    ],
                  ),
                  if (isToday || isTomorrow) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isToday
                            ? AppColors.warning.withAlpha(25)
                            : AppColors.info.withAlpha(25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isToday ? 'Hoje' : 'Amanha',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color:
                              isToday ? AppColors.warning : AppColors.info,
                        ),
                      ),
                    ),
                  ],
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
            child: const Text('Nao'),
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
                  SnackbarUtils.showSuccess(
                      context, 'Reserva cancelada');
                  ref.invalidate(myReservationsProvider);
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
