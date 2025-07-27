import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/supabase_service.dart';

/// Helper class for managing profile pictures with proper cleanup
class ProfilePictureHandler {
  static final _supabase = SupabaseService.client;
  
  /// Upload a new profile picture and delete the old one
  static Future<String?> uploadProfilePicture(
    String userId, 
    String? oldProfilePictureUrl,
    ImagePicker picker,
    Function(bool) setUploading,
    Function(String, {bool isError}) showMessage,
  ) async {
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return null;

      setUploading(true);

      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = '$userId/$fileName';

      // Upload to Supabase Storage
      final fileBytes = await image.readAsBytes();
      
      // Upload the new image
      final uploadResponse = await _supabase
          .storage
          .from('profile_pictures')
          .uploadBinary(filePath, fileBytes);

      if (uploadResponse.contains('error')) {
        throw Exception('Failed to upload image');
      }

      // Get the public URL
      final String imageUrl = _supabase
          .storage
          .from('profile_pictures')
          .getPublicUrl(filePath);

      // Delete old profile picture if it exists
      if (oldProfilePictureUrl != null && oldProfilePictureUrl.isNotEmpty) {
        await _deleteOldProfilePicture(oldProfilePictureUrl);
      }

      // Update user profile with new image URL
      final updates = {
        'profile_picture': imageUrl,
      };
      
      await _supabase
          .from('profiles')
          .update(updates)
          .eq('id', userId);

      setUploading(false);
      showMessage("✅ Profile picture updated!");
      
      return imageUrl;
    } catch (e) {
      print("Detailed profile picture upload error: $e");
      setUploading(false);
      showMessage("❌ Error uploading image: $e", isError: true);
      return null;
    }
  }

  /// Delete old profile picture from storage
  static Future<void> _deleteOldProfilePicture(String oldProfilePictureUrl) async {
    try {
      print("Attempting to delete old profile picture: $oldProfilePictureUrl");
      
      // Extract path from URL
      final String? oldFilePath = _extractStoragePathFromUrl(oldProfilePictureUrl);
      
      if (oldFilePath != null) {
        // Delete the old file
        await _supabase.storage.from('profile_pictures').remove([oldFilePath]);
        print("Successfully deleted old profile picture: $oldFilePath");
      } else {
        print("Could not extract path from old profile picture URL: $oldProfilePictureUrl");
      }
    } catch (e) {
      print("Error deleting old profile picture: $e");
      // Continue even if deletion fails
    }
  }

  /// Extract storage path from a Supabase storage URL
  static String? _extractStoragePathFromUrl(String url) {
    try {
      print("Extracting path from URL: $url");
      
      // Parse URL and extract path components
      final Uri uri = Uri.parse(url);
      
      // Look for 'profile_pictures' in the path segments
      final List<String> pathSegments = uri.pathSegments;
      
      // Find the index of 'storage' and 'profile_pictures' in the path
      int storageIndex = pathSegments.indexOf('storage');
      int objectIndex = pathSegments.indexOf('object');
      int profilePicturesIndex = pathSegments.indexOf('profile_pictures');
      
      // Debug information
      print("Path segments: $pathSegments");
      print("Storage index: $storageIndex");
      print("Object index: $objectIndex");
      print("Profile pictures index: $profilePicturesIndex");
      
      // Different ways to extract the path based on URL format
      if (profilePicturesIndex != -1 && profilePicturesIndex < pathSegments.length - 1) {
        // Start from after 'profile_pictures'
        return pathSegments.sublist(profilePicturesIndex + 1).join('/');
      }
      else if (storageIndex != -1 && objectIndex != -1 && objectIndex < pathSegments.length - 1) {
        // The path might be after 'object' in the URL
        int startIndex = objectIndex + 1;
        
        // Find the bucket name position
        int bucketPos = pathSegments.indexOf('profile_pictures', startIndex);
        if (bucketPos != -1 && bucketPos < pathSegments.length - 1) {
          return pathSegments.sublist(bucketPos + 1).join('/');
        }
      }
      
      // Direct extraction method as fallback
      // This handles URLs like: https://abc.supabase.co/storage/v1/object/public/profile_pictures/userid/file.jpg
      if (url.contains('/profile_pictures/')) {
        final parts = url.split('/profile_pictures/');
        if (parts.length > 1) {
          return parts[1];
        }
      }
      
      return null;
    } catch (e) {
      print("Error extracting storage path: $e");
      return null;
    }
  }
}