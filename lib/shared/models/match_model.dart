class MatchModel {
  final String id;
  final String challengeId;
  final String? sportId;
  final String winnerId;
  final String loserId;
  final List<SetScore> sets;
  final int winnerSets;
  final int loserSets;
  final bool superTiebreak;
  final DateTime playedAt;
  final String? notes;
  final DateTime createdAt;

  const MatchModel({
    required this.id,
    required this.challengeId,
    this.sportId,
    required this.winnerId,
    required this.loserId,
    required this.sets,
    required this.winnerSets,
    required this.loserSets,
    this.superTiebreak = false,
    required this.playedAt,
    this.notes,
    required this.createdAt,
  });

  String get scoreDisplay {
    return sets.map((s) => s.display).join(' ');
  }

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    final setsJson = json['sets'] as List<dynamic>? ?? [];

    return MatchModel(
      id: json['id'] as String,
      challengeId: json['challenge_id'] as String,
      sportId: json['sport_id'] as String?,
      winnerId: json['winner_id'] as String,
      loserId: json['loser_id'] as String,
      sets: setsJson
          .map((s) => SetScore.fromJson(s as Map<String, dynamic>))
          .toList(),
      winnerSets: json['winner_sets'] as int,
      loserSets: json['loser_sets'] as int,
      superTiebreak: json['super_tiebreak'] as bool? ?? false,
      playedAt: DateTime.parse(json['played_at'] as String),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'challenge_id': challengeId,
      if (sportId != null) 'sport_id': sportId,
      'winner_id': winnerId,
      'loser_id': loserId,
      'sets': sets.map((s) => s.toJson()).toList(),
      'winner_sets': winnerSets,
      'loser_sets': loserSets,
      'super_tiebreak': superTiebreak,
      'played_at': playedAt.toIso8601String(),
      'notes': notes,
    };
  }
}

class SetScore {
  final int winnerGames;
  final int loserGames;
  final int? tiebreakWinner;
  final int? tiebreakLoser;

  const SetScore({
    required this.winnerGames,
    required this.loserGames,
    this.tiebreakWinner,
    this.tiebreakLoser,
  });

  bool get hasTiebreak => tiebreakWinner != null && tiebreakLoser != null;

  String get display {
    if (hasTiebreak) {
      return '$winnerGames-$loserGames($tiebreakWinner-$tiebreakLoser)';
    }
    return '$winnerGames-$loserGames';
  }

  factory SetScore.fromJson(Map<String, dynamic> json) {
    return SetScore(
      winnerGames: json['winner_games'] as int,
      loserGames: json['loser_games'] as int,
      tiebreakWinner: json['tiebreak_winner'] as int?,
      tiebreakLoser: json['tiebreak_loser'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'winner_games': winnerGames,
      'loser_games': loserGames,
      if (tiebreakWinner != null) 'tiebreak_winner': tiebreakWinner,
      if (tiebreakLoser != null) 'tiebreak_loser': tiebreakLoser,
    };
  }
}
