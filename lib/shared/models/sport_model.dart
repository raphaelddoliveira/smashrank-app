import 'package:flutter/material.dart';

/// Configuration for facility terminology and surface types per sport
class FacilityConfig {
  final String label;        // "Quadra", "Campo"
  final String plural;       // "Quadras", "Campos"
  final String coveredLabel; // "Quadra coberta", "Campo coberto"
  final String emptyState;   // "Nenhuma quadra disponível"
  final String emptyAdmin;   // "Nenhuma quadra cadastrada"
  final String nameLabel;    // "Nome da quadra"
  final String nameHint;     // "Ex: Quadra 1"
  final String newTitle;     // "Nova Quadra"
  final String editTitle;    // "Editar Quadra"
  final List<({String value, String label})> surfaces;

  const FacilityConfig({
    required this.label,
    required this.plural,
    required this.coveredLabel,
    required this.emptyState,
    required this.emptyAdmin,
    required this.nameLabel,
    required this.nameHint,
    required this.newTitle,
    required this.editTitle,
    required this.surfaces,
  });
}

class SportModel {
  final String id;
  final String name;
  final String scoringType; // 'sets_games', 'sets_points', 'simple_score'
  final Map<String, dynamic> config;
  final String icon;
  final int displayOrder;
  final bool isActive;

  const SportModel({
    required this.id,
    required this.name,
    required this.scoringType,
    this.config = const {},
    this.icon = 'sports',
    this.displayOrder = 0,
    this.isActive = true,
  });

  bool get isSetsGames => scoringType == 'sets_games';
  bool get isSetsPoints => scoringType == 'sets_points';
  bool get isSimpleScore => scoringType == 'simple_score';

  int get maxSets => config['max_sets'] as int? ?? 3;
  int get gamesToWin => config['games_to_win'] as int? ?? 6;
  bool get hasTiebreak => config['has_tiebreak'] as bool? ?? false;
  bool get hasSuperTiebreak => config['has_super_tiebreak'] as bool? ?? false;
  int get pointsToWin => config['points_to_win'] as int? ?? 25;
  int get finalSetPoints => config['final_set_points'] as int? ?? 15;
  int get minDiff => config['min_diff'] as int? ?? 2;
  int get halves => config['halves'] as int? ?? 2;

  bool get isTennis {
    final n = name.toLowerCase();
    return n == 'tenis' || n == 'tênis';
  }

  IconData get iconData {
    switch (name.toLowerCase()) {
      case 'tenis':
      case 'tênis':
        return Icons.sports_tennis;
      case 'volei quadra':
      case 'vôlei quadra':
      case 'volei de areia':
      case 'vôlei de areia':
      case 'futevôlei':
      case 'futevolei':
        return Icons.sports_volleyball;
      case 'futsal':
      case 'futebol de campo':
        return Icons.sports_soccer;
      default:
        return Icons.emoji_events;
    }
  }

  FacilityConfig get facilityConfig {
    switch (name.toLowerCase()) {
      case 'tenis':
      case 'tênis':
        return const FacilityConfig(
          label: 'Quadra',
          plural: 'Quadras',
          coveredLabel: 'Quadra coberta',
          emptyState: 'Nenhuma quadra disponível',
          emptyAdmin: 'Nenhuma quadra cadastrada',
          nameLabel: 'Nome da quadra',
          nameHint: 'Ex: Quadra 1',
          newTitle: 'Nova Quadra',
          editTitle: 'Editar Quadra',
          surfaces: [
            (value: 'saibro', label: 'Saibro'),
            (value: 'dura', label: 'Quadra Dura'),
            (value: 'grama', label: 'Grama'),
            (value: 'carpet', label: 'Carpet'),
            (value: 'sintetica', label: 'Sintética'),
          ],
        );
      case 'futsal':
        return const FacilityConfig(
          label: 'Quadra',
          plural: 'Quadras',
          coveredLabel: 'Quadra coberta',
          emptyState: 'Nenhuma quadra disponível',
          emptyAdmin: 'Nenhuma quadra cadastrada',
          nameLabel: 'Nome da quadra',
          nameHint: 'Ex: Quadra 1',
          newTitle: 'Nova Quadra',
          editTitle: 'Editar Quadra',
          surfaces: [
            (value: 'grama_sintetica', label: 'Grama Sintética'),
            (value: 'piso', label: 'Piso'),
            (value: 'cimento', label: 'Cimento'),
          ],
        );
      case 'futebol de campo':
        return const FacilityConfig(
          label: 'Campo',
          plural: 'Campos',
          coveredLabel: 'Campo coberto',
          emptyState: 'Nenhum campo disponível',
          emptyAdmin: 'Nenhum campo cadastrado',
          nameLabel: 'Nome do campo',
          nameHint: 'Ex: Campo 1',
          newTitle: 'Novo Campo',
          editTitle: 'Editar Campo',
          surfaces: [
            (value: 'grama_natural', label: 'Grama Natural'),
            (value: 'grama_sintetica', label: 'Grama Sintética'),
            (value: 'society', label: 'Society'),
          ],
        );
      case 'volei quadra':
      case 'vôlei quadra':
      case 'volei de quadra':
      case 'vôlei de quadra':
        return const FacilityConfig(
          label: 'Quadra',
          plural: 'Quadras',
          coveredLabel: 'Quadra coberta',
          emptyState: 'Nenhuma quadra disponível',
          emptyAdmin: 'Nenhuma quadra cadastrada',
          nameLabel: 'Nome da quadra',
          nameHint: 'Ex: Quadra 1',
          newTitle: 'Nova Quadra',
          editTitle: 'Editar Quadra',
          surfaces: [
            (value: 'piso', label: 'Piso'),
            (value: 'areia', label: 'Areia'),
          ],
        );
      case 'volei de areia':
      case 'vôlei de areia':
      case 'futevolei':
      case 'futevôlei':
        return const FacilityConfig(
          label: 'Quadra',
          plural: 'Quadras',
          coveredLabel: 'Quadra coberta',
          emptyState: 'Nenhuma quadra disponível',
          emptyAdmin: 'Nenhuma quadra cadastrada',
          nameLabel: 'Nome da quadra',
          nameHint: 'Ex: Quadra 1',
          newTitle: 'Nova Quadra',
          editTitle: 'Editar Quadra',
          surfaces: [
            (value: 'areia', label: 'Areia'),
          ],
        );
      default:
        return const FacilityConfig(
          label: 'Local',
          plural: 'Locais',
          coveredLabel: 'Local coberto',
          emptyState: 'Nenhum local disponível',
          emptyAdmin: 'Nenhum local cadastrado',
          nameLabel: 'Nome do local',
          nameHint: 'Ex: Local 1',
          newTitle: 'Novo Local',
          editTitle: 'Editar Local',
          surfaces: [],
        );
    }
  }

  factory SportModel.fromJson(Map<String, dynamic> json) {
    return SportModel(
      id: json['id'] as String,
      name: json['name'] as String,
      scoringType: json['scoring_type'] as String,
      config: json['config'] as Map<String, dynamic>? ?? {},
      icon: json['icon'] as String? ?? 'sports',
      displayOrder: json['display_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'scoring_type': scoringType,
      'config': config,
      'icon': icon,
      'display_order': displayOrder,
      'is_active': isActive,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SportModel && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Model for club_sports join table
class ClubSportModel {
  final String id;
  final String clubId;
  final String sportId;
  final bool isActive;
  final DateTime createdAt;
  final SportModel? sport;

  // Configurable rules (defaults: all enabled)
  final bool ruleAmbulanceEnabled;
  final bool ruleCooldownEnabled;
  final bool rulePositionGapEnabled;
  final bool ruleResultDelayEnabled;

  const ClubSportModel({
    required this.id,
    required this.clubId,
    required this.sportId,
    this.isActive = true,
    required this.createdAt,
    this.sport,
    this.ruleAmbulanceEnabled = true,
    this.ruleCooldownEnabled = true,
    this.rulePositionGapEnabled = true,
    this.ruleResultDelayEnabled = true,
  });

  factory ClubSportModel.fromJson(Map<String, dynamic> json) {
    return ClubSportModel(
      id: json['id'] as String,
      clubId: json['club_id'] as String,
      sportId: json['sport_id'] as String,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      sport: json['sport'] != null
          ? SportModel.fromJson(json['sport'] as Map<String, dynamic>)
          : null,
      ruleAmbulanceEnabled: json['rule_ambulance_enabled'] as bool? ?? true,
      ruleCooldownEnabled: json['rule_cooldown_enabled'] as bool? ?? true,
      rulePositionGapEnabled: json['rule_position_gap_enabled'] as bool? ?? true,
      ruleResultDelayEnabled: json['rule_result_delay_enabled'] as bool? ?? true,
    );
  }
}
