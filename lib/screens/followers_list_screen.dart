import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/followers_service.dart'; // Import the followers service
import 'profile_screen.dart';

class FollowersListScreen extends StatefulWidget {
  final String userId;
  final bool showFollowers; // Determines if we show followers or following

  const FollowersListScreen(
      {super.key, required this.userId, required this.showFollowers});

  @override
  FollowersListScreenState createState() => FollowersListScreenState();
}

class FollowersListScreenState extends State<FollowersListScreen> {
  final _followersService = FollowersService(); // Use the followers service
  bool _isLoading = true;
  List<Map<String, dynamic>> _users = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      if (widget.showFollowers) {
        // Get users who follow the current user using FollowersService
        final followers = await _followersService.getFollowers(widget.userId);
        if (mounted) {
          setState(() {
            _users = followers;
            _isLoading = false;
          });
        }
      } else {
        // Get users whom the current user follows using FollowersService
        final following = await _followersService.getFollowing(widget.userId);
        if (mounted) {
          setState(() {
            _users = following;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Error loading users: $e";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.showFollowers ? "Followers" : "Following"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchUsers,
            tooltip: "Refresh",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _fetchUsers,
                        child: const Text("Try Again"),
                      ),
                    ],
                  ),
                )
              : _users.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            widget.showFollowers
                                ? Icons.people_outline
                                : Icons.person_outline,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.showFollowers
                                ? "No followers yet."
                                : "Not following anyone.",
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final userData = _users[index];
                        final userId = userData['id'];

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey[300],
                            backgroundImage:
                                userData['profile_picture'] != null &&
                                        userData['profile_picture'].isNotEmpty
                                    ? NetworkImage(userData['profile_picture'])
                                    : null,
                            child: userData['profile_picture'] == null ||
                                    userData['profile_picture'].isEmpty
                                ? Icon(Icons.person, color: Colors.grey[700])
                                : null,
                          ),
                          title: Text(userData['username'] ?? "Unknown"),
                          subtitle: Text(userData['name'] ?? ""),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfileScreen(
                                  userId: userId,
                                  currentUserId:
                                      SupabaseService.currentUserId ?? "",
                                ),
                              ),
                            ).then((_) {
                              // Refresh the list when returning from profile screen
                              _fetchUsers();
                            });
                          },
                        );
                      },
                    ),
    );
  }
}
