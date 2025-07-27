// lib/utils/secure_file_viewer.dart

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:provider/provider.dart'; // Import Provider
import '../services/supabase_service.dart';
// Remove direct import of engagement service
// import '../services/note_engagement_service.dart';
import '../providers/note_engagement_provider.dart'; // Import Provider

class SecureFileViewer extends StatefulWidget {
  final String filePath;
  final String fileName;
  final String fileType;
  final String userId;
  final String noteId; // Added to track which note is being viewed

  const SecureFileViewer({
    Key? key,
    required this.filePath,
    required this.fileName,
    required this.fileType,
    required this.userId,
    required this.noteId, // Made required
  }) : super(key: key);

  @override
  State<SecureFileViewer> createState() => _SecureFileViewerState();
}

class _SecureFileViewerState extends State<SecureFileViewer> with WidgetsBindingObserver {

  bool _isLoading = true;
  String _errorMessage = '';
  int _currentPage = 0;
  int _totalPages = 0;
  bool _fileExists = false;
  int _fileSize = 0;
  File? _file;
  bool _isInitializing = true;
  bool _isFileViewerReady = false;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Use addPostFrameCallback to ensure context is ready for Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initFileAndLogView(); // Call combined initialization and logging
      }
    });
  }

   @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Clean up the specific temporary file when viewer is closed
    _cleanupTempFile();
    super.dispose();
  }

  // --- Initialization and View Recording ---
  Future<void> _initFileAndLogView() async {
    if (!mounted) return;

    setState(() {
      _isInitializing = true;
      _isLoading = true;
      _errorMessage = '';
      _fileExists = false;
      _isFileViewerReady = false;
    });

    try {
      // Log the view attempt using the provider BEFORE loading the file
      if (widget.noteId.isNotEmpty && widget.userId.isNotEmpty) {
        // Call provider's recordNoteView. We don't block on its success here,
        // but trigger it. The provider handles the actual DB interaction.
        Provider.of<NoteEngagementProvider>(context, listen: false)
            .recordNoteView(widget.noteId);
        print("Triggered view recording for note ${widget.noteId} via provider.");
      } else {
        print("Skipping view recording: Invalid noteId ('${widget.noteId}') or userId ('${widget.userId}') in SecureFileViewer.");
      }

      // Proceed with checking and loading the file
      _file = File(widget.filePath);
      final bool exists = await _file!.exists();

      if (!exists) {
        throw Exception('File not found at path: ${widget.filePath}');
      }

      final fileStat = await _file!.stat();
      final fileSize = fileStat.size;

      if (fileSize <= 0) {
        throw Exception('File appears to be empty');
      }

      // File exists and has content, update state to allow viewer rendering
      if (mounted) {
        setState(() {
          _fileExists = true;
          _fileSize = fileSize;
          _isLoading = false;
          _isInitializing = false;
          _isFileViewerReady = true; // Mark viewer as ready
        });
      }

    } catch (e) {
      print("Error initializing file or logging view: $e");
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading file: $e';
          _isLoading = false;
          _isInitializing = false;
          _fileExists = false; // Ensure file is marked as not existing on error
        });
      }
    }
  }

  // --- Lifecycle and Cleanup ---
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _handleAppBackground();
    }
  }

  void _handleAppBackground() {
    print("App moved to background - SecureFileViewer active.");
    // Potential future security actions here
  }

  Future<void> _cleanupTempFile() async {
    try {
      if (_file != null && await _file!.exists()) {
        await _file!.delete();
        print("Cleaned up temp file: ${widget.filePath}");
      }
    } catch (e) {
      print("Error cleaning up temp file: $e");
    }
  }


  // --- UI Building ---

  Widget _buildImageError(dynamic error) {
     // Basic error display for image loading
     return Center(
       child: Padding(
         padding: const EdgeInsets.all(20.0),
         child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             const Icon(Icons.broken_image_outlined, size: 60, color: Colors.redAccent),
             const SizedBox(height: 16),
             const Text(
               "Error Loading Image",
               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
               textAlign: TextAlign.center,
             ),
             const SizedBox(height: 8),
             Text(
               error.toString(),
               textAlign: TextAlign.center,
               style: const TextStyle(color: Colors.grey),
             ),
           ],
         ),
       ),
     );
  }


  Widget _buildUnsupportedFileTypeView(String fileExtension) {
     IconData fileIcon; String fileTypeLabel;
     if (fileExtension.contains('doc')) { fileIcon = Icons.description; fileTypeLabel = "Word Document"; }
     else if (fileExtension.contains('ppt')) { fileIcon = Icons.slideshow; fileTypeLabel = "PowerPoint Presentation"; }
     else if (fileExtension.contains('xls')) { fileIcon = Icons.table_chart; fileTypeLabel = "Excel Spreadsheet"; }
     else if (fileExtension.contains('pdf')) { fileIcon = Icons.picture_as_pdf; fileTypeLabel = "PDF Document"; }
     else if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(fileExtension)) { fileIcon = Icons.image; fileTypeLabel = "Image File"; }
     else { fileIcon = Icons.insert_drive_file; fileTypeLabel = "Document"; }
     return Center( child: SingleChildScrollView( child: Padding( padding: const EdgeInsets.all(24.0), child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [ Icon( fileIcon, size: 80, color: Theme.of(context).primaryColor), const SizedBox(height: 24), Text( widget.fileName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center), const SizedBox(height: 8), Text( _formatFileSize(_fileSize), style: TextStyle(color: Colors.grey[600], fontSize: 14)), const SizedBox(height: 32), Container( padding: const EdgeInsets.all(16), margin: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration( color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade100)), child: Column( children: [ Row( mainAxisSize: MainAxisSize.min, children: [ Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20), const SizedBox(width: 8), Flexible(child: Text("Preview Unavailable", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800)))]), const SizedBox(height: 12), Text("A preview for this file type (.$fileExtension) is not currently supported within the app.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[800])), const SizedBox(height: 12), Text("The file has been securely downloaded and is only accessible here.", textAlign: TextAlign.center, style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.grey[700])) ] ) ) ] ) ) ) );
  }


  Widget _buildFileViewer() {
    // Handle loading and error states first
    if (_isInitializing || _isLoading) { return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Loading document...')])); }
    if (_errorMessage.isNotEmpty) { return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.error_outline, size: 64, color: Colors.red), const SizedBox(height: 16), Text(_errorMessage, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center), const SizedBox(height: 24), ElevatedButton(onPressed: _initFileAndLogView, child: const Text('Try Again'))])); }
    if (!_fileExists) { return const Center(child: Text("File could not be loaded or does not exist.")); }
    if (!_isFileViewerReady) { return const Center(child: CircularProgressIndicator()); } // Added check for readiness

    final fileExtension = path.extension(widget.fileName).toLowerCase().replaceAll('.', '');

    // PDF Viewer
    if (fileExtension == 'pdf') {
      try { return Stack(children: [ PDFView( filePath: widget.filePath, enableSwipe: true, swipeHorizontal: false, // Prefer vertical scrolling for PDFs
          autoSpacing: true, pageFling: true, pageSnap: true, onRender: (pages) { if (mounted) setState(() => _totalPages = pages ?? 0); }, onPageChanged: (int? page, int? total) { if (mounted) setState(() { _currentPage = page ?? 0; if (total != null && total > 0) _totalPages = total; }); }, onError: (error) { if (mounted) setState(() => _errorMessage = "Error loading PDF: $error"); print("PDF Error: $error");}, onPageError: (page, error) { print("PDF Page Error on page $page: $error");}), _buildWatermark() // Watermark added
        ]);
      } catch (e) {
        print("Error rendering PDF: $e");
        // Fallback to unsupported view if PDFView throws error directly
        return _buildUnsupportedFileTypeView(fileExtension);
      }
    }
    // Image Viewer
    else if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(fileExtension)) {
      try { return Stack(children: [ PhotoView( imageProvider: FileImage(File(widget.filePath)), minScale: PhotoViewComputedScale.contained * 0.8, maxScale: PhotoViewComputedScale.covered * 4, backgroundDecoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor), loadingBuilder: (context, event) => const Center(child: CircularProgressIndicator()), errorBuilder: (context, error, stackTrace) => _buildImageError(error), heroAttributes: PhotoViewHeroAttributes(tag: widget.filePath)), _buildWatermark(text: "Uploaded On Black") // Watermark added
        ]);
      } catch (e) {
         print("Error rendering Image: $e");
        return _buildUnsupportedFileTypeView(fileExtension);
      }
    }
    // Text File Viewer
    else if (fileExtension == 'txt') {
      try { return FutureBuilder<String>( future: File(widget.filePath).readAsString(), builder: (context, snapshot) { if (snapshot.connectionState == ConnectionState.waiting) { return const Center(child: CircularProgressIndicator()); } if (snapshot.hasError) { return Center(child: Text("Error reading text file: ${snapshot.error}")); } if (!snapshot.hasData || snapshot.data!.isEmpty) { return const Center(child: Text("Text file is empty.")); }
        return Stack( // Wrap with Stack for watermark
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(snapshot.data!, style: const TextStyle(fontFamily: 'monospace', height: 1.4)),
            ),
            _buildWatermark(), // Add watermark here too
          ],
        );
       });
      } catch (e) {
         print("Error rendering Text file: $e");
        return _buildUnsupportedFileTypeView(fileExtension);
      }
    }
    // Fallback for all other types
    else { return _buildUnsupportedFileTypeView(fileExtension); }
  }

  // --- Watermark Widget (Fixed Style) ---
  Widget _buildWatermark({String text = "Uploaded In Black"}) {
    // Use the light mode style regardless of the current theme
    final Color watermarkColor = Colors.black.withOpacity(0.20); // Fixed light mode opacity

    return Positioned.fill(
      child: IgnorePointer( // Ignore pointer events so it doesn't interfere with gestures
        child: Center(
          child: Transform.rotate(
            angle: -0.4, // Keep the rotation angle
            child: Text(
              text,
              style: TextStyle(
                fontSize: 24, // Keep existing font size
                fontWeight: FontWeight.bold, // Keep existing font weight
                color: watermarkColor, // Apply the fixed color and opacity
              ),
            ),
          ),
        ),
      ),
    );
  }
  // --- END Watermark Widget ---


  void _showFileInfo() {
     // Basic file info dialog
     showDialog(
       context: context,
       builder: (context) => AlertDialog(
         title: const Text("File Information"),
         content: Column(
           mainAxisSize: MainAxisSize.min,
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             _infoRow("Name", widget.fileName),
             _infoRow("Type", widget.fileType.isEmpty ? path.extension(widget.fileName) : widget.fileType),
             _infoRow("Size", _formatFileSize(_fileSize)),
             _infoRow("Status", _fileExists ? "Loaded Successfully" : "Error/Not Found"),
             if(_errorMessage.isNotEmpty) _infoRow("Error", _errorMessage),
             _infoRow("Path", "Secure App Storage (Temporary)"),
             const SizedBox(height: 16),
             const Text(
               "This file is viewed securely within the app and cannot be shared or exported.",
               style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12)
             ),
           ]
         ),
         actions: [
           TextButton(
             onPressed: () => Navigator.pop(context),
             child: const Text("Close")
           )
         ]
       )
     );
  }

  Widget _infoRow(String label, String value) {
     return Padding(
       padding: const EdgeInsets.symmetric(vertical: 4),
       child: Row(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           SizedBox(
             width: 60, // Fixed width for label
             child: Text("$label:", style: const TextStyle(fontWeight: FontWeight.bold))
           ),
           const SizedBox(width: 8),
           Expanded(child: Text(value)) // Value takes remaining space
         ]
       )
     );
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }


  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Prevent back navigation while the file is initializing/loading
      onWillPop: () async => !_isInitializing && !_isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.fileName, style: const TextStyle(fontSize: 16)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new), // Use iOS style back arrow
            onPressed: () => Navigator.pop(context),
            tooltip: "Back"
          ),
          actions: [
            // Show page number only for PDFs and when loaded
            if (_totalPages > 0 && !_isLoading && !_isInitializing && path.extension(widget.fileName).toLowerCase() == '.pdf')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Text("Page ${_currentPage + 1}/$_totalPages", style: const TextStyle(fontSize: 14)),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _showFileInfo,
              tooltip: "File Info"
            ),
          ],
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
          elevation: 1, // Subtle elevation
        ),
        // --- Use a Container to manage background color ---
        body: Container(
            color: Theme.of(context).scaffoldBackgroundColor, // Ensure background matches theme
            child: Column(
              children: [
                // Security Banner (Keep as is)
                Container(
                  width: double.infinity,
                  color: Colors.amber.shade100,
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.security, size: 16, color: Colors.amber.shade800),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Protected document - viewable only in this app",
                          style: TextStyle(fontSize: 12, color: Colors.amber.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
                // --- File Viewer Area ---
                // Use Expanded to make the viewer take remaining space
                Expanded(
                  child: Container(
                     // Set a specific background for the viewer area if needed
                     // Use a slightly different background for viewer area for contrast
                    color: Theme.of(context).brightness == Brightness.dark
                           ? Colors.black // Keep black for dark mode PDF/Image background
                           : Colors.grey[200], // Light grey for light mode viewer background
                    child: _buildFileViewer(),
                  ),
                ),
              ],
            ),
        ),
        // --- End Container ---
      ),
    );
  }
}