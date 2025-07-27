import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:photo_view/photo_view.dart';
import '../services/supabase_service.dart' as app_supabase;
import 'file_loading_dialog.dart';

class InAppFileViewer {
  static final _supabase = app_supabase.SupabaseService.client;
  static int _retryCount = 0;
  static const int _maxRetries = 3;

  /// Open a file securely in the app
  static Future<void> openFile(BuildContext context, String fileUrl, String fileName) async {
    try {
      // Extract the path from the URL
      final Uri uri = Uri.parse(fileUrl);
      final segments = uri.pathSegments;
      
      // Find the notes bucket in the path
      final int notesIndex = segments.indexOf('notes');
      if (notesIndex == -1 || notesIndex + 1 >= segments.length) {
        throw Exception('Invalid file URL format. Cannot extract file path.');
      }
      
      // Get path after the 'notes' segment
      final String path = segments.sublist(notesIndex + 1).join('/');
      print("Extracted file path: $path");
      
      // Create a fresh signed URL with 1-hour expiration
      final signedUrl = await _supabase
          .storage
          .from('notes')
          .createSignedUrl(path, 60 * 60);
      
      print("Generated signed URL: $signedUrl");
      
      // Now proceed with the file opening process using the signed URL
      _retryCount = 0;
      await _attemptFileOpen(context, signedUrl, fileName);
    } catch (e) {
      print("Error preparing file URL: $e");
      if (context.mounted) {
        _showErrorSnackbar(context, "Error preparing file: $e");
      }
    }
  }
  
  /// Attempt to open a file with retry logic
  static Future<void> _attemptFileOpen(BuildContext context, String fileUrl, String fileName) async {
    // Create loading future
    final Future<DownloadResult> loadingFuture = _downloadFile(fileUrl, fileName);
    
    // Show loading dialog with our new component
    final bool loadingSuccess = await FileLoadingDialog.show(
      context: context,
      loadingFuture: loadingFuture,
      fileName: fileName,
      retryCount: _retryCount,
      maxRetries: _maxRetries,
      retryDelay: Duration(seconds: _retryCount + 1), // Exponential backoff
    );
    
    // If loading failed, check if we should retry
    if (!loadingSuccess) {
      if (_retryCount < _maxRetries) {
        _retryCount++;
        // Try again with exponential backoff
        await Future.delayed(Duration(seconds: _retryCount));
        if (context.mounted) {
          await _attemptFileOpen(context, fileUrl, fileName);
        }
        return;
      } else {
        // Max retries reached, show an error
        if (context.mounted) {
          _showErrorSnackbar(context, "Maximum retry attempts reached. Please try again later.");
        }
        return;
      }
    }
    
    try {
      // Get the downloaded file info from the completed future
      final downloadResult = await loadingFuture;
      final tempFilePath = downloadResult.filePath;
      final fileExtension = downloadResult.fileExtension;
      
      // Open appropriate viewer based on file type
      if (context.mounted) {
        if (fileExtension == 'pdf') {
          await _openPdfViewer(context, tempFilePath, fileName);
        } else if (['jpg', 'jpeg', 'png', 'gif'].contains(fileExtension)) {
          await _openImageViewer(context, tempFilePath, fileName);
        } else {
          await _openGenericFileViewer(context, tempFilePath, fileName, _getMimeType(fileExtension));
        }
      }
      
      // Log file access
      _logFileAccess(fileUrl, fileName);
      
    } catch (e) {
      print("Error in openFile: $e");
      
      if (context.mounted) {
        _showErrorSnackbar(context, "Error loading file: $e");
      }
    }
  }
  
  /// Download the file and return its info - this wraps the download process for the loading dialog
  static Future<DownloadResult> _downloadFile(String fileUrl, String fileName) async {
    try {
      print("Opening file: $fileUrl");
      print("File name: $fileName");
      
      // Validate URL
      if (!fileUrl.startsWith('http')) {
        throw Exception('Invalid URL format. URL must start with http:// or https://');
      }
      
      if (fileUrl.contains('/null/') || fileUrl.contains('null.null')) {
        throw Exception('Invalid file URL. The file path contains null values.');
      }
      
      // Get file extension
      final fileExtension = path.extension(fileName).toLowerCase().replaceAll('.', '');
      if (fileExtension.isEmpty) {
        print("Warning: File extension not found in filename: $fileName");
      }
      
      // Download file to temporary location
      final tempDir = await getTemporaryDirectory();
      final tempFileName = 'temp_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final tempFilePath = '${tempDir.path}/$tempFileName';
      
      print("Downloading file to: $tempFilePath");
      
      // Download with proper headers and error handling
      final response = await http.get(
        Uri.parse(fileUrl),
        headers: {
          'Accept': '*/*',
          'User-Agent': 'BlackApp/1.0',
          'Connection': 'keep-alive',
          'Authorization': 'Bearer ${_supabase.auth.currentSession?.accessToken}',
        },
      ).timeout(const Duration(seconds: 30));
      
      // Handle HTTP errors explicitly
      if (response.statusCode == 400) {
        throw Exception('The server rejected the request (Error 400). The file may not be available.');
      } else if (response.statusCode == 401) {
        throw Exception('Authentication required to access this file (Error 401).');
      } else if (response.statusCode == 403) {
        throw Exception('You do not have permission to access this file (Error 403).');
      } else if (response.statusCode == 404) {
        throw Exception('The requested file could not be found on the server (Error 404).');
      } else if (response.statusCode != 200) {
        throw Exception('Failed to download file: HTTP Status ${response.statusCode}');
      }
      
      if (response.bodyBytes.isEmpty) {
        throw Exception('Downloaded file is empty');
      }
      
      // Save file to temporary location
      final file = File(tempFilePath);
      await file.writeAsBytes(response.bodyBytes);
      
      // Verify file was created and has content
      if (!await file.exists()) {
        throw Exception('Failed to create local file');
      }
      
      final fileSize = await file.length();
      if (fileSize == 0) {
        throw Exception('Created file is empty');
      }
      
      print("File saved to: $tempFilePath with size $fileSize bytes");
      
      return DownloadResult(
        filePath: tempFilePath,
        fileExtension: fileExtension.isEmpty ? 'bin' : fileExtension,
        fileSize: fileSize
      );
    } catch (e) {
      print("Error downloading file: $e");
      // Rethrow the error to be handled by the loading dialog
      rethrow;
    }
  }
  
  /// Show error snackbar
  static void _showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
  
  /// Open PDF viewer
  static Future<void> _openPdfViewer(BuildContext context, String filePath, String fileName) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(fileName),
          ),
          body: Stack(
            children: [
              PDFView(
                filePath: filePath,
                enableSwipe: true,
                swipeHorizontal: true,
                autoSpacing: true,
                pageFling: true,
                onError: (error) {
                  print("PDF Error: $error");
                  _showErrorSnackbar(context, "Error loading PDF: $error");
                },
                onPageError: (page, error) {
                  print("PDF Page Error on page $page: $error");
                },
              ),
              // Watermark overlay
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Opacity(
                      opacity: 0.15,
                      child: Transform.rotate(
                        angle: -0.3,
                        child: Text(
                          "Protected Document",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Open image viewer
  static Future<void> _openImageViewer(BuildContext context, String filePath, String fileName) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(fileName),
          ),
          body: Stack(
            children: [
              PhotoView(
                imageProvider: FileImage(File(filePath)),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
                backgroundDecoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                ),
                loadingBuilder: (context, event) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  print("Error in PhotoView: $error");
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.broken_image, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          "Failed to load image: $error",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  );
                },
              ),
              // Watermark overlay
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Opacity(
                      opacity: 0.15,
                      child: Transform.rotate(
                        angle: -0.3,
                        child: Text(
                          "Uploaded In Black",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Open generic file viewer for other file types
  static Future<void> _openGenericFileViewer(BuildContext context, String filePath, String fileName, String fileType) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(fileName),
          ),
          body: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getFileIcon(fileType),
                      size: 80,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      fileName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatFileSize(File(filePath).lengthSync()),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.yellow.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.yellow.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.info_outline, color: Colors.amber[700], size: 20),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  "File has been securely downloaded",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "This file type requires additional plugins for preview.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "The file is only accessible within this app and cannot be shared externally.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  /// Determine MIME type from file extension
  static String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  /// Get icon for file type
  static IconData _getFileIcon(String fileType) {
    if (fileType.contains('pdf')) {
      return Icons.picture_as_pdf;
    } else if (fileType.contains('doc')) {
      return Icons.description;
    } else if (fileType.contains('ppt')) {
      return Icons.slideshow;
    } else if (fileType.contains('xls')) {
      return Icons.table_chart;
    } else if (fileType.contains('image')) {
      return Icons.image;
    } else {
      return Icons.insert_drive_file;
    }
  }

  /// Format file size
  static String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1048576) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1073741824) {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
    }
  }

  /// Log file access for analytics and security
  static Future<void> _logFileAccess(String fileUrl, String fileName) async {
    try {
      final currentUserId = app_supabase.SupabaseService.currentUserId;
      if (currentUserId != null) {
        await _supabase.from('file_access_logs').insert({
          'user_id': currentUserId,
          'user_email': app_supabase.SupabaseService.currentUser?.email,
          'file_url': fileUrl,
          'file_name': fileName,
          'access_time': DateTime.now().toIso8601String(),
          'device_info': Platform.operatingSystem,
          'action': 'view',
        });
      }
    } catch (e) {
      print("Error logging file access: $e");
    }
  }

  /// Clean up temporary files
  static Future<void> cleanupTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();
      for (var file in files) {
        if (file is File && file.path.contains('temp_')) {
          try {
            await file.delete();
            print("Deleted temporary file: ${file.path}");
          } catch (e) {
            print("Error deleting temp file: $e");
          }
        }
      }
    } catch (e) {
      print("Error cleaning up temp files: $e");
    }
  }
}

/// Class to hold the download result information
class DownloadResult {
  final String filePath;
  final String fileExtension;
  final int fileSize;
  
  DownloadResult({
    required this.filePath,
    required this.fileExtension,
    required this.fileSize,
  });
}