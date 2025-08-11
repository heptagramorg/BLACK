import '../services/supabase_service.dart';

class FollowersService {
  final _supabase = SupabaseService.client;

  /// **Follow a user**
  Future<void> followUser(String currentUserId, String targetUserId) async {
    try {
      // Check if already following to prevent duplicates
      final existing = await _supabase
          .from('followers')
          .select()
          .eq('follower_id', currentUserId)
          .eq('followed_id', targetUserId)
          .maybeSingle();

      if (existing != null) {
        print("Already following this user");
        return;
      }

      // Insert the follow relationship
      await _supabase.from('followers').insert({
        'follower_id': currentUserId,
        'followed_id': targetUserId,
      });

      // The counts will be updated automatically by the database trigger
    } catch (e) {
      print("Error following user: $e");
      rethrow;
    }
  }

  /// **Unfollow a user**
  Future<void> unfollowUser(String currentUserId, String targetUserId) async {
    try {
      // Delete the follow relationship
      await _supabase
          .from('followers')
          .delete()
          .eq('follower_id', currentUserId)
          .eq('followed_id', targetUserId);

      // The counts will be updated automatically by the database trigger
    } catch (e) {
      print("Error unfollowing user: $e");
      rethrow;
    }
  }

  /// **Check if the user is following another user**
  Future<bool> isFollowing(String currentUserId, String targetUserId) async {
    try {
      final result = await _supabase
          .from('followers')
          .select()
          .eq('follower_id', currentUserId)
          .eq('followed_id', targetUserId)
          .maybeSingle();

      return result != null;
    } catch (e) {
      print("Error checking follow status: $e");
      return false;
    }
  }

  /// **Get followers count** - This method counts the followers directly
  Future<int> getFollowersCount(String userId) async {
    try {
      // Get the list of followers
      final followers = await _supabase
          .from('followers')
          .select('follower_id')
          .eq('followed_id', userId);

      // Return the length of the list
      return (followers as List).length;
    } catch (e) {
      print("Error getting followers count: $e");
      return 0;
    }
  }

  /// **Get following count** - This method counts the following directly
  Future<int> getFollowingCount(String userId) async {
    try {
      // Get the list of users that this user follows
      final following = await _supabase
          .from('followers')
          .select('followed_id')
          .eq('follower_id', userId);

      // Return the length of the list
      return (following as List).length;
    } catch (e) {
      print("Error getting following count: $e");
      return 0;
    }
  }

  /// **Get followers list**
  Future<List<Map<String, dynamic>>> getFollowers(String userId) async {
    try {
      // Get users who follow the current user (their follower_id)
      final result = await _supabase
          .from('followers')
          .select('follower_id')
          .eq('followed_id', userId);

      // Extract the follower IDs
      final followerIds = (result as List)
          .map((item) => item['follower_id'] as String)
          .toList();

      if (followerIds.isEmpty) {
        return [];
      }

      // Get the profiles for these users using filter instead of in_
      final List<Map<String, dynamic>> profiles = [];

      for (final id in followerIds) {
        final userProfile = await _supabase
            .from('profiles')
            .select()
            .eq('id', id)
            .maybeSingle();

        if (userProfile != null) {
          profiles.add(Map<String, dynamic>.from(userProfile));
        }
      }

      return profiles;
    } catch (e) {
      print("Error fetching followers: $e");
      return [];
    }
  }

  /// **Get following list**
  Future<List<Map<String, dynamic>>> getFollowing(String userId) async {
    try {
      // Get users whom the current user follows (their followed_id)
      final result = await _supabase
          .from('followers')
          .select('followed_id')
          .eq('follower_id', userId);

      // Extract the following IDs
      final followingIds = (result as List)
          .map((item) => item['followed_id'] as String)
          .toList();

      if (followingIds.isEmpty) {
        return [];
      }

      // Get the profiles for these users using filter instead of in_
      final List<Map<String, dynamic>> profiles = [];

      for (final id in followingIds) {
        final userProfile = await _supabase
            .from('profiles')
            .select()
            .eq('id', id)
            .maybeSingle();

        if (userProfile != null) {
          profiles.add(Map<String, dynamic>.from(userProfile));
        }
      }

      return profiles;
    } catch (e) {
      print("Error fetching following: $e");
      return [];
    }
  }
}
