import 'package:flutter/material.dart';
import 'dart:async';

class FileLoadingDialog extends StatefulWidget {
  final Future<void> loadingFuture;
  final String fileName;
  final int retryCount;
  final int maxRetries;
  final Duration retryDelay;

  const FileLoadingDialog({
    Key? key,
    required this.loadingFuture,
    required this.fileName,
    this.retryCount = 0,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 2),
  }) : super(key: key);

  @override
  State<FileLoadingDialog> createState() => _FileLoadingDialogState();

  /// Shows a loading dialog that automatically handles errors and dismisses itself
  static Future<bool> show({
    required BuildContext context,
    required Future<void> loadingFuture,
    required String fileName,
    int retryCount = 0,
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    bool result = true;

    // Show the dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => FileLoadingDialog(
        loadingFuture: loadingFuture,
        fileName: fileName,
        retryCount: retryCount,
        maxRetries: maxRetries,
        retryDelay: retryDelay,
      ),
    );

    // Wait for the future to complete
    try {
      await loadingFuture;
    } catch (e) {
      result = false;
      // Error is handled by the dialog itself
    }

    return result;
  }
}

class _FileLoadingDialogState extends State<FileLoadingDialog> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = "An error occurred while loading the file.";
  String _errorDetails = "";
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _handleLoading();
  }

  Future<void> _handleLoading() async {
    try {
      await widget.loadingFuture;

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Close dialog automatically after successful load
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();
        String errorDetails = "";

        // Format HTTP error messages more clearly
        if (errorMessage.contains("400")) {
          errorMessage = "Failed to load file";
          errorDetails =
              "The server rejected the request (Error 400). The file may not be available.";
        } else if (errorMessage.contains("403")) {
          errorMessage = "Access denied";
          errorDetails =
              "You don't have permission to access this file (Error 403).";
        } else if (errorMessage.contains("404")) {
          errorMessage = "File not found";
          errorDetails =
              "The requested file could not be found on the server (Error 404).";
        } else if (errorMessage.contains("timeout")) {
          errorMessage = "Connection timeout";
          errorDetails =
              "The server took too long to respond. Please check your internet connection.";
        } else if (errorMessage.contains("connection refused") ||
            errorMessage.contains("network is unreachable")) {
          errorMessage = "Network error";
          errorDetails =
              "Could not connect to the server. Please check your internet connection.";
        }

        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = errorMessage;
          _errorDetails = errorDetails;
        });

        // Don't close dialog automatically on error
        // User needs to press "Try Again" or "Cancel"
      }
    }
  }

  void _retryLoading() {
    if (widget.retryCount >= widget.maxRetries) {
      // Max retries reached, show a different message
      setState(() {
        _errorMessage = "Maximum retry attempts reached";
        _errorDetails =
            "Please try again later or contact support if the problem persists.";
      });
      return;
    }

    setState(() {
      _isRetrying = true;
      _errorMessage = "Retrying...";
      _errorDetails =
          "Attempt ${widget.retryCount + 1} of ${widget.maxRetries}";
    });

    // For simplicity, we'll close this dialog and let the caller handle reopening it
    // with an incremented retry count after a delay
    Future.delayed(const Duration(seconds: 1), () {
      Navigator.of(context).pop(false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? const Color(0xFF2A2A2A) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoading) ...[
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  color: Colors.purple,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Preparing file for viewing...",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.fileName,
                style: TextStyle(
                  fontSize: 14,
                  color: textColor.withOpacity(0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ] else if (_hasError) ...[
              _isRetrying
                  ? const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        color: Colors.orange,
                        strokeWidth: 3,
                      ),
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.error_outline,
                        size: 36,
                        color: Colors.red,
                      ),
                    ),
              const SizedBox(height: 20),
              Text(
                _errorMessage,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              if (_errorDetails.isNotEmpty) ...[
                Text(
                  _errorDetails,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 24),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isRetrying ? null : _retryLoading,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(_isRetrying ? "Retrying..." : "Try Again"),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
