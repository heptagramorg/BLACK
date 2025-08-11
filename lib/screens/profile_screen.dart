// lib/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:ui';
import '../services/followers_service.dart';
import '../services/user_service.dart';
import '../utils/profile_picture_handler.dart';
import '../widgets/profile_notes_grid.dart';
import 'followers_list_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  final String currentUserId;

  const ProfileScreen({
    super.key,
    required this.userId,
    required this.currentUserId,
  });

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  final FollowersService _followersService = FollowersService();
  final UserService _userService = UserService();
  final ImagePicker _picker = ImagePicker();

  Map<String, dynamic>? _profileData;
  late bool isOwnProfile;
  bool isFollowing = false;
  int followersCount = 0;
  int followingCount = 0;

  bool _isLoadingProfile = true;
  bool _isUploadingPicture = false;
  bool _isUpdatingProfile = false;
  bool _isTogglingFollow = false;

  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    isOwnProfile = widget.userId == widget.currentUserId;
    _loadProfileDataWithRPC();
  }

  Future<void> _loadProfileDataWithRPC() async {
    if (!mounted) return;
    setState(() {
      _isLoadingProfile = true;
      _errorMessage = "";
    });

    try {
      final combinedData = await _userService.getProfileScreenData(
        profileUserId: widget.userId,
        requestingUserId: widget.currentUserId,
      );

      if (!mounted) return;

      if (combinedData == null) {
        setState(() {
          _errorMessage = "Failed to load profile data. Response was null.";
          _isLoadingProfile = false;
        });
        return;
      }

      if (combinedData['error_message'] != null) {
        setState(() {
          _errorMessage = combinedData['error_message'];
          _profileData = null;
          _isLoadingProfile = false;
        });
        return;
      }

      final profileMap = combinedData['profile'] as Map<String, dynamic>?;

      if (profileMap == null) {
        setState(() {
          _errorMessage = "User profile data not found within RPC response.";
          _profileData = null;
          _isLoadingProfile = false;
        });
        return;
      }

      setState(() {
        _profileData = profileMap;
        followersCount = combinedData['followers_count'] as int? ?? 0;
        followingCount = combinedData['following_count'] as int? ?? 0;
        if (!isOwnProfile) {
          isFollowing = combinedData['is_following'] as bool? ?? false;
        }
        _isLoadingProfile = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst("Exception: ", "");
          _profileData = null;
          _isLoadingProfile = false;
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (isOwnProfile || widget.currentUserId.isEmpty || _isTogglingFollow)
      return;
    if (!mounted) return;

    setState(() => _isTogglingFollow = true);
    final originalIsFollowingState = isFollowing;

    try {
      if (isFollowing) {
        await _followersService.unfollowUser(
            widget.currentUserId, widget.userId);
      } else {
        await _followersService.followUser(widget.currentUserId, widget.userId);
      }

      // After the async operation, check if the widget is still in the tree.
      if (!mounted) return;

      await _loadProfileDataWithRPC();

      if (mounted) {
        _showMessage(
            originalIsFollowingState
                ? "Successfully unfollowed"
                : "Successfully followed",
            isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showMessage("Action failed: ${e.toString()}", isError: true);
        setState(() {
          isFollowing = originalIsFollowingState;
        });
      }
    } finally {
      if (mounted) setState(() => _isTogglingFollow = false);
    }
  }

  Future<void> _uploadProfilePicture() async {
    if (!isOwnProfile || _isUploadingPicture) return;
    if (!mounted) return;

    setState(() => _isUploadingPicture = true);

    final String? newImageUrl =
        await ProfilePictureHandler.uploadProfilePicture(
      widget.userId,
      _profileData?['profile_picture'] as String?,
      _picker,
      (bool
          uploading) {}, // This callback seems unused, can be removed if not needed.
      _showMessage,
    );

    if (mounted) {
      if (newImageUrl != null) {
        setState(() {
          _profileData?['profile_picture'] = newImageUrl;
        });
        _showMessage("Profile picture updated!", isError: false);
      }
      setState(() => _isUploadingPicture = false);
    }
  }

  Future<void> _editProfile() async {
    if (!isOwnProfile || _profileData == null) return;

    final String currentUsername = _profileData!['username'] as String? ?? '';
    final String currentName = _profileData!['name'] as String? ?? '';
    final String currentUniversity =
        _profileData!['university'] as String? ?? '';
    final String currentBio = _profileData!['bio'] as String? ?? '';

    final TextEditingController usernameController =
        TextEditingController(text: currentUsername);
    final TextEditingController nameController =
        TextEditingController(text: currentName);
    final TextEditingController universityController =
        TextEditingController(text: currentUniversity);
    final TextEditingController bioController =
        TextEditingController(text: currentBio);
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    if (!mounted) return;

    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24.0),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withAlpha(26)
                        : Colors.white.withAlpha(217),
                    borderRadius: BorderRadius.circular(24.0),
                    border: Border.all(
                        color: isDarkMode
                            ? Colors.white.withAlpha(38)
                            : Colors.grey.shade300.withAlpha(128),
                        width: 0.5)),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Edit Profile",
                          style: theme.textTheme.headlineSmall?.copyWith(
                              color: isDarkMode
                                  ? Colors.white.withAlpha(230)
                                  : theme.textTheme.headlineSmall?.color,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      _buildEditTextField(
                          usernameController, "Username", theme, isDarkMode),
                      _buildEditTextField(
                          nameController, "Name", theme, isDarkMode),
                      _buildEditTextField(universityController, "University",
                          theme, isDarkMode),
                      _buildEditTextField(
                          bioController, "Bio", theme, isDarkMode,
                          maxLines: 3),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: Text("Cancel",
                                style: TextStyle(
                                    color: isDarkMode
                                        ? theme.colorScheme.secondary
                                        : theme.hintColor)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () async {
                              final newUsername =
                                  usernameController.text.trim();
                              if (newUsername.isEmpty) {
                                // This is synchronous, so it's safe to call _showMessage.
                                _showMessage("Username cannot be empty.",
                                    isError: true);
                                return;
                              }
                              if (newUsername != currentUsername) {
                                final isTaken =
                                    await _userService.isUsernameTaken(
                                  newUsername,
                                  excludeUserId: widget.userId,
                                );

                                // FIX: Added a mounted check after the async gap.
                                // This prevents using the BuildContext if the widget was disposed.
                                if (!mounted) return;

                                if (isTaken) {
                                  _showMessage("Username already taken.",
                                      isError: true);
                                  return;
                                }
                              }
                              // Pop with the dialog's context, which is safe.
                              Navigator.pop(dialogContext, {
                                'username': newUsername,
                                'name': nameController.text.trim(),
                                'university': universityController.text.trim(),
                                'bio': bioController.text.trim(),
                              });
                            },
                            style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12))),
                            child: const Text("Save"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (result != null && mounted) {
      setState(() => _isUpdatingProfile = true);
      try {
        await _userService.updateProfile(widget.userId, result);
        if (mounted) {
          await _loadProfileDataWithRPC();
          if (mounted) {
            _showMessage("Profile updated successfully!", isError: false);
          }
        }
      } catch (e) {
        if (mounted) {
          _showMessage("Failed to update profile: ${e.toString()}",
              isError: true);
        }
      } finally {
        if (mounted) setState(() => _isUpdatingProfile = false);
      }
    }
  }

  Widget _buildEditTextField(TextEditingController controller, String label,
      ThemeData theme, bool isDarkMode,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(
            color: isDarkMode
                ? Colors.white.withAlpha(230)
                : theme.textTheme.bodyLarge?.color),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
              color:
                  isDarkMode ? Colors.white.withAlpha(179) : theme.hintColor),
          filled: true,
          fillColor: isDarkMode
              ? Colors.black.withAlpha(38)
              : Colors.white.withAlpha(77),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.0),
              borderSide: BorderSide(
                  color: isDarkMode
                      ? Colors.white.withAlpha(51)
                      : Colors.grey.shade400,
                  width: 0.5)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.0),
              borderSide: BorderSide(
                  color: isDarkMode
                      ? Colors.white.withAlpha(51)
                      : Colors.grey.shade400,
                  width: 0.5)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14.0),
              borderSide:
                  BorderSide(color: theme.colorScheme.primary, width: 1)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
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

  void _navigateToFollowList(bool showFollowers) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FollowersListScreen(
          userId: widget.userId,
          showFollowers: showFollowers,
        ),
      ),
    ).then((_) => _loadProfileDataWithRPC());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    if (_isLoadingProfile) {
      return Scaffold(
          appBar: AppBar(
            title: Text(isOwnProfile ? "My Profile" : "Profile",
                style: TextStyle(color: theme.appBarTheme.foregroundColor)),
            backgroundColor:
                isDarkMode ? Colors.black : theme.appBarTheme.backgroundColor,
            elevation: 0,
          ),
          body: const Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage.isNotEmpty && _profileData == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(isOwnProfile ? "My Profile" : "Profile",
              style: TextStyle(color: theme.appBarTheme.foregroundColor)),
          backgroundColor:
              isDarkMode ? Colors.black : theme.appBarTheme.backgroundColor,
          elevation: 0,
        ),
        body: Center(
            child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.error),
          ),
        )),
      );
    }

    if (_profileData == null) {
      return Scaffold(
          appBar: AppBar(
            title: Text(isOwnProfile ? "My Profile" : "Profile",
                style: TextStyle(color: theme.appBarTheme.foregroundColor)),
            backgroundColor:
                isDarkMode ? Colors.black : theme.appBarTheme.backgroundColor,
            elevation: 0,
          ),
          body: const Center(child: Text("Could not load profile.")));
    }

    final String username = _profileData!['username'] as String? ?? 'User...';
    final String name = _profileData!['name'] as String? ?? 'N/A';
    final String university = _profileData!['university'] as String? ?? ' ';
    final String bio = _profileData!['bio'] as String? ?? 'No bio.';
    final String? profilePictureUrl =
        _profileData!['profile_picture'] as String?;

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            expandedHeight: 60.0,
            floating: false,
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor:
                isDarkMode ? Colors.black : theme.appBarTheme.backgroundColor,
            foregroundColor: theme.appBarTheme.foregroundColor,
            title: Text(username,
                style: TextStyle(
                    color: theme.appBarTheme.foregroundColor,
                    fontWeight: FontWeight.w600)),
            centerTitle: true,
            actions: [
              if (isOwnProfile)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 24),
                  tooltip: "Edit Profile",
                  onPressed: _isUpdatingProfile ? null : _editProfile,
                ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 65,
                        backgroundColor: theme
                            .colorScheme.surfaceContainerHighest
                            .withAlpha(isDarkMode ? 77 : 255),
                        backgroundImage: profilePictureUrl != null &&
                                profilePictureUrl.isNotEmpty
                            ? NetworkImage(profilePictureUrl)
                            : null,
                        child: (profilePictureUrl == null ||
                                profilePictureUrl.isEmpty)
                            ? Icon(Icons.person_rounded,
                                size: 70,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withAlpha(isDarkMode ? 153 : 255))
                            : null,
                      ),
                      if (isOwnProfile)
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Material(
                            color: theme.colorScheme.primary,
                            shape: const CircleBorder(),
                            elevation: 3,
                            child: InkWell(
                              onTap: _isUploadingPicture
                                  ? null
                                  : _uploadProfilePicture,
                              customBorder: const CircleBorder(),
                              child: Padding(
                                padding: const EdgeInsets.all(10.0),
                                child: _isUploadingPicture
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white)))
                                    : Icon(Icons.camera_alt_rounded,
                                        size: 20,
                                        color: theme.colorScheme.onPrimary),
                              ),
                            ),
                          ),
                        )
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? Colors.white
                              : theme.textTheme.headlineSmall?.color)),
                  if (university.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(university,
                          style: theme.textTheme.titleMedium?.copyWith(
                              color: isDarkMode
                                  ? Colors.grey[400]
                                  : theme.textTheme.bodySmall?.color)),
                    ),
                  if (bio.isNotEmpty)
                    Padding(
                      padding:
                          const EdgeInsets.only(top: 10.0, left: 16, right: 16),
                      child: Text(bio,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDarkMode
                                  ? Colors.grey[300]
                                  : theme.textTheme.bodyMedium?.color,
                              height: 1.4)),
                    ),
                  const SizedBox(height: 24),
                  _buildFollowerStats(context, theme, isDarkMode),
                  const SizedBox(height: 20),
                  if (!isOwnProfile)
                    ElevatedButton.icon(
                      onPressed: _isTogglingFollow ? null : _toggleFollow,
                      icon: _isTogglingFollow
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white))
                          : Icon(
                              isFollowing
                                  ? Icons.person_remove_alt_1_rounded
                                  : Icons.person_add_alt_1_rounded,
                              size: 20),
                      label: Text(isFollowing ? "Unfollow" : "Follow"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFollowing
                            ? (isDarkMode
                                ? Colors.grey.shade800
                                : Colors.grey.shade300)
                            : theme.colorScheme.primary,
                        foregroundColor: isFollowing
                            ? (isDarkMode ? Colors.white70 : Colors.black87)
                            : theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.0)),
                      ),
                    ),
                  if (_isUpdatingProfile || _isTogglingFollow)
                    const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: CircularProgressIndicator()),
                  const SizedBox(height: 28),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Notes",
                        style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? Colors.white
                                : theme.textTheme.titleLarge?.color)),
                  ),
                  Divider(
                      thickness: 0.5, height: 24, color: theme.dividerColor),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 30.0),
            sliver: ProfileNotesGrid(
              userId: widget.userId,
              currentUserId: widget.currentUserId,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowerStats(
      BuildContext context, ThemeData theme, bool isDarkMode) {
    Color statTextColor = isDarkMode
        ? Colors.white.withAlpha(230)
        : theme.textTheme.titleLarge!.color!;
    Color labelTextColor =
        isDarkMode ? Colors.grey[400]! : theme.textTheme.bodySmall!.color!;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem("Followers", followersCount,
            () => _navigateToFollowList(true), statTextColor, labelTextColor),
        Container(
            height: 40, width: 1, color: theme.dividerColor.withAlpha(128)),
        _buildStatItem("Following", followingCount,
            () => _navigateToFollowList(false), statTextColor, labelTextColor),
      ],
    );
  }

  Widget _buildStatItem(String label, int count, VoidCallback onTap,
      Color statColor, Color labelColor) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: statColor),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 13, color: labelColor),
            ),
          ],
        ),
      ),
    );
  }
}
