// lib/screens/view_notes_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../services/note_service.dart';
import '../providers/note_engagement_provider.dart';
import '../utils/secure_file_handler.dart';
import '../widgets/native_ad_widget.dart'; // Import the ad widget

// The hardcoded Ad Unit ID has been removed from here.
// It will now be loaded from your .env file using the key 'ADMOB_NATIVE_AD_VIEW_NOTES'.
const bool USE_TEST_ADS_VIEW_NOTES = false; // Set to false for production

class ViewNotesScreen extends StatefulWidget {
  final String userId;
  const ViewNotesScreen({super.key, required this.userId});
  @override
  State<ViewNotesScreen> createState() => _ViewNotesScreenState();
}

class _ViewNotesScreenState extends State<ViewNotesScreen> {
  final NotesService _notesService = NotesService();
  List<Map<String, dynamic>> _notes = [];
  bool _isLoading = true;
  String _selectedFilter = "All Notes";
  final List<String> _filters = ["All Notes", "My Notes", "Saved Notes", "Public Notes"];
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  String _errorMessage = "";
  Set<String> _savedNoteIds = {};
  Map<String, bool> _processingNotes = {};
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadSavedNotes();
    await _fetchNotes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSavedNotes() async {
    if (!mounted) return;
    try {
      final savedIds = await _notesService.getSavedNoteIds(widget.userId);
      if (mounted) { _savedNoteIds = savedIds; }
    } catch (e) {
      print("❌ ViewNotesScreen: Error loading saved notes: $e");
    }
  }

  Future<void> _fetchNotes() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = ""; });
    try {
      List<Map<String, dynamic>> fetchedNotes = [];
      if (_selectedFilter == "My Notes") { fetchedNotes = await _notesService.fetchUserNotes(widget.userId); }
      else if (_selectedFilter == "Saved Notes") { fetchedNotes = await _notesService.fetchSavedNotes(widget.userId); }
      else if (_selectedFilter == "Public Notes") { fetchedNotes = await _notesService.fetchPublicNotes(); }
      else { fetchedNotes = await _notesService.fetchAccessibleNotes(widget.userId); }

      if (_searchQuery.isNotEmpty) {
        final lowerCaseQuery = _searchQuery.toLowerCase();
        fetchedNotes = fetchedNotes.where((note) {
          final title = (note['title'] ?? '').toString().toLowerCase();
          final content = (note['content'] ?? '').toString().toLowerCase();
          List<dynamic> tags = note['tags'] is List ? note['tags'] : [];
          final tagStrings = tags.map((tag) => tag.toString().toLowerCase()).toList();
          return title.contains(lowerCaseQuery) || content.contains(lowerCaseQuery) || tagStrings.any((tag) => tag.contains(lowerCaseQuery));
        }).toList();
      }
      if (mounted) {
         final engagementProvider = Provider.of<NoteEngagementProvider>(context, listen: false);
         for (var note in fetchedNotes) {
           final noteId = note['id']?.toString() ?? '';
           if (noteId.isNotEmpty) {
             engagementProvider.updateNoteData( noteId, note['view_count'] as int? ?? 0, note['like_count'] as int? ?? 0 );
             note['is_saved'] = _savedNoteIds.contains(noteId);
           }
         }
         setState(() { _notes = fetchedNotes;});
       }
    } catch (e) {
      print("❌ ViewNotesScreen: Error fetching notes: $e");
      if (mounted) { setState(() { _errorMessage = "Error loading notes. Please try again."; }); }
    } finally {
      if (mounted) { setState(() { _isLoading = false; });}
    }
  }

  Future<void> _toggleSaveNote(String noteId, bool currentlySaved) async {
    if (!mounted) return;
    // Use the most up-to-date status from the state set
    final bool isCurrentlySavedInState = _savedNoteIds.contains(noteId);
    try {
      final success = await _notesService.toggleSaveNote(widget.userId, noteId, isCurrentlySavedInState);
      if (success && mounted) {
        setState(() {
          if (isCurrentlySavedInState) {
            _savedNoteIds.remove(noteId);
          } else {
            _savedNoteIds.add(noteId);
          }
          // Update the specific note in the list to reflect the change immediately
          for (var note in _notes) {
            if (note['id'] == noteId) {
              note['is_saved'] = !isCurrentlySavedInState;
              break;
            }
          }
        });
        _showMessage(isCurrentlySavedInState ? "Note removed from saved" : "Note saved successfully", isError: false);
        // If user is in "Saved Notes" filter, refetch the list after unsaving
        if (_selectedFilter == "Saved Notes" && isCurrentlySavedInState) {
          _fetchNotes();
        }
      } else if (mounted) {
        _showMessage("Failed to update saved status", isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showMessage("Failed to update saved status: $e", isError: true);
      }
    }
  }


  Future<void> _toggleNoteLike(String noteId) async {
    if (!mounted) return;
    final engagementProvider = Provider.of<NoteEngagementProvider>(context, listen: false);
    if (engagementProvider.isNoteProcessing(noteId)) return;
    final success = await engagementProvider.toggleNoteLike(noteId);
    if (success && mounted) { _showMessage(engagementProvider.isNoteLiked(noteId) ? "Note liked" : "Note unliked", isError: false); }
    else if (mounted) { _showMessage("Failed to update like status", isError: true); }
  }

  Future<void> _toggleNoteVisibility(String noteId, bool currentlyPublic) async {
    if (!mounted) return;
    try {
      final success = await _notesService.updateNoteVisibility(noteId, !currentlyPublic);
      if (success && mounted) {
        setState(() { for (var note in _notes) { if (note['id'] == noteId) { note['is_public'] = !currentlyPublic; break; } } });
        _showMessage(currentlyPublic ? "Note is now private" : "Note is now public", isError: false);
         if(_selectedFilter == "Public Notes" && currentlyPublic) _fetchNotes();
         if(_selectedFilter == "My Notes" && !currentlyPublic) _fetchNotes();
      } else if (mounted) { _showMessage("Failed to update note visibility", isError: true); }
    } catch (e) { if (mounted) { _showMessage("Failed to update note visibility: $e", isError: true); }}
  }

  void _openFile(Map<String, dynamic> note) async {
    if (!mounted) return;
    final String noteId = note['id'] as String? ?? '';
    final String fileUrl = note['file_url'] as String? ?? '';
    final String fileName = note['file_name'] as String? ?? 'document';
    final String fileType = note['file_type'] as String? ?? '';
    if (_processingNotes[noteId] == true) return;
    if (fileUrl.isNotEmpty && noteId.isNotEmpty) {
      setState(() => _processingNotes[noteId] = true);
      try {
        // File viewing and logging is handled by SecureFileHandler and SecureFileViewer
        await SecureFileHandler.openFile( context, fileUrl, fileName, fileType, noteId, widget.userId );
      } catch (e) {
        print("❌ ViewNotesScreen: Error opening file: $e");
        if (mounted) _showMessage("Error opening file: $e", isError: true);
      } finally { Future.delayed(const Duration(seconds: 1), () { if (mounted) setState(() => _processingNotes[noteId] = false); }); }
    } else { _showMessage("Note ID or File URL is missing.", isError: true); }
  }

  void _shareNoteText(String title, String content) {
    try { Share.share('$title\n\n$content', subject: title); }
    catch (e) { _showMessage("Could not share content: $e", isError: true); }
  }

  void _showMessage(String message, {bool isError = false, Duration? duration}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar( SnackBar( content: Text(message), backgroundColor: isError ? Theme.of(context).colorScheme.error : Colors.green.shade600, duration: duration ?? Duration(seconds: isError ? 4 : 2), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)), margin: const EdgeInsets.all(10.0)));
  }

  IconData _getFileIcon(String fileType) {
    fileType = fileType.toLowerCase();
    if (fileType.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (fileType.contains('doc')) return Icons.description_rounded;
    if (fileType.contains('ppt')) return Icons.slideshow_rounded;
    if (fileType.contains('xls')) return Icons.table_chart_rounded;
    if (fileType.contains('image')) return Icons.image_rounded;
    return Icons.insert_drive_file_rounded;
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  void _showNoteDetailsBottomSheet(Map<String, dynamic> note) {
     final String noteId = note['id'] as String? ?? '';
     final bool isOwner = note['user_id'] == widget.userId;
     final bool isSaved = _savedNoteIds.contains(noteId);
     String authorName = "Unknown User"; String? authorUsername, authorProfilePic;
      if (note['profiles'] != null && note['profiles'] is Map<String, dynamic>) {
         final authorProfile = note['profiles'] as Map<String, dynamic>;
         authorName = authorProfile['name'] ?? "Unknown User";
         authorUsername = authorProfile['username'];
         authorProfilePic = authorProfile['profile_picture'];
      }

      showModalBottomSheet(
        context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        builder: (context) {
          return Consumer<NoteEngagementProvider>(
            builder: (context, engagementProvider, child) {
              final theme = Theme.of(context);
              final bool isDarkMode = theme.brightness == Brightness.dark;
              final bool isLiked = engagementProvider.isNoteLiked(noteId);
              final bool isProcessingLike = engagementProvider.isNoteProcessing(noteId);
              final int viewCount = engagementProvider.getViewCount(noteId);
              final int likeCount = engagementProvider.getLikeCount(noteId);
              final Color onSurfaceColor = isDarkMode ? Colors.white.withOpacity(0.9) : theme.textTheme.bodyLarge!.color!;
              final Color subtleTextColor = isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;

              return DraggableScrollableSheet(
                 initialChildSize: 0.9, maxChildSize: 0.9, minChildSize: 0.5,
                 builder: (_, controller) => Container(
                    decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(22))
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                         children: [
                           Expanded(
                             child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                                 Padding(
                                   padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                   child: Row(
                                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                     children: [
                                       IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context), tooltip: "Close"),
                                       Expanded(child: Container()),
                                       Row(
                                         mainAxisSize: MainAxisSize.min,
                                         children: [
                                           if (isProcessingLike) const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                                           else IconButton(icon: Icon(isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isLiked ? Colors.redAccent : theme.iconTheme.color, size: 22), onPressed: () => _toggleNoteLike(noteId), tooltip: isLiked ? "Unlike" : "Like"),
                                           if (isOwner) IconButton(icon: Icon(note['is_public'] == true ? Icons.public_off_rounded : Icons.public_rounded, color: note['is_public'] == true ? Colors.grey.shade500 : Colors.green.shade500, size: 22), onPressed: () { Navigator.pop(context); _toggleNoteVisibility(noteId, note['is_public'] == true); }, tooltip: note['is_public'] == true ? "Make Private" : "Make Public"),
                                           IconButton(icon: Icon(isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: isSaved ? theme.colorScheme.primary : theme.iconTheme.color, size: 22 ), onPressed: () { Navigator.pop(context); _toggleSaveNote(noteId, isSaved); }, tooltip: isSaved ? "Unsave" : "Save"),
                                           IconButton(icon: const Icon(Icons.share_outlined, size: 22), onPressed: () { Navigator.pop(context); _shareNoteText(note['title']?.toString() ?? "", note['content']?.toString() ?? ""); }, tooltip: "Share Text Content"),
                                           IconButton(icon: const Icon(Icons.copy_outlined, size: 20), onPressed: () { Clipboard.setData(ClipboardData(text: note['content']?.toString() ?? "")); _showMessage("Content copied", isError: false); }, tooltip: "Copy Content"),
                                         ]
                                       )
                                     ]
                                   ),
                                 ),
                                 Padding(
                                   padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                   child: Row(
                                     children: [
                                       Expanded(child: Text(note['title']?.toString() ?? "Untitled", style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: onSurfaceColor))),
                                       if (note['is_public'] == true)
                                         Container(
                                           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                           decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
                                           child: Row(mainAxisSize: MainAxisSize.min, children: [ Icon(Icons.public_rounded, size: 14, color: Colors.green.shade600), const SizedBox(width: 5), Text("Public", style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w500))])
                                         )
                                     ]
                                   )
                                 ),
                                 if (!isOwner && note['profiles'] != null)
                                   Padding(
                                     padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                                     child: Row(
                                       children: [
                                         CircleAvatar(radius: 18, backgroundImage: (authorProfilePic != null && authorProfilePic.isNotEmpty) ? NetworkImage(authorProfilePic) : null, child: (authorProfilePic == null || authorProfilePic.isEmpty) ? Icon(Icons.person_rounded, size: 18, color: subtleTextColor) : null),
                                         const SizedBox(width: 10),
                                         Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(authorName, style: theme.textTheme.titleSmall?.copyWith(color: onSurfaceColor, fontWeight: FontWeight.w600)), if (authorUsername != null) Text("@$authorUsername", style: theme.textTheme.bodySmall?.copyWith(color: subtleTextColor)) ])
                                       ]
                                     )
                                   ),
                                 Padding(
                                   padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                   child: Row(children: [ Icon(Icons.visibility_outlined, size: 16, color: Colors.blueAccent), const SizedBox(width: 5), Text("$viewCount views", style: TextStyle(fontSize: 13, color: Colors.blueAccent, fontWeight: FontWeight.w500)), const SizedBox(width: 18), Icon(Icons.favorite_border_rounded, size: 16, color: Colors.redAccent), const SizedBox(width: 5), Text("$likeCount likes", style: TextStyle(fontSize: 13, color: Colors.redAccent, fontWeight: FontWeight.w500))])
                                 ),
                                 if (note['tags'] != null && (note['tags'] as List).isNotEmpty)
                                   Padding(
                                     padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                                     child: Wrap(spacing: 8, runSpacing: 6, children: (note['tags'] as List).map<Widget>((tag) => Chip(label: Text(tag.toString()), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), visualDensity: VisualDensity.compact, labelStyle: TextStyle(fontSize: 12, color: theme.chipTheme.labelStyle?.color), backgroundColor: theme.chipTheme.backgroundColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))).toList())
                                   ),
                                 const Divider(height: 1, thickness: 0.5),
                                 Expanded(
                                   child: SingleChildScrollView(
                                     controller: controller,
                                     padding: const EdgeInsets.all(20),
                                     child: Column(
                                       crossAxisAlignment: CrossAxisAlignment.start,
                                       children: [
                                         SelectableText(note['content']?.toString() ?? "No content available.", style: theme.textTheme.bodyLarge?.copyWith(height: 1.6, color: onSurfaceColor.withOpacity(0.85))),
                                         if (note['file_url'] != null && note['file_url'].toString().isNotEmpty)
                                           Container(
                                             margin: const EdgeInsets.only(top: 24, bottom: 16),
                                             padding: const EdgeInsets.all(16),
                                             decoration: BoxDecoration(
                                               color: theme.cardColor.withOpacity(0.7),
                                               borderRadius: BorderRadius.circular(12),
                                               border: Border.all(color: theme.dividerColor.withOpacity(0.5))
                                             ),
                                             child: Column(
                                               crossAxisAlignment: CrossAxisAlignment.start,
                                               children: [
                                                 Row(children: [ Icon(_getFileIcon(note['file_type'] ?? ''), color: theme.colorScheme.primary), const SizedBox(width: 10), Expanded(child: Text(note['file_name'] ?? "File attachment", style: TextStyle(fontWeight: FontWeight.bold, color: onSurfaceColor), maxLines: 1, overflow: TextOverflow.ellipsis))]),
                                                 const SizedBox(height: 8),
                                                 Text("${_formatFileSize(note['file_size'] as int? ?? 0)} • ${note['file_type'] ?? 'Unknown type'}", style: theme.textTheme.bodySmall?.copyWith(color: subtleTextColor)),
                                                 const SizedBox(height: 18),
                                                 SizedBox(
                                                   width: double.infinity,
                                                   child: ElevatedButton.icon(
                                                     onPressed: _processingNotes[noteId] == true ? null : () { Navigator.pop(context); _openFile(note); },
                                                     icon: _processingNotes[noteId] == true ? const SizedBox(width:16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.visibility_outlined, size: 18),
                                                     label: Text(_processingNotes[noteId] == true ? "Loading File..." : "View Note"),
                                                     style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))
                                                   )
                                                 ),
                                                 const SizedBox(height: 10),
                                                 const Center(child: Text("Files are protected and viewable only within the app", style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey), textAlign: TextAlign.center)),
                                               ]
                                             )
                                           )
                                       ]
                                     )
                                   )
                                 ),
                              ]
                            )
                           ),
                         ],
                       ),
                     ),
                 );
            }
          );
        }
      );
  }

  void _viewNoteDetails(Map<String, dynamic> note) async {
    if (!mounted) return;
    final String noteId = note['id'] as String? ?? '';
    if (noteId.isNotEmpty) {
      await Provider.of<NoteEngagementProvider>(context, listen: false).refreshNoteData(noteId);
    }
    if (!mounted) return;
    _showNoteDetailsBottomSheet(note);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final int adFrequency = 1; // 1 note, 1 ad
    final double adHeight = 100.0;


    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
           final result = await Navigator.pushNamed(context, '/upload_note', arguments: {'userId': widget.userId});
           if (result == true && mounted) { _fetchNotes(); }
        },
        tooltip: 'Upload Note',
        child: const Icon(Icons.add_rounded),
      ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text("View Notes"),
            backgroundColor: isDarkMode ? Colors.black : theme.appBarTheme.backgroundColor,
            elevation: 0,
            pinned: true,
            floating: true,
            snap: true,
            forceElevated: false,
            scrolledUnderElevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _fetchNotes,
                tooltip: "Refresh Notes"
              )
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(120.0),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      style: TextStyle(color: isDarkMode ? Colors.white.withOpacity(0.9) : null),
                      decoration: InputDecoration(
                        hintText: "Search notes (title, content, tags)...",
                        prefixIcon: Icon(Icons.search_rounded, color: theme.inputDecorationTheme.prefixIconColor),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear_rounded, color: theme.inputDecorationTheme.suffixIconColor),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() { _searchQuery = ""; });
                                  _fetchNotes();
                                  _searchFocusNode.unfocus();
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.0)),
                      ),
                      onChanged: (value) {
                        setState(() { _searchQuery = value; });
                        _fetchNotes();
                      },
                      onSubmitted: (_) => _fetchNotes(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 12.0),
                    child: SizedBox(
                      height: 42,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _filters.map((filter) {
                          final isSelected = _selectedFilter == filter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 10.0),
                            child: ChoiceChip(
                              label: Text(filter),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected && _selectedFilter != filter) {
                                  setState(() { _selectedFilter = filter; });
                                  _fetchNotes();
                                  _searchFocusNode.unfocus();
                                }
                              },
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_errorMessage.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                color: theme.colorScheme.errorContainer.withOpacity(0.1),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_errorMessage, style: TextStyle(color: theme.colorScheme.onErrorContainer))),
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 18, color: theme.colorScheme.onErrorContainer),
                      onPressed: () => setState(() { _errorMessage = ""; }),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    )
                  ]
                ),
              ),
            ),
          _isLoading
              ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              : _notes.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.note_alt_outlined, size: 70, color: theme.hintColor), // Changed icon
                              const SizedBox(height: 20),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No notes found matching "$_searchQuery"'
                                    : _selectedFilter == "Saved Notes"
                                        ? "You haven't saved any notes yet"
                                        : "No notes found for this filter",
                                style: theme.textTheme.titleLarge?.copyWith(color: theme.hintColor),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? "Try different search terms or filters."
                                    : _selectedFilter == "Saved Notes"
                                        ? "Save notes using the bookmark icon."
                                        : "Try uploading some notes!",
                                style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor?.withOpacity(0.8)),
                                textAlign: TextAlign.center,
                              )
                            ],
                          ),
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            bool isAdIndex = index.isOdd;
                            int noteIndex = index ~/ 2;

                            if (isAdIndex) {
                              if (noteIndex < _notes.length) {
                                return NativeAdWidget(
                                  key: ValueKey('view_notes_ad_slot_$noteIndex'), // Unique key
                                  adUnitKey: 'ADMOB_NATIVE_AD_VIEW_NOTES', // MODIFIED
                                  useTestId: USE_TEST_ADS_VIEW_NOTES,
                                  height: adHeight,
                                  cornerRadius: 16.0,
                                );
                              } else {
                                return const SizedBox.shrink();
                              }
                            } else {
                              if (noteIndex >= _notes.length) return const SizedBox.shrink();
                              final note = _notes[noteIndex];
                              return _buildNoteItem(note, theme);
                            }
                          },
                          childCount: _notes.isEmpty ? 0 : (_notes.length * 2 - (_notes.isNotEmpty ? 1 : 0)),
                        ),
                      ),
                    ),
            SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildNoteItem(Map<String, dynamic> note, ThemeData theme) {
    final String noteId = note['id'] as String? ?? '';
    if (noteId.isEmpty) return const SizedBox.shrink();

    final bool isOwner = note['user_id'] == widget.userId;
    final bool isSaved = _savedNoteIds.contains(noteId);
    String authorName = "Unknown"; String? authorUsername, authorProfilePic;
    if (note['profiles'] != null && note['profiles'] is Map<String, dynamic>) {
      final authorProfile = note['profiles'] as Map<String, dynamic>;
      authorName = authorProfile['name'] ?? "Unknown";
      authorUsername = authorProfile['username'];
      authorProfilePic = authorProfile['profile_picture'];
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.0)),
      child: InkWell(
        onTap: () => _viewNoteDetails(note),
        borderRadius: BorderRadius.circular(18.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: theme.colorScheme.primaryContainer.withOpacity(0.5),
                    backgroundImage: !isOwner && authorProfilePic != null && authorProfilePic.isNotEmpty ? NetworkImage(authorProfilePic) : null,
                    child: (isOwner || authorProfilePic == null || authorProfilePic.isEmpty) ? Icon(_getFileIcon(note['file_type'] ?? ''), color: theme.colorScheme.onPrimaryContainer, size: 22) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(note['title']?.toString() ?? "Untitled Note", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        if (note['is_public'] == true) Padding( padding: const EdgeInsets.only(top: 4.0), child: Row(mainAxisSize: MainAxisSize.min, children: [ Icon(Icons.public_rounded, size: 14, color: Colors.green.shade500), const SizedBox(width: 4), Text("Public", style: TextStyle(fontSize: 11, color: Colors.green.shade600, fontWeight: FontWeight.w500))])),
                      ],
                    )
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Consumer<NoteEngagementProvider>(
                        builder: (context, engagementProvider, _) {
                           final bool isLiked = engagementProvider.isNoteLiked(noteId);
                           final bool isProcessingLike = engagementProvider.isNoteProcessing(noteId);
                           return isProcessingLike
                            ? const SizedBox(width: 24, height: 24, child: Padding(padding: EdgeInsets.all(4.0), child: CircularProgressIndicator(strokeWidth: 2)))
                            : IconButton(icon: Icon(isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isLiked ? Colors.redAccent : theme.iconTheme.color, size: 20), onPressed: () => _toggleNoteLike(noteId), tooltip: isLiked ? "Unlike" : "Like", visualDensity: VisualDensity.compact);
                        }
                      ),
                      if (isOwner) IconButton(icon: Icon(note['is_public'] == true ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: note['is_public'] == true ? Colors.grey.shade500 : Colors.green.shade500, size: 20), onPressed: () => _toggleNoteVisibility(noteId, note['is_public'] == true), tooltip: note['is_public'] == true ? "Make Private" : "Make Public", visualDensity: VisualDensity.compact),
                      IconButton(icon: Icon(isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, color: isSaved ? theme.colorScheme.primary : theme.iconTheme.color, size: 20), onPressed: () => _toggleSaveNote(noteId, isSaved), tooltip: isSaved ? "Unsave" : "Save", visualDensity: VisualDensity.compact),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(note['description']?.toString() ?? "No description", maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
              const SizedBox(height: 10),
              if (note['tags'] != null && (note['tags'] as List).isNotEmpty) Padding( padding: const EdgeInsets.only(top: 6.0, bottom: 4.0), child: Wrap( spacing: 8, runSpacing: 6, children: (note['tags'] as List).map<Widget>((tag) { return Chip( label: Text(tag.toString()), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)) ); }).toList(), ), ),
              if (!isOwner) Padding( padding: const EdgeInsets.only(top: 8.0), child: Row( children: [ Icon(Icons.person_outline_rounded, size: 14, color: theme.textTheme.bodySmall?.color), const SizedBox(width: 5), Text( authorUsername != null ? "@$authorUsername" : authorName, style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)) ])),
              if (note['file_name'] != null && note['file_name'].toString().isNotEmpty) Padding( padding: const EdgeInsets.only(top: 8.0), child: Row( children: [ Icon(_getFileIcon(note['file_type']?.toString() ?? ''), size: 16, color: theme.colorScheme.primary), const SizedBox(width: 6), Expanded( child: Text( note['file_name'].toString(), style: TextStyle(fontSize: 12, color: theme.colorScheme.primary, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)), const SizedBox(width: 4), Text("(${_formatFileSize(note['file_size'] ?? 0)})", style: theme.textTheme.bodySmall) ])),
              Divider(height: 24, thickness: 0.5, color: theme.dividerColor.withOpacity(0.7)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Consumer<NoteEngagementProvider>(
                     builder: (context, engagementProvider, _) {
                        final int viewCount = engagementProvider.getViewCount(noteId);
                        final int likeCount = engagementProvider.getLikeCount(noteId);
                        return Row( children: [ Icon(Icons.remove_red_eye_outlined, size: 16, color: theme.textTheme.bodySmall?.color), const SizedBox(width: 5), Text("$viewCount", style: theme.textTheme.bodySmall), const SizedBox(width: 16), Icon(Icons.favorite_border_rounded, size: 16, color: theme.textTheme.bodySmall?.color), const SizedBox(width: 5), Text("$likeCount", style: theme.textTheme.bodySmall) ]);
                     }
                  ),
                  Row( mainAxisSize: MainAxisSize.min, children: [ TextButton.icon( icon: const Icon(Icons.read_more_rounded, size: 18), label: const Text("Details"), style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)), onPressed: () => _viewNoteDetails(note)), if (note['file_url'] != null && note['file_url'].toString().isNotEmpty) Padding( padding: const EdgeInsets.only(left: 10.0), child: TextButton.icon(icon: const Icon(Icons.file_open_outlined, size: 18), label: const Text("View File"), style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)), onPressed: _processingNotes[noteId] == true ? null : () => _openFile(note)) )])
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
