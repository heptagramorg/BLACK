// lib/screens/forum_screen.dart
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../services/forum_service.dart';
import 'forum_post_screen.dart';
import 'create_post_screen.dart';
import '../widgets/native_ad_widget.dart';

// The hardcoded Ad Unit ID has been removed from here.
// It will now be loaded from your .env file using the key 'ADMOB_NATIVE_AD_FORUM'.
const bool useTestAdsForum = false; // Set to false for production

enum ForumSortOption { newest, top }

class ForumScreen extends StatefulWidget {
  final String userId;
  const ForumScreen({super.key, required this.userId});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  final ForumService _forumService = ForumService();
  Map<String, int> _userVotes = {};
  bool _isLoadingUserVotes = true;
  ForumSortOption _sortOption = ForumSortOption.newest;

  List<Map<String, dynamic>> _posts = [];
  int _currentPage = 1;
  final int _pageSize = 15; // Number of posts per page
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMorePosts = true;
  String? _errorMessage;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 300 &&
          !_isLoadingMore &&
          _hasMorePosts) {
        _fetchMorePosts();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await _loadUserVotes();
    await _fetchInitialPosts();
  }

  Future<void> _loadUserVotes() async {
    if (widget.userId.isEmpty) {
      if (mounted) setState(() => _isLoadingUserVotes = false);
      return;
    }
    if (mounted) setState(() => _isLoadingUserVotes = true);
    try {
      final votes = await _forumService.getUserPostVotes(widget.userId);
      if (mounted) {
        setState(() {
          _userVotes = votes;
        });
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) setState(() => _isLoadingUserVotes = false);
    }
  }

  Future<void> _fetchInitialPosts() async {
    if (mounted) {
      setState(() {
        _isLoadingInitial = true;
        _currentPage = 1;
        _posts = [];
        _hasMorePosts = true;
        _errorMessage = null;
      });
    }
    try {
      final fetchedPosts = await _forumService.getForumPosts(
        sortOption: _sortOption,
        pageNumber: _currentPage,
        pageSize: _pageSize,
      );
      if (mounted) {
        setState(() {
          _posts = fetchedPosts;
          _hasMorePosts = fetchedPosts.length == _pageSize;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Could not load posts. Please try again.";
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _fetchMorePosts() async {
    if (_isLoadingMore || !_hasMorePosts) return;
    if (mounted) setState(() => _isLoadingMore = true);
    _currentPage++;
    try {
      final fetchedPosts = await _forumService.getForumPosts(
        sortOption: _sortOption,
        pageNumber: _currentPage,
        pageSize: _pageSize,
      );
      if (mounted) {
        setState(() {
          _posts.addAll(fetchedPosts);
          _hasMorePosts = fetchedPosts.length == _pageSize;
        });
      }
    } catch (e) {
      if (mounted) {
        _currentPage--;
      }
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _handleRefresh() async {
    await _loadUserVotes();
    await _fetchInitialPosts();
  }

  Future<void> _toggleVote(String postId, int newVoteDirection) async {
    if (widget.userId.isEmpty) {
      _showErrorSnackbar("You must be logged in to vote.");
      return;
    }
    if (_isLoadingUserVotes) return;

    final currentVoteStatus = _userVotes[postId] ?? 0;
    int finalVoteToStore = newVoteDirection;
    if (currentVoteStatus == newVoteDirection) {
      finalVoteToStore = 0;
    }

    final originalUserVote = _userVotes[postId];
    final postIndex = _posts.indexWhere((p) => p['id'] == postId);
    Map<String, dynamic>? originalPostData;

    if (mounted) {
      setState(() {
        _userVotes[postId] = finalVoteToStore;
        if (postIndex != -1) {
          originalPostData = Map<String, dynamic>.from(_posts[postIndex]);
          int currentUpvotes = _posts[postIndex]['upvotes'] ?? 0;
          int currentDownvotes = _posts[postIndex]['downvotes'] ?? 0;
          if (currentVoteStatus == 1) currentUpvotes--;
          if (currentVoteStatus == -1) currentDownvotes--;
          if (finalVoteToStore == 1) currentUpvotes++;
          if (finalVoteToStore == -1) currentDownvotes++;
          _posts[postIndex]['upvotes'] =
              currentUpvotes < 0 ? 0 : currentUpvotes;
          _posts[postIndex]['downvotes'] =
              currentDownvotes < 0 ? 0 : currentDownvotes;
        }
      });
    }

    try {
      final result = await _forumService.togglePostVote(
          postId, widget.userId, finalVoteToStore);
      if (mounted) {
        if (result['success'] == true) {
          if (postIndex != -1) {
            setState(() {
              _posts[postIndex]['upvotes'] = result['new_upvotes'];
              _posts[postIndex]['downvotes'] = result['new_downvotes'];
            });
          }
        } else {
          throw Exception(result['error'] ?? 'Failed to update vote');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userVotes[postId] = originalUserVote ?? 0;
          if (postIndex != -1 && originalPostData != null) {
            _posts[postIndex] = originalPostData!;
          }
        });
        _showErrorSnackbar(
            "Error updating vote: ${e.toString().replaceFirst("Exception: ", "")}");
      }
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    const int adFrequency = 2; // Show an ad after every 2 posts
    const double adHeight = 100.0;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: theme.colorScheme.primary,
        backgroundColor: theme.cardColor,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              title: const Text("Community Forum"),
              backgroundColor:
                  isDarkMode ? Colors.black : theme.appBarTheme.backgroundColor,
              elevation: 0,
              pinned: true,
              floating: true,
              snap: true,
              forceElevated: false,
              scrolledUnderElevation: 0,
              actions: [
                PopupMenuButton<ForumSortOption>(
                  initialValue: _sortOption,
                  onSelected: (ForumSortOption result) {
                    if (_sortOption != result) {
                      setState(() => _sortOption = result);
                      _fetchInitialPosts();
                    }
                  },
                  icon: Icon(Icons.sort_rounded,
                      color: theme.appBarTheme.actionsIconTheme?.color),
                  tooltip: "Sort Posts",
                  // Uses DialogTheme from main.dart for popup shape and background
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<ForumSortOption>>[
                    const PopupMenuItem<ForumSortOption>(
                        value: ForumSortOption.newest, child: Text('Newest')),
                    const PopupMenuItem<ForumSortOption>(
                        value: ForumSortOption.top, child: Text('Top Rated')),
                  ],
                )
              ],
            ),
            if (_isLoadingInitial && !_isLoadingUserVotes)
              const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator())),
            if (_errorMessage != null && _posts.isEmpty && !_isLoadingInitial)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded,
                            color: theme.colorScheme.error, size: 60),
                        const SizedBox(height: 16),
                        Text("Error Loading Forum",
                            style: theme.textTheme.headlineSmall
                                ?.copyWith(color: theme.colorScheme.error)),
                        const SizedBox(height: 8),
                        Text(_errorMessage!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 20),
                        ElevatedButton(
                            onPressed: _fetchInitialPosts,
                            child: const Text("Try Again"))
                      ],
                    ),
                  ),
                ),
              ),
            if (_posts.isEmpty && !_isLoadingInitial && _errorMessage == null)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.forum_outlined,
                            size: 70, color: theme.hintColor),
                        const SizedBox(height: 20),
                        Text("No Posts Yet",
                            style: theme.textTheme.titleLarge
                                ?.copyWith(color: theme.hintColor)),
                        const SizedBox(height: 10),
                        Text(
                          "Be the first to start a discussion!",
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.hintColor
                                  .withAlpha((255 * 0.8).round())),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            SliverPadding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    int itemNumber = index + 1;
                    bool isAdPosition = itemNumber % (adFrequency + 1) == 0;

                    if (isAdPosition) {
                      int adIndex = itemNumber ~/ (adFrequency + 1) - 1;
                      if (adIndex * adFrequency < _posts.length) {
                        return NativeAdWidget(
                          key: ValueKey('forum_ad_slot_$adIndex'),
                          adUnitKey: 'ADMOB_NATIVE_AD_FORUM', // MODIFIED
                          useTestId: useTestAdsForum,
                          height: adHeight,
                          cornerRadius: 16.0,
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
                    } else {
                      int postIndex = index - (itemNumber ~/ (adFrequency + 1));
                      if (postIndex < _posts.length) {
                        return _buildPostItem(_posts[postIndex], theme);
                      } else {
                        if (_isLoadingMore && postIndex == _posts.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20.0),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return const SizedBox.shrink();
                      }
                    }
                  },
                  childCount: _posts.length +
                      (_posts.length ~/ adFrequency) +
                      (_isLoadingMore ? 1 : 0),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => CreatePostScreen(userId: widget.userId)),
          );
          if (result == true && mounted) {
            _fetchInitialPosts();
          }
        },
        tooltip: 'Create Post',
        icon: const Icon(Icons.edit_note_rounded),
        label: const Text("New Post"),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      ),
    );
  }

  Widget _buildPostItem(Map<String, dynamic> post, ThemeData theme) {
    final String postId = post['id'] as String? ?? '';
    if (postId.isEmpty) return const SizedBox.shrink();

    final String title = post['title'] as String? ?? "Untitled Post";
    final String description = post['description'] as String? ??
        post['content'] as String? ??
        "No content";
    final int upvotes = post['upvotes'] as int? ?? 0;
    final int downvotes = post['downvotes'] as int? ?? 0;
    final int score = upvotes - downvotes;
    final DateTime createdAt =
        DateTime.tryParse(post['created_at'] as String? ?? '') ??
            DateTime.now();
    final String authorName = post['author_name'] as String? ?? 'Unknown User';
    final String? authorProfilePic = post['author_profile_picture'] as String?;
    final int replyCount = (post['reply_count'] as num?)?.toInt() ?? 0;
    final int userVote = _userVotes[postId] ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.0)),
      child: InkWell(
        onTap: () async {
          final postWasModified = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    ForumPostScreen(postId: postId, userId: widget.userId)),
          );
          await _loadUserVotes();
          if (postWasModified == true && mounted) {
            _fetchInitialPosts();
          } else if (mounted) {
            final updatedPostData =
                await _forumService.getSinglePostDetails(postId: postId);
            if (updatedPostData != null) {
              final index = _posts.indexWhere((p) => p['id'] == postId);
              if (index != -1) {
                setState(() {
                  _posts[index]['upvotes'] = updatedPostData['upvotes'];
                  _posts[index]['downvotes'] = updatedPostData['downvotes'];
                });
              }
            }
          }
        },
        borderRadius: BorderRadius.circular(18.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_upward_rounded,
                        color: userVote == 1
                            ? theme.colorScheme.primary
                            : theme.hintColor,
                        size: 24),
                    onPressed: () => _toggleVote(postId, 1),
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    tooltip: "Upvote",
                    splashRadius: 20,
                  ),
                  Text(
                    score.toString(),
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: score == 0
                            ? theme.textTheme.bodyMedium?.color
                            : (score > 0
                                ? theme.colorScheme.primary
                                : theme.colorScheme.error)),
                  ),
                  IconButton(
                    icon: Icon(Icons.arrow_downward_rounded,
                        color: userVote == -1
                            ? theme.colorScheme.error
                            : theme.hintColor,
                        size: 24),
                    onPressed: () => _toggleVote(postId, -1),
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    tooltip: "Downvote",
                    splashRadius: 20,
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: theme
                              .colorScheme.surfaceContainerHighest
                              .withAlpha((255 * 0.5).round()),
                          backgroundImage: authorProfilePic != null &&
                                  authorProfilePic.isNotEmpty
                              ? NetworkImage(authorProfilePic)
                              : null,
                          child: (authorProfilePic == null ||
                                  authorProfilePic.isEmpty)
                              ? Icon(Icons.person_outline_rounded,
                                  size: 14,
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withAlpha((255 * 0.7).round()))
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "$authorName • ${timeago.format(createdAt)}",
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.hintColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(title,
                        style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600, fontSize: 17)),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color
                              ?.withAlpha((255 * 0.85).round()),
                          height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.mode_comment_outlined,
                            size: 18, color: theme.hintColor),
                        const SizedBox(width: 6),
                        Text(
                            "$replyCount ${replyCount == 1 ? 'Reply' : 'Replies'}",
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.hintColor,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
