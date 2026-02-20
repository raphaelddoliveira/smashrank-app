import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/extensions/date_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../shared/models/challenge_model.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/providers/current_player_provider.dart';
import '../viewmodel/challenge_detail_viewmodel.dart';
import '../viewmodel/challenge_list_viewmodel.dart';

class ChallengeDetailScreen extends ConsumerWidget {
  final String challengeId;

  const ChallengeDetailScreen({super.key, required this.challengeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengeAsync = ref.watch(challengeDetailProvider(challengeId));
    final currentPlayer = ref.watch(currentPlayerProvider);
    final playerId = currentPlayer.valueOrNull?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhe do Desafio'),
      ),
      body: challengeAsync.when(
        data: (challenge) => _ChallengeDetailBody(
          challenge: challenge,
          currentPlayerId: playerId,
          challengeId: challengeId,
        ),
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
                onPressed: () =>
                    ref.invalidate(challengeDetailProvider(challengeId)),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChallengeDetailBody extends ConsumerWidget {
  final ChallengeModel challenge;
  final String currentPlayerId;
  final String challengeId;

  const _ChallengeDetailBody({
    required this.challenge,
    required this.currentPlayerId,
    required this.challengeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isChallenger = challenge.isChallenger(currentPlayerId);
    final isChallenged = challenge.isChallenged(currentPlayerId);
    final matchAsync = ref.watch(challengeMatchProvider(challengeId));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Players card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _PlayerRow(
                    label: 'Desafiante',
                    name: challenge.challengerName ?? 'Jogador',
                    position: challenge.challengerPosition,
                    isCurrentUser: isChallenger,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('VS',
                              style: GoogleFonts.spaceGrotesk(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  letterSpacing: 2,
                                  color: AppColors.onBackgroundMedium)),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                  ),
                  _PlayerRow(
                    label: 'Desafiado',
                    name: challenge.challengedName ?? 'Jogador',
                    position: challenge.challengedPosition,
                    isCurrentUser: isChallenged,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Status card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  _StatusChip(status: challenge.status),
                  const SizedBox(height: 8),
                  if (challenge.responseDeadline != null &&
                      challenge.status == ChallengeStatus.pending)
                    _InfoRow(
                      icon: Icons.timer,
                      label: 'Prazo para responder',
                      value: challenge.responseDeadline!.countdown(),
                      color: AppColors.warning,
                    ),
                  if (challenge.chosenDate != null)
                    _InfoRow(
                      icon: Icons.calendar_today,
                      label: 'Data agendada',
                      value: challenge.chosenDate!.formattedDateTime,
                    ),
                  if (challenge.playDeadline != null &&
                      challenge.status == ChallengeStatus.scheduled)
                    _InfoRow(
                      icon: Icons.timer,
                      label: 'Prazo para jogar',
                      value: challenge.playDeadline!.countdown(),
                      color: AppColors.warning,
                    ),
                  if (challenge.weatherExtensionDays > 0)
                    _InfoRow(
                      icon: Icons.water_drop,
                      label: 'Extensão por chuva',
                      value: '+${challenge.weatherExtensionDays} dias',
                      color: AppColors.info,
                    ),
                  if (challenge.completedAt != null)
                    _InfoRow(
                      icon: Icons.check_circle,
                      label: 'Finalizado em',
                      value: challenge.completedAt!.formattedDateTime,
                    ),
                  _InfoRow(
                    icon: Icons.access_time,
                    label: 'Criado',
                    value: challenge.createdAt.timeAgo(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Proposed dates
          if (challenge.proposedDates.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Datas Propostas',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ...challenge.proposedDates.map((date) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                date == challenge.chosenDate
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                size: 18,
                                color: date == challenge.chosenDate
                                    ? AppColors.success
                                    : AppColors.onBackgroundLight,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                date.formattedDateTime,
                                style: TextStyle(
                                  fontWeight: date == challenge.chosenDate
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Match result
          matchAsync.when(
            data: (match) {
              if (match == null) return const SizedBox.shrink();
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Resultado',
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          match.scoreDisplay,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: Text(
                          match.superTiebreak
                              ? 'Super tiebreak'
                              : '${match.winnerSets}x${match.loserSets} sets',
                          style: const TextStyle(color: AppColors.onBackgroundMedium),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),

          const SizedBox(height: 24),

          // Action buttons based on status + role
          ..._buildActions(context, ref, isChallenger, isChallenged),
        ],
      ),
    );
  }

  List<Widget> _buildActions(
    BuildContext context,
    WidgetRef ref,
    bool isChallenger,
    bool isChallenged,
  ) {
    final actions = <Widget>[];

    switch (challenge.status) {
      case ChallengeStatus.pending:
        if (isChallenged) {
          actions.add(
            ElevatedButton.icon(
              onPressed: () {
                context.push('/challenges/$challengeId/propose-dates');
              },
              icon: const Icon(Icons.calendar_month),
              label: const Text('Propor Datas'),
            ),
          );
        }
        if (isChallenger) {
          actions.add(const SizedBox(height: 8));
          actions.add(
            OutlinedButton.icon(
              onPressed: () => _confirmCancel(context, ref),
              icon: const Icon(Icons.close, color: AppColors.error),
              label: const Text('Cancelar Desafio',
                  style: TextStyle(color: AppColors.error)),
            ),
          );
        }
        break;

      case ChallengeStatus.datesProposed:
        if (challenge.allProposedDatesExpired) {
          actions.add(
            Card(
              color: AppColors.error.withAlpha(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.timer_off, color: AppColors.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Todas as datas propostas já passaram. Este desafio será expirado automaticamente.',
                        style: TextStyle(color: AppColors.error, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else if (isChallenger) {
          actions.add(
            ElevatedButton.icon(
              onPressed: () {
                context.push(
                  '/challenges/$challengeId/choose-date',
                  extra: {'proposedDates': challenge.proposedDates},
                );
              },
              icon: const Icon(Icons.event_available),
              label: const Text('Escolher Data'),
            ),
          );
        }
        break;

      case ChallengeStatus.scheduled:
        actions.add(
          ElevatedButton.icon(
            onPressed: () {
              context.push(
                '/challenges/$challengeId/record-result',
                extra: {
                  'challengerId': challenge.challengerId,
                  'challengedId': challenge.challengedId,
                  'challengerName': challenge.challengerName ?? 'Desafiante',
                  'challengedName': challenge.challengedName ?? 'Desafiado',
                },
              );
            },
            icon: const Icon(Icons.scoreboard),
            label: const Text('Registrar Resultado'),
          ),
        );
        actions.add(const SizedBox(height: 8));
        actions.add(
          OutlinedButton.icon(
            onPressed: () => _confirmWeatherExtension(context, ref),
            icon: const Icon(Icons.water_drop, color: AppColors.info),
            label: Text(
              'Adiamento por Chuva (+2 dias)',
              style: TextStyle(color: AppColors.info),
            ),
          ),
        );
        break;

      default:
        break;
    }

    return actions;
  }

  void _confirmWeatherExtension(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adiamento por Chuva'),
        content: Text(
          'O prazo para jogar será estendido em +2 dias devido à chuva.\n\n'
          '${challenge.weatherExtensionDays > 0 ? 'Extensão atual: +${challenge.weatherExtensionDays} dias\nNovo total: +${challenge.weatherExtensionDays + 2} dias' : 'Novo prazo: +2 dias além do original'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await ref
                  .read(challengeActionProvider.notifier)
                  .requestWeatherExtension(challengeId);
              if (success && context.mounted) {
                SnackbarUtils.showSuccess(
                    context, 'Prazo estendido em +2 dias por chuva');
                ref.invalidate(challengeDetailProvider(challengeId));
                ref.invalidate(activeChallengesProvider);
              }
            },
            icon: const Icon(Icons.water_drop),
            label: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  void _confirmCancel(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar Desafio'),
        content: const Text('Tem certeza que deseja cancelar este desafio?'),
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
                  .read(challengeActionProvider.notifier)
                  .cancelChallenge(challengeId);
              if (success && context.mounted) {
                SnackbarUtils.showSuccess(context, 'Desafio cancelado');
                ref.invalidate(challengeDetailProvider(challengeId));
                ref.invalidate(activeChallengesProvider);
              }
            },
            child: const Text('Cancelar Desafio'),
          ),
        ],
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final String label;
  final String name;
  final int position;
  final bool isCurrentUser;

  const _PlayerRow({
    required this.label,
    required this.name,
    required this.position,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.surfaceVariant,
          child: Text('#$position',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: AppColors.onBackgroundLight),
              ),
              Row(
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (isCurrentUser)
                    const Text(
                      ' (Você)',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.primary),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final ChallengeStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ChallengeStatus.pending => AppColors.challengePending,
      ChallengeStatus.datesProposed => AppColors.challengePending,
      ChallengeStatus.scheduled => AppColors.challengeScheduled,
      ChallengeStatus.completed => AppColors.challengeCompleted,
      _ => AppColors.challengeWo,
    };

    final label = switch (status) {
      ChallengeStatus.pending => 'Aguardando resposta',
      ChallengeStatus.datesProposed => 'Datas propostas',
      ChallengeStatus.scheduled => 'Agendado',
      ChallengeStatus.completed => 'Finalizado',
      ChallengeStatus.woChallenger => 'WO Desafiante',
      ChallengeStatus.woChallenged => 'WO Desafiado',
      ChallengeStatus.expired => 'Expirado',
      ChallengeStatus.cancelled => 'Cancelado',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color ?? AppColors.onBackgroundLight),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: AppColors.onBackgroundMedium, fontSize: 13)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
