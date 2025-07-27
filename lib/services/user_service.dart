// lib/services/user_service.dart

import '../services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Added for PostgrestException

class UserService {
  final _supabase = SupabaseService.client;

  /// **Fetch user profile from Supabase**
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final profile = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      return profile;
    } catch (e) {
      print("Error fetching user profile: $e");
      return null;
    }
  }

  /// **Update user profile in Supabase**
  Future<void> updateProfile(String userId, Map<String, dynamic> data) async {
    try {
      // Remove last_updated field if it exists to avoid updating it manually
      data.remove('last_updated');

      await _supabase
          .from('profiles')
          .update(data)
          .eq('id', userId);
    } catch (e) {
      print("Error updating profile: $e");
      rethrow; // Rethrow to allow caller to handle
    }
  }

  /// **Get user's storage usage**
  Future<int> getUserStorageUsage(String userId) async {
    try {
      final profile = await _supabase
          .from('profiles')
          .select('storage_used')
          .eq('id', userId)
          .single();

      return profile['storage_used'] ?? 0;
    } catch (e) {
      print("Error fetching storage usage: $e");
      return 0;
    }
  }

  /// **Increment user's storage usage using RPC for atomicity**
  Future<void> incrementStorageUsage(String userId, int bytes) async {
    if (userId.isEmpty || bytes <= 0) {
      print("Skipping storage increment: Invalid userId or bytes <= 0");
      return;
    }
    try {
      // Call the Supabase RPC function 'increment_storage'
      await _supabase.rpc('increment_storage', params: {
        'user_uuid': userId, // Ensure parameter name matches RPC function
        'bytes_to_add': bytes, // Ensure parameter name matches RPC function
      });
      print("Successfully called increment_storage RPC for user $userId, adding $bytes bytes.");
    } catch (e) {
      print("Error calling increment_storage RPC for user $userId: $e");
      // Consider rethrowing or specific error handling
      rethrow;
    }
  }

  /// **Decrement user's storage usage using RPC for atomicity**
  Future<void> decrementStorageUsage(String userId, int bytes) async {
    if (userId.isEmpty || bytes <= 0) {
      print("Skipping storage decrement: Invalid userId or bytes <= 0");
      return;
    }
    try {
      // Call the Supabase RPC function 'decrement_storage'
      await _supabase.rpc('decrement_storage', params: {
        'user_uuid': userId, // Ensure parameter name matches RPC function
        'bytes_to_subtract': bytes, // Ensure parameter name matches RPC function
      });
      print("Successfully called decrement_storage RPC for user $userId, subtracting $bytes bytes.");
    } catch (e) {
      print("Error calling decrement_storage RPC for user $userId: $e");
      // Consider rethrowing or specific error handling
      rethrow;
    }
  }

  /// **Check if username is taken**
  Future<bool> isUsernameTaken(String username, {String? excludeUserId}) async {
    try {
      var query = _supabase
          .from('profiles')
          .select('username')
          .eq('username', username);

      if (excludeUserId != null) {
        query = query.neq('id', excludeUserId);
      }

      final result = await query.maybeSingle();

      return result != null;
    } catch (e) {
      print("Error checking username: $e");
      return false; // Assume not taken on error? Or handle differently?
    }
  }

  /// **Get user role**
  Future<String> getUserRole(String userId) async {
    try {
      final profile = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();

      return profile['role'] ?? 'User'; // Default role
    } catch (e) {
      print("Error fetching user role: $e");
      return 'User'; // Default role on error
    }
  }

  /// **Search users**
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .or('name.ilike.%$query%,username.ilike.%$query%') // Corrected ilike syntax
          .order('username');

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print("Error searching users: $e");
      return [];
    }
  }

  // --- NEW METHOD TO CALL THE get_profile_screen_data RPC ---
  /// **Fetch combined profile data for the profile screen**
  Future<Map<String, dynamic>?> getProfileScreenData({
    required String profileUserId,
    required String requestingUserId,
  }) async {
    try {
      final result = await _supabase.rpc(
        'get_profile_screen_data', // Name of the RPC function created in Supabase
        params: {
          'p_profile_user_id': profileUserId,
          'p_requesting_user_id': requestingUserId,
        },
      );
      // The RPC is designed to return a single JSON object
      if (result is Map<String, dynamic>) {
          // Check for an error field within the JSON response from the RPC
          if (result['error'] != null) {
              print("Error from get_profile_screen_data RPC: ${result['error']}");
              // Return the map containing the error message for the UI to handle
              return {'error_message': result['error']};
          }
        return result; // This map contains 'profile', 'followers_count', etc.
      } else {
         print('Unexpected result type from get_profile_screen_data RPC: ${result.runtimeType}. Expected Map<String, dynamic>.');
         // You might want to throw a more specific error or return a structured error map
         throw Exception('Failed to parse profile data from server.');
      }
    } catch (e) {
      print('Error calling getProfileScreenData RPC: $e');
      if (e is PostgrestException) {
        print('PostgrestException details: ${e.message}, code: ${e.code}, details: ${e.details}');
      }
      // Rethrow so the UI can handle it, or return a structured error
      throw Exception('Failed to load profile data: ${e.toString()}');
    }
  }
}