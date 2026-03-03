import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../shared/models/club_member_model.dart';
import '../../../shared/models/sport_model.dart';
import '../../clubs/viewmodel/club_providers.dart';
import '../../ranking/viewmodel/ranking_list_viewmodel.dart';
import '../viewmodel/admin_ranking_viewmodel.dart';

class AdminRankingScreen extends ConsumerStatefulWidget {
  const AdminRankingScreen({super.key});

  @override
  ConsumerState<AdminRankingScreen> createState() => _AdminRankingScreenState();
}

class _AdminRankingScreenState extends ConsumerState<AdminRankingScreen> {
  List<ClubMemberModel>? _reorderedMembers;
  List<ClubMemberModel>? _originalMembers;
  String? _selectedSportId;
  bool _saving = false;

  bool get _hasChanges {
    if (_reorderedMembers == null || _originalMembers == null) return false;
    for (int i = 0; i < _reorderedMembers!.length; i++) {
      if (_reorderedMembers![i].id != _originalMembers![i].id) return true;
    }
    return false;
  }

  void _initMembers(List<ClubMemberModel> members) {
    if (_originalMembers == null ||
        _originalMembers!.length != members.length ||
        _selectedSportId != _lastLoadedSportId) {
      _originalMembers = List.from(members);
      _reorderedMembers = List.from(members);
      _lastLoadedSportId = _selectedSportId;
    }
  }

  String? _lastLoadedSportId;

  void _resetOrder() {
    if (_originalMembers != null) {
      setState(() {
        _reorderedMembers = List.from(_originalMembers!);
      });
    }
  }

  Future<void> _saveRanking() async {
    final clubId = ref.read(currentClubIdProvider);
    if (clubId == null || _selectedSportId == null || _reorderedMembers == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Reordenacao'),
        content: const Text(
          'Tem certeza que deseja salvar a nova ordem do ranking?\n\n'
          'Todos os jogadores afetados serao notificados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);

    final success = await ref.read(adminRankingSaveProvider.notifier).saveRanking(
      clubId: clubId,
      sportId: _selectedSportId!,
      orderedMembers: _reorderedMembers!,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (success) {
      SnackbarUtils.showSuccess(context, 'Ranking reordenado com sucesso');
      ref.invalidate(adminRankingMembersProvider(_selectedSportId!));
      ref.invalidate(rankingListProvider);
      // Reset state so it reloads fresh
      _originalMembers = null;
      _reorderedMembers = null;
    } else {
      final error = ref.read(adminRankingSaveProvider);
      SnackbarUtils.showError(
        context,
        'Erro ao salvar: ${error.error}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final clubId = ref.watch(currentClubIdProvider);
    if (clubId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ordenar Ranking')),
        body: const Center(child: Text('Selecione um clube primeiro')),
      );
    }

    final clubSportsAsync = ref.watch(clubSportsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ordenar Ranking'),
        actions: [
          if (_hasChanges) ...[
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Desfazer alteracoes',
              onPressed: _resetOrder,
            ),
          ],
        ],
      ),
      floatingActionButton: _hasChanges && !_saving
          ? FloatingActionButton.extended(
              onPressed: _saveRanking,
              icon: const Icon(Icons.save),
              label: const Text('Salvar'),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            )
          : null,
      body: clubSportsAsync.when(
        data: (clubSports) {
          if (clubSports.isEmpty) {
            return const Center(child: Text('Nenhum esporte habilitado'));
          }

          // Auto-select first sport if none selected
          _selectedSportId ??= ref.read(currentSportIdProvider) ?? clubSports.first.sportId;

          return Column(
            children: [
              _SportSelector(
                clubSports: clubSports,
                selectedSportId: _selectedSportId!,
                onChanged: (sportId) {
                  setState(() {
                    _selectedSportId = sportId;
                    _originalMembers = null;
                    _reorderedMembers = null;
                  });
                },
              ),
              Expanded(
                child: _RankingList(
                  sportId: _selectedSportId!,
                  onMembersLoaded: _initMembers,
                  reorderedMembers: _reorderedMembers,
                  saving: _saving,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = _reorderedMembers!.removeAt(oldIndex);
                      _reorderedMembers!.insert(newIndex, item);
                    });
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
      ),
    );
  }
}

// ─── Sport Selector ───
class _SportSelector extends StatelessWidget {
  final List<ClubSportModel> clubSports;
  final String selectedSportId;
  final ValueChanged<String> onChanged;

  const _SportSelector({
    required this.clubSports,
    required this.selectedSportId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: clubSports.map((cs) {
          final isSelected = cs.sportId == selectedSportId;
          final sportName = cs.sport?.name ?? 'Esporte';
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(sportName),
              selected: isSelected,
              onSelected: (_) => onChanged(cs.sportId),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.onPrimary : AppColors.onBackground,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Ranking List ───
class _RankingList extends ConsumerWidget {
  final String sportId;
  final void Function(List<ClubMemberModel>) onMembersLoaded;
  final List<ClubMemberModel>? reorderedMembers;
  final bool saving;
  final void Function(int oldIndex, int newIndex) onReorder;

  const _RankingList({
    required this.sportId,
    required this.onMembersLoaded,
    required this.reorderedMembers,
    required this.saving,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(adminRankingMembersProvider(sportId));

    return membersAsync.when(
      data: (members) {
        if (members.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Nenhum jogador no ranking deste esporte',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // Initialize parent state with loaded members
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onMembersLoaded(members);
        });

        final displayMembers = reorderedMembers ?? members;

        if (saving) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                '${displayMembers.length} jogadores — arraste para reordenar',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.onBackgroundLight,
                ),
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: displayMembers.length,
                onReorder: onReorder,
                proxyDecorator: (child, index, animation) {
                  return Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: child,
                  );
                },
                itemBuilder: (context, index) {
                  final member = displayMembers[index];
                  final originalIndex = reorderedMembers != null
                      ? (members.indexWhere((m) => m.id == member.id))
                      : index;
                  final positionDelta = originalIndex - index;

                  return Card(
                    key: ValueKey(member.id),
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.surfaceVariant,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      title: Text(
                        member.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Row(
                        children: [
                          if (member.ambulanceActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.ambulanceActive.withAlpha(25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.local_hospital,
                                      size: 10, color: AppColors.ambulanceActive),
                                  SizedBox(width: 3),
                                  Text('Ambulancia',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.ambulanceActive)),
                                ],
                              ),
                            ),
                          if (positionDelta != 0) ...[
                            if (member.ambulanceActive) const SizedBox(width: 6),
                            _PositionDeltaBadge(delta: positionDelta),
                          ],
                        ],
                      ),
                      trailing: ReorderableDragStartListener(
                        index: index,
                        child: const Icon(Icons.drag_handle,
                            color: AppColors.onBackgroundLight),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Erro: $error')),
    );
  }
}

class _PositionDeltaBadge extends StatelessWidget {
  final int delta;

  const _PositionDeltaBadge({required this.delta});

  @override
  Widget build(BuildContext context) {
    final isUp = delta > 0;
    final color = isUp ? AppColors.rankUp : AppColors.rankDown;
    final icon = isUp ? Icons.arrow_upward : Icons.arrow_downward;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 2),
          Text(
            '${delta.abs()}',
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
