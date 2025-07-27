import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

class DocumentPreviewWidget extends StatelessWidget {
  final String filePath;
  final String fileName;

  const DocumentPreviewWidget({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    final fileExtension = path.extension(fileName).toLowerCase().replaceAll('.', '');
    final File file = File(filePath);

    // Get file size
    int fileSize = 0;
    try {
      fileSize = file.lengthSync();
    } catch (e) {
      // Error getting file size is handled silently.
    }

    // Configure document type-specific styling
    IconData fileIcon;
    String fileTypeLabel;
    Color themeColor;

    if (fileExtension.contains('doc')) {
      fileIcon = Icons.description;
      fileTypeLabel = "Word Document";
      themeColor = Colors.blue;
    } else if (fileExtension.contains('ppt')) {
      fileIcon = Icons.slideshow;
      fileTypeLabel = "PowerPoint Presentation";
      themeColor = Colors.orange;
    } else if (fileExtension.contains('xls')) {
      fileIcon = Icons.table_chart;
      fileTypeLabel = "Excel Spreadsheet";
      themeColor = Colors.green;
    } else {
      fileIcon = Icons.insert_drive_file;
      fileTypeLabel = "Document";
      themeColor = Colors.blue;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Document icon and info
          Icon(fileIcon, size: 80, color: themeColor),
          const SizedBox(height: 16),
          Text(
            fileName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          Text(
            fileTypeLabel,
            style: TextStyle(color: themeColor, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            formatFileSize(fileSize),
            style: TextStyle(color: Colors.grey[600]),
          ),

          const SizedBox(height: 40),
          const Divider(),
          const SizedBox(height: 20),

          // Content placeholder
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Showing document preview or placeholder
                buildDocumentPreview(fileExtension, themeColor),

                const SizedBox(height: 30),

                // Security notice
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Document Information",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      infoRow("Type", fileTypeLabel),
                      infoRow("Size", formatFileSize(fileSize)),
                      const SizedBox(height: 16),
                      // Security notice
                      Row(
                        children: [
                          Icon(Icons.security,
                              color: Colors.grey[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "This document is protected and can only be viewed within this app",
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build a document preview based on file type
  Widget buildDocumentPreview(String fileExtension, Color themeColor) {
    if (fileExtension.contains('doc')) {
      return buildWordDocPreview(themeColor);
    } else if (fileExtension.contains('ppt')) {
      return buildPowerPointPreview(themeColor);
    } else if (fileExtension.contains('xls')) {
      return buildExcelPreview(themeColor);
    } else {
      return buildGenericDocPreview(themeColor);
    }
  }

  // Word document preview
  Widget buildWordDocPreview(Color themeColor) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: themeColor.withAlpha(26),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: themeColor.withAlpha(51)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.description, color: themeColor),
                  const SizedBox(width: 8),
                  Text(
                    "Word Document Preview",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: themeColor,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                "This document is being securely viewed within the app. For security and copyright protection, a full rendering is not available.",
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.5),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Document content preview
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withAlpha(77)),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 8),

              // Mimic paragraphs
              for (int i = 0; i < 4; i++) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Add a "watermark" overlay
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: themeColor.withAlpha(26),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Transform.rotate(
                    angle: -0.1,
                    child: Text(
                      "PROTECTED CONTENT",
                      style: TextStyle(
                        color: themeColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // More paragraph placeholders
              for (int i = 0; i < 3; i++) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // PowerPoint preview
  Widget buildPowerPointPreview(Color themeColor) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: themeColor.withAlpha(26),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: themeColor.withAlpha(51)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.slideshow, color: themeColor),
                  const SizedBox(width: 8),
                  Text(
                    "PowerPoint Preview",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: themeColor,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                "This presentation is being securely viewed within the app. For security and copyright protection, a full rendering is not available.",
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.5),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Slide preview
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withAlpha(77)),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(24),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 32,
                      decoration: BoxDecoration(
                        color: themeColor.withAlpha(51),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Bullet points
                    for (int i = 0; i < 3; i++) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "• ",
                            style: TextStyle(
                              color: themeColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.only(top: 8),
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),

                // Watermark in the center of the slide
                Center(
                  child: Transform.rotate(
                    angle: -0.2,
                    child: Text(
                      "PROTECTED CONTENT",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: themeColor.withAlpha(51),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Page selector
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: themeColor),
              onPressed: null, // Disabled
            ),
            Text(
              "Slide 1 of X",
              style: TextStyle(fontWeight: FontWeight.bold, color: themeColor),
            ),
            IconButton(
              icon: Icon(Icons.arrow_forward, color: themeColor),
              onPressed: null, // Disabled
            ),
          ],
        ),
      ],
    );
  }

  // Excel preview
  Widget buildExcelPreview(Color themeColor) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: themeColor.withAlpha(26),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: themeColor.withAlpha(51)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.table_chart, color: themeColor),
                  const SizedBox(width: 8),
                  Text(
                    "Excel Spreadsheet Preview",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: themeColor,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                "This spreadsheet is being securely viewed within the app. For security and copyright protection, a full rendering is not available.",
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.5),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Table preview
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withAlpha(128)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: [
              // Header row
              Container(
                padding: const EdgeInsets.all(8),
                color: themeColor.withAlpha(51),
                child: Row(
                  children: [
                    for (int i = 0; i < 4; i++)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border:
                                Border.all(color: Colors.grey.withAlpha(77)),
                            color: themeColor.withAlpha(26),
                          ),
                          child: Center(
                            child: Container(
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Data rows
              for (int row = 0; row < 6; row++)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.withAlpha(77)),
                    ),
                  ),
                  child: Row(
                    children: [
                      for (int col = 0; col < 4; col++)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.grey.withAlpha(51)),
                            ),
                            child: Center(
                              child: Container(
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Watermark
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: themeColor.withAlpha(26),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Transform.rotate(
              angle: -0.1,
              child: Text(
                "PROTECTED CONTENT",
                style: TextStyle(
                  color: themeColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Generic document preview
  Widget buildGenericDocPreview(Color themeColor) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: themeColor.withAlpha(26),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: themeColor.withAlpha(51)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.file_present, color: themeColor),
                  const SizedBox(width: 8),
                  Text(
                    "Document Preview",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: themeColor,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                "This document is being securely viewed within the app. For security and copyright protection, a full rendering is not available.",
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.5),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Generic content preview
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withAlpha(77)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title placeholder
              Container(
                width: double.infinity,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 20),

              // Content placeholders
              for (int i = 0; i < 5; i++) ...[
                Container(
                  width: double.infinity,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              const SizedBox(height: 16),

              // Center watermark
              Center(
                child: Transform.rotate(
                  angle: -0.2,
                  child: Text(
                    "PROTECTED CONTENT",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: themeColor.withAlpha(51),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // More content placeholders
              for (int i = 0; i < 3; i++) ...[
                Container(
                  width: double.infinity,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String formatFileSize(int bytes) {
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
}
