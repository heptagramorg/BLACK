// lib/services/forum_service.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../screens/forum_screen.dart'; // For ForumSortOption enum

class ForumService {
  final SupabaseClient _supabase = SupabaseService.client;
  final Map<String, Map<String, dynamic>> _userProfileCache = {};

  Future<Map<String, int>> getUserPostVotes(String userId) async {
    if (userId.isEmpty) return {};
    try {
      final data = await _supabase
          .from('post_votes')
          .select('post_id, vote_type')
          .eq('user_id', userId);

      return {
        for (var item in (data as List))
          (item['post_id'] as String): (item['vote_type'] as int? ?? 0)
      };
    } catch (e) {
      print("Error fetching user post votes: $e");
      return {};
    }
  }

  Future<Map<String, dynamic>> togglePostVote(String postId, String userId, int voteValue) async {
    if (userId.isEmpty) {
      return {'success': false, 'error': 'User not authenticated'};
    }
    try {
      final result = await _supabase.rpc(
        'toggle_post_vote', // This RPC remains for voting action
        params: {
          'post_uuid': postId,
          'voter_uuid': userId,
          'vote_value': voteValue,
        },
      );

      if (result is Map<String, dynamic>) {
        if (result['success'] == true) {
          return {
            'success': true,
            'new_upvotes': result['new_upvotes'] as int? ?? 0,
            'new_downvotes': result['new_downvotes'] as int? ?? 0,
          };
        } else {
          final errorMsg = result['error'] ?? 'Unknown RPC error while toggling vote.';
          return {'success': false, 'error': errorMsg};
        }
      } else {
        return {'success': false, 'error': 'Unexpected result from server (togglePostVote RPC). Found: ${result.runtimeType}'};
      }
    } catch (e) {
      print("Error calling toggle_post_vote RPC for post $postId: $e");
      if (e is PostgrestException) {
        return {'success': false, 'error': 'Database error: ${e.message}'};
      }
      return {'success': false, 'error': 'Network or unexpected error: ${e.toString()}'};
    }
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId, {bool useCache = true}) async {
    if (userId.isEmpty) return {"name": "Unknown User", "profile_picture": null};
    if (useCache && _userProfileCache.containsKey(userId)) {
      return _userProfileCache[userId]!;
    }
    try {
      final userData = await _supabase
          .from('profiles')
          .select('id, name, profile_picture')
          .eq('id', userId)
          .maybeSingle(); // Use maybeSingle to handle null gracefully

      if (userData != null) {
         _userProfileCache[userId] = userData;
         return userData;
      } else {
         final fallback = {"name": "Unknown User", "profile_picture": null, "error": true};
         _userProfileCache[userId] = fallback;
         return fallback;
      }
    } catch (e) {
      print("❌ ForumService: Error fetching user profile for $userId: $e");
      final fallback = {"name": "Unknown User", "profile_picture": null, "error": true};
      _userProfileCache[userId] = fallback;
      return fallback;
    }
  }

  // --- NEW RPC CALLING METHODS ---

  Future<List<Map<String, dynamic>>> getForumPosts({
    required ForumSortOption sortOption,
    required int pageNumber,
    required int pageSize,
  }) async {
    try {
      final result = await _supabase.rpc(
        'get_forum_posts_with_details',
        params: {
          'p_sort_option': sortOption == ForumSortOption.top ? 'top' : 'newest',
          'p_page_size': pageSize,
          'p_page_number': pageNumber,
        },
      );
      // The RPC returns a list of records directly (List<dynamic>)
      if (result is List) {
        return result.cast<Map<String, dynamic>>();
      } else {
        print('Unexpected result type from get_forum_posts_with_details RPC: ${result.runtimeType}');
        return []; // Or throw an error
      }
    } catch (e) {
      print('Error fetching forum posts via RPC: $e');
      // Consider rethrowing or returning an empty list with an error indicator
      if (e is PostgrestException) {
         print('PostgrestException details: ${e.message}, code: ${e.code}, details: ${e.details}');
      }
      return [];
    }
  }

  Future<Map<String, dynamic>?> getSinglePostDetails({required String postId}) async {
    try {
      final result = await _supabase.rpc(
        'get_single_post_details',
        params: {'p_post_id': postId},
      );
      // This RPC returns a list with a single item or an empty list
      if (result is List && result.isNotEmpty) {
        return result.first as Map<String, dynamic>;
      } else if (result is List && result.isEmpty) {
        return null; // Post not found
      } else {
         print('Unexpected result type from get_single_post_details RPC: ${result.runtimeType}');
         return null;
      }
    } catch (e) {
      print('Error fetching single post details via RPC: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getForumReplies({
    required String postId,
    required int pageNumber,
    required int pageSize,
  }) async {
    try {
      final result = await _supabase.rpc(
        'get_forum_replies_with_details',
        params: {
          'p_post_id': postId,
          'p_page_size': pageSize,
          'p_page_number': pageNumber,
        },
      );
      if (result is List) {
        return result.cast<Map<String, dynamic>>();
      } else {
         print('Unexpected result type from get_forum_replies_with_details RPC: ${result.runtimeType}');
         return [];
      }
    } catch (e) {
      print('Error fetching forum replies via RPC: $e');
      return [];
    }
  }
}