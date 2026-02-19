import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/court_model.dart';
import '../../clubs/view/club_selector_widget.dart';
import '../../clubs/viewmodel/club_providers.dart';
import '../viewmodel/courts_viewmodel.dart';

class CourtsScreen extends ConsumerWidget {
  const CourtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courtsAsync = ref.watch(courtsListProvider);
    final currentSport = ref.watch(currentSportProvider).valueOrNull;
    final facilityConfig = currentSport?.facilityConfig;

    return Scaffold(
      appBar: AppBar(
        title: clubAppBarTitle(facilityConfig?.plural ?? 'Reservas', context, ref),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => context.push('/courts/my-reservations'),
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Minhas Reservas',
          ),
        ],
      ),
      body: courtsAsync.when(
        data: (courts) {
          if (courts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event_available, size: 64, color: AppColors.onBackgroundLight),
                  const SizedBox(height: 16),
                  Text(
                    facilityConfig?.emptyState ?? 'Nenhum local disponível',
                    style: const TextStyle(fontSize: 16, color: AppColors.onBackgroundLight),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(courtsListProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: courts.length,
              itemBuilder: (context, index) =>
                  _CourtCard(court: courts[index]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Erro: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(courtsListProvider),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourtCard extends StatelessWidget {
  final CourtModel court;

  const _CourtCard({required this.court});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.push('/courts/${court.id}/schedule', extra: court);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 80,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primaryLight,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Icon(
                  court.isCovered ? Icons.roofing : Icons.wb_sunny,
                  size: 40,
                  color: Colors.white.withAlpha(200),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    court.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.grass,
                        label: court.surfaceLabel,
                      ),
                      const SizedBox(width: 8),
                      _InfoChip(
                        icon: court.isCovered ? Icons.roofing : Icons.wb_sunny,
                        label: court.isCovered ? 'Coberta' : 'Descoberta',
                      ),
                    ],
                  ),
                  if (court.notes != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      court.notes!,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.onBackgroundMedium),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.onBackgroundMedium),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppColors.onBackgroundMedium),
          ),
        ],
      ),
    );
  }
}
