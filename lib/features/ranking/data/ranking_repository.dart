import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/supabase_constants.dart';
import '../../../core/errors/error_handler.dart';
import '../../../services/supabase_service.dart';
import '../../../shared/models/club_member_model.dart';
import '../../../shared/models/ranking_history_model.dart';

final rankingRepositoryProvider = Provider<RankingRepository>((ref) {
  return RankingRepository(ref.watch(supabaseClientProvider));
});

class RankingRepository {
  final SupabaseClient _client;

  RankingRepository(this._client);

  /// Get ranking for a club + sport (from club_members joined with players)
  Future<List<ClubMemberModel>> getRanking(String clubId, {String? sportId}) async {
    try {
      var query = _client
          .from('club_members')
          .select('*, player:players(full_name, nickname, avatar_url, email, phone), sport:sports(name, scoring_type)')
          .eq('club_id', clubId)
          .eq('status', 'active')
          .not('ranking_position', 'is', null);
      if (sportId != null) {
        query = query.eq('sport_id', sportId);
      }
      final data = await query.order('ranking_position', ascending: true);
      return data.map((e) => ClubMemberModel.fromJson(e)).toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<void> toggleRankingParticipation({
    required String clubId,
    required String sportId,
    required bool optIn,
  }) async {
    try {
      final authId = _client.auth.currentUser!.id;
      await _client.rpc('toggle_ranking_participation', params: {
        'p_auth_id': authId,
        'p_club_id': clubId,
        'p_sport_id': sportId,
        'p_opt_in': optIn,
      });
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  Future<List<RankingHistoryModel>> getPlayerHistory(
    String playerId, {
    String? clubId,
    String? sportId,
    int limit = 50,
  }) async {
    try {
      var query = _client
          .from(SupabaseConstants.rankingHistoryTable)
          .select()
          .eq('player_id', playerId);

      if (clubId != null) {
        query = query.eq('club_id', clubId);
      }
      if (sportId != null) {
        query = query.eq('sport_id', sportId);
      }

      final data = await query
          .order('created_at', ascending: false)
          .limit(limit);
      return data.map((e) => RankingHistoryModel.fromJson(e)).toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
