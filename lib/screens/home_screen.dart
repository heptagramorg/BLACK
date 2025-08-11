import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/supabase_service.dart';
import 'profile_screen.dart';
import 'upload_notes_screen.dart';
import 'search_users_screen.dart';
import 'search_notes_screen.dart';
import 'forum_screen.dart';
import 'settings_screen.dart';
import 'calendar_screen.dart';
import 'todo_screen.dart';
import 'view_notes_screen.dart';
import 'trending_notes_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userId;
  final String userRole;

  const HomeScreen({super.key, required this.userId, required this.userRole});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final _supabase = SupabaseService.client;
  String name = "Loading...";
  String? profilePictureUrl;
  int _selectedIndex = 0;
  bool _isSidebarOpen = false;

  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    _loadUserData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final profile = await _supabase
          .from('profiles')
          .select()
          .eq('id', widget.userId)
          .single();
      if (mounted) {
        setState(() {
          name = profile['name'] ?? 'Unknown User';
          profilePictureUrl = profile['profile_picture'];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          name = "Error";
        });
      }
    }
  }

  void _closeSidebar() {
    if (mounted) {
      setState(() {
        _isSidebarOpen = false;
      });
    }
  }

  void _navigateToScreen(Widget screen) {
    _closeSidebar();
    Future.delayed(const Duration(milliseconds: 280), () {
      if (mounted) {
        Navigator.push(
            context, MaterialPageRoute(builder: (context) => screen));
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final List<Widget> screens = [
      _buildHomeTabContent(isDarkMode),
      UploadNotesScreen(userId: widget.userId),
      ProfileScreen(userId: widget.userId, currentUserId: widget.userId),
      const SettingsScreen(),
    ];

    final double sidebarWidth = MediaQuery.of(context).size.width * 0.8;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: <Widget>[
              SliverAppBar(
                title: Text("Home",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.appBarTheme.foregroundColor)),
                backgroundColor: isDarkMode
                    ? Colors.black
                    : theme.appBarTheme.backgroundColor,
                elevation: 0,
                pinned: true,
                forceElevated: false,
                scrolledUnderElevation: 0,
                systemOverlayStyle: theme.appBarTheme.systemOverlayStyle,
                leading: IconButton(
                  icon: Icon(Icons.menu_rounded,
                      color: theme.iconTheme.color, size: 28),
                  onPressed: () =>
                      setState(() => _isSidebarOpen = !_isSidebarOpen),
                  tooltip: "Open Menu",
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: true,
                child: IndexedStack(
                  index: _selectedIndex,
                  children: screens,
                ),
              ),
            ],
          ),
          if (_isSidebarOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeSidebar,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            left: _isSidebarOpen ? 0 : -sidebarWidth,
            top: 0,
            bottom: 0,
            width: sidebarWidth,
            child: _buildSidebar(theme, isDarkMode),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(theme, isDarkMode),
    );
  }

  Widget _buildSidebar(ThemeData theme, bool isDarkMode) {
    final double sidebarWidth = MediaQuery.of(context).size.width * 0.8;
    const double borderRadiusValue = 24.0;

    final RadialGradient sidebarGradient = RadialGradient(
      center: Alignment.topLeft,
      radius: 1.5,
      colors: isDarkMode
          ? [
              theme.colorScheme.primary.withValues(alpha: 0.6),
              theme.colorScheme.primary.withValues(alpha: 0.3),
              Colors.black.withValues(alpha: 0.7),
              Colors.black.withValues(alpha: 0.9),
            ]
          : [
              theme.colorScheme.primary.withValues(alpha: 0.1),
              Colors.white.withValues(alpha: 0.7),
            ],
      stops: isDarkMode ? const [0.0, 0.3, 0.8, 1.0] : const [0.0, 1.0],
    );

    return Material(
      elevation: 16.0,
      color: Colors.transparent,
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(borderRadiusValue),
        bottomRight: Radius.circular(borderRadiusValue),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(borderRadiusValue),
          bottomRight: Radius.circular(borderRadiusValue),
        ),
        child: Container(
          width: sidebarWidth,
          decoration: BoxDecoration(
            gradient: sidebarGradient,
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSidebarHeader(theme, isDarkMode),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Column(
                      children: [
                        _buildSidebarItemGroup([
                          _buildSidebarItem(
                              Icons.search_rounded,
                              "Search Notes",
                              SearchNotesScreen(userId: widget.userId),
                              theme,
                              isDarkMode),
                          _buildSidebarItem(
                              Icons.person_search_rounded,
                              "Search Users",
                              SearchUsersScreen(currentUserId: widget.userId),
                              theme,
                              isDarkMode),
                          _buildSidebarItem(
                              Icons.trending_up_rounded,
                              "Trending Notes",
                              TrendingNotesScreen(userId: widget.userId),
                              theme,
                              isDarkMode),
                        ], theme, isDarkMode),
                        _buildSidebarSectionDivider(theme),
                        _buildSidebarItemGroup([
                          _buildSidebarItem(
                              Icons.forum_outlined,
                              "Forum",
                              ForumScreen(userId: widget.userId),
                              theme,
                              isDarkMode),
                          _buildSidebarItem(
                              Icons.description_outlined,
                              "View Notes",
                              ViewNotesScreen(userId: widget.userId),
                              theme,
                              isDarkMode),
                          _buildSidebarItem(
                              Icons.calendar_today_outlined,
                              "Calendar",
                              const CalendarScreen(),
                              theme,
                              isDarkMode),
                          _buildSidebarItem(
                              Icons.checklist_rtl_rounded,
                              "To-Do List",
                              const TodoScreen(),
                              theme,
                              isDarkMode),
                        ], theme, isDarkMode),
                        _buildSidebarSectionDivider(theme),
                        _buildDarkModeToggle(theme, isDarkMode),
                        _buildSidebarItem(Icons.settings_outlined, "Settings",
                            const SettingsScreen(), theme, isDarkMode),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarItemGroup(
      List<Widget> items, ThemeData theme, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.05)
              : theme.colorScheme.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(18.0),
        ),
        child: Column(
          children: List.generate(items.length, (index) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                items[index],
                if (index < items.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 60.0, right: 16.0),
                    child: Divider(
                        height: 0.5,
                        thickness: 0.5,
                        color: theme.dividerColor
                            .withValues(alpha: isDarkMode ? 0.2 : 0.3)),
                  )
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildSidebarSectionDivider(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Divider(
          height: 1,
          thickness: 1,
          color: theme.dividerColor.withValues(alpha: 0.1)),
    );
  }

  Widget _buildSidebarHeader(ThemeData theme, bool isDarkMode) {
    final textColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.9)
        : theme.textTheme.bodyLarge?.color;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: isDarkMode
                ? theme.colorScheme.primary.withValues(alpha: 0.2)
                : Colors.grey.shade300,
            backgroundImage:
                profilePictureUrl != null && profilePictureUrl!.isNotEmpty
                    ? NetworkImage(profilePictureUrl!)
                    : null,
            child: profilePictureUrl == null || profilePictureUrl!.isEmpty
                ? Icon(Icons.person_outline_rounded,
                    size: 32,
                    color: isDarkMode ? Colors.white70 : Colors.grey.shade700)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hi,",
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.7)
                        : Colors.grey.shade700,
                  ),
                ),
                Text(
                  name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String label, Widget screen,
      ThemeData theme, bool isDarkMode) {
    final itemColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.85)
        : theme.textTheme.bodyLarge!.color;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateToScreen(screen),
        borderRadius: BorderRadius.circular(14),
        splashColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        highlightColor: theme.colorScheme.primary.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 22),
              const SizedBox(width: 22),
              Expanded(
                  child: Text(label,
                      style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500, color: itemColor))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDarkModeToggle(ThemeData theme, bool isDarkMode) {
    final itemColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.85)
        : theme.textTheme.bodyLarge!.color;
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Container(
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.05)
                  : theme.colorScheme.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(18.0),
            ),
            child: SwitchListTile(
              title: Text("Dark Mode",
                  style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500, color: itemColor)),
              secondary: Icon(
                isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: theme.colorScheme.primary,
                size: 22,
              ),
              value: themeProvider.themeMode == ThemeMode.dark,
              onChanged: (value) {
                themeProvider.toggleTheme(value);
              },
              activeTrackColor: theme.colorScheme.primary,
              inactiveTrackColor:
                  isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
              inactiveThumbColor:
                  isDarkMode ? Colors.grey.shade500 : Colors.grey.shade50,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomNavigationBar(ThemeData theme, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(28.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.5 : 0.15),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28.0),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: theme.colorScheme.primary,
          unselectedItemColor: isDarkMode
              ? theme.bottomNavigationBarTheme.unselectedItemColor
              : Colors.grey.shade500,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          elevation: 0,
          iconSize: 26,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.cloud_upload_outlined),
              activeIcon: Icon(Icons.cloud_upload),
              label: "Upload",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: "Profile",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: "Settings",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTabContent(bool isDarkMode) {
    final theme = Theme.of(context);
    final textColor = (isDarkMode
            ? Colors.white.withValues(alpha: 0.9)
            : theme.textTheme.bodyLarge?.color) ??
        Colors.black;

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: RefreshIndicator(
        onRefresh: () async {
          await _loadUserData();
        },
        color: theme.colorScheme.primary,
        backgroundColor: theme.cardColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 20),
                child: Text("Welcome back,",
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: textColor.withValues(alpha: 0.7))),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Text(name,
                    style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold, color: textColor)),
              ),
              const SizedBox(height: 24),
              _buildQuickActionsSection(isDarkMode, theme),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection(bool isDarkMode, ThemeData theme) {
    final RadialGradient darkRadialGradient = RadialGradient(
      center: Alignment.center,
      radius: 0.9,
      colors: [
        theme.colorScheme.primary.withValues(alpha: 0.8),
        theme.colorScheme.primary.withValues(alpha: 0.6),
        const Color(0xFF121212),
        Colors.black,
      ],
      stops: const [0.0, 0.35, 0.75, 1.0],
    );
    final LinearGradient lightLinearGradient = LinearGradient(
      colors: [
        theme.colorScheme.primary,
        theme.colorScheme.primary.withValues(alpha: 0.65),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Quick Actions",
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.0,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildFeatureCardNew(
                  context,
                  "Upload Note",
                  Icons.upload_file_rounded,
                  isDarkMode ? darkRadialGradient : lightLinearGradient,
                  () => _onItemTapped(1),
                  theme,
                  isDarkMode),
              _buildFeatureCardNew(
                  context,
                  "Calendar",
                  Icons.calendar_month_rounded,
                  isDarkMode ? darkRadialGradient : lightLinearGradient,
                  () => _navigateToScreen(const CalendarScreen()),
                  theme,
                  isDarkMode),
              _buildFeatureCardNew(
                  context,
                  "Forum",
                  Icons.forum_rounded,
                  isDarkMode ? darkRadialGradient : lightLinearGradient,
                  () => _navigateToScreen(ForumScreen(userId: widget.userId)),
                  theme,
                  isDarkMode),
              _buildFeatureCardNew(
                  context,
                  "Search Notes",
                  Icons.search_rounded,
                  isDarkMode ? darkRadialGradient : lightLinearGradient,
                  () => _navigateToScreen(
                      SearchNotesScreen(userId: widget.userId)),
                  theme,
                  isDarkMode),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCardNew(
    BuildContext context,
    String title,
    IconData icon,
    Gradient gradient,
    VoidCallback onTap,
    ThemeData theme,
    bool isDarkMode,
  ) {
    final Color iconTextColor = Colors.white.withValues(alpha: 0.95);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: isDarkMode
                  ? Colors.black.withValues(alpha: 0.6)
                  : Colors.grey.withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: iconTextColor),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: iconTextColor,
                  fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
