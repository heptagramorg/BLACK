import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/note_service.dart';

class ManageNotesScreen extends StatefulWidget {
  final String userId;
  const ManageNotesScreen({super.key, required this.userId});

  @override
  ManageNotesScreenState createState() => ManageNotesScreenState();
}

class ManageNotesScreenState extends State<ManageNotesScreen> {
  final _supabase = SupabaseService.client;
  final NotesService _notesService = NotesService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _notes = [];
  int _userStorageUsed = 0;
  static const int maxStorageLimit = 262144000; // 250MB in bytes
  final Set<String> _selectedNotes = {};
  bool _isDeleting = false;
  bool _isRefreshing = false;
  String _statusMessage = "";
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchUserStorageUsage();
    _fetchUserNotes();
  }

  /// Fetch User Storage Usage
  Future<void> _fetchUserStorageUsage() async {
    try {
      final profile = await _supabase
          .from('profiles')
          .select('storage_used')
          .eq('id', widget.userId)
          .single();
          
      if (!mounted) return;
      setState(() {
        _userStorageUsed = profile['storage_used'] ?? 0;
      });
    } catch (e) {
      // Error is handled silently as this is a background update.
    }
  }

  /// Fetch User Notes
  Future<void> _fetchUserNotes() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
      _statusMessage = "";
    });
    
    try {
      final notes = await _notesService.fetchUserNotes(widget.userId);
      if (!mounted) return;
      
      setState(() {
        _notes = notes;
        _isLoading = false;
      });

      if (_notes.isEmpty) {
        _showMessage("No notes found", isError: false);
      }
    } catch (e) {
      if (!mounted) return;
      final errorMessage = "Error fetching notes: ${e.toString()}";
      setState(() {
        _isLoading = false;
        _hasError = true;
        _statusMessage = errorMessage;
      });
      _showMessage(errorMessage, isError: true);
    }
  }

  /// Format File Size
  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  /// Toggle Note Selection
  void _toggleNoteSelection(String noteId) {
    setState(() {
      if (_selectedNotes.contains(noteId)) {
        _selectedNotes.remove(noteId);
      } else {
        _selectedNotes.add(noteId);
      }
    });
  }

  /// Toggle note visibility (public/private)
  Future<void> _toggleNoteVisibility(String noteId, bool currentlyPublic) async {
    try {
      final success = await _notesService.updateNoteVisibility(noteId, !currentlyPublic);
      
      if (!mounted) return;

      if (success) {
        setState(() {
          final noteIndex = _notes.indexWhere((note) => note['id'] == noteId);
          if (noteIndex != -1) {
            _notes[noteIndex]['is_public'] = !currentlyPublic;
          }
        });
        _showMessage(currentlyPublic ? "Note is now private" : "Note is now public");
      } else {
        _showMessage("Failed to update note visibility", isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage("Error updating note visibility: ${e.toString()}", isError: true);
    }
  }

  /// Delete a Single Note
  Future<bool> _deleteSingleNote(String noteId) async {
    try {
      final success = await _notesService.deleteNote(noteId);
      if (success) {
        await _fetchUserStorageUsage();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Delete Selected Notes
  Future<void> _deleteSelectedNotes() async {
    if (_selectedNotes.isEmpty) {
      _showMessage("Please select notes to delete first", isError: true);
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Deletion"),
        content: Text(
          "Are you sure you want to delete ${_selectedNotes.length} selected note${_selectedNotes.length > 1 ? 's' : ''}? "
          "This action cannot be undone."
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (shouldDelete != true || !mounted) return;

    setState(() {
      _isDeleting = true;
      _statusMessage = "Deleting ${_selectedNotes.length} notes...";
      _hasError = false;
    });

    int successCount = 0;
    List<String> failedNoteIds = [];
    final Set<String> notesToDelete = Set<String>.from(_selectedNotes);
    
    for (String noteId in notesToDelete) {
      final success = await _deleteSingleNote(noteId);
      if (success) {
        successCount++;
      } else {
        failedNoteIds.add(noteId);
      }
    }

    if (!mounted) return;

    setState(() {
      _notes.removeWhere((note) => notesToDelete.contains(note['id']) && !failedNoteIds.contains(note['id']));
      _selectedNotes.removeWhere((noteId) => !failedNoteIds.contains(noteId));
      _isDeleting = false;
      
      if (failedNoteIds.isNotEmpty) {
        _hasError = true;
        _statusMessage = "Failed to delete ${failedNoteIds.length} notes";
      } else {
        _statusMessage = "Successfully deleted $successCount notes";
      }
    });
    
    if (successCount > 0) {
      _showMessage("Successfully deleted $successCount note(s)${failedNoteIds.isNotEmpty ? ", ${failedNoteIds.length} failed" : ""}",
            isError: failedNoteIds.isNotEmpty);
    } else if (failedNoteIds.isNotEmpty) {
      _showMessage("Failed to delete ${failedNoteIds.length} note(s)", isError: true);
    }
    
    await _fetchUserStorageUsage();
  }
  
  /// Fix Storage Usage Calculation
  Future<void> _fixStorageUsage() async {
    setState(() { _isRefreshing = true; _statusMessage = "Recalculating storage usage..."; });
    
    try {
      final correctedStorageUsage = await _notesService.cleanupStorageUsage(widget.userId);
      if (!mounted) return;

      if (correctedStorageUsage >= 0) {
        setState(() {
          _userStorageUsed = correctedStorageUsage;
          _statusMessage = "Storage usage has been recalculated";
        });
        _showMessage("Storage usage recalculated: ${_formatFileSize(correctedStorageUsage)}");
      } else {
        setState(() { _hasError = true; _statusMessage = "Failed to recalculate storage usage"; });
        _showMessage("Failed to recalculate storage usage", isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _hasError = true; _statusMessage = "Error recalculating storage: ${e.toString()}"; });
      _showMessage("Error recalculating storage: ${e.toString()}", isError: true);
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }
  
  /// Clean up orphaned files in storage
  Future<void> _cleanupOrphanedFiles() async {
    setState(() { _isRefreshing = true; _statusMessage = "Cleaning up storage..."; });
    
    try {
      final notesData = await _supabase.from('notes').select('file_url').eq('user_id', widget.userId);
      final validFileUrls = notesData.map((note) => note['file_url'] as String?).where((url) => url != null && url.isNotEmpty).toSet();
      final storageList = await _supabase.storage.from('notes').list(path: widget.userId);
      
      int cleanedCount = 0;
      int totalFreedSpace = 0;
      
      for (var item in storageList) {
        final String filePath = '${widget.userId}/${item.name}';
        final fileUrl = _supabase.storage.from('notes').getPublicUrl(filePath);
        
        if (!validFileUrls.contains(fileUrl)) {
          final fileSize = item.metadata?['size'] as int? ?? 0;
          await _supabase.storage.from('notes').remove([filePath]);
          cleanedCount++;
          totalFreedSpace += fileSize;
        }
      }
      
      await _fixStorageUsage();
      if (!mounted) return;

      setState(() {
        _statusMessage = cleanedCount > 0 ? "Cleaned up $cleanedCount orphaned files" : "No orphaned files found";
      });
      
      if (cleanedCount > 0) {
        _showMessage("Cleaned up $cleanedCount orphaned files (${_formatFileSize(totalFreedSpace)})");
      }
      
      await _fetchUserNotes();
    } catch (e) {
      if (!mounted) return;
      setState(() { _hasError = true; _statusMessage = "Error cleaning up: ${e.toString()}"; });
      _showMessage("Error cleaning up: ${e.toString()}", isError: true);
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  // Refresh data completely
  Future<void> _refreshData() async {
    setState(() { _isRefreshing = true; _selectedNotes.clear(); _statusMessage = "Refreshing..."; });
    
    try {
      await _fetchUserStorageUsage();
      await _fetchUserNotes();
      if (!mounted) return;
      setState(() { _statusMessage = "Data refreshed"; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _hasError = true; _statusMessage = "Error refreshing: ${e.toString()}"; });
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
          duration: Duration(seconds: isError ? 4 : 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Notes"),
        actions: [
          if (_selectedNotes.isNotEmpty && !_isDeleting)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: "Delete Selected",
              onPressed: _deleteSelectedNotes,
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'refresh') {
                _refreshData();
              } else if (value == 'cleanup') {
                _cleanupOrphanedFiles();
              } else if (value == 'fix_storage') {
                _fixStorageUsage();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'refresh', child: ListTile(leading: Icon(Icons.refresh), title: Text('Refresh'))),
              const PopupMenuItem(value: 'cleanup', child: ListTile(leading: Icon(Icons.cleaning_services), title: Text('Clean Up Storage'))),
              const PopupMenuItem(value: 'fix_storage', child: ListTile(leading: Icon(Icons.auto_fix_high), title: Text('Fix Storage Calculation'))),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Storage Usage", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(
                        "${_formatFileSize(_userStorageUsed)} / 250 MB",
                        style: TextStyle(
                          color: (_userStorageUsed / maxStorageLimit) > 0.9 ? Colors.red : null,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _userStorageUsed / maxStorageLimit,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>((_userStorageUsed / maxStorageLimit) > 0.9 ? Colors.red : Colors.green),
                  ),
                ],
              ),
            ),
          ),
          if (_statusMessage.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _hasError ? Colors.red.shade50 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _hasError ? Colors.red.shade200 : Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(_hasError ? Icons.error_outline : Icons.info_outline, color: _hasError ? Colors.red : Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_statusMessage, style: TextStyle(color: _hasError ? Colors.red.shade800 : Colors.green.shade800))),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => setState(() => _statusMessage = ""),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: _hasError ? Colors.red : Colors.green,
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading || _isRefreshing
                ? const Center(child: CircularProgressIndicator())
                : _notes.isEmpty 
                    ? const Center(child: Text("No notes found"))
                    : ListView.builder(
                        itemCount: _notes.length,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final note = _notes[index];
                          final String id = note['id'] as String;
                          final bool isSelected = _selectedNotes.contains(id);
                          final bool isPublic = note['is_public'] == true;
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: isSelected ? 2 : 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: isSelected ? const BorderSide(color: Colors.blue, width: 2) : BorderSide.none,
                            ),
                            child: Column(
                              children: [
                                ListTile(
                                  leading: Checkbox(value: isSelected, onChanged: (value) => _toggleNoteSelection(id)),
                                  title: Row(
                                    children: [
                                      Expanded(child: Text(note['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold))),
                                      if (isPublic)
                                        const Tooltip(message: "Public Note", child: Icon(Icons.public, size: 16, color: Colors.green)),
                                    ],
                                  ),
                                  subtitle: Text(note['description'] as String, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  trailing: Text(_formatFileSize(note['file_size'] as int? ?? 0)),
                                  onTap: () => _toggleNoteSelection(id),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton.icon(
                                        icon: Icon(isPublic ? Icons.public : Icons.lock, size: 16, color: isPublic ? Colors.green : null),
                                        label: Text(isPublic ? "Public" : "Private", style: TextStyle(color: isPublic ? Colors.green : null)),
                                        onPressed: () => _toggleNoteVisibility(id, isPublic),
                                        style: OutlinedButton.styleFrom(side: BorderSide(color: isPublic ? Colors.green : Colors.grey)),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                        label: const Text("Delete", style: TextStyle(color: Colors.red)),
                                        onPressed: () async {
                                          final shouldDelete = await showDialog<bool>(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text("Delete Note"),
                                              content: const Text("Are you sure you want to delete this note? This action cannot be undone."),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                                                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
                                              ],
                                            ),
                                          );
                                          
                                          if (shouldDelete == true) {
                                            setState(() => _isDeleting = true);
                                            final success = await _deleteSingleNote(id);
                                            
                                            if (!mounted) return;

                                            if (success) {
                                              setState(() {
                                                _notes.removeAt(index);
                                                _selectedNotes.remove(id);
                                              });
                                              _fetchUserStorageUsage();
                                              _showMessage("Note deleted successfully");
                                            } else {
                                              _showMessage("Failed to delete note", isError: true);
                                            }
                                            setState(() => _isDeleting = false);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
