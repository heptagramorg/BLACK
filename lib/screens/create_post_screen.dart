// lib/screens/create_post_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class CreatePostScreen extends StatelessWidget {
  final String userId;

  const CreatePostScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final supabase = SupabaseService.client;
    bool isSubmitting = false; // To prevent double taps

    return Scaffold(
      appBar: AppBar(title: const Text("Create Post")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: "Title",
                hintText: "Enter a clear and concise title",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: "Description / Content",
                hintText: "Share your thoughts or question...",
                border: OutlineInputBorder(),
              ),
              maxLines: 5, // Allow more lines for content
            ),
            const SizedBox(height: 24), // Increased spacing
            StatefulBuilder(
                // Use StatefulBuilder for the button's loading state
                builder: (BuildContext context, StateSetter setState) {
              return SizedBox(
                // Ensure button stretches
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    // Consider using Theme's primary color
                    // backgroundColor: Theme.of(context).colorScheme.primary,
                    // foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (titleController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Title cannot be empty!"),
                                  backgroundColor: Colors.orange),
                            );
                            return;
                          }
                          // Optional: Check description length if needed
                          // if (descriptionController.text.trim().isEmpty) { ... }

                          setState(() => isSubmitting = true); // Disable button

                          try {
                            // *** CORRECTED INSERT STATEMENT ***
                            await supabase.from('forum_posts').insert({
                              'user_id': userId,
                              'title': titleController.text.trim(),
                              'content': descriptionController.text.trim(),
                              'description': descriptionController.text
                                  .trim(), // Keep if needed, else remove
                              'upvotes': 0, // Initialize new upvotes column
                              'downvotes': 0, // Initialize new downvotes column
                              // 'likes': 0, <-- REMOVED old likes column
                              'created_at': DateTime.now().toIso8601String(),
                            });
                            // *** END CORRECTION ***

                            // Check if context is still mounted before navigating/showing snackbar
                            if (!context.mounted) return;

                            Navigator.pop(context,
                                true); // Go back to forum screen and indicate success

                            // Show success message
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Post created successfully!"),
                                  backgroundColor: Colors.green),
                            );
                          } catch (e) {
                            // Check if context is still mounted before showing snackbar
                            if (!context.mounted) return;

                            // Detailed error handling
                            String errorMessage = "Error creating post.";
                            if (e is PostgrestException) {
                              errorMessage =
                                  "Error creating post: ${e.message}";
                            } else {
                              errorMessage =
                                  "Error creating post: ${e.toString()}";
                            }
                            if (e.toString().contains('permission-denied')) {
                              errorMessage =
                                  "You don't have permission to create posts. Make sure you're signed in.";
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(errorMessage),
                                  backgroundColor: Colors.red),
                            );
                          } finally {
                            // Re-enable button regardless of success or failure
                            // Check mounted status again in case widget disposed during async operation
                            if (context.mounted) {
                              setState(() => isSubmitting = false);
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text("Create Post",
                          style: TextStyle(fontSize: 16)),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
