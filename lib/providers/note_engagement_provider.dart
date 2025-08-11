import 'package:flutter/material.dart';
import '../services/note_engagement_service.dart';

class NoteEngagementProvider extends ChangeNotifier {
  final NoteEngagementService _engagementService = NoteEngagementService();

  // State variables
  Set<String> _likedNoteIds =
      {}; // Stores IDs of notes liked by the current user
  Map<String, int> _likeCounts = {}; // Stores like counts for notes viewed
  Map<String, int> _viewCounts = {}; // Stores view counts for notes viewed
  Map<String, bool> _processingNotes = {}; // Tracks notes being liked/unliked

  bool _isLoading = true;
  bool get isLoading => _isLoading;
  String _userId = '';

  // --- Getters for UI ---
  int getLikeCount(String noteId) => _likeCounts[noteId] ?? 0;
  int getViewCount(String noteId) => _viewCounts[noteId] ?? 0;
  bool isNoteLiked(String noteId) => _likedNoteIds.contains(noteId);
  bool isNoteProcessing(String noteId) => _processingNotes[noteId] ?? false;

  // --- Initialization ---
  Future<void> initialize(String userId) async {
    if (userId.isEmpty || _userId == userId)
      return; // Avoid re-initialization for same user

    _userId = userId;
    _isLoading = true;
    notifyListeners();

    try {
      // Load initial liked notes for the current user
      _likedNoteIds = await _engagementService.getLikedNoteIds(_userId);
      _isLoading = false;
    } catch (e) {
      // Error initializing
      _isLoading = false; // Ensure loading state is reset on error
    } finally {
      if (mounted) {
        // Check if provider is still mounted
        notifyListeners();
      }
    }
  }

  bool mounted = true; // Add this flag

  @override
  void dispose() {
    mounted = false; // Set flag to false when disposed
    super.dispose();
  }

  // --- Update Local State ---
  /// Updates the local state with data fetched from the service (e.g., when viewing notes)
  void updateNoteData(String noteId, int viewCount, int likeCount) {
    if (!mounted) return;
    bool changed = false;
    if (_viewCounts[noteId] != viewCount) {
      _viewCounts[noteId] = viewCount;
      changed = true;
    }
    if (_likeCounts[noteId] != likeCount) {
      _likeCounts[noteId] = likeCount;
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  // --- Actions ---

  /// Records a view. Called when a note's file is opened.
  Future<bool> recordNoteView(String noteId) async {
    if (_userId.isEmpty) return false; // Need a logged-in user

    // Call the service to record the view (backend handles uniqueness)
    final bool viewRecorded =
        await _engagementService.recordNoteView(noteId, _userId);

    // If the view was newly recorded, refresh data to show updated count
    if (viewRecorded && mounted) {
      await refreshNoteData(noteId); // Fetch updated counts
      return true;
    }
    return false; // View was not newly recorded or user is owner
  }

  /// Toggles the like status of a note.
  Future<bool> toggleNoteLike(String noteId) async {
    if (_userId.isEmpty || isNoteProcessing(noteId)) {
      if (_userId.isEmpty) print("User ID is empty");

      print('User ID is empty or note is already being processed.');
      return false; // Need user, avoid double taps
    }

    if (!mounted) return false; // Check if mounted

    print("Toggling like for note: $noteId by user: $_userId");

    // Indicate processing
    _processingNotes[noteId] = true;
    notifyListeners();

    bool currentLikeStatus =
        isNoteLiked(noteId); // Store current status before call

    try {
      // Call the service which calls the Supabase function
      final result = await _engagementService.toggleNoteLike(noteId, _userId);

      if (!mounted) return false; // Check again after async operation

      if (result['success'] == true) {
        // Update local state based on the result from the backend function
        final bool newIsLiked = result['isLiked'] ?? !currentLikeStatus;
        final int newLikeCount = result['newLikeCount'] ??
            (_likeCounts[noteId] ?? 0) + (newIsLiked ? 1 : -1);

        if (newIsLiked) {
          _likedNoteIds.add(noteId);
        } else {
          _likedNoteIds.remove(noteId);
        }
        _likeCounts[noteId] =
            newLikeCount < 0 ? 0 : newLikeCount; // Ensure count isn't negative

        return true; // Indicate success
      } else {
        // Handle error reported by the service/function
        return false; // Indicate failure
      }
    } catch (e) {
      print('Error toggling like for note $noteId: $e');
      if (!mounted) return false; // Check again
      return false; // Indicate failure
    } finally {
      if (mounted) {
        // Check again
        // Stop indicating processing
        _processingNotes[noteId] = false;
        notifyListeners();
      }
    }
  }

  /// Refreshes the engagement data (counts) for a specific note.
  Future<void> refreshNoteData(String noteId) async {
    if (!mounted) return; // Check if mounted
    try {
      final noteData = await _engagementService.getNoteWithEngagement(noteId);
      if (noteData != null && mounted) {
        // Check again
        updateNoteData(
          noteId,
          noteData['view_count'] as int? ?? 0,
          noteData['like_count'] as int? ?? 0,
        );
      }
    } catch (e) {
      if (!mounted) return; // Check again
    }
  }

  /// Clears all engagement data (e.g., on sign out).
  void clear() {
    if (!mounted) return;
    _likedNoteIds = {};
    _likeCounts = {};
    _viewCounts = {};
    _processingNotes = {};
    _userId = '';
    _isLoading = true; // Reset loading state
    notifyListeners();
  }
}
