import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui'; // For ImageFilter.blur

import '../providers/theme_provider.dart';
import '../providers/note_engagement_provider.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';
import 'login_screen.dart';
import 'manage_notes_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  final _supabase = SupabaseService.client;

  bool _isLoading = false;
  bool _enableAllNotifications = true;
  bool _newFollowerNotifications = true;
  bool _noteInteractionNotifications = true;
  String _appVersion = "1.2.5"; // Placeholder, consider using package_info_plus

  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final GlobalKey<FormState> _passwordFormKey = GlobalKey<FormState>();
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _getAppVersion(); // Load app version
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _getAppVersion() async {
    // In a real app, use package_info_plus to get this dynamically
    // For now, we'll keep the placeholder.
    // final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    // if (mounted) {
    //   setState(() {
    //     _appVersion = "${packageInfo.version}+${packageInfo.buildNumber}";
    //   });
    // }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _enableAllNotifications =
            prefs.getBool('enable_all_notifications') ?? true;
        _newFollowerNotifications =
            prefs.getBool('new_follower_notifications') ?? true;
        _noteInteractionNotifications =
            prefs.getBool('note_interaction_notifications') ?? true;
      });
    }
  }

  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  void _showSnackBar(String message,
      {bool isError = false, Duration duration = const Duration(seconds: 4)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0)), // Themed
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    _isNewPasswordVisible = false;
    _isConfirmPasswordVisible = false;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final bool? success = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent, // For glass effect
            insetPadding: const EdgeInsets.all(20),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24.0)), // More rounded
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
                  child: Form(
                    key: _passwordFormKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text("Change Password",
                            style: theme.textTheme.headlineSmall?.copyWith(
                                color: isDarkMode
                                    ? Colors.white.withAlpha(229)
                                    : theme.textTheme.headlineSmall?.color,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _newPasswordController,
                          obscureText: !_isNewPasswordVisible,
                          style: TextStyle(
                              color: isDarkMode
                                  ? Colors.white.withAlpha(229)
                                  : null),
                          decoration: _inputDecoration(
                            "New Password",
                            Icons.lock_outline,
                            theme,
                            isDarkMode,
                            suffixIcon: IconButton(
                              icon: Icon(_isNewPasswordVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined),
                              onPressed: () => setDialogState(() =>
                                  _isNewPasswordVisible =
                                      !_isNewPasswordVisible),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a new password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters long';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: !_isConfirmPasswordVisible,
                          style: TextStyle(
                              color: isDarkMode
                                  ? Colors.white.withAlpha(229)
                                  : null),
                          decoration: _inputDecoration(
                            "Confirm New Password",
                            Icons.lock_outline,
                            theme,
                            isDarkMode,
                            suffixIcon: IconButton(
                              icon: Icon(_isConfirmPasswordVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined),
                              onPressed: () => setDialogState(() =>
                                  _isConfirmPasswordVisible =
                                      !_isConfirmPasswordVisible),
                            ),
                          ),
                          validator: (value) {
                            if (value != _newPasswordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              child: Text("Cancel",
                                  style: TextStyle(
                                      color: isDarkMode
                                          ? theme.colorScheme.secondary
                                          : theme.hintColor)),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () {
                                if (_passwordFormKey.currentState!.validate()) {
                                  Navigator.of(dialogContext).pop(true);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12))),
                              child: const Text("Update Password"),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        });
      },
    );

    if (success == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await _supabase.auth
            .updateUser(UserAttributes(password: _newPasswordController.text));
        if (mounted) {
          _showSnackBar("Password updated successfully!", isError: false);
        }
      } on AuthException catch (e) {
        if (mounted) {
          _showSnackBar("Failed to update password: ${e.message}",
              isError: true);
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar("An unexpected error occurred: ${e.toString()}",
              isError: true);
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
    _newPasswordController.clear();
    _confirmPasswordController.clear();
  }

  InputDecoration _inputDecoration(
      String label, IconData icon, ThemeData theme, bool isDarkMode,
      {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
          color: isDarkMode ? Colors.white.withAlpha(179) : theme.hintColor),
      prefixIcon: Icon(icon,
          // FIX: Removed unnecessary null-aware operator `?.` because `hintColor` is guaranteed to be non-null by the app's theme.
          color: isDarkMode
              ? Colors.white.withAlpha(179)
              : theme.hintColor.withAlpha(204)),
      suffixIcon: suffixIcon != null
          ? Theme(
              data: theme.copyWith(
                  iconTheme: IconThemeData(
                      color: isDarkMode
                          ? Colors.white.withAlpha(179)
                          : theme.hintColor)),
              child: suffixIcon)
          : null,
      filled: true,
      fillColor:
          isDarkMode ? Colors.black.withAlpha(38) : Colors.white.withAlpha(77),
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
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Future<void> _signOut() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await NotificationService().removeTokenOnLogout();
      await _authService.signOut();
      if (mounted) {
        Provider.of<NoteEngagementProvider>(context, listen: false).clear();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar("Sign out failed: ${e.toString()}", isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final theme = Theme.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Delete Account?"),
          content: const Text(
              "This is permanent and cannot be undone. All your notes, profile data, and activity will be erased."),
          actions: <Widget>[
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.error),
              child: Text("Delete My Account",
                  style: TextStyle(color: theme.colorScheme.onError)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      _deleteAccount();
    }
  }

  Future<void> _deleteAccount() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    _showSnackBar("Deleting your account and data... This may take a moment.",
        duration: const Duration(seconds: 5));
    try {
      final user = SupabaseService.currentUser;
      if (user == null) {
        _showSnackBar("No authenticated user found to delete.", isError: true);
        setState(() => _isLoading = false);
        return;
      }
      final userId = user.id;
      await _performManualUserDataCleanup(userId);

      await _supabase.auth.signOut();
      if (mounted) {
        _showSnackBar(
            "Account data has been processed for deletion. You have been signed out.",
            isError: false,
            duration: const Duration(seconds: 5));
        Provider.of<NoteEngagementProvider>(context, listen: false).clear();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar("Failed to process account deletion: ${e.toString()}",
            isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _performManualUserDataCleanup(String userId) async {
    bool allSuccess = true;
    Future<void> deleteFromTable(String table, String column) async {
      try {
        await _supabase.from(table).delete().eq(column, userId);
      } catch (e) {
        allSuccess = false;
      }
    }

    await deleteFromTable('note_likes', 'user_id');
    await deleteFromTable('note_views', 'user_id');
    await deleteFromTable('saved_notes', 'user_id');
    await deleteFromTable('file_access_logs', 'user_id');
    await deleteFromTable('followers', 'follower_id');
    await deleteFromTable('followers', 'followed_id');
    await deleteFromTable('forum_replies', 'user_id');
    await deleteFromTable('forum_posts', 'user_id');
    await deleteFromTable('events', 'user_id');

    try {
      final notes = await _supabase
          .from('notes')
          .select('id, file_url')
          .eq('user_id', userId);
      List<String> noteFilePathsToDelete = [];
      for (var note in (notes as List)) {
        final fileUrl = note['file_url'] as String?;
        if (fileUrl != null && fileUrl.isNotEmpty) {
          final path = _extractStoragePathFromUrl(fileUrl, 'notes');
          if (path != null) noteFilePathsToDelete.add(path);
        }
      }
      if (noteFilePathsToDelete.isNotEmpty) {
        await _supabase.storage.from('notes').remove(noteFilePathsToDelete);
      }
      await deleteFromTable('notes', 'user_id');
    } catch (e) {
      allSuccess = false;
    }

    try {
      final profile = await _supabase
          .from('profiles')
          .select('profile_picture')
          .eq('id', userId)
          .maybeSingle();
      final profilePicUrl = profile?['profile_picture'] as String?;
      if (profilePicUrl != null && profilePicUrl.isNotEmpty) {
        final path =
            _extractStoragePathFromUrl(profilePicUrl, 'profile_pictures');
        if (path != null) {
          await _supabase.storage.from('profile_pictures').remove([path]);
        }
      }
    } catch (e) {
      allSuccess = false;
    }

    await deleteFromTable('profiles', 'id');
    return allSuccess;
  }

  String? _extractStoragePathFromUrl(String url, String bucketName) {
    try {
      final Uri uri = Uri.parse(url);
      final List<String> segments = uri.pathSegments;
      int bucketSegmentIndex = segments.indexOf(bucketName);
      if (bucketSegmentIndex != -1 &&
          bucketSegmentIndex + 1 < segments.length) {
        return segments.sublist(bucketSegmentIndex + 1).join('/');
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _launchUrlUtil(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        _showSnackBar("Could not launch URL: $urlString", isError: true);
      }
    }
  }

  void _showAboutAppDialog(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    showDialog(
        context: context,
        builder: (context) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24.0)),
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.menu_book_rounded,
                            size: 54, color: theme.colorScheme.primary),
                        const SizedBox(height: 16),
                        Text("Black",
                            style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? Colors.white.withAlpha(229)
                                    : theme.textTheme.headlineSmall?.color)),
                        const SizedBox(height: 8),
                        Text("Version $_appVersion",
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDarkMode
                                    ? Colors.grey[400]
                                    : Colors.grey[600])),
                        const SizedBox(height: 16),
                        Text(
                          "Black is a student note-sharing app designed to help students collaborate and share academic resources, fostering a community of learners.",
                          style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.5,
                              color: isDarkMode
                                  ? Colors.grey[300]
                                  : Colors.grey[700]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Text("© ${DateTime.now().year} Black App",
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: isDarkMode
                                    ? Colors.grey[500]
                                    : Colors.grey[500])),
                        const SizedBox(height: 20),
                        TextButton(
                          child: const Text("Close"),
                          onPressed: () => Navigator.of(context).pop(),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ));
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text("Settings"),
            backgroundColor:
                isDarkMode ? Colors.black : theme.appBarTheme.backgroundColor,
            elevation: 0,
            pinned: true,
            forceElevated: false,
            scrolledUnderElevation: 0,
            actions: [
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.0)),
                )
            ],
          ),
          SliverList(
            delegate: SliverChildListDelegate(
              [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 8.0),
                  child: Column(
                    children: [
                      _SectionHeader(title: 'Account', theme: theme),
                      _SettingTile(
                        icon: Icons.notes_outlined,
                        title: "Manage Notes",
                        subtitle: "View and edit your uploaded notes",
                        onTap: () {
                          final userId = SupabaseService.currentUserId;
                          if (userId != null) {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        ManageNotesScreen(userId: userId)));
                          } else {
                            _showSnackBar(
                                "You must be logged in to manage notes.",
                                isError: true);
                          }
                        },
                        theme: theme,
                        isDarkMode: isDarkMode,
                      ),
                      _SettingTile(
                        icon: Icons.lock_outline_rounded,
                        title: "Change Password",
                        subtitle: "Update your login password",
                        onTap: _showChangePasswordDialog,
                        theme: theme,
                        isDarkMode: isDarkMode,
                      ),
                      _SectionHeader(title: 'App Settings', theme: theme),
                      _SettingTile(
                        isSwitchTile: true,
                        icon: Icons.dark_mode_outlined,
                        title: "Dark Mode",
                        value: themeProvider.themeMode == ThemeMode.dark,
                        onChanged: (value) {
                          themeProvider.toggleTheme(value);
                        },
                        theme: theme,
                        isDarkMode: isDarkMode,
                      ),
                      _SettingTile(
                        isSwitchTile: true,
                        icon: Icons.notifications_active_outlined,
                        title: "Enable All Notifications",
                        subtitle: "Master control for all app alerts",
                        value: _enableAllNotifications,
                        onChanged: (value) {
                          setState(() => _enableAllNotifications = value);
                          _savePreference('enable_all_notifications', value);
                        },
                        theme: theme,
                        isDarkMode: isDarkMode,
                      ),
                      if (_enableAllNotifications) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 20.0),
                          child: _SettingTile(
                            isSwitchTile: true,
                            icon: Icons.person_add_alt_1_outlined,
                            title: "New Follower Alerts",
                            value: _newFollowerNotifications,
                            onChanged: (value) {
                              setState(() => _newFollowerNotifications = value);
                              _savePreference(
                                  'new_follower_notifications', value);
                            },
                            theme: theme,
                            isDarkMode: isDarkMode,
                            dense: true,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 20.0),
                          child: _SettingTile(
                            isSwitchTile: true,
                            icon: Icons.comment_outlined,
                            title: "Note Engagement Alerts",
                            subtitle: "Likes, comments on your notes",
                            value: _noteInteractionNotifications,
                            onChanged: (value) {
                              setState(
                                  () => _noteInteractionNotifications = value);
                              _savePreference(
                                  'note_interaction_notifications', value);
                            },
                            theme: theme,
                            isDarkMode: isDarkMode,
                            dense: true,
                          ),
                        ),
                      ],
                      _SectionHeader(title: 'Support & Legal', theme: theme),
                      _SettingTile(
                        icon: Icons.help_outline_rounded,
                        title: "Help & Support",
                        subtitle: "Find answers and contact support",
                        onTap: () => _launchUrlUtil(
                            'https://www.ultimatelyitsblack.com/support.html'),
                        theme: theme,
                        isDarkMode: isDarkMode,
                      ),
                      _SettingTile(
                        icon: Icons.privacy_tip_outlined,
                        title: "Privacy Policy",
                        subtitle: "Read our data handling practices",
                        onTap: () => _launchUrlUtil(
                            'https://www.ultimatelyitsblack.com/privacy.html'),
                        theme: theme,
                        isDarkMode: isDarkMode,
                      ),
                      _SettingTile(
                        icon: Icons.info_outline_rounded,
                        title: "About Black",
                        subtitle: "App version and information",
                        onTap: () => _showAboutAppDialog(context),
                        theme: theme,
                        isDarkMode: isDarkMode,
                      ),
                      _SectionHeader(title: 'Session', theme: theme),
                      _SettingTile(
                        icon: Icons.logout_rounded,
                        title: "Sign Out",
                        subtitle: "End your current session",
                        onTap: _isLoading ? null : _signOut,
                        theme: theme,
                        isDarkMode: isDarkMode,
                        titleColor: theme.colorScheme.error,
                        iconColor: theme.colorScheme.error,
                      ),
                      _SectionHeader(title: 'Danger Zone', theme: theme),
                      _SettingTile(
                        icon: Icons.delete_forever_outlined,
                        title: "Delete Account",
                        subtitle: "Permanently erase your account and data",
                        onTap: _isLoading ? null : _confirmDeleteAccount,
                        theme: theme,
                        isDarkMode: isDarkMode,
                        titleColor: theme.colorScheme.error,
                        iconColor: theme.colorScheme.error,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 30.0, horizontal: 16.0),
                        child: Center(
                          child: Text(
                            "App Version: $_appVersion",
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.hintColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final ThemeData theme;
  const _SectionHeader({required this.title, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final ThemeData theme;
  final bool isDarkMode;
  final Color? titleColor;
  final Color? iconColor;
  final bool isSwitchTile;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool dense;

  const _SettingTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    required this.theme,
    required this.isDarkMode,
    this.titleColor,
    this.iconColor,
    this.isSwitchTile = false,
    this.value = false,
    this.onChanged,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color defaultIconColor =
        iconColor ?? (isDarkMode ? Colors.grey[400] : Colors.grey[600])!;
    final Color defaultTitleColor = titleColor ??
        (isDarkMode
            ? Colors.white.withAlpha(229)
            : theme.textTheme.titleMedium!.color)!;
    final Color defaultSubtitleColor = subtitle != null
        ? (isDarkMode ? Colors.grey[500] : Colors.grey[600])!
        : Colors.transparent;

    Widget tileContent = ListTile(
      contentPadding:
          EdgeInsets.symmetric(horizontal: 16.0, vertical: dense ? 4.0 : 8.0),
      leading: Icon(icon, color: defaultIconColor, size: dense ? 20 : 24),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
            color: defaultTitleColor,
            fontSize: dense ? 15 : null,
            fontWeight: dense ? FontWeight.normal : FontWeight.w500),
      ),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: defaultSubtitleColor, fontSize: dense ? 11 : null))
          : null,
      trailing: isSwitchTile
          ? Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeTrackColor: theme.colorScheme.primary,
              inactiveTrackColor: isDarkMode
                  ? Colors.grey.shade800.withAlpha(179)
                  : Colors.grey.shade300,
              inactiveThumbColor:
                  isDarkMode ? Colors.grey.shade600 : Colors.grey.shade50,
            )
          : (onTap != null
              ? Icon(Icons.arrow_forward_ios_rounded,
                  size: 18, color: theme.hintColor)
              : null),
      onTap: isSwitchTile ? () => onChanged?.call(!value) : onTap,
      dense: dense,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
    );

    return Card(
      margin: EdgeInsets.symmetric(
          horizontal: dense ? 0 : 8.0, vertical: dense ? 2.0 : 4.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: tileContent,
    );
  }
}
