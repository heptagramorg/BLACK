import '../services/supabase_service.dart';

class SearchService {
  final _supabase = SupabaseService.client;

  /// **Search notes by tags, title, or content**
  Future<List<Map<String, dynamic>>> searchNotes(
      String query, String userId) async {
    try {
      // First approach: Use Supabase's built-in text search (this might not be working)
      try {
        final data = await _supabase.rpc('search_notes',
            params: {'search_query': query, 'current_user_id': userId});

        return List<Map<String, dynamic>>.from(data);
      } catch (e) {
        print("RPC search failed, using fallback method: $e");

        // Fallback approach: Use ILIKE for case-insensitive pattern matching
        // First get public notes with matching content
        final publicNotesData = await _supabase
            .from('notes')
            .select('*, profiles:user_id(*)')
            .eq('is_public', true)
            .or('title.ilike.%${query}%,content.ilike.%${query}%')
            .order('created_at', ascending: false);

        // Then get user's own notes with matching content
        final userNotesData = await _supabase
            .from('notes')
            .select('*, profiles:user_id(*)')
            .eq('user_id', userId)
            .or('title.ilike.%${query}%,content.ilike.%${query}%')
            .order('created_at', ascending: false);

        // Also search notes with matching tags using contains operator
        final tagNotesData = await _supabase
            .from('notes')
            .select('*, profiles:user_id(*)')
            .or('is_public.eq.true,user_id.eq.$userId')
            .filter('tags', 'cs', '{$query}')
            .order('created_at', ascending: false);

        // Combine results and remove duplicates
        final Map<String, Map<String, dynamic>> uniqueNotes = {};

        for (var note in [
          ...List<Map<String, dynamic>>.from(publicNotesData),
          ...List<Map<String, dynamic>>.from(userNotesData),
          ...List<Map<String, dynamic>>.from(tagNotesData)
        ]) {
          uniqueNotes[note['id']] = note;
        }

        return uniqueNotes.values.toList();
      }
    } catch (e) {
      print("Error searching notes: $e");
      return [];
    }
  }

  /// **Search users by username or name**
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .or('username.ilike.%${query}%,name.ilike.%${query}%')
          .order('username');

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print("Error searching users: $e");
      return [];
    }
  }

  /// **Search notes by tag**
  Future<List<Map<String, dynamic>>> searchNotesByTag(
      String tag, String userId) async {
    try {
      // First get public notes with this tag
      final publicNotesData = await _supabase
          .from('notes')
          .select('*, profiles:user_id(*)')
          .eq('is_public', true)
          .filter('tags', 'cs', '{$tag}')
          .order('created_at', ascending: false);

      // Then get user's own notes with this tag
      final userNotesData = await _supabase
          .from('notes')
          .select('*, profiles:user_id(*)')
          .eq('user_id', userId)
          .filter('tags', 'cs', '{$tag}')
          .order('created_at', ascending: false);

      // Combine results and remove duplicates
      final Map<String, Map<String, dynamic>> uniqueNotes = {};

      for (var note in [
        ...List<Map<String, dynamic>>.from(publicNotesData),
        ...List<Map<String, dynamic>>.from(userNotesData)
      ]) {
        uniqueNotes[note['id']] = note;
      }

      return uniqueNotes.values.toList();
    } catch (e) {
      print("Error searching notes by tag: $e");
      return [];
    }
  }

  /// **Get popular tags**
  Future<List<String>> getPopularTags() async {
    try {
      try {
        // This would ideally be an RPC function in Supabase
        final data = await _supabase.rpc('get_popular_tags', params: {});

        return List<String>.from(data);
      } catch (e) {
        print("RPC for popular tags failed, using fallback method: $e");

        // Fallback approach
        final notesData =
            await _supabase.from('notes').select('tags').limit(100);

        // Count tag occurrences
        Map<String, int> tagCounts = {};
        for (var note in notesData) {
          if (note['tags'] != null) {
            List<dynamic> noteTags = note['tags'];
            for (var tag in noteTags) {
              if (tag is String) {
                tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
              }
            }
          }
        }

        // Sort tags by count
        var sortedTags = tagCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return sortedTags.take(10).map((e) => e.key).toList();
      }
    } catch (e) {
      print("Error getting popular tags: $e");
      return [];
    }
  }
}
