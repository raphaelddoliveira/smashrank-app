import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_handler.dart';
import '../../../services/supabase_service.dart';
import '../../../shared/models/club_member_model.dart';
import '../../../shared/models/club_model.dart';
import '../../../shared/models/sport_model.dart';

final clubRepositoryProvider = Provider<ClubRepository>((ref) {
  return ClubRepository(ref.watch(supabaseClientProvider));
});

class ClubRepository {
  final SupabaseClient _client;

  ClubRepository(this._client);

  /// Get all clubs the current player belongs to (distinct by club)
  Future<List<ClubModel>> getMyClubs(String playerId) async {
    try {
      final data = await _client
          .from('club_members')
          .select('club:clubs(*)')
          .eq('player_id', playerId)
          .eq('status', 'active');
      // Deduplicate by club id (player may have multiple rows per sport)
      final seen = <String>{};
      final clubs = <ClubModel>[];
      for (final e in data) {
        final club = ClubModel.fromJson(e['club'] as Map<String, dynamic>);
        if (seen.add(club.id)) {
          clubs.add(club);
        }
      }
      return clubs;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Get a single club by ID
  Future<ClubModel> getClub(String clubId) async {
    try {
      final data = await _client
          .from('clubs')
          .select()
          .eq('id', clubId)
          .single();
      return ClubModel.fromJson(data);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Create a new club via RPC
  Future<String> createClub({
    required String authId,
    required String name,
    String? description,
  }) async {
    try {
      final result = await _client.rpc('create_club', params: {
        'p_auth_id': authId,
        'p_name': name,
        'p_description': description,
      });
      return result as String;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Request to join a club by invite code
  Future<String> joinClubByCode({
    required String authId,
    required String inviteCode,
  }) async {
    try {
      final result = await _client.rpc('join_club_by_code', params: {
        'p_auth_id': authId,
        'p_invite_code': inviteCode,
      });
      return result as String;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Get members of a club (with player data)
  Future<List<ClubMemberModel>> getMembers(String clubId) async {
    try {
      final data = await _client
          .from('club_members')
          .select('*, player:players(full_name, nickname, avatar_url, email, phone)')
          .eq('club_id', clubId)
          .eq('status', 'active')
          .order('ranking_position', ascending: true);
      return data.map((e) => ClubMemberModel.fromJson(e)).toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Get the current player's membership for a specific club + sport
  Future<ClubMemberModel?> getMyMembership(String clubId, String playerId, {String? sportId}) async {
    try {
      var query = _client
          .from('club_members')
          .select('*, player:players(full_name, nickname, avatar_url, email, phone), sport:sports(name, scoring_type)')
          .eq('club_id', clubId)
          .eq('player_id', playerId)
          .eq('status', 'active');
      if (sportId != null) {
        query = query.eq('sport_id', sportId);
      }
      final data = await query.maybeSingle();
      if (data == null) return null;
      return ClubMemberModel.fromJson(data);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Get pending join requests for a club
  Future<List<Map<String, dynamic>>> getJoinRequests(String clubId) async {
    try {
      final data = await _client
          .from('club_join_requests')
          .select('*, player:players!club_join_requests_player_id_fkey(full_name, avatar_url)')
          .eq('club_id', clubId)
          .eq('status', 'pending')
          .order('requested_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Approve a join request (with sport_ids to enroll)
  Future<void> approveJoinRequest(String requestId, String adminAuthId, {List<String>? sportIds}) async {
    try {
      await _client.rpc('approve_join_request', params: {
        'p_request_id': requestId,
        'p_admin_auth_id': adminAuthId,
        if (sportIds != null) 'p_sport_ids': sportIds,
      });
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Reject a join request
  Future<void> rejectJoinRequest(String requestId, String adminAuthId) async {
    try {
      await _client.rpc('reject_join_request', params: {
        'p_request_id': requestId,
        'p_admin_auth_id': adminAuthId,
      });
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Update member role (promote/demote)
  Future<void> updateMemberRole(String memberId, String role) async {
    try {
      await _client
          .from('club_members')
          .update({'role': role})
          .eq('id', memberId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Remove a member from the club (with ranking recompaction)
  Future<void> removeMember(String memberId, String adminAuthId) async {
    try {
      await _client.rpc('remove_club_member', params: {
        'p_member_id': memberId,
        'p_admin_auth_id': adminAuthId,
      });
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Update club details
  Future<void> updateClub(String clubId, {String? name, String? description}) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      await _client.from('clubs').update(updates).eq('id', clubId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Regenerate invite code
  Future<String> regenerateInviteCode(String clubId) async {
    try {
      final newCode = await _client.rpc('generate_invite_code');
      await _client
          .from('clubs')
          .update({'invite_code': newCode})
          .eq('id', clubId);
      return newCode as String;
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  // ─── Sports ───

  /// Get all active sports (for normal use)
  Future<List<SportModel>> getAllSports() async {
    try {
      final data = await _client
          .from('sports')
          .select()
          .eq('is_active', true)
          .order('display_order', ascending: true);
      return data.map((e) => SportModel.fromJson(e)).toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Get all sports including inactive (for admin)
  Future<List<SportModel>> getAllSportsAdmin() async {
    try {
      final data = await _client
          .from('sports')
          .select()
          .order('display_order', ascending: true);
      return data.map((e) => SportModel.fromJson(e)).toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Toggle sport active status
  Future<void> toggleSportActive(String sportId, bool isActive) async {
    try {
      await _client
          .from('sports')
          .update({'is_active': isActive})
          .eq('id', sportId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Get sports enabled for a club
  Future<List<ClubSportModel>> getClubSports(String clubId) async {
    try {
      final data = await _client
          .from('club_sports')
          .select('*, sport:sports(*)')
          .eq('club_id', clubId)
          .eq('is_active', true)
          .order('created_at', ascending: true);
      return data.map((e) => ClubSportModel.fromJson(e)).toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Add a sport to a club
  Future<void> addClubSport(String clubId, String sportId) async {
    try {
      await _client.from('club_sports').upsert({
        'club_id': clubId,
        'sport_id': sportId,
        'is_active': true,
      }, onConflict: 'club_id,sport_id');
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Remove (deactivate) a sport from a club
  Future<void> removeClubSport(String clubId, String sportId) async {
    try {
      await _client
          .from('club_sports')
          .update({'is_active': false})
          .eq('club_id', clubId)
          .eq('sport_id', sportId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Enroll a member in a sport
  Future<void> enrollMemberInSport({
    required String clubId,
    required String playerId,
    required String sportId,
  }) async {
    try {
      await _client.rpc('enroll_member_in_sport', params: {
        'p_club_id': clubId,
        'p_player_id': playerId,
        'p_sport_id': sportId,
      });
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Update rules for a club sport
  Future<void> updateClubSportRules({
    required String clubId,
    required String sportId,
    required bool ruleAmbulanceEnabled,
    required bool ruleCooldownEnabled,
    required bool rulePositionGapEnabled,
  }) async {
    try {
      await _client
          .from('club_sports')
          .update({
            'rule_ambulance_enabled': ruleAmbulanceEnabled,
            'rule_cooldown_enabled': ruleCooldownEnabled,
            'rule_position_gap_enabled': rulePositionGapEnabled,
          })
          .eq('club_id', clubId)
          .eq('sport_id', sportId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Get members of a club for a specific sport
  Future<List<ClubMemberModel>> getMembersBySport(String clubId, String sportId) async {
    try {
      final data = await _client
          .from('club_members')
          .select('*, player:players(full_name, nickname, avatar_url, email, phone), sport:sports(name, scoring_type)')
          .eq('club_id', clubId)
          .eq('sport_id', sportId)
          .eq('status', 'active')
          .order('ranking_position', ascending: true);
      return data.map((e) => ClubMemberModel.fromJson(e)).toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
