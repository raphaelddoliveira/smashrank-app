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
import '../../clubs/viewmodel/club_providers.dart';
import '../../courts/viewmodel/reservation_viewmodel.dart';
import '../viewmodel/challenge_detail_viewmodel.dart';
import '../viewmodel/challenge_list_viewmodel.dart';
import '../viewmodel/h2h_viewmodel.dart';

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
                    playerId: challenge.challengerId,
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
                    playerId: challenge.challengedId,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // H2H card (compact)
          _H2HCard(
            challenge: challenge,
            currentPlayerId: currentPlayerId,
            challengeId: challengeId,
          ),

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
                      label: 'Prazo para agendar',
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

          // Court + date info (new flow: court selected)
          if (challenge.courtId != null &&
              challenge.chosenDate != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quadra e Horário',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.place,
                      label: 'Quadra',
                      value: challenge.courtName ?? 'Quadra',
                    ),
                    _InfoRow(
                      icon: Icons.calendar_today,
                      label: 'Data',
                      value: challenge.chosenDate!.formattedDateTime,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Legacy: proposed dates (old flow, for backward compatibility)
          if (challenge.courtId == null &&
              challenge.proposedDates.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Datas Propostas',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...challenge.proposedDates.map(
                      (date) => Padding(
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
                                fontWeight:
                                    date == challenge.chosenDate
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
              final isWinner = match.winnerId == currentPlayerId;
              final isParticipant = match.winnerId == currentPlayerId ||
                  match.loserId == currentPlayerId;
              final winnerName = match.winnerId == challenge.challengerId
                  ? challenge.challengerName
                  : challenge.challengedName;
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
                      const SizedBox(height: 12),
                      // Winner/loser highlight
                      if (isParticipant)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isWinner
                                  ? AppColors.success.withAlpha(20)
                                  : AppColors.error.withAlpha(20),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isWinner
                                    ? AppColors.success.withAlpha(80)
                                    : AppColors.error.withAlpha(80),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isWinner
                                      ? Icons.emoji_events
                                      : Icons.sentiment_dissatisfied,
                                  size: 20,
                                  color: isWinner
                                      ? AppColors.secondary
                                      : AppColors.error,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isWinner
                                      ? 'Você venceu!'
                                      : 'Você perdeu',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: isWinner
                                        ? AppColors.success
                                        : AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (winnerName != null)
                        Center(
                          child: Text(
                            '$winnerName venceu',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppColors.onBackgroundMedium,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
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
        {
          final isAdmin = ref.watch(isClubAdminProvider).valueOrNull ?? false;
          // Any participant or admin can pick court/date
          if (isChallenger || isChallenged || isAdmin) {
            actions.add(
              ElevatedButton.icon(
                onPressed: () {
                  context.push(
                      '/challenges/$challengeId/select-court');
                },
                icon: const Icon(Icons.event_note),
                label: const Text('Escolher Quadra e Horário'),
              ),
            );
            // Só admin pode cancelar desafio de ranking — jogador não pode
            // (evita "dodge"). Cancela, não anula (anular é p/ concluídos).
            if (isAdmin) {
              actions.add(const SizedBox(height: 8));
              actions.add(
                OutlinedButton.icon(
                  onPressed: () => _confirmCancel(context, ref),
                  icon: const Icon(Icons.close, color: AppColors.error),
                  label: const Text(
                    'Cancelar Desafio (Admin)',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              );
            }
          }
        }
        break;

      case ChallengeStatus.datesProposed:
        // Legacy: should no longer happen (challenges go straight to scheduled).
        // Treat like scheduled for any old challenges still in this state.
        break;

      case ChallengeStatus.scheduled:
        // Ações sobre o jogo só para participantes ou admin — um terceiro que
        // apenas visualiza o desafio não pode registrar resultado, adiar nem
        // cancelar.
        final isAdmin = ref.watch(isClubAdminProvider).valueOrNull ?? false;
        final canActOnChallenge = isChallenger || isChallenged || isAdmin;
        // Check result delay rule
        final clubSports = ref.watch(clubSportsProvider).valueOrNull ?? [];
        final clubSport = clubSports.where((cs) => cs.sportId == challenge.sportId).firstOrNull;
        final ruleDelayEnabled = clubSport?.ruleResultDelayEnabled ?? true;
        final chosenDate = challenge.chosenDate;
        final delayBlocked = ruleDelayEnabled &&
            chosenDate != null &&
            DateTime.now().isBefore(chosenDate.add(const Duration(minutes: 40)));

        if (delayBlocked) {
          final unlockTime = chosenDate.add(const Duration(minutes: 40));
          final diff = unlockTime.difference(DateTime.now());
          final hours = diff.inHours;
          final mins = diff.inMinutes.remainder(60);
          final timeLeft = hours > 0 ? '${hours}h ${mins}min' : '${mins}min';

          actions.add(
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.timer, color: AppColors.warning),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Resultado disponível em $timeLeft (40 min após o horário agendado).',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else if (canActOnChallenge) {
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
                    'challengeStatus': challenge.status.dbValue,
                  },
                );
              },
              icon: const Icon(Icons.scoreboard),
              label: const Text('Registrar Resultado'),
            ),
          );
        }
        // Adiamento por chuva disponível em QUALQUER dia dentro do prazo de
        // jogo (não só no último dia) — a quadra pode ficar impraticável antes.
        final deadline = challenge.playDeadline?.toLocal();
        final today = DateTime.now().toLocal();
        final withinPlayWindow = deadline != null &&
            !DateTime(today.year, today.month, today.day).isAfter(
                DateTime(deadline.year, deadline.month, deadline.day));
        // Adiamento por chuva agora é PEDIDO: quem libera é o admin do clube
        // (tinha jogador usando a opção sem ter chovido, só pra prorrogar).
        final pedidoChuva =
            ref.watch(pendingWeatherRequestProvider(challengeId)).valueOrNull;

        if (pedidoChuva != null) {
          actions.add(const SizedBox(height: 8));
          actions.add(
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.water_drop, color: AppColors.info),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Adiamento por chuva aguardando liberação do administrador.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    if (isAdmin) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _reviewWeather(
                                  context, ref, pedidoChuva['id'] as String,
                                  approve: false),
                              child: const Text('Recusar'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _reviewWeather(
                                  context, ref, pedidoChuva['id'] as String,
                                  approve: true),
                              child: const Text('Liberar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        } else if (withinPlayWindow &&
            canActOnChallenge &&
            challenge.canRequestWeatherExtension) {
          final weatherDays = challenge.nextWeatherExtensionDays;
          actions.add(const SizedBox(height: 8));
          actions.add(
            OutlinedButton.icon(
              onPressed: () => _confirmWeatherExtension(context, ref),
              icon: const Icon(Icons.water_drop, color: AppColors.info),
              label: Text(
                'Pedir Adiamento por Chuva (+$weatherDays ${weatherDays > 1 ? 'dias' : 'dia'})',
                style: TextStyle(color: AppColors.info),
              ),
            ),
          );
        }
        {
          // Only allow rescheduling before the day of the match
          final matchDate = challenge.chosenDate?.toLocal();
          final now = DateTime.now().toLocal();
          final isBeforeMatchDay = matchDate == null ||
              DateTime(now.year, now.month, now.day)
                  .isBefore(DateTime(matchDate.year, matchDate.month, matchDate.day));
          // Exceção: adiamento por chuva JÁ LIBERADO para esta data. Chove no
          // dia do jogo, então aqui a data da partida é sempre hoje ou já
          // passou — com a regra acima sozinha o jogador ficava sem como
          // remarcar, que foi o relato do grupo em 05 e 07/10 ("pedi
          // adiamento, não aparece a data pra mudar o jogo").
          final adiadoPorChuva = challenge.weatherExtendedFor != null &&
              challenge.chosenDate != null &&
              challenge.weatherExtendedFor!
                  .isAtSameMomentAs(challenge.chosenDate!);
          final dentroDoPrazoDeJogo = challenge.playDeadline == null ||
              DateTime.now().isBefore(challenge.playDeadline!);
          if ((isChallenger || isChallenged || isAdmin) &&
              (isBeforeMatchDay || (adiadoPorChuva && dentroDoPrazoDeJogo))) {
            actions.add(const SizedBox(height: 8));
            actions.add(
              OutlinedButton.icon(
                onPressed: () => _confirmReschedule(context, ref),
                icon: const Icon(Icons.edit_calendar),
                label: Text(
                  isAdmin && !isChallenger && !isChallenged
                      ? 'Alterar Quadra/Horário (Admin)'
                      : 'Alterar Quadra/Horário',
                ),
              ),
            );
          }
        }
        // Admin actions (jogador não pode cancelar desafio de ranking)
        if (isAdmin) {
          // Admin: registrar resultado furando a regra de atraso
          if (delayBlocked) {
            actions.add(const SizedBox(height: 8));
            actions.add(
              OutlinedButton.icon(
                onPressed: () {
                  context.push(
                    '/challenges/$challengeId/record-result',
                    extra: {
                      'challengerId': challenge.challengerId,
                      'challengedId': challenge.challengedId,
                      'challengerName': challenge.challengerName ?? 'Desafiante',
                      'challengedName': challenge.challengedName ?? 'Desafiado',
                      'isAdminEdit': true,
                      'challengeStatus': challenge.status.dbValue,
                    },
                  );
                },
                icon: Icon(Icons.scoreboard, color: AppColors.warning),
                label: Text('Registrar Resultado (Admin)',
                    style: TextStyle(color: AppColors.warning)),
              ),
            );
          }
          // Admin pode cancelar (jogador não). Cancela, não anula —
          // anular é para desafios já concluídos.
          actions.add(const SizedBox(height: 8));
          actions.add(
            OutlinedButton.icon(
              onPressed: () => _confirmCancel(context, ref),
              icon: const Icon(Icons.gavel, color: AppColors.error),
              label: const Text('Cancelar Desafio (Admin)',
                  style: TextStyle(color: AppColors.error)),
            ),
          );
        }
        break;

      case ChallengeStatus.pendingResult:
        // Legacy: results now auto-complete. For any old challenges still
        // in pending_result, show option to re-submit result.
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
                  'challengeStatus': challenge.status.dbValue,
                },
              );
            },
            icon: const Icon(Icons.scoreboard),
            label: const Text('Registrar Resultado'),
          ),
        );
        // Só admin pode cancelar desafio de ranking (jogador não pode).
        if (ref.watch(isClubAdminProvider).valueOrNull ?? false) {
          actions.add(const SizedBox(height: 8));
          actions.add(
            OutlinedButton.icon(
              onPressed: () => _confirmCancel(context, ref),
              icon: const Icon(Icons.close, color: AppColors.error),
              label: const Text('Cancelar Desafio (Admin)',
                  style: TextStyle(color: AppColors.error)),
            ),
          );
        }
        break;

      case ChallengeStatus.completed:
      case ChallengeStatus.woChallenger:
      case ChallengeStatus.woChallenged:
        final isAdmin = ref.watch(isClubAdminProvider).valueOrNull ?? false;
        if (isAdmin) {
          actions.add(
            OutlinedButton.icon(
              onPressed: () => _confirmAnnul(context, ref),
              icon: const Icon(Icons.gavel, color: AppColors.error),
              label: const Text('Anular Desafio',
                  style: TextStyle(color: AppColors.error)),
            ),
          );
          if (challenge.status == ChallengeStatus.completed) {
            actions.add(const SizedBox(height: 8));
            actions.add(
              OutlinedButton.icon(
                onPressed: () {
                  context.push(
                    '/challenges/$challengeId/record-result',
                    extra: {
                      'challengerId': challenge.challengerId,
                      'challengedId': challenge.challengedId,
                      'challengerName': challenge.challengerName ?? 'Desafiante',
                      'challengedName': challenge.challengedName ?? 'Desafiado',
                      'isAdminEdit': true,
                      'challengeStatus': challenge.status.dbValue,
                    },
                  );
                },
                icon: Icon(Icons.edit, color: AppColors.warning),
                label: Text('Editar Resultado',
                    style: TextStyle(color: AppColors.warning)),
              ),
            );
          }
        }
        break;

      default:
        break;
    }

    return actions;
  }

  void _confirmAnnul(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anular Desafio'),
        content: const Text(
          'Tem certeza que deseja anular este desafio?\n\n'
          'O ranking será revertido e o resultado será apagado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await ref
                  .read(challengeActionProvider.notifier)
                  .annulChallenge(challengeId);
              if (success && context.mounted) {
                SnackbarUtils.showSuccess(
                    context, 'Desafio anulado. Ranking revertido.');
                ref.invalidate(challengeDetailProvider(challengeId));
                ref.invalidate(activeChallengesProvider);
                ref.invalidate(playersWithActiveChallengeProvider);
                ref.invalidate(challengeHistoryProvider);
              }
            },
            child: const Text('Anular'),
          ),
        ],
      ),
    );
  }


  void _confirmReschedule(BuildContext context, WidgetRef ref) {
    // Navigate directly to court selection. The actual cancel of old reservation
    // and update of challenge happens atomically when the user confirms the
    // new slot (via selectCourtAndDate), so if the user backs out nothing changes.
    context.push('/challenges/$challengeId/select-court');
  }

  void _confirmWeatherExtension(BuildContext context, WidgetRef ref) {
    final weatherDays = challenge.nextWeatherExtensionDays;
    final dayLabel = weatherDays > 1 ? 'dias' : 'dia';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pedir Adiamento por Chuva'),
        content: Text(
          'O pedido vai para um administrador do clube liberar.\n\n'
          'Se for liberado, o prazo para jogar aumenta em +$weatherDays $dayLabel. '
          'Até lá o prazo continua o mesmo.',
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
                ref.invalidate(pendingWeatherRequestProvider(challengeId));
                ref.invalidate(challengeDetailProvider(challengeId));
                SnackbarUtils.showSuccess(context,
                    'Pedido enviado. Um administrador vai liberar ou recusar.');
              }
            },
            icon: const Icon(Icons.water_drop),
            label: const Text('Enviar pedido'),
          ),
        ],
      ),
    );
  }

  /// Admin libera ou recusa o pedido de chuva. Só na liberação o prazo muda.
  void _reviewWeather(BuildContext context, WidgetRef ref, String requestId,
      {required bool approve}) async {
    final success = await ref
        .read(challengeActionProvider.notifier)
        .reviewWeatherExtension(requestId, approve: approve);
    if (!context.mounted) return;
    if (success) {
      ref.invalidate(pendingWeatherRequestProvider(challengeId));
      ref.invalidate(challengeDetailProvider(challengeId));
      ref.invalidate(activeChallengesProvider);
      SnackbarUtils.showSuccess(
          context, approve ? 'Adiamento liberado' : 'Pedido recusado');
    } else {
      SnackbarUtils.showError(context, 'Não foi possível responder ao pedido');
    }
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
                ref.invalidate(playersWithActiveChallengeProvider);
                ref.invalidate(myReservationsProvider);
                ref.invalidate(hasActiveFriendlyReservationProvider);
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
  final String playerId;

  const _PlayerRow({
    required this.label,
    required this.name,
    required this.position,
    required this.isCurrentUser,
    required this.playerId,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (isCurrentUser) {
          context.push('/profile');
        } else {
          context.push('/players/$playerId');
        }
      },
      child: Row(
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
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 16, color: AppColors.onBackgroundLight),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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
      ChallengeStatus.pending => 'Aguardando agendamento',
      ChallengeStatus.datesProposed => 'Aguardando confirmação',
      ChallengeStatus.scheduled => 'Agendado',
      ChallengeStatus.pendingResult => 'Aguardando confirmação do resultado',
      ChallengeStatus.completed => 'Finalizado',
      ChallengeStatus.woChallenger => 'WO Desafiante',
      ChallengeStatus.woChallenged => 'WO Desafiado',
      ChallengeStatus.expired => 'Expirado',
      ChallengeStatus.cancelled => 'Cancelado',
      ChallengeStatus.annulled => 'Anulado',
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

// ─── H2H Compact Card ───

class _H2HCard extends ConsumerWidget {
  final ChallengeModel challenge;
  final String currentPlayerId;
  final String challengeId;

  const _H2HCard({
    required this.challenge,
    required this.currentPlayerId,
    required this.challengeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubId = ref.watch(currentClubIdProvider);
    final sportId = ref.watch(currentSportIdProvider);
    if (clubId == null) return const SizedBox.shrink();

    final h2hAsync = ref.watch(h2hProvider((
      p1: challenge.challengerId,
      p2: challenge.challengedId,
      clubId: clubId,
      sportId: sportId,
    )));

    return h2hAsync.when(
      data: (h2h) {
        if (h2h.isEmpty) return const SizedBox.shrink();

        final p1Name = _shortName(h2h.player1Name ?? 'Jogador 1');
        final p2Name = _shortName(h2h.player2Name ?? 'Jogador 2');
        final last = h2h.lastMatch;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push(
                '/challenges/$challengeId/h2h',
                extra: {
                  'player1Id': challenge.challengerId,
                  'player2Id': challenge.challengedId,
                },
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.compare_arrows,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Confronto Direto',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Icon(Icons.chevron_right,
                            size: 20, color: AppColors.onBackgroundLight),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Score row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            p1Name,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: h2h.player1Wins >= h2h.player2Wins
                                  ? AppColors.onBackground
                                  : AppColors.onBackgroundMedium,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            '${h2h.player1Wins}  x  ${h2h.player2Wins}',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            p2Name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: h2h.player2Wins >= h2h.player1Wins
                                  ? AppColors.onBackground
                                  : AppColors.onBackgroundMedium,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (last != null) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Último: ${last.resultDisplay} · ${_formatDate(last.playedAt)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.onBackgroundLight,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  String _shortName(String name) {
    final parts = name.trim().split(' ');
    if (parts.length <= 1) return name;
    return '${parts.first} ${parts.last[0]}.';
  }

  String _formatDate(DateTime date) {
    final d = date.isUtc ? date.toLocal() : date;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
