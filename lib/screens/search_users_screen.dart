// lib/screens/search_users_screen.dart
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'profile_screen.dart';

class SearchUsersScreen extends StatefulWidget {
  final String currentUserId;

  const SearchUsersScreen({super.key, required this.currentUserId});

  @override
  SearchUsersScreenState createState() => SearchUsersScreenState();
}

class SearchUsersScreenState extends State<SearchUsersScreen> {
  final _supabase = SupabaseService.client;
  final TextEditingController searchController = TextEditingController();
  List<Map<String, dynamic>> searchResults = [];
  bool isSearching = false;
  String errorMessage = "";
  final FocusNode _searchFocusNode = FocusNode();


  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          searchResults = [];
          isSearching = false;
          errorMessage = "";
        });
      }
      return;
    }

    if (mounted) setState(() => isSearching = true);

    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .or('username.ilike.%$query%,name.ilike.%$query%')
          .order('username');

      if (mounted) {
        setState(() {
          searchResults = List<Map<String, dynamic>>.from(data);
          isSearching = false;
          errorMessage = "";
          if (searchResults.isEmpty) {
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isSearching = false;
          if (e.toString().contains('permission')) {
            errorMessage = "You don't have permission to search users. Make sure you're signed in.";
          } else {
            errorMessage = "Error searching users. Please try again.";
          }
        });
      }
    }
  }

  void _clearSearch() {
    searchController.clear();
    if (mounted) {
      setState(() {
        searchResults = [];
        errorMessage = "";
        isSearching = false;
      });
    }
    _searchFocusNode.unfocus();
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text("Search Users"),
            backgroundColor: isDarkMode ? Colors.black : theme.appBarTheme.backgroundColor,
            elevation: 0,
            pinned: true,
            floating: true,
            snap: true,
            forceElevated: false,
            scrolledUnderElevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(70.0),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 12.0),
                child: TextField(
                  controller: searchController,
                  focusNode: _searchFocusNode,
                  style: TextStyle(color: isDarkMode ? Colors.white.withValues(alpha: 0.9) : null),
                  decoration: InputDecoration(
                    hintText: "Search by username or name...",
                    prefixIcon: Icon(Icons.search_rounded, color: theme.inputDecorationTheme.prefixIconColor),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded, color: theme.inputDecorationTheme.suffixIconColor),
                            onPressed: _clearSearch,
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.0)),
                  ),
                  onChanged: (query) => _searchUsers(query),
                  onSubmitted: (query) => _searchUsers(query),
                ),
              ),
            ),
          ),

          if (errorMessage.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.1),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: theme.colorScheme.error),
                    const SizedBox(width: 10),
                    Expanded(child: Text(errorMessage, style: TextStyle(color: theme.colorScheme.onErrorContainer))),
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 18, color: theme.colorScheme.onErrorContainer),
                      onPressed: () => setState(() { errorMessage = ""; }),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    )
                  ]
                ),
              ),
            ),

          if (isSearching)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
          if (!isSearching && searchController.text.isEmpty && searchResults.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_search_outlined, size: 70, color: theme.hintColor),
                      const SizedBox(height: 20),
                      Text(
                        "Find users by their username or name.",
                        style: theme.textTheme.titleMedium?.copyWith(color: theme.hintColor),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            ),
          if (!isSearching && searchResults.isEmpty && searchController.text.isNotEmpty)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    'No users found matching "${searchController.text}"',
                    style: theme.textTheme.titleMedium?.copyWith(color: theme.hintColor),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            ),
          
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final user = searchResults[index];
                  if (user['id'] == widget.currentUserId) {
                    return const SizedBox.shrink();
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                        backgroundImage: user['profile_picture'] != null && (user['profile_picture'] as String).isNotEmpty
                            ? NetworkImage(user['profile_picture'])
                            : null,
                        child: (user['profile_picture'] == null || (user['profile_picture'] as String).isEmpty)
                            ? Icon(Icons.person_rounded, color: theme.colorScheme.onPrimaryContainer, size: 26)
                            : null,
                      ),
                      title: Text(
                        user['username'] != null && (user['username'] as String).isNotEmpty
                            ? "@${user['username']}"
                            : user['name'] ?? "Unknown User",
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        user['name'] ?? ( (user['username'] != null && (user['username'] as String).isNotEmpty) ? "" : "No name provided"),
                        style: theme.textTheme.bodySmall,
                      ),
                      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 18, color: theme.hintColor),
                      onTap: () {
                        _searchFocusNode.unfocus();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfileScreen(
                              userId: user['id'],
                              currentUserId: widget.currentUserId,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
                childCount: searchResults.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}