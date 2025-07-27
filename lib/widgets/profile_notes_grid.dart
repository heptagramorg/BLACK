// lib/widgets/profile_notes_grid.dart
import 'package:flutter/material.dart';
import '../services/note_service.dart';
import '../utils/secure_file_handler.dart';
// import '../screens/view_notes_screen.dart'; // _showNoteDetails is now local

class ProfileNotesGrid extends StatefulWidget {
  final String userId; // The ID of the profile whose notes are being viewed
  final String currentUserId; // The ID of the currently logged-in user

  const ProfileNotesGrid({
    Key? key,
    required this.userId,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<ProfileNotesGrid> createState() => _ProfileNotesGridState();
}

class _ProfileNotesGridState extends State<ProfileNotesGrid> {
  final NotesService _notesService = NotesService();
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  List<Map<String, dynamic>> _notes = [];
  String _errorMessage = "";

  int _currentPage = 1;
  final int _pageSize = 12; // Number of notes per page, adjust as needed
  bool _hasMoreNotes = true;

  @override
  void initState() {
    super.initState();
    _fetchInitialNotes();
  }

  Future<void> _fetchInitialNotes() async {
    if (!mounted) return;
    setState(() {
      _isLoadingInitial = true;
      _errorMessage = "";
      _currentPage = 1;
      _notes = []; // Clear previous notes
      _hasMoreNotes = true; // Assume there are more notes initially
    });
    await _fetchNotes(); // Call the common fetch logic
    if (mounted) {
      setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _fetchMoreNotes() async {
    if (!mounted || _isLoadingMore || !_hasMoreNotes) return;
    setState(() => _isLoadingMore = true);
    _currentPage++;
    await _fetchNotes(); // Call the common fetch logic
    if (mounted) {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _fetchNotes() async {
    // Common logic to fetch notes for current page
    try {
      final fetchedNotes = await _notesService.fetchNotesForUserPaginated(
        profileUserId: widget.userId,
        requestingUserId: widget.currentUserId,
        pageNumber: _currentPage,
        pageSize: _pageSize,
      );

      if (!mounted) return;
      setState(() {
        if (_currentPage == 1) { // For initial load
          _notes = fetchedNotes;
        } else { // For "load more"
          _notes.addAll(fetchedNotes);
        }
        _hasMoreNotes = fetchedNotes.length == _pageSize;
        if (fetchedNotes.isNotEmpty) { // Clear error if we successfully fetched some notes
             _errorMessage = "";
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst("Exception: ", "");
          if (_currentPage > 1) { // If error on "load more", revert page count
            _currentPage--;
          }
        });
      }
    }
  }

  void _openNote(Map<String, dynamic> note) {
    final fileUrl = note['file_url'] as String?;
    final fileName = note['file_name'] as String? ?? 'document';
    final fileType = note['file_type'] as String? ?? '';
    final noteId = note['id'] as String? ?? '';

    if (fileUrl != null && fileUrl.isNotEmpty) {
      SecureFileHandler.openFile(
        context, // Assuming SecureFileHandler needs context
        fileUrl,
        fileName,
        fileType,
        noteId,
        widget.currentUserId,
      );
    } else {
      _showNoteDetails(context, note); // Pass context
    }
  }

  void _showNoteDetails(BuildContext dialogContext, Map<String, dynamic> note) {
    showModalBottomSheet(
      context: dialogContext, // Use the passed context
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bsContext) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Theme.of(bsContext).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      note['title'] ?? "Untitled",
                      style: Theme.of(bsContext).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis, // Prevent long titles from breaking layout
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(bsContext), // Use bsContext to pop
                  ),
                ],
              ),
              if (note['is_public'] == true)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Chip(
                    label: const Text("Public"),
                    avatar: Icon(Icons.public, color: Colors.green.shade700),
                    backgroundColor: Colors.green.withOpacity(0.1),
                  ),
                ),
              if (note['tags'] != null && (note['tags'] as List).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: (note['tags'] as List)
                        .map<Widget>((tag) => Chip(label: Text(tag.toString())))
                        .toList(),
                  ),
                ),
              const Divider(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  child: SelectableText(
                    note['content'] ?? "No content available.",
                    style: Theme.of(bsContext).textTheme.bodyLarge?.copyWith(height: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getFileIcon(String? fileType) {
    fileType = fileType?.toLowerCase() ?? '';
    if (fileType.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (fileType.contains('doc')) return Icons.description_rounded;
    if (fileType.contains('ppt')) return Icons.slideshow_rounded;
    if (fileType.contains('xls')) return Icons.table_chart_rounded;
    if (fileType.contains('image')) return Icons.image_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color _getIconColor(String? fileType, ThemeData theme) {
    fileType = fileType?.toLowerCase() ?? '';
    if (fileType.contains('pdf')) return Colors.red.shade300;
    if (fileType.contains('doc')) return Colors.blue.shade300;
    if (fileType.contains('ppt')) return Colors.orange.shade300;
    if (fileType.contains('xls')) return Colors.green.shade300;
    if (fileType.contains('image')) return Colors.purple.shade300;
    return theme.colorScheme.onSurfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoadingInitial) {
      return const SliverToBoxAdapter(
          child: Center(
              child: Padding(
        padding: EdgeInsets.all(32.0), // Added padding
        child: CircularProgressIndicator(),
      )));
    }

    // Show error message if initial load failed and no notes are present
    if (_errorMessage.isNotEmpty && _notes.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(_errorMessage,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                    onPressed: _fetchInitialNotes, child: const Text("Try Again")),
              ],
            ),
          ),
        ),
      );
    }

    if (_notes.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                vertical: 40.0, horizontal: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.note_add_outlined,
                    size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  widget.userId == widget.currentUserId
                      ? "You haven't uploaded any notes yet."
                      : "This user hasn't shared any public notes.",
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                if (widget.userId == widget.currentUserId) ...[
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/upload_note',
                              arguments: {'userId': widget.userId})
                          .then((_) =>
                              _fetchInitialNotes()); // Refresh after potential upload
                    },
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text("Upload Your First Note"),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final double screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount =
        (screenWidth / 160).floor().clamp(2, 4); // Min 2, Max 4 columns

    // Group all slivers for ProfileNotesGrid
    return SliverMainAxisGroup(
      slivers: [
        SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.85,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final note = _notes[index];
              final fileType = note['file_type'] as String?;
              final iconData = _getFileIcon(fileType);
              final iconColor = _getIconColor(fileType, theme);

              return InkWell(
                onTap: () => _openNote(note),
                borderRadius: BorderRadius.circular(12),
                child: Card(
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            color: iconColor.withOpacity(0.1),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12)),
                          ),
                          child: Center(
                              child:
                                  Icon(iconData, size: 40, color: iconColor)),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                note['title']?.toString() ?? "Untitled",
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(
                                    note['is_public'] == true ? Icons.public : Icons.lock_outline,
                                    size: 14,
                                    color: note['is_public'] == true ? Colors.green.shade600 : Colors.grey.shade600,
                                  ),
                                  Text(
                                    "${note['view_count'] ?? 0} views",
                                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            childCount: _notes.length,
          ),
        ),
        // Sliver for "Load More" button or error message for loading more
        if (_hasMoreNotes || (_errorMessage.isNotEmpty && _notes.isNotEmpty))
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: _isLoadingMore
                    ? const CircularProgressIndicator()
                    : (_errorMessage.isNotEmpty && !_hasMoreNotes && _notes.isNotEmpty) // Show error if load more failed
                        ? Column(
                            children: [
                              Text(_errorMessage, style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 8),
                              ElevatedButton(onPressed: _fetchMoreNotes, child: const Text("Try Again"))
                            ],
                          )
                        : (_hasMoreNotes // Show "Load More" button only if there are more notes and no error from last fetchMore
                            ? ElevatedButton(
                                onPressed: _fetchMoreNotes,
                                child: const Text("Load More Notes"),
                              )
                            : const SizedBox.shrink() // Should not be reached if !_hasMoreNotes and no error
                           ),
              ),
            ),
          ),
      ],
    );
  }
}