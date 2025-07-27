// lib/services/note_service.dart

import '../services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // For PostgrestException
import 'user_service.dart'; // Import UserService

class NotesService {
  final _supabase = SupabaseService.client;
  final UserService _userService = UserService(); // Instantiate UserService

  Future<void> uploadNote({
    required String userId,
    required String title,
    required String content,
    required List<String> tags,
    String? fileUrl,
    String? fileName,
    String? fileType,
    int? fileSize,
    bool isPublic = false,
  }) async {
    try {
      await _supabase.from('notes').insert({
        'user_id': userId,
        'title': title,
        'description': content,
        'content': content,
        'file_url': fileUrl ?? '',
        'file_name': fileName ?? '',
        'file_type': fileType ?? '',
        'file_size': fileSize ?? 0,
        'tags': tags,
        'is_public': isPublic,
        'created_at': DateTime.now().toIso8601String(),
        'view_count': 0,
        'like_count': 0,
      });
    } catch (e) {
      // Error is rethrown to be handled by the caller UI.
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchNotes() async {
    try {
      final data = await _supabase
          .from('notes')
          .select('*, profiles:user_id(*)')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      // In case of an error, return an empty list to prevent UI crashes.
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchUserNotes(String userId) async {
    try {
      final data = await _supabase
          .from('notes')
          .select('*, view_count, like_count, profiles:user_id(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchPublicNotes() async {
    try {
      final data = await _supabase
          .from('notes')
          .select(
              '*, view_count, like_count, profiles:user_id(id, name, username, profile_picture)')
          .eq('is_public', true)
          .not('file_url', 'is', null)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchAccessibleNotes(String userId) async {
    try {
      final data = await _supabase
          .from('notes')
          .select(
              '*, view_count, like_count, profiles:user_id(id, name, username, profile_picture)')
          .or('is_public.eq.true,user_id.eq.$userId')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchSavedNotes(String userId) async {
    try {
      final savedRefs =
          await _supabase.from('saved_notes').select('note_id').eq('user_id', userId);

      final savedList = savedRefs as List<dynamic>? ?? [];
      if (savedList.isEmpty) {
        return [];
      }

      final savedIds =
          savedList.map((item) => item['note_id'] as String).toList();

      if (savedIds.isEmpty) {
        return [];
      }

      final data = await _supabase
          .from('notes')
          .select(
              '*, view_count, like_count, profiles:user_id(id, name, username, profile_picture)')
          .filter('id', 'in', savedIds)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchNotes(
      String query, String userId) async {
    try {
      try {
        final data = await _supabase.rpc('search_notes',
            params: {'search_query': query, 'current_user_id': userId});
        return List<Map<String, dynamic>>.from(data ?? []);
      } catch (rpcError) {
        final ilikeQuery = '%${query.toLowerCase()}%';
        final data = await _supabase
            .from('notes')
            .select(
                '*, view_count, like_count, profiles:user_id(id, name, username, profile_picture)')
            .or('is_public.eq.true,user_id.eq.$userId')
            .or('title.ilike.$ilikeQuery,content.ilike.$ilikeQuery,tags.cs.{$query.toLowerCase()}')
            .order('created_at', ascending: false);

        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchNotesByMultipleTags(
      List<String> tags, String userId) async {
    if (tags.isEmpty) return [];
    final lowerCaseTags = tags.map((tag) => tag.toLowerCase()).toList();
    try {
      final data = await _supabase
          .from('notes')
          .select(
              '*, view_count, like_count, profiles:user_id(id, name, username, profile_picture)')
          .or('is_public.eq.true,user_id.eq.$userId')
          .contains('tags', lowerCaseTags)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchNotesByTag(
      String tag, String userId) async {
    try {
      final lowerCaseTag = tag.toLowerCase();
      final data = await _supabase
          .from('notes')
          .select(
              '*, view_count, like_count, profiles:user_id(id, name, username, profile_picture)')
          .or('is_public.eq.true,user_id.eq.$userId')
          .contains('tags', [lowerCaseTag])
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  Future<bool> deleteNote(String noteId) async {
    String? userId;
    int fileSize = 0;
    String? fileUrl;
    bool fileDeletedFromStorage = false;

    try {
      final note = await _supabase
          .from('notes')
          .select('user_id, file_url, file_size')
          .eq('id', noteId)
          .maybeSingle();

      if (note == null) {
        return false;
      }

      userId = note['user_id'] as String?;
      fileSize = note['file_size'] as int? ?? 0;
      fileUrl = note['file_url'] as String?;

      if (userId == null || userId.isEmpty) {
        return false;
      }

      await _supabase.from('note_likes').delete().eq('note_id', noteId);
      await _supabase.from('note_views').delete().eq('note_id', noteId);
      await _supabase.from('saved_notes').delete().eq('note_id', noteId);

      await _supabase.from('notes').delete().eq('id', noteId);

      if (fileUrl != null && fileUrl.isNotEmpty) {
        try {
          final Uri uri = Uri.parse(fileUrl);
          final String storagePath =
              uri.pathSegments.skipWhile((segment) => segment != 'notes').skip(1).join('/');

          if (storagePath.isNotEmpty) {
            await _supabase.storage.from('notes').remove([storagePath]);
            fileDeletedFromStorage = true;
          }
        } catch (storageError) {
          if (storageError is StorageException &&
              (storageError.statusCode == '404' ||
                  (storageError.message
                          ?.toLowerCase()
                          .contains("object not found") ??
                      false))) {
            fileDeletedFromStorage = true;
          }
        }
      } else {
        fileDeletedFromStorage = true;
      }

      if (fileDeletedFromStorage && fileSize > 0) {
        try {
          await _userService.decrementStorageUsage(userId, fileSize);
        } catch (rpcError) {
          // Log or handle the fact that storage might be inaccurate
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateNoteVisibility(String noteId, bool isPublic) async {
    try {
      await _supabase
          .from('notes')
          .update({'is_public': isPublic}).eq('id', noteId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> toggleSaveNote(
      String userId, String noteId, bool currentlySaved) async {
    try {
      if (currentlySaved) {
        await _supabase
            .from('saved_notes')
            .delete()
            .match({'user_id': userId, 'note_id': noteId});
      } else {
        await _supabase
            .from('saved_notes')
            .insert({'user_id': userId, 'note_id': noteId});
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isNoteSaved(String userId, String noteId) async {
    try {
      final data = await _supabase
          .from('saved_notes')
          .select('note_id')
          .eq('user_id', userId)
          .eq('note_id', noteId)
          .maybeSingle();

      return data != null;
    } catch (e) {
      return false;
    }
  }

  Future<Set<String>> getSavedNoteIds(String userId) async {
    try {
      final data =
          await _supabase.from('saved_notes').select('note_id').eq('user_id', userId);

      final list = data as List<dynamic>? ?? [];
      return list.map((item) => item['note_id'] as String).toSet();
    } catch (e) {
      return {};
    }
  }

  Future<int> cleanupStorageUsage(String userId) async {
    try {
      final notesData =
          await _supabase.from('notes').select('file_size').eq('user_id', userId);

      int totalCalculatedSize = 0;
      for (var note in notesData) {
        totalCalculatedSize += (note['file_size'] as int? ?? 0);
      }

      await _supabase
          .from('profiles')
          .update({'storage_used': totalCalculatedSize}).eq('id', userId);

      return totalCalculatedSize;
    } catch (e) {
      return -1;
    }
  }

  Future<Map<String, dynamic>?> getNoteById(String noteId) async {
    try {
      final note = await _supabase
          .from('notes')
          .select(
              '*, view_count, like_count, profiles:user_id(id, name, username, profile_picture)')
          .eq('id', noteId)
          .maybeSingle();

      return note;
    } catch (e) {
      return null;
    }
  }

  Future<List<String>> getPopularTags({int limit = 10}) async {
    try {
      final notesData = await _supabase
          .from('notes')
          .select('tags')
          .eq('is_public', true)
          .order('created_at', ascending: false)
          .limit(500);

      Map<String, int> tagCounts = {};
      for (var note in notesData) {
        if (note['tags'] != null && note['tags'] is List) {
          List<dynamic> noteTags = note['tags'];
          for (var tag in noteTags) {
            if (tag is String && tag.trim().isNotEmpty) {
              String normalizedTag = tag.trim().toLowerCase();
              if (normalizedTag.length > 2) {
                tagCounts[normalizedTag] = (tagCounts[normalizedTag] ?? 0) + 1;
              }
            }
          }
        }
      }

      var sortedTags = tagCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sortedTags.take(limit).map((e) => e.key).toList();
    } catch (e) {
      return [];
    }
  }

  /// **Fetch paginated notes for a specific user, respecting privacy**
  Future<List<Map<String, dynamic>>> fetchNotesForUserPaginated({
    required String profileUserId,
    required String requestingUserId,
    required int pageNumber,
    required int pageSize,
  }) async {
    try {
      final result = await _supabase.rpc(
        'get_user_notes_paginated', // Name of the RPC function you created
        params: {
          'p_profile_user_id': profileUserId,
          'p_requesting_user_id': requestingUserId,
          'p_page_number': pageNumber,
          'p_page_size': pageSize,
        },
      );
      if (result is List) {
        return result.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to parse notes from server.');
      }
    } catch (e) {
      if (e is PostgrestException) {
        // Specific database error handling can be done here
      }
      throw Exception('Failed to load notes: ${e.toString()}');
    }
  }
}
