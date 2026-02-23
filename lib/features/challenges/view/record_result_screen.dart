import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../shared/models/match_model.dart';
import '../../../shared/models/sport_model.dart';
import '../../clubs/viewmodel/club_providers.dart';
import '../viewmodel/challenge_detail_viewmodel.dart';
import '../viewmodel/challenge_list_viewmodel.dart';

class RecordResultScreen extends ConsumerStatefulWidget {
  final String challengeId;
  final String challengerId;
  final String challengedId;
  final String challengerName;
  final String challengedName;

  const RecordResultScreen({
    super.key,
    required this.challengeId,
    required this.challengerId,
    required this.challengedId,
    required this.challengerName,
    required this.challengedName,
  });

  @override
  ConsumerState<RecordResultScreen> createState() =>
      _RecordResultScreenState();
}

class _RecordResultScreenState extends ConsumerState<RecordResultScreen> {
  bool _superTiebreak = false;
  bool _isSubmitting = false;
  bool _singleSet = false;

  // WO state
  String? _woLoserId;

  // Set scores: up to 5 sets (depends on sport)
  late List<_SetScoreInput> _sets;
  bool _initialized = false;

  // Simple score (for futsal/futebol)
  int? _challengerScore;
  int? _challengedScore;

  void _initSets(SportModel? sport) {
    if (_initialized) return;
    _initialized = true;
    if (sport != null && sport.isSimpleScore) {
      _sets = [];
    } else {
      _sets = [_SetScoreInput(), _SetScoreInput()];
    }
  }

  void _switchToSingleSet() {
    setState(() {
      _singleSet = true;
      _superTiebreak = false;
      _sets = [_SetScoreInput()];
    });
  }

  void _switchToNormal() {
    setState(() {
      _singleSet = false;
      _superTiebreak = false;
      _sets = [_SetScoreInput(), _SetScoreInput()];
    });
  }

  String? _determineWinner(SportModel? sport) {
    if (_woLoserId != null) return null; // WO mode — winner determined separately
    if (sport == null) return _determineWinnerSetsGames();

    if (sport.isSimpleScore) {
      return _determineWinnerSimple();
    } else if (sport.isSetsGames && _singleSet) {
      return _determineWinnerSingleSet();
    } else {
      return _determineWinnerSets(sport);
    }
  }

  String? _determineWinnerSimple() {
    if (_challengerScore == null || _challengedScore == null) return null;
    if (_challengerScore! > _challengedScore!) return widget.challengerId;
    if (_challengedScore! > _challengerScore!) return widget.challengedId;
    return null; // draw not allowed
  }

  String? _determineWinnerSingleSet() {
    if (_sets.isEmpty) return null;
    final set = _sets.first;
    if (set.challengerGames == null || set.challengedGames == null) return null;
    if (set.challengerGames! > set.challengedGames!) return widget.challengerId;
    if (set.challengedGames! > set.challengerGames!) return widget.challengedId;
    // Tiebreak at 7-7: determine winner by tiebreak score
    if (set.isTiebreak(true) &&
        set.challengerTiebreak != null &&
        set.challengedTiebreak != null) {
      if (set.challengerTiebreak! > set.challengedTiebreak!) return widget.challengerId;
      if (set.challengedTiebreak! > set.challengerTiebreak!) return widget.challengedId;
    }
    return null;
  }

  String? _determineWinnerSets(SportModel sport) {
    int challengerSetsWon = 0;
    int challengedSetsWon = 0;
    final setsToWin = (sport.maxSets / 2).ceil();

    for (final set in _sets) {
      if (set.challengerGames != null && set.challengedGames != null) {
        if (set.challengerGames! > set.challengedGames!) {
          challengerSetsWon++;
        } else if (set.challengedGames! > set.challengerGames!) {
          challengedSetsWon++;
        }
      }
    }

    if (challengerSetsWon >= setsToWin) return widget.challengerId;
    if (challengedSetsWon >= setsToWin) return widget.challengedId;
    return null;
  }

  String? _determineWinnerSetsGames() {
    if (_singleSet) return _determineWinnerSingleSet();

    int challengerSetsWon = 0;
    int challengedSetsWon = 0;

    for (final set in _sets) {
      if (set.challengerGames != null && set.challengedGames != null) {
        if (set.challengerGames! > set.challengedGames!) {
          challengerSetsWon++;
        } else if (set.challengedGames! > set.challengerGames!) {
          challengedSetsWon++;
        }
      }
    }

    if (challengerSetsWon > challengedSetsWon && challengerSetsWon >= 2) {
      return widget.challengerId;
    } else if (challengedSetsWon > challengerSetsWon && challengedSetsWon >= 2) {
      return widget.challengedId;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final sport = ref.watch(currentSportProvider).valueOrNull;
    _initSets(sport);

    final winnerId = _determineWinner(sport);
    final winnerName = winnerId == widget.challengerId
        ? widget.challengerName
        : winnerId == widget.challengedId
            ? widget.challengedName
            : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Resultado'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── WO Section ───
            _buildWoCard(context),
            const SizedBox(height: 16),

            // Score input (hidden when WO is selected)
            if (_woLoserId == null) ...[
              // Score input (varies by sport type)
              if (sport != null && sport.isSimpleScore)
                _buildSimpleScoreCard(context)
              else if (sport != null && sport.isSetsPoints)
                _buildSetsPointsCard(context, sport)
              else
                _buildSetsGamesCard(context, sport),

              const SizedBox(height: 16),

              // Auto-determined winner indicator
              if (winnerId != null)
                Card(
                  color: AppColors.success.withAlpha(20),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.emoji_events,
                            color: AppColors.secondary, size: 28),
                        const SizedBox(height: 8),
                        Text(
                          '$winnerName venceu!',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _buildScoreString(sport),
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w600),
                        ),
                        if (_superTiebreak && (sport == null || sport.isSetsGames))
                          Text(
                            _singleSet ? 'Set único · Super tiebreak' : 'Super tiebreak',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.onBackgroundLight),
                          )
                        else if (_singleSet)
                          const Text(
                            'Set único de 8 games',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.onBackgroundLight),
                          ),
                      ],
                    ),
                  ),
                )
              else if (_hasAnyScore(sport))
                Card(
                  color: AppColors.surfaceVariant,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline,
                            size: 18, color: AppColors.onBackgroundMedium),
                        SizedBox(width: 8),
                        Text(
                          'Preencha o placar para definir o vencedor',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.onBackgroundMedium),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Submit button
              ElevatedButton.icon(
                onPressed: _determineWinner(sport) != null && !_isSubmitting
                    ? () => _submit(sport)
                    : null,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(
                    _isSubmitting ? 'Registrando...' : 'Registrar Resultado'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── WO Card ───

  Widget _buildWoCard(BuildContext context) {
    final woWinnerId = _woLoserId != null
        ? (_woLoserId == widget.challengerId
            ? widget.challengedId
            : widget.challengerId)
        : null;
    final woWinnerName = woWinnerId == widget.challengerId
        ? widget.challengerName
        : woWinnerId == widget.challengedId
            ? widget.challengedName
            : null;
    final woLoserName = _woLoserId == widget.challengerId
        ? widget.challengerName
        : _woLoserId == widget.challengedId
            ? widget.challengedName
            : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_off, size: 20, color: AppColors.warning),
                const SizedBox(width: 8),
                Text(
                  'WO (Walkover)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                if (_woLoserId != null)
                  TextButton(
                    onPressed: () => setState(() => _woLoserId = null),
                    child: const Text('Cancelar'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Marque WO se um jogador não compareceu',
              style: TextStyle(fontSize: 13, color: AppColors.onBackgroundLight),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _WoButton(
                    label: _firstName(widget.challengerName),
                    sublabel: 'não compareceu',
                    isSelected: _woLoserId == widget.challengerId,
                    onTap: () => setState(() {
                      _woLoserId = _woLoserId == widget.challengerId
                          ? null
                          : widget.challengerId;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _WoButton(
                    label: _firstName(widget.challengedName),
                    sublabel: 'não compareceu',
                    isSelected: _woLoserId == widget.challengedId,
                    onTap: () => setState(() {
                      _woLoserId = _woLoserId == widget.challengedId
                          ? null
                          : widget.challengedId;
                    }),
                  ),
                ),
              ],
            ),
            if (_woLoserId != null) ...[
              const SizedBox(height: 16),
              Card(
                color: AppColors.warning.withAlpha(20),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events,
                          color: AppColors.secondary, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$woWinnerName vence por WO',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            Text(
                              '$woLoserName não compareceu',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.onBackgroundMedium),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitWo,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle),
                  label: Text(_isSubmitting ? 'Registrando...' : 'Registrar WO'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Simple Score (Futsal / Futebol) ───

  Widget _buildSimpleScoreCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Placar',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        _firstName(widget.challengerName),
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.onBackgroundMedium,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _NumberInput(
                        value: _challengerScore,
                        maxValue: 99,
                        onChanged: (v) => setState(() => _challengerScore = v),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Text(' x ',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 20)),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        _firstName(widget.challengedName),
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.onBackgroundMedium,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _NumberInput(
                        value: _challengedScore,
                        maxValue: 99,
                        onChanged: (v) => setState(() => _challengedScore = v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Sets + Points (Volei / Beach / Futevolei) ───

  Widget _buildSetsPointsCard(BuildContext context, SportModel sport) {
    final maxSets = sport.maxSets;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Placar por Sets',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (_sets.length < maxSets)
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _sets.add(_SetScoreInput()));
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: Text('Set ${_sets.length + 1}'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Column headers
            Row(
              children: [
                const SizedBox(width: 60),
                Expanded(
                  child: Center(
                    child: Text(
                      _firstName(widget.challengerName),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.onBackgroundMedium,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      _firstName(widget.challengedName),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.onBackgroundMedium,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (_sets.length > 2) const SizedBox(width: 40),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(_sets.length, (index) {
              final set = _sets[index];
              final isLast = index == _sets.length - 1;
              final maxPoints = index == maxSets - 1
                  ? sport.finalSetPoints + 20 // allow deuce
                  : sport.pointsToWin + 20;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        'Set ${index + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: _NumberInput(
                        value: set.challengerGames,
                        maxValue: maxPoints,
                        onChanged: (v) =>
                            setState(() => set.challengerGames = v),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('x',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: _NumberInput(
                        value: set.challengedGames,
                        maxValue: maxPoints,
                        onChanged: (v) =>
                            setState(() => set.challengedGames = v),
                      ),
                    ),
                    if (_sets.length > 2 && isLast)
                      IconButton(
                        onPressed: () {
                          setState(() => _sets.removeLast());
                        },
                        icon: const Icon(Icons.close,
                            size: 20, color: AppColors.onBackgroundLight),
                      )
                    else if (_sets.length > 2)
                      const SizedBox(width: 40),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ─── Sets + Games (Tennis) ───

  Widget _buildSetsGamesCard(BuildContext context, SportModel? sport) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Format toggle: Normal / Set único
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Placar',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (!_singleSet && _sets.length < 3)
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _sets.add(_SetScoreInput()));
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('3o Set'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            // Format selector
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Normal'),
                  icon: Icon(Icons.looks_two, size: 18),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Set único (8 games)'),
                  icon: Icon(Icons.looks_one, size: 18),
                ),
              ],
              selected: {_singleSet},
              onSelectionChanged: (v) {
                if (v.first) {
                  _switchToSingleSet();
                } else {
                  _switchToNormal();
                }
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStatePropertyAll(
                  const TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Column headers with player names
            Row(
              children: [
                const SizedBox(width: 60),
                Expanded(
                  child: Center(
                    child: Text(
                      _firstName(widget.challengerName),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.onBackgroundMedium,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      _firstName(widget.challengedName),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.onBackgroundMedium,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (!_singleSet && _sets.length > 2) const SizedBox(width: 40),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(_sets.length, (index) {
              final isLast = index == _sets.length - 1;
              final set = _sets[index];
              final isTb = set.isTiebreak(_singleSet);
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 60,
                          child: Text(
                            _singleSet
                                ? 'Set'
                                : index == 2 && _superTiebreak
                                    ? 'Tiebreak'
                                    : 'Set ${index + 1}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          child: _ScoreDropdown(
                            value: set.challengerGames,
                            isSuperTiebreak: !_singleSet && index == 2 && _superTiebreak,
                            isSingleSet: _singleSet,
                            onChanged: (v) => setState(() {
                              set.challengerGames = v;
                              if (!set.isTiebreak(_singleSet)) {
                                set.challengerTiebreak = null;
                                set.challengedTiebreak = null;
                              }
                            }),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('x',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Expanded(
                          child: _ScoreDropdown(
                            value: set.challengedGames,
                            isSuperTiebreak: !_singleSet && index == 2 && _superTiebreak,
                            isSingleSet: _singleSet,
                            onChanged: (v) => setState(() {
                              set.challengedGames = v;
                              if (!set.isTiebreak(_singleSet)) {
                                set.challengerTiebreak = null;
                                set.challengedTiebreak = null;
                              }
                            }),
                          ),
                        ),
                        if (!_singleSet && _sets.length > 2 && isLast)
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _sets.removeLast();
                                _superTiebreak = false;
                              });
                            },
                            icon: const Icon(Icons.close,
                                size: 20, color: AppColors.onBackgroundLight),
                          )
                        else if (!_singleSet && _sets.length > 2)
                          const SizedBox(width: 40),
                      ],
                    ),
                  ),
                  // Tiebreak score row
                  if (isTb)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 60,
                            child: Text(
                              _singleSet ? 'Super TB' : 'TB ${index + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: _ScoreDropdown(
                              value: set.challengerTiebreak,
                              isTiebreak: true,
                              onChanged: (v) => setState(
                                  () => set.challengerTiebreak = v),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('x',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ),
                          Expanded(
                            child: _ScoreDropdown(
                              value: set.challengedTiebreak,
                              isTiebreak: true,
                              onChanged: (v) => setState(
                                  () => set.challengedTiebreak = v),
                            ),
                          ),
                          if (!_singleSet && _sets.length > 2)
                            const SizedBox(width: 40),
                        ],
                      ),
                    ),
                ],
              );
            }),
            // Super tiebreak toggle (only for normal mode with 3 sets)
            if (!_singleSet && _sets.length >= 3)
              SwitchListTile(
                title: const Text('Super Tiebreak (3o set)'),
                subtitle: const Text(
                  'Marque se o 3o set foi decidido por super tiebreak',
                  style: TextStyle(fontSize: 12),
                ),
                value: _superTiebreak,
                onChanged: (v) => setState(() => _superTiebreak = v),
                activeTrackColor: AppColors.primary.withAlpha(100),
                contentPadding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
    );
  }

  bool _hasAnyScore(SportModel? sport) {
    if (sport != null && sport.isSimpleScore) {
      return _challengerScore != null || _challengedScore != null;
    }
    return _sets.any(
        (s) => s.challengerGames != null || s.challengedGames != null);
  }

  String _buildScoreString(SportModel? sport) {
    if (sport != null && sport.isSimpleScore) {
      final winnerId = _determineWinner(sport);
      if (winnerId == widget.challengerId) {
        return '$_challengerScore x $_challengedScore';
      }
      return '$_challengedScore x $_challengerScore';
    }

    final winnerId = _determineWinner(sport);
    return _sets
        .where(
            (s) => s.challengerGames != null && s.challengedGames != null)
        .map((s) {
      final String games;
      final String tb;
      final isTb = s.isTiebreak(_singleSet);

      if (winnerId == widget.challengerId) {
        games = '${s.challengerGames}-${s.challengedGames}';
        tb = (isTb &&
                s.challengerTiebreak != null &&
                s.challengedTiebreak != null)
            ? '(${s.challengerTiebreak}-${s.challengedTiebreak})'
            : '';
      } else {
        games = '${s.challengedGames}-${s.challengerGames}';
        tb = (isTb &&
                s.challengerTiebreak != null &&
                s.challengedTiebreak != null)
            ? '(${s.challengedTiebreak}-${s.challengerTiebreak})'
            : '';
      }
      return '$games$tb';
    }).join(' ');
  }

  String _firstName(String fullName) {
    return fullName.split(' ').first;
  }

  Future<void> _submitWo() async {
    if (_woLoserId == null) return;

    final winnerId = _woLoserId == widget.challengerId
        ? widget.challengedId
        : widget.challengerId;

    setState(() => _isSubmitting = true);

    final success = await ref.read(challengeActionProvider.notifier).recordWo(
          challengeId: widget.challengeId,
          winnerId: winnerId,
          loserId: _woLoserId!,
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      SnackbarUtils.showSuccess(context, 'WO registrado!');
      ref.invalidate(challengeDetailProvider(widget.challengeId));
      ref.invalidate(challengeMatchProvider(widget.challengeId));
      ref.invalidate(activeChallengesProvider);
      ref.invalidate(challengeHistoryProvider);
      context.pop();
    } else {
      SnackbarUtils.showError(context, 'Erro ao registrar WO');
    }
  }

  Future<void> _submit(SportModel? sport) async {
    final winnerId = _determineWinner(sport);
    if (winnerId == null) return;

    final loserId = winnerId == widget.challengerId
        ? widget.challengedId
        : widget.challengerId;

    final validSets = <SetScore>[];
    int winnerSets = 0;
    int loserSets = 0;

    if (sport != null && sport.isSimpleScore) {
      // Simple score: store as single "set"
      final wScore = winnerId == widget.challengerId
          ? _challengerScore!
          : _challengedScore!;
      final lScore = winnerId == widget.challengerId
          ? _challengedScore!
          : _challengerScore!;
      validSets.add(SetScore(winnerGames: wScore, loserGames: lScore));
      winnerSets = 1;
      loserSets = 0;
    } else {
      // Sets-based (games or points)
      for (final set in _sets) {
        if (set.challengerGames != null && set.challengedGames != null) {
          final int wGames;
          final int lGames;

          if (winnerId == widget.challengerId) {
            wGames = set.challengerGames!;
            lGames = set.challengedGames!;
          } else {
            wGames = set.challengedGames!;
            lGames = set.challengerGames!;
          }

          int? tbWinner;
          int? tbLoser;
          if (set.isTiebreak(_singleSet) &&
              set.challengerTiebreak != null &&
              set.challengedTiebreak != null) {
            if (winnerId == widget.challengerId) {
              tbWinner = set.challengerTiebreak;
              tbLoser = set.challengedTiebreak;
            } else {
              tbWinner = set.challengedTiebreak;
              tbLoser = set.challengerTiebreak;
            }
          }

          validSets.add(SetScore(
            winnerGames: wGames,
            loserGames: lGames,
            tiebreakWinner: tbWinner,
            tiebreakLoser: tbLoser,
          ));

          if (wGames > lGames) {
            winnerSets++;
          } else if (wGames == lGames && set.isTiebreak(_singleSet)) {
            // Tiebreak at 7-7 in single set: winner takes the set
            winnerSets++;
          } else {
            loserSets++;
          }
        }
      }
    }

    // In single set mode, tiebreak at 7-7 is a super tiebreak
    final isSuperTb = _singleSet
        ? (_sets.isNotEmpty && _sets.first.isTiebreak(true))
        : _superTiebreak;

    setState(() => _isSubmitting = true);

    final success =
        await ref.read(challengeActionProvider.notifier).recordResult(
              challengeId: widget.challengeId,
              winnerId: winnerId,
              loserId: loserId,
              sets: validSets,
              winnerSets: winnerSets,
              loserSets: loserSets,
              superTiebreak: isSuperTb,
            );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      SnackbarUtils.showSuccess(context, 'Resultado registrado!');
      ref.invalidate(challengeDetailProvider(widget.challengeId));
      ref.invalidate(challengeMatchProvider(widget.challengeId));
      ref.invalidate(activeChallengesProvider);
      ref.invalidate(challengeHistoryProvider);
      context.pop();
    } else {
      SnackbarUtils.showError(context, 'Erro ao registrar resultado');
    }
  }
}

class _SetScoreInput {
  int? challengerGames;
  int? challengedGames;
  int? challengerTiebreak;
  int? challengedTiebreak;

  bool isTiebreak(bool singleSet) {
    if (challengerGames == null || challengedGames == null) return false;
    if (singleSet) {
      // Single set of 8 games: tiebreak at 7-7
      return challengerGames == 7 && challengedGames == 7;
    }
    return (challengerGames == 7 && challengedGames == 6) ||
        (challengerGames == 6 && challengedGames == 7);
  }
}

/// WO selection button
class _WoButton extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool isSelected;
  final VoidCallback onTap;

  const _WoButton({
    required this.label,
    required this.sublabel,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.warning.withAlpha(20)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.warning : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.person_off,
              size: 24,
              color: isSelected ? AppColors.warning : AppColors.onBackgroundLight,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isSelected ? AppColors.warning : null,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              sublabel,
              style: TextStyle(
                fontSize: 11,
                color: isSelected
                    ? AppColors.warning.withAlpha(180)
                    : AppColors.onBackgroundLight,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Dropdown for tennis games (0-7 normal, 0-8 single set) and tiebreak (0-20)
class _ScoreDropdown extends StatelessWidget {
  final int? value;
  final bool isSuperTiebreak;
  final bool isTiebreak;
  final bool isSingleSet;
  final ValueChanged<int?> onChanged;

  const _ScoreDropdown({
    required this.value,
    this.isSuperTiebreak = false,
    this.isTiebreak = false,
    this.isSingleSet = false,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final int count;
    if (isSuperTiebreak) {
      count = 21; // 0-20 for super tiebreak
    } else if (isTiebreak) {
      count = 21; // 0-20 for regular tiebreak
    } else if (isSingleSet) {
      count = 9; // 0-8 for single set of 8 games
    } else {
      count = 8; // 0-7 for regular games
    }
    final items = List.generate(count, (i) => i);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isTiebreak
              ? AppColors.primary.withAlpha(80)
              : AppColors.divider,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          hint: const Center(child: Text('-')),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          items: items
              .map((i) => DropdownMenuItem(
                    value: i,
                    child: Center(
                      child: Text(
                        '$i',
                        style: TextStyle(
                          fontSize: isTiebreak ? 15 : 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Number input for points/goals (0 to maxValue)
class _NumberInput extends StatelessWidget {
  final int? value;
  final int maxValue;
  final ValueChanged<int?> onChanged;

  const _NumberInput({
    required this.value,
    this.maxValue = 99,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          hint: const Center(child: Text('-')),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          menuMaxHeight: 300,
          items: List.generate(maxValue + 1, (i) => i)
              .map((i) => DropdownMenuItem(
                    value: i,
                    child: Center(
                      child: Text(
                        '$i',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
