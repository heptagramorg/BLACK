// lib/screens/forum_post_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../services/supabase_service.dart';
import '../services/forum_service.dart';

class ForumPostScreen extends StatefulWidget {
  final String postId;
  final String userId;

  const ForumPostScreen(
      {super.key, required this.postId, required this.userId});

  @override
  State<ForumPostScreen> createState() => _ForumPostScreenState();
}

class _ForumPostScreenState extends State<ForumPostScreen> {
  final TextEditingController _replyController = TextEditingController();
  final ForumService _forumService = ForumService();
  final SupabaseClient _supabase = SupabaseService.client;

  Map<String, dynamic>? _postData;
  int _currentUserVoteForThisPost = 0;
  bool _isLoadingPost = true;
  bool _isVoteProcessing = false;
  String _postErrorMessage = "";

  List<Map<String, dynamic>> _replies = [];
  int _currentReplyPage = 1;
  final int _replyPageSize = 20;
  bool _isLoadingReplies = true;
  bool _isLoadingMoreReplies = false;
  bool _hasMoreReplies = true;
  String? _repliesErrorMessage;
  bool _postWasDeleted = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMoreReplies &&
          _hasMoreReplies) {
        _fetchMoreReplies();
      }
    });
  }

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await _fetchFullPostData();
    if (_postData != null) {
      await _loadUserVoteForThisPost();
      await _fetchInitialReplies();
    }
  }

  Future<void> _fetchFullPostData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingPost = true;
      _postErrorMessage = "";
    });
    try {
      final postData =
          await _forumService.getSinglePostDetails(postId: widget.postId);
      if (!mounted) return;
      if (postData == null) {
        setState(() {
          _postData = null;
          _isLoadingPost = false;
          _postErrorMessage = "Post not found or has been deleted.";
        });
      } else {
        setState(() {
          _postData = postData;
          _isLoadingPost = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingPost = false;
        _postErrorMessage = "Error loading post. Please try again.";
      });
    }
  }

  Future<void> _loadUserVoteForThisPost() async {
    if (widget.userId.isEmpty || _postData == null) return;
    try {
      final voteData = await _supabase
          .from('post_votes')
          .select('vote_type')
          .eq('user_id', widget.userId)
          .eq('post_id', widget.postId)
          .maybeSingle();

      if (mounted && voteData != null) {
        setState(() {
          _currentUserVoteForThisPost = voteData['vote_type'] as int? ?? 0;
        });
      }
    } catch (e) {
      // Handle error silently or log it
      debugPrint("Error loading user vote: $e");
    }
  }

  Future<void> _fetchInitialReplies() async {
    if (!mounted || _postData == null) return;
    setState(() {
      _isLoadingReplies = true;
      _currentReplyPage = 1;
      _replies = [];
      _hasMoreReplies = true;
      _repliesErrorMessage = null;
    });
    try {
      final fetchedReplies = await _forumService.getForumReplies(
        postId: widget.postId,
        pageNumber: _currentReplyPage,
        pageSize: _replyPageSize,
      );
      if (mounted) {
        setState(() {
          _replies = fetchedReplies;
          _hasMoreReplies = fetchedReplies.length == _replyPageSize;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _repliesErrorMessage = "Could not load replies.";
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingReplies = false);
    }
  }

  Future<void> _fetchMoreReplies() async {
    if (_isLoadingMoreReplies ||
        !_hasMoreReplies ||
        !mounted ||
        _postData == null) return;
    setState(() => _isLoadingMoreReplies = true);

    _currentReplyPage++;
    try {
      final fetchedReplies = await _forumService.getForumReplies(
        postId: widget.postId,
        pageNumber: _currentReplyPage,
        pageSize: _replyPageSize,
      );
      if (mounted) {
        setState(() {
          _replies.addAll(fetchedReplies);
          _hasMoreReplies = fetchedReplies.length == _replyPageSize;
        });
      }
    } catch (e) {
      if (mounted) _currentReplyPage--;
    } finally {
      if (mounted) setState(() => _isLoadingMoreReplies = false);
    }
  }

  Future<void> _toggleVoteForThisPost(int newVoteDirection) async {
    if (widget.userId.isEmpty || _postData == null || _isVoteProcessing) return;
    setState(() => _isVoteProcessing = true);

    final currentVoteStatusOnScreen = _currentUserVoteForThisPost;
    int finalVoteToSend = newVoteDirection;
    if (currentVoteStatusOnScreen == newVoteDirection) finalVoteToSend = 0;

    final originalPostData = Map<String, dynamic>.from(_postData!);
    if (mounted) {
      setState(() {
        _currentUserVoteForThisPost = finalVoteToSend;
        int upvotes = _postData!['upvotes'] ?? 0;
        int downvotes = _postData!['downvotes'] ?? 0;
        if (currentVoteStatusOnScreen == 1) upvotes--;
        if (currentVoteStatusOnScreen == -1) downvotes--;
        if (finalVoteToSend == 1) upvotes++;
        if (finalVoteToSend == -1) downvotes--;
        _postData!['upvotes'] = upvotes < 0 ? 0 : upvotes;
        _postData!['downvotes'] = downvotes < 0 ? 0 : downvotes;
      });
    }

    try {
      final result = await _forumService.togglePostVote(
          widget.postId, widget.userId, finalVoteToSend);
      if (mounted) {
        if (result['success'] == true) {
          setState(() {
            _postData!['upvotes'] =
                result['new_upvotes'] ?? _postData!['upvotes'];
            _postData!['downvotes'] =
                result['new_downvotes'] ?? _postData!['downvotes'];
          });
        } else {
          throw Exception(
              result['error'] ?? "Failed to update vote on server.");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _postData = originalPostData;
          _currentUserVoteForThisPost = currentVoteStatusOnScreen;
        });
        _showMessage(
            "Failed to update vote: ${e.toString().replaceFirst("Exception: ", "")}",
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isVoteProcessing = false);
    }
  }

  Future<void> _postReply() async {
    String replyContent = _replyController.text.trim();
    if (replyContent.isEmpty || widget.userId.isEmpty) return;
    final FocusScopeNode currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus && currentFocus.hasFocus) {
      currentFocus.unfocus();
    }
    try {
      await _supabase.from('forum_replies').insert({
        'post_id': widget.postId,
        'user_id': widget.userId,
        'reply_content': replyContent,
        'created_at': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        _replyController.clear();
        _showMessage("Reply posted!", isError: false);
        _fetchInitialReplies();
      }
    } catch (e) {
      if (mounted)
        _showMessage("Error posting reply: ${e.toString()}", isError: true);
    }
  }

  Future<void> _deletePost() async {
    final confirm = await _showConfirmationDialog("Delete Post",
        "Are you sure you want to delete this post and all its replies? This cannot be undone.");
    if (confirm != true || !mounted) return;
    try {
      await _supabase.from('forum_posts').delete().eq('id', widget.postId);
      if (mounted) {
        _showMessage("Post deleted!", isError: false);
        _postWasDeleted = true;
        Navigator.pop(context, _postWasDeleted);
      }
    } catch (e) {
      if (mounted)
        _showMessage("Error deleting post: ${e.toString()}", isError: true);
    }
  }

  Future<void> _deleteReply(String replyId) async {
    final confirm = await _showConfirmationDialog(
        "Delete Reply", "Are you sure you want to delete this reply?");
    if (confirm != true || !mounted) return;
    try {
      await _supabase.from('forum_replies').delete().eq('id', replyId);
      if (mounted) {
        _showMessage("Reply deleted!", isError: false);
        setState(() {
          _replies.removeWhere((reply) => reply['id'] == replyId);
        });
      }
    } catch (e) {
      if (mounted)
        _showMessage("Error deleting reply: ${e.toString()}", isError: true);
    }
  }

  Future<bool?> _showConfirmationDialog(String title, String content) async {
    final theme = Theme.of(context);
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(content),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        // FIX: `dialogBackgroundColor` is deprecated. Use `dialogTheme.backgroundColor`.
        backgroundColor: theme.dialogTheme.backgroundColor,
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.error),
              child: Text("Delete",
                  style: TextStyle(color: theme.colorScheme.onError))),
        ],
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Colors.green.shade600,
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

    if (_isLoadingPost) {
      return Scaffold(
          appBar: AppBar(
            title: const Text("Loading Post..."),
            backgroundColor:
                isDarkMode ? Colors.black : theme.appBarTheme.backgroundColor,
            elevation: 0,
          ),
          body: const Center(child: CircularProgressIndicator()));
    }
    if (_postErrorMessage.isNotEmpty || _postData == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_postData?['title'] ?? "Post Details",
              style: TextStyle(color: theme.appBarTheme.foregroundColor)),
          backgroundColor:
              isDarkMode ? Colors.black : theme.appBarTheme.backgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: theme.appBarTheme.iconTheme?.color),
            onPressed: () => Navigator.pop(context, _postWasDeleted),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.error_outline_rounded,
                  color: theme.colorScheme.error, size: 60),
              const SizedBox(height: 16),
              Text(
                  _postErrorMessage.isNotEmpty
                      ? _postErrorMessage
                      : "Post not found.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: theme.colorScheme.error)),
              const SizedBox(height: 20),
              ElevatedButton(
                  onPressed: _loadAllData, child: const Text("Try Again"))
            ]),
          ),
        ),
      );
    }

    final post = _postData!;
    final bool isPostOwner = widget.userId == post['user_id'];
    final String postAuthorName =
        post['author_name'] as String? ?? "Unknown User";
    final String? postAuthorPic = post['author_profile_picture'] as String?;
    final int upvotes = post['upvotes'] as int? ?? 0;
    final int downvotes = post['downvotes'] as int? ?? 0;
    final int score = upvotes - downvotes;
    final DateTime createdAt =
        DateTime.tryParse(post['created_at'] as String? ?? '') ??
            DateTime.now();

    // FIX: Replaced deprecated `PopScope` with the modern version to handle back navigation correctly.
    return PopScope(
      canPop: false, // We handle the pop manually to pass back a result.
      onPopInvoked: (bool didPop) {
        // If the pop was already handled, do nothing.
        if (didPop) return;
        // Otherwise, pop with our result.
        Navigator.pop(context, _postWasDeleted);
      },
      child: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverAppBar(
                    title: Text(post['title'] as String? ?? "Post Details",
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: theme.appBarTheme.foregroundColor,
                            fontWeight: FontWeight.w600)),
                    backgroundColor: isDarkMode
                        ? Colors.black
                        : theme.appBarTheme.backgroundColor,
                    elevation: 0,
                    pinned: true,
                    leading: IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded,
                          color: theme.appBarTheme.iconTheme?.color),
                      onPressed: () => Navigator.pop(context, _postWasDeleted),
                    ),
                    actions: [
                      if (isPostOwner)
                        IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 24),
                            onPressed: _deletePost,
                            tooltip: "Delete Post",
                            color: theme.colorScheme.error),
                      IconButton(
                          icon: const Icon(Icons.share_outlined, size: 22),
                          onPressed: () => Share.share(
                              '${post['title']}\n\n${post['content']}',
                              subject: post['title']),
                          tooltip: "Share Post"),
                    ],
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                // FIX: `withOpacity` is deprecated, use `withAlpha`. (255 * 0.5).round() = 128
                                backgroundColor: theme
                                    .colorScheme.surfaceContainerHighest
                                    .withAlpha(128),
                                backgroundImage: postAuthorPic != null &&
                                        postAuthorPic.isNotEmpty
                                    ? NetworkImage(postAuthorPic)
                                    : null,
                                child: (postAuthorPic == null ||
                                        postAuthorPic.isEmpty)
                                    // FIX: `withOpacity` is deprecated, use `withAlpha`. (255 * 0.7).round() = 179
                                    ? Icon(Icons.person_outline_rounded,
                                        color: theme
                                            .colorScheme.onSurfaceVariant
                                            .withAlpha(179),
                                        size: 22)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(postAuthorName,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w600)),
                                    Text(timeago.format(createdAt),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(color: theme.hintColor)),
                                  ],
                                ),
                              ),
                              _isVoteProcessing
                                  ? const Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 20.0),
                                      child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2.5)))
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.arrow_upward_rounded,
                                              color:
                                                  _currentUserVoteForThisPost ==
                                                          1
                                                      ? theme
                                                          .colorScheme.primary
                                                      : theme.hintColor,
                                              size: 26),
                                          onPressed: () =>
                                              _toggleVoteForThisPost(1),
                                          tooltip: "Upvote",
                                          splashRadius: 22,
                                        ),
                                        Text(score.toString(),
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: score == 0
                                                        ? theme.textTheme
                                                            .bodyMedium?.color
                                                        : (score > 0
                                                            ? theme.colorScheme
                                                                .primary
                                                            : theme.colorScheme
                                                                .error))),
                                        IconButton(
                                          icon: Icon(
                                              Icons.arrow_downward_rounded,
                                              color:
                                                  _currentUserVoteForThisPost ==
                                                          -1
                                                      ? theme.colorScheme.error
                                                      : theme.hintColor,
                                              size: 26),
                                          onPressed: () =>
                                              _toggleVoteForThisPost(-1),
                                          tooltip: "Downvote",
                                          splashRadius: 22,
                                        ),
                                      ],
                                    )
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(post['title'] as String? ?? "Untitled",
                              style: theme.textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          SelectableText(
                            post['content'] as String? ?? "No description",
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(height: 1.65),
                            textAlign: TextAlign.start,
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Icon(Icons.thumb_up_alt_outlined,
                                  size: 16, color: theme.hintColor),
                              Text(" $upvotes Upvotes",
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: theme.hintColor)),
                              const SizedBox(width: 20),
                              Icon(Icons.thumb_down_alt_outlined,
                                  size: 16, color: theme.hintColor),
                              Text(" $downvotes Downvotes",
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: theme.hintColor)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Divider(thickness: 0.5, color: theme.dividerColor),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Text("Replies (${_replies.length})",
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildRepliesList(theme, isDarkMode),
                  SliverToBoxAdapter(
                      child: SizedBox(
                          height: MediaQuery.of(context).padding.bottom + 90)),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 12.0,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16.0),
              decoration: BoxDecoration(
                  color: isDarkMode ? Colors.black : theme.cardColor,
                  // FIX: `withOpacity` is deprecated, use `withAlpha`. (255 * 0.1).round() = 26
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withAlpha(26),
                        blurRadius: 10,
                        offset: const Offset(0, -3))
                  ],
                  border: Border(
                      top: BorderSide(color: theme.dividerColor, width: 0.5))),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyController,
                      decoration: const InputDecoration(
                        hintText: "Write a reply...",
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _postReply(),
                      minLines: 1,
                      maxLines: 5,
                      // FIX: `withOpacity` is deprecated, use `withAlpha`. (255 * 0.9).round() = 230
                      style: TextStyle(
                          color:
                              isDarkMode ? Colors.white.withAlpha(230) : null),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: Icon(Icons.send_rounded,
                        color: theme.colorScheme.primary, size: 26),
                    onPressed: _postReply,
                    tooltip: "Post Reply",
                    style: IconButton.styleFrom(
                        // FIX: `withOpacity` is deprecated, use `withAlpha`. (255 * 0.1).round() = 26
                        backgroundColor:
                            theme.colorScheme.primary.withAlpha(26),
                        padding: const EdgeInsets.all(14)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRepliesList(ThemeData theme, bool isDarkMode) {
    if (_isLoadingReplies) {
      return const SliverToBoxAdapter(
          child: Center(
              child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(strokeWidth: 2.5))));
    }
    if (_repliesErrorMessage != null) {
      return SliverToBoxAdapter(
          child: Center(
              child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(_repliesErrorMessage!,
            style: TextStyle(color: theme.colorScheme.error)),
      )));
    }
    if (_replies.isEmpty) {
      return SliverToBoxAdapter(
          child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
        child: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.chat_bubble_outline_rounded,
                size: 50, color: theme.hintColor),
            const SizedBox(height: 16),
            Text("Be the first to reply!",
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: theme.hintColor)),
          ]),
        ),
      ));
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == _replies.length &&
              _hasMoreReplies &&
              _isLoadingMoreReplies) {
            return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child:
                    Center(child: CircularProgressIndicator(strokeWidth: 2.5)));
          }
          if (index == _replies.length &&
              _hasMoreReplies &&
              !_isLoadingMoreReplies) {
            return Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 16.0, horizontal: 60),
              child: OutlinedButton(
                onPressed: _fetchMoreReplies,
                child: const Text("Load More Replies"),
              ),
            );
          }
          if (index >= _replies.length) return null;

          final reply = _replies[index];
          final String replyUserId = reply['user_id'] as String? ?? '';
          final bool isReplyOwner = widget.userId == replyUserId;
          final DateTime replyCreatedAt =
              DateTime.tryParse(reply['created_at'] as String? ?? '') ??
                  DateTime.now();
          final String replyAuthorName =
              reply['author_name'] as String? ?? "User";
          final String? replyAuthorPic =
              reply['author_profile_picture'] as String?;

          return Card(
            elevation: 0.5,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.0)),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    // FIX: `withOpacity` is deprecated, use `withAlpha`. (255 * 0.6).round() = 153
                    backgroundColor: theme.colorScheme.surfaceContainerHighest
                        .withAlpha(153),
                    backgroundImage:
                        replyAuthorPic != null && replyAuthorPic.isNotEmpty
                            ? NetworkImage(replyAuthorPic)
                            : null,
                    child: (replyAuthorPic == null || replyAuthorPic.isEmpty)
                        // FIX: `withOpacity` is deprecated, use `withAlpha`. (255 * 0.7).round() = 179
                        ? Icon(Icons.person_outline_rounded,
                            color: theme.colorScheme.onSurfaceVariant
                                .withAlpha(179),
                            size: 18)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(replyAuthorName,
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(width: 6),
                            Text("• ${timeago.format(replyCreatedAt)}",
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: theme.hintColor)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SelectableText(reply['reply_content'] as String? ?? "",
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(height: 1.5)),
                      ],
                    ),
                  ),
                  if (isReplyOwner)
                    IconButton(
                      // FIX: `withOpacity` is deprecated, use `withAlpha`. (255 * 0.8).round() = 204
                      icon: Icon(Icons.delete_outline_rounded,
                          color: theme.colorScheme.error.withAlpha(204),
                          size: 20),
                      onPressed: () => _deleteReply(reply['id'] as String),
                      tooltip: "Delete Reply",
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      splashRadius: 20,
                    ),
                ],
              ),
            ),
          );
        },
        childCount: _replies.length + (_hasMoreReplies ? 1 : 0),
      ),
    );
  }
}
