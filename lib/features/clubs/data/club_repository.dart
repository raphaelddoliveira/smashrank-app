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

  /// Get members of a club (with player data), including suspended
  Future<List<ClubMemberModel>> getMembers(String clubId) async {
    try {
      final data = await _client
          .from('club_members')
          .select('*, player:players(full_name, nickname, avatar_url, email, phone)')
          .eq('club_id', clubId)
          .inFilter('status', ['active', 'inactive'])
          .order('status', ascending: true)
          .order('ranking_position', ascending: true);
      return data.map((e) => ClubMemberModel.fromJson(e)).toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Get members paginated (for infinite scroll)
  Future<List<ClubMemberModel>> getMembersPaginated(
    String clubId, {
    required int offset,
    required int limit,
    String? search,
  }) async {
    try {
      var query = _client
          .from('club_members')
          .select('*, player:players!inner(full_name, nickname, avatar_url, email, phone)')
          .eq('club_id', clubId)
          .inFilter('status', ['active', 'inactive']);

      if (search != null && search.isNotEmpty) {
        query = query.or('full_name.ilike.%$search%,nickname.ilike.%$search%', referencedTable: 'players');
      }

      final data = await query
          .order('status', ascending: true)
          .range(offset, offset + limit - 1);
      return data.map((e) => ClubMemberModel.fromJson(e)).toList();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Admin toggle ranking participation for a member
  Future<void> adminToggleRanking({
    required String memberId,
    required String adminAuthId,
    required bool optIn,
  }) async {
    try {
      await _client.rpc('admin_toggle_ranking_participation', params: {
        'p_admin_auth_id': adminAuthId,
        'p_member_id': memberId,
        'p_opt_in': optIn,
      });
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
        'p_sport_ids': sportIds,
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

  /// Update member role (promote/demote) — updates ALL sport rows for this player
  Future<void> updateMemberRole(String memberId, String role) async {
    try {
      // Get club_id and player_id from the member row
      final member = await _client
          .from('club_members')
          .select('club_id, player_id')
          .eq('id', memberId)
          .single();
      // Update ALL rows for this player in this club (all sports)
      await _client
          .from('club_members')
          .update({'role': role})
          .eq('club_id', member['club_id'])
          .eq('player_id', member['player_id']);
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

  /// Suspend a member (set status to inactive)
  Future<void> suspendMember(String memberId) async {
    try {
      // Get member info for notification
      final member = await _client
          .from('club_members')
          .select('player_id, club_id')
          .eq('id', memberId)
          .single();

      await _client
          .from('club_members')
          .update({'status': 'inactive'})
          .eq('id', memberId);

      // Notify the member
      final clubData = await _client
          .from('clubs')
          .select('name')
          .eq('id', member['club_id'])
          .single();

      await _client.from('notifications').insert({
        'player_id': member['player_id'],
        'type': 'general',
        'title': 'Conta Suspensa',
        'body': 'Sua conta no clube ${clubData['name']} foi suspensa pelo administrador. Entre em contato para regularizar.',
        'data': {'club_id': member['club_id']},
        'club_id': member['club_id'],
      });
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Unsuspend (reactivate) a member
  Future<void> unsuspendMember(String memberId) async {
    try {
      final member = await _client
          .from('club_members')
          .select('player_id, club_id')
          .eq('id', memberId)
          .single();

      await _client
          .from('club_members')
          .update({'status': 'active'})
          .eq('id', memberId);

      final clubData = await _client
          .from('clubs')
          .select('name')
          .eq('id', member['club_id'])
          .single();

      await _client.from('notifications').insert({
        'player_id': member['player_id'],
        'type': 'general',
        'title': 'Conta Reativada',
        'body': 'Sua conta no clube ${clubData['name']} foi reativada. Você já pode voltar a jogar!',
        'data': {'club_id': member['club_id']},
        'club_id': member['club_id'],
      });
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  /// Update club details
  Future<void> updateClub(
    String clubId, {
    String? name,
    String? description,
    String? phone,
    String? email,
    String? website,
    String? coverUrl,
    String? avatarUrl,
    String? addressStreet,
    String? addressNumber,
    String? addressComplement,
    String? addressNeighborhood,
    String? addressCity,
    String? addressState,
    String? addressZip,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (phone != null) updates['phone'] = phone;
      if (email != null) updates['email'] = email;
      if (website != null) updates['website'] = website;
      if (coverUrl != null) updates['cover_url'] = coverUrl;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      if (addressStreet != null) updates['address_street'] = addressStreet;
      if (addressNumber != null) updates['address_number'] = addressNumber;
      if (addressComplement != null) updates['address_complement'] = addressComplement;
      if (addressNeighborhood != null) updates['address_neighborhood'] = addressNeighborhood;
      if (addressCity != null) updates['address_city'] = addressCity;
      if (addressState != null) updates['address_state'] = addressState;
      if (addressZip != null) updates['address_zip'] = addressZip;
      if (updates.isNotEmpty) {
        await _client.from('clubs').update(updates).eq('id', clubId);
      }
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
    required bool ruleResultDelayEnabled,
  }) async {
    try {
      await _client
          .from('club_sports')
          .update({
            'rule_ambulance_enabled': ruleAmbulanceEnabled,
            'rule_cooldown_enabled': ruleCooldownEnabled,
            'rule_position_gap_enabled': rulePositionGapEnabled,
            'rule_result_delay_enabled': ruleResultDelayEnabled,
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
