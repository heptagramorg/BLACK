import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'dart:io' show File, Platform, Directory;
import 'dart:async';
import 'package:path/path.dart' as path;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv

import '../services/supabase_service.dart';
import '../utils/secure_file_viewer.dart';
import 'file_loading_dialog.dart';

/// Handles secure file downloading, caching, and viewing,
/// integrating AdMob interstitial ads before displaying the file.
class SecureFileHandler {
  static final _supabase = SupabaseService.client;
  static final DefaultCacheManager _cacheManager = DefaultCacheManager();
  static int _retryCount = 0;
  static const int _maxRetries = 3;

  // --- AdMob Interstitial Ad Logic ---
  static InterstitialAd? _interstitialAd;
  static bool _isAdLoading = false;
  static bool _isAdReady = false;

  // The hardcoded production Ad Unit ID has been removed from here.
  // It will now be loaded from your .env file.

  static String get _adUnitId {
    // MODIFIED: Load the Ad Unit ID from .env using the key
    final adUnitId = dotenv.env['ADMOB_INTERSTITIAL_AD_SECURE_FILE'];

    if (adUnitId == null || adUnitId.isEmpty) {
      return ''; // Return empty string to prevent loading and potential crashes
    }

    return adUnitId;
  }

  /// Loads an interstitial ad from AdMob.
  static void _loadInterstitialAd() {
    if (_isAdLoading || _isAdReady) {
      return;
    }

    final String effectiveAdUnitId = _adUnitId;
    if (effectiveAdUnitId.isEmpty) {
      return;
    }

    _isAdLoading = true;
    _isAdReady = false;

    InterstitialAd.load(
      adUnitId: effectiveAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd?.dispose();
          _interstitialAd = ad;
          _isAdReady = true;
          _isAdLoading = false;
        },
        onAdFailedToLoad: (LoadAdError error) {
          _interstitialAd?.dispose();
          _interstitialAd = null;
          _isAdReady = false;
          _isAdLoading = false;
        },
      ),
    );
  }

  /// Sets up the necessary FullScreenContentCallback for the ad instance.
  static void _setupAdCallbacks(Function onAdDismissedOrFailed) {
    if (_interstitialAd == null) {
      onAdDismissedOrFailed();
      _loadInterstitialAd();
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (InterstitialAd ad) {},
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        _isAdReady = false;
        ad.dispose();
        _interstitialAd = null;
        onAdDismissedOrFailed();
        _loadInterstitialAd();
      },
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        _isAdReady = false;
        ad.dispose();
        _interstitialAd = null;
        onAdDismissedOrFailed();
        _loadInterstitialAd();
      },
      onAdImpression: (InterstitialAd ad) {},
      onAdClicked: (InterstitialAd ad) {},
    );
  }

  /// Attempts to show the loaded interstitial ad.
  static void _showAdThenExecute(Function onAdDismissedOrFailed) {
    if (_interstitialAd != null && _isAdReady) {
      _setupAdCallbacks(onAdDismissedOrFailed);
      _interstitialAd!.show();
      _isAdReady = false;
    } else {
      onAdDismissedOrFailed();
      if (!_isAdLoading && !_isAdReady) {
        _loadInterstitialAd();
      }
    }
  }

  /// Disposes the current interstitial ad instance to free resources.
  static void disposeAd() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isAdReady = false;
    _isAdLoading = false;
  }

  /// Shows a message (Snackbar) to the user.
  static void _showMessage(BuildContext context, String message,
      {bool isError = true}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
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

  /// Main public method to open a file securely.
  static Future<bool> openFile(BuildContext context, String fileUrl,
      String fileName,
      [String fileType = '', String noteId = '', String userId = '']) async {
    _loadInterstitialAd();

    try {
      if (fileUrl.isEmpty) throw Exception('File URL is empty');
      if (fileName.isEmpty) fileName = 'document';
      String finalUserId = userId.trim().isEmpty
          ? (SupabaseService.currentUserId ?? "")
          : userId.trim();
      if (finalUserId.isEmpty) {
        if (context.mounted) {
          _showMessage(context, "Login required to view notes.",
              isError: true);
        }
        return false;
      }

      final Uri uri = Uri.parse(fileUrl);
      final segments = uri.pathSegments;
      final int notesIndex = segments.indexOf('notes');
      if (notesIndex == -1 || notesIndex + 1 >= segments.length) {
        throw Exception(
            'Invalid file URL format (cannot find "notes" bucket or path).');
      }
      final String filePath = segments.sublist(notesIndex + 1).join('/');
      if (filePath.isEmpty || filePath.contains('//') || filePath.endsWith('/')) {
        throw Exception('Invalid extracted file path: "$filePath"');
      }
      final signedUrl =
          await _supabase.storage.from('notes').createSignedUrl(filePath, 3600);

      _retryCount = 0;
      if (!context.mounted) return false;
      return await _attemptFileOpenInternal(
          context, signedUrl, fileName, fileType, noteId, finalUserId);
    } catch (e) {
      if (context.mounted) {
        _showMessage(context, "Error preparing file view: ${e.toString()}");
      }
      return false;
    }
  }

  /// Internal method: Downloads file, shows ad, then navigates to viewer.
  static Future<bool> _attemptFileOpenInternal(
      BuildContext context,
      String signedFileUrl,
      String fileName,
      String fileType,
      String noteId,
      String userId) async {
    String? localFilePath;
    try {
      final Future<String?> downloadFuture =
          _downloadAndPrepareFile(signedFileUrl, fileName);

      final bool fileLoadingSuccess = await FileLoadingDialog.show(
        context: context,
        loadingFuture: downloadFuture,
        fileName: fileName,
        retryCount: _retryCount,
        maxRetries: _maxRetries,
        retryDelay: Duration(seconds: _retryCount + 1),
      );

      if (!context.mounted) return false;

      if (!fileLoadingSuccess) {
        return false;
      }

      localFilePath = await downloadFuture;
      if (localFilePath == null) {
        throw Exception("File download reported success but path is null.");
      }

      void navigateToFileViewer() {
        if (!context.mounted) {
          if (localFilePath != null) {
            try {
              File(localFilePath).deleteSync();
            } catch (_) {}
          }
          return;
        }
        try {
          final finalFileType =
              fileType.isEmpty ? getMimeType(fileName) : fileType;
          final safeNoteId = noteId.trim().isEmpty ? "" : noteId.trim();

          _logFileAccess(signedFileUrl, fileName, userId, safeNoteId);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SecureFileViewer(
                filePath: localFilePath!,
                fileName: fileName,
                fileType: finalFileType,
                userId: userId,
                noteId: safeNoteId,
              ),
            ),
          );
        } catch (navError) {
          if (context.mounted) {
            _showMessage(context, "Error displaying file: $navError");
          }
          if (localFilePath != null) {
            try {
              File(localFilePath).deleteSync();
            } catch (_) {}
          }
        }
      }

      _showAdThenExecute(navigateToFileViewer);
      return true;
    } catch (e) {
      if (context.mounted) _showMessage(context, "Error opening file: $e");
      if (localFilePath != null) {
        try {
          File(localFilePath).deleteSync();
        } catch (_) {}
      }
      return false;
    }
  }

  /// Downloads file using signed URL or retrieves from cache.
  static Future<String?> _downloadAndPrepareFile(
      String signedFileUrl, String fileName) async {
    try {
      if (!signedFileUrl.startsWith('http')) {
        throw Exception('Invalid Signed URL format.');
      }

      final cacheFile = await _cacheManager.getFileFromCache(signedFileUrl);
      if (cacheFile != null && await cacheFile.file.exists()) {
        return cacheFile.file.path;
      }

      final response = await http.get(
        Uri.parse(signedFileUrl),
        headers: {
          'Accept': '*/*',
          'User-Agent': 'BlackApp/1.0',
          'Connection': 'keep-alive',
        },
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        if (response.statusCode == 403) {
          throw Exception(
              'Access denied via signed URL (Expired/Invalid?). Code: 403');
        }
        if (response.statusCode == 404) {
          throw Exception('File not found at signed URL. Code: 404');
        }
        throw Exception('Download failed: HTTP ${response.statusCode}');
      }
      if (response.bodyBytes.isEmpty) throw Exception('Downloaded file is empty');

      final fileExtension = path.extension(fileName).isNotEmpty
          ? path.extension(fileName)
          : '.${getMimeType(fileName).split('/').last}';
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final tempFileName =
          'secure_${timestamp}_${fileName.hashCode}${fileExtension.toLowerCase()}';
      final tempDir = await getTemporaryDirectory();
      final filePath = path.join(tempDir.path, tempFileName);

      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      if (!await file.exists() || await file.length() == 0) {
        throw Exception('Failed to save or verify local file at $filePath');
      }

      await _cacheManager.putFile(
        signedFileUrl,
        response.bodyBytes,
        key: signedFileUrl,
        maxAge: const Duration(minutes: 55),
      );

      return filePath;
    } catch (e) {
      rethrow;
    }
  }

  /// Determines MIME type from file path or name.
  static String getMimeType(String filePathOrName) {
    final extension =
        path.extension(filePathOrName).toLowerCase().replaceAll('.', '');
    switch (extension) {
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

  /// Cleans up cached files and temporary secure files created by this handler.
  static Future<void> cleanupCache() async {
    try {
      await _cacheManager.emptyCache();
      final tempDir = await getTemporaryDirectory();
      final directory = Directory(tempDir.path);
      if (await directory.exists()) {
        await for (final entity in directory.list()) {
          if (entity is File &&
              path.basename(entity.path).startsWith('secure_')) {
            try {
              await entity.delete();
            } catch (e) {
              // Silently ignore deletion errors
            }
          }
        }
      }
    } catch (e) {
      // Silently ignore cache cleaning errors
    }
  }

  /// Logs file access attempts for auditing purposes.
  static Future<void> _logFileAccess(
      String fileUrl, String fileName, String userId, String noteId) async {
    try {
      if (userId.isEmpty) return;
      await _supabase.from('file_access_logs').insert({
        'user_id': userId,
        'file_url': fileUrl,
        'file_name': fileName,
        'note_id': noteId.trim().isEmpty ? null : noteId.trim(),
        'access_time': DateTime.now().toIso8601String(),
        'device_info': Platform.operatingSystem,
        'action': 'view_attempt'
      });
    } catch (e) {
      // Silently ignore logging errors
    }
  }
}
