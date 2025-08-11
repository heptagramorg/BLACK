import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class NoteEngagementService {
  final SupabaseClient _supabase;

  NoteEngagementService({SupabaseClient? supabase})
      : _supabase = supabase ?? SupabaseService.client;

  Future<Map<String, dynamic>> toggleNoteLike(
      String noteId, String userId) async {
    if (userId.isEmpty) {
      return {'success': false, 'error': 'User not authenticated'};
    }

    try {
      final result = await _supabase.rpc(
        'toggle_note_like',
        params: {
          'note_uuid': noteId,
          'liker_uuid': userId,
        },
      );

      if (result is Map<String, dynamic> && result['success'] == true) {
        return {
          'success': true,
          'newLikeCount': result['newLikeCount'] as int? ?? 0,
          'isLiked': result['isLiked'] as bool? ?? false,
        };
      } else {
        final errorMessage = result?['error'] ?? 'Unknown RPC error';
        return {
          'success': false,
          'error': errorMessage,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'An unexpected exception occurred: $e',
      };
    }
  }

  Future<bool> recordNoteView(String noteId, String userId) async {
    try {
      final noteData = await _supabase
          .from('notes')
          .select('user_id')
          .eq('id', noteId)
          .maybeSingle();

      if (noteData == null || noteData['user_id'] == userId) {
        return false;
      }

      await _supabase.rpc(
        'record_note_view',
        params: {
          'note_uuid': noteId,
          'viewer_uuid': userId,
        },
      );
      return true;
    } on PostgrestException catch (e) {
      if (e.code != '23505') {
        // Handle specific PostgreSQL error codes if needed
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<Set<String>> getLikedNoteIds(String userId) async {
    if (userId.isEmpty) return <String>{};

    try {
      final data = await _supabase
          .from('note_likes')
          .select('note_id')
          .eq('user_id', userId);

      return data.map((item) => item['note_id'] as String).toSet();
    } catch (e) {
      return <String>{};
    }
  }

  Future<Map<String, dynamic>?> getNoteWithEngagement(String noteId) async {
    try {
      if (noteId.isEmpty) return null;

      final noteData = await _supabase
          .from('notes')
          .select('*, view_count, like_count, profiles:user_id(*)')
          .eq('id', noteId)
          .maybeSingle();

      return noteData;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> getUserPayoutStatus(String userId) async {
    const int noteCountTarget = 20;
    const int viewsTarget = 1000;

    const errorResponse = {
      'noteCount': 0,
      'totalViews': 0,
      'isEligibleForPayout': false,
      'noteCountProgress': 0.0,
      'viewsProgress': 0.0,
      'noteCountTarget': noteCountTarget,
      'viewsTarget': viewsTarget,
    };

    if (userId.isEmpty) {
      return errorResponse;
    }

    try {
      final notesData = await _supabase
          .from('notes')
          .select('view_count')
          .eq('user_id', userId);

      int noteCount = notesData.length;
      int totalViews = notesData.fold(
          0, (sum, note) => sum + (note['view_count'] as int? ?? 0));

      final bool isEligibleForPayout =
          noteCount >= noteCountTarget && totalViews >= viewsTarget;

      final double noteCountProgress =
          (noteCount / noteCountTarget * 100).clamp(0.0, 100.0);
      final double viewsProgress =
          (totalViews / viewsTarget * 100).clamp(0.0, 100.0);

      return {
        'noteCount': noteCount,
        'totalViews': totalViews,
        'isEligibleForPayout': isEligibleForPayout,
        'noteCountProgress': noteCountProgress,
        'viewsProgress': viewsProgress,
        'noteCountTarget': noteCountTarget,
        'viewsTarget': viewsTarget,
      };
    } catch (e) {
      return errorResponse;
    }
  }
}
