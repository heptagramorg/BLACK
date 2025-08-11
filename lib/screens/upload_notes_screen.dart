// lib/screens/upload_notes_screen.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import 'dart:ui'; // For ImageFilter
import '../services/supabase_service.dart';
import '../services/user_service.dart';
import 'manage_notes_screen.dart';

class UploadNotesScreen extends StatefulWidget {
  final String userId;
  const UploadNotesScreen({super.key, required this.userId});

  @override
  UploadNotesScreenState createState() => UploadNotesScreenState();
}

class UploadNotesScreenState extends State<UploadNotesScreen> {
  final _supabase = SupabaseService.client;
  final UserService _userService = UserService();
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController tagController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  List<String> tags = [];
  String? fileName;
  Uint8List? fileBytes;
  String _fileType = 'application/octet-stream';
  bool isUploading = false;
  int userStorageUsed = 0;
  static const int maxStorageLimit = 262144000; // 250MB
  bool _isPublic = false;

  @override
  void initState() {
    super.initState();
    _fetchUserStorageUsage();
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    tagController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserStorageUsage() async {
    try {
      final storage = await _userService.getUserStorageUsage(widget.userId);
      if (mounted) {
        setState(() {
          userStorageUsed = storage;
        });
      }
    } catch (e) {
      if (mounted) {
        _showMessage("Failed to fetch storage usage", isError: true);
      }
    }
  }

  Future<void> _pickDocument() async {
    try {
      final selectedType = await _showFileTypeDialog();
      if (selectedType == null) return;
      XFile? pickedFile;
      if (selectedType == 'image') {
        pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      } else {
        pickedFile = await _picker.pickMedia();
      }
      if (pickedFile == null) return;
      final String pickedFilePath = pickedFile.path;
      final String extension = pickedFilePath.split('.').last.toLowerCase();
      if (selectedType == 'pdf' && extension != 'pdf') {
        _showMessage("Invalid file selected. Please choose a PDF document.",
            isError: true);
        return;
      }
      final fileSize = await pickedFile.length();
      if (fileSize > maxStorageLimit) {
        _showMessage("File too large. Maximum file size is 250MB.",
            isError: true);
        return;
      }
      await _fetchUserStorageUsage();
      if ((userStorageUsed + fileSize) > maxStorageLimit) {
        _showMessage(
            "Uploading this file would exceed your 250MB storage limit.",
            isError: true);
        return;
      }
      final String pickedFileName = pickedFile.name;
      final String mimeType = _getMimeType(extension);
      if (mounted) {
        setState(() {
          fileName = pickedFileName;
          _fileType = mimeType;
        });
      }
      final bytes = await pickedFile.readAsBytes();
      if (mounted) {
        setState(() {
          fileBytes = bytes;
        });
        _showMessage("File '${fileName!}' loaded successfully!");
      }
    } catch (e) {
      _showMessage("Error processing file: $e", isError: true);
    }
  }

  Future<String?> _showFileTypeDialog() async {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return SimpleDialog(
          title: Text('Select File Type',
              style: TextStyle(color: theme.textTheme.titleLarge?.color)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          backgroundColor: theme.dialogTheme.backgroundColor,
          children: <Widget>[
            _buildFileTypeOption(
                context, 'PDF Document', 'pdf', Icons.picture_as_pdf_rounded),
            _buildFileTypeOption(
                context, 'Image (PNG, JPG)', 'image', Icons.image_rounded),
            _buildFileTypeOption(context, 'Other Document', 'document',
                Icons.insert_drive_file_rounded),
          ],
        );
      },
    );
  }

  Widget _buildFileTypeOption(
      BuildContext context, String title, String value, IconData icon) {
    final theme = Theme.of(context);
    return SimpleDialogOption(
      onPressed: () {
        Navigator.pop(context, value);
      },
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 16),
          Text(title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.textTheme.bodyLarge?.color)),
        ],
      ),
    );
  }

  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
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

  void _navigateToManageNotes() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => ManageNotesScreen(userId: widget.userId)),
    ).then((_) {
      if (mounted) _fetchUserStorageUsage();
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  Future<void> _uploadNote() async {
    if (titleController.text.trim().isEmpty) {
      _showMessage("Title is required!", isError: true);
      return;
    }
    if (descriptionController.text.trim().isEmpty) {
      _showMessage("Description is required!", isError: true);
      return;
    }
    if (tags.isEmpty) {
      _showMessage("At least one tag is required!", isError: true);
      return;
    }
    if (fileBytes == null) {
      _showMessage("Please select a document file.", isError: true);
      return;
    }
    if (mounted) setState(() => isUploading = true);
    String? fileUrlToSave;
    String? fileNameToSave;
    String fileTypeToSave = _fileType;
    int? fileSizeToSave;
    String? uploadedSupabaseFilePath;
    try {
      if (fileBytes != null && fileName != null) {
        final int localFileSize = fileBytes!.length;
        await _fetchUserStorageUsage();
        if ((userStorageUsed + localFileSize) > maxStorageLimit) {
          _showMessage(
              "Uploading this file would exceed your 250MB Supabase storage limit.",
              isError: true);
          if (mounted) setState(() => isUploading = false);
          return;
        }
        String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        String sanitizedLocalFileName =
            fileName!.replaceAll(RegExp(r'[^\w\s\-\.]'), '_');
        uploadedSupabaseFilePath =
            "${widget.userId}/${timestamp}_$sanitizedLocalFileName";
        await _supabase.storage.from('notes').uploadBinary(
            uploadedSupabaseFilePath, fileBytes!,
            fileOptions:
                const FileOptions(cacheControl: '3600', upsert: false));
        fileUrlToSave = _supabase.storage
            .from('notes')
            .getPublicUrl(uploadedSupabaseFilePath);
        fileNameToSave = fileName;
        fileTypeToSave = _fileType;
        fileSizeToSave = localFileSize;
        await _userService.incrementStorageUsage(widget.userId, fileSizeToSave);
      } else {
        _showMessage("No file selected.", isError: true);
        if (mounted) setState(() => isUploading = false);
        return;
      }
      await _supabase.from('notes').insert({
        'user_id': widget.userId,
        'title': titleController.text.trim(),
        'description': descriptionController.text.trim(),
        'content': descriptionController.text.trim(),
        'file_url': fileUrlToSave,
        'file_type': fileTypeToSave,
        'tags': tags,
        'file_name': fileNameToSave,
        'file_size': fileSizeToSave ?? 0,
        'is_public': _isPublic,
        'created_at': DateTime.now().toIso8601String(),
        'view_count': 0,
        'like_count': 0,
      });
      if (mounted) {
        await _fetchUserStorageUsage();
        setState(() => isUploading = false);
        _showMessage("Note uploaded successfully!");
        _resetForm();
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) setState(() => isUploading = false);
      _showMessage("Upload failed: ${e.toString()}", isError: true);
      if (uploadedSupabaseFilePath != null) {
        try {
          await _supabase.storage
              .from('notes')
              .remove([uploadedSupabaseFilePath]);
        } catch (_) {}
      }
    }
  }

  void _resetForm() {
    titleController.clear();
    descriptionController.clear();
    tagController.clear();
    if (mounted) {
      setState(() {
        tags = [];
        fileName = null;
        fileBytes = null;
        _fileType = 'application/octet-stream';
        _isPublic = false;
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
            title: const Text("Upload Successful"),
            content: const Text(
                "Your note has been uploaded. What would you like to do next?"),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Upload Another")),
              ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToManageNotes();
                  },
                  child: const Text("Manage Notes"))
            ]);
      },
    );
  }

  void _addTag() {
    final tag = tagController.text.trim().toLowerCase();
    if (tag.isNotEmpty && !tags.contains(tag)) {
      if (tags.length < 5) {
        if (mounted) {
          setState(() {
            tags.add(tag);
            tagController.clear();
          });
        }
      } else {
        _showMessage("Maximum of 5 tags allowed.", isError: true);
      }
    } else if (tag.isNotEmpty) {
      _showMessage("Tag '$tag' already added.", isError: true);
    }
  }

  void _removeTag(String tagToRemove) {
    if (mounted) {
      setState(() => tags.remove(tagToRemove));
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Colors.green.shade600,
        duration: Duration(seconds: isError ? 4 : 3),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        margin: const EdgeInsets.all(10),
      ));
    }
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 28.0, bottom: 14.0),
      child: Text(
        title,
        style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.brightness == Brightness.dark
                ? Colors.white.withAlpha(242)
                : theme.textTheme.titleLarge?.color),
      ),
    );
  }

  Widget _buildStyledCard(BuildContext context,
      {required Widget child,
      double borderRadius = 22.0,
      bool applyGradient = false,
      bool applyGlassEffect = false}) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    BoxDecoration cardDecoration;

    if (applyGradient) {
      final RadialGradient darkRadialGradient = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          theme.colorScheme.primary.withAlpha(128),
          theme.colorScheme.primary.withAlpha(51),
          Colors.black.withAlpha(179),
          Colors.black,
        ],
        stops: const [0.0, 0.25, 0.8, 1.0],
      );
      final LinearGradient lightLinearGradient = LinearGradient(
        colors: [
          theme.colorScheme.primary.withAlpha(204),
          theme.colorScheme.primary.withAlpha(128),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      cardDecoration = BoxDecoration(
        gradient: isDarkMode ? darkRadialGradient : lightLinearGradient,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withAlpha(102)
                : Colors.grey.withAlpha(38),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      );
    } else {
      cardDecoration = BoxDecoration(
        color: isDarkMode
            ? Colors.white.withAlpha(13)
            : theme.cardColor.withAlpha(217),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
            color: isDarkMode
                ? Colors.white.withAlpha(26)
                : Colors.grey.shade300.withAlpha(128),
            width: 0.5),
      );
    }

    Widget cardContent = Container(
      padding: const EdgeInsets.all(18.0),
      decoration: cardDecoration,
      child: child,
    );

    if (applyGlassEffect && !applyGradient) {
      cardContent = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
          child: cardContent,
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: (applyGlassEffect && !applyGradient)
            ? [
                BoxShadow(
                  color: isDarkMode
                      ? Colors.black.withAlpha(51)
                      : Colors.grey.withAlpha(26),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ]
            : null,
      ),
      child: cardContent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final Color onGlassTextColor = isDarkMode
        ? Colors.white.withAlpha(229)
        : theme.textTheme.bodyLarge!.color!;
    final Color onGradientTextColor = Colors.white.withAlpha(242);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text("Upload Note"),
            backgroundColor:
                isDarkMode ? Colors.black : theme.appBarTheme.backgroundColor,
            elevation: 0,
            pinned: true,
            forceElevated: false,
            scrolledUnderElevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.snippet_folder_outlined),
                tooltip: "Manage My Notes",
                onPressed: _navigateToManageNotes,
              ),
            ],
          ),
          SliverPadding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildStyledCard(
                        context,
                        applyGradient: false,
                        applyGlassEffect: true,
                        borderRadius: 22,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Storage Used",
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: onGlassTextColor)),
                                  Text(
                                      "${_formatFileSize(userStorageUsed)} / 250 MB",
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                              color: (userStorageUsed /
                                                          maxStorageLimit) >
                                                      0.9
                                                  ? theme.colorScheme.error
                                                  : onGlassTextColor
                                                      .withAlpha(204),
                                              fontWeight: FontWeight.bold))
                                ]),
                            const SizedBox(height: 10),
                            LinearProgressIndicator(
                              value: userStorageUsed / maxStorageLimit,
                              backgroundColor:
                                  (isDarkMode ? Colors.white : Colors.black)
                                      .withAlpha(26),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  (userStorageUsed / maxStorageLimit) > 0.9
                                      ? theme.colorScheme.error
                                      : theme.colorScheme.primary),
                              minHeight: 10,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ],
                        ),
                      ),
                      _buildSectionHeader("Note Details", theme),
                      TextField(
                        controller: titleController,
                        style: TextStyle(
                            color: isDarkMode
                                ? Colors.white.withAlpha(229)
                                : null),
                        decoration: InputDecoration(
                          labelText: "Title *",
                          prefixIcon: const Icon(Icons.title_rounded),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: descriptionController,
                        maxLines: 4,
                        minLines: 2,
                        style: TextStyle(
                            color: isDarkMode
                                ? Colors.white.withAlpha(229)
                                : null),
                        decoration: InputDecoration(
                          labelText: "Description / Content *",
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 40.0),
                            child: Icon(Icons.description_outlined),
                          ),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _buildSectionHeader("Settings", theme),
                      _buildStyledCard(
                        context,
                        applyGradient: false,
                        applyGlassEffect: true,
                        borderRadius: 22,
                        child: SwitchListTile(
                          title: Text("Make Note Public",
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(color: onGlassTextColor)),
                          subtitle: Text(
                              _isPublic
                                  ? "Anyone can find and view this note"
                                  : "Only you can view this note",
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: onGlassTextColor.withAlpha(179))),
                          value: _isPublic,
                          onChanged: (bool value) {
                            if (mounted) setState(() => _isPublic = value);
                          },
                          activeColor: theme.colorScheme.secondary,
                          inactiveTrackColor:
                              (isDarkMode ? Colors.white : Colors.black)
                                  .withAlpha(51),
                          secondary: Icon(
                              _isPublic
                                  ? Icons.public_rounded
                                  : Icons.lock_outline_rounded,
                              color: onGlassTextColor.withAlpha(204)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                        ),
                      ),
                      TextField(
                        controller: tagController,
                        style: TextStyle(
                            color: isDarkMode
                                ? Colors.white.withAlpha(229)
                                : null),
                        decoration: InputDecoration(
                          labelText: "Tags * (e.g., physics, exam)",
                          hintText: "Add up to 5 relevant tags",
                          prefixIcon: const Icon(Icons.label_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.add_circle_outline_rounded,
                                color: theme.colorScheme.primary),
                            onPressed: _addTag,
                            tooltip: "Add Tag",
                          ),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onSubmitted: (_) => _addTag(),
                      ),
                      if (tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12.0),
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: tags
                                .map((tag) => Chip(
                                      label: Text(tag,
                                          style: TextStyle(
                                              color: isDarkMode
                                                  ? Colors.white.withAlpha(229)
                                                  : theme.colorScheme
                                                      .onSecondaryContainer,
                                              fontSize: 13)),
                                      onDeleted: () => _removeTag(tag),
                                      deleteIconColor: theme.colorScheme.error
                                          .withAlpha(204),
                                      backgroundColor: theme
                                          .colorScheme.secondary
                                          .withAlpha(isDarkMode ? 77 : 204),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10.0)),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                    ))
                                .toList(),
                          ),
                        ),
                      _buildSectionHeader("Attach File *", theme),
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _pickDocument,
                          icon: const Icon(Icons.attach_file_rounded),
                          label: const Text("Select Local PDF/Image"),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 28, vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      if (fileName != null)
                        _buildStyledCard(
                          context,
                          applyGradient: true,
                          borderRadius: 22,
                          child: Row(children: [
                            Icon(_getIconForFileType(_fileType),
                                color: onGradientTextColor, size: 36),
                            const SizedBox(width: 16),
                            Expanded(
                                child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(fileName!,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: onGradientTextColor),
                                    overflow: TextOverflow.ellipsis),
                                if (fileBytes != null)
                                  Text(
                                      "Size: ${_formatFileSize(fileBytes!.length)}",
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                              color: onGradientTextColor
                                                  .withAlpha(191)))
                              ],
                            )),
                            IconButton(
                                icon: Icon(Icons.cancel_rounded,
                                    size: 24,
                                    color:
                                        theme.colorScheme.error.withAlpha(204)),
                                onPressed: () {
                                  if (mounted) {
                                    setState(() {
                                      fileName = null;
                                      fileBytes = null;
                                      _fileType = 'application/octet-stream';
                                    });
                                  }
                                },
                                tooltip: "Clear Selection")
                          ]),
                        ),
                      const SizedBox(height: 32),
                      Center(
                        child: isUploading
                            ? CircularProgressIndicator(
                                color: theme.colorScheme.primary)
                            : SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                    onPressed: _uploadNote,
                                    icon:
                                        const Icon(Icons.cloud_upload_rounded),
                                    label: const Text("Upload Note"),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 18),
                                      textStyle: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14)),
                                    ))),
                      ),
                      const SizedBox(height: 70),
                    ],
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForFileType(String mimeType) {
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (mimeType.contains('doc')) return Icons.description_rounded;
    if (mimeType.contains('ppt')) return Icons.slideshow_rounded;
    if (mimeType.contains('xls')) return Icons.table_chart_rounded;
    if (mimeType.contains('image')) return Icons.image_rounded;
    return Icons.insert_drive_file_rounded;
  }
}
