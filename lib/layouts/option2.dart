import 'package:flutter/material.dart';
import 'dart:ui';

class RobinDashboardMinimal extends StatefulWidget {
  const RobinDashboardMinimal({Key? key}) : super(key: key);

  @override
  State<RobinDashboardMinimal> createState() => _RobinDashboardMinimalState();
}

class _RobinDashboardMinimalState extends State<RobinDashboardMinimal> {
  int selectedIndex = 0;
  PageController pageController = PageController();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F0F23), Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: Stack(
          children: [
            // Background Pattern
            _buildBackgroundPattern(),

            // Main Content
            SafeArea(
              child: Column(
                children: [
                  _buildTopAppBar(context, isDesktop),
                  Expanded(
                    child: Row(
                      children: [
                        if (isDesktop)
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: _buildDesktopSidebar(),
                          ),
                        Expanded(
                          child: _buildMainDashboard(context, isDesktop),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // Floating Bottom Navigation for mobile
      floatingActionButtonLocation:
          screenWidth <= 800 ? FloatingActionButtonLocation.centerDocked : null,
      floatingActionButton:
          screenWidth <= 800 ? _buildFloatingNav() : _buildDesktopFAB(),

      bottomNavigationBar: screenWidth <= 800 ? _buildGlassBottomBar() : null,
    );
  }

  Widget _buildBackgroundPattern() {
    return Positioned.fill(
      child: CustomPaint(painter: BackgroundPatternPainter()),
    );
  }

  Widget _buildTopAppBar(BuildContext context, bool isDesktop) {
    return Container(
      height: 80,
      margin: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Logo
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF667EEA).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.code_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),

                const Text(
                  'Robin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),

                const Spacer(),

                // Search
                if (isDesktop) ...[
                  _buildGlassSearchBar(),
                  const SizedBox(width: 16),
                ],

                // Profile & Actions
                _buildProfileSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassSearchBar() {
    return Container(
      width: 320,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: TextField(
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search anything...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
          prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.6)),
          suffixIcon: Container(
            margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF667EEA).withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.tune, color: Colors.white, size: 16),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Row(
      children: [
        _buildGlassIconButton(Icons.notifications_rounded),
        const SizedBox(width: 12),
        _buildGlassIconButton(Icons.brightness_6_rounded),
        const SizedBox(width: 16),

        // Profile Avatar
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF667EEA).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'JD',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassIconButton(IconData icon) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: IconButton(
        onPressed: () {},
        icon: Icon(icon, color: Colors.white.withOpacity(0.8), size: 20),
      ),
    );
  }

  Widget _buildDesktopSidebar() {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(left: 16, bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                // Navigation
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildNavSection('MAIN', [
                        _buildNavItem(Icons.dashboard_rounded, 'Dashboard', 0),
                        _buildNavItem(Icons.folder_rounded, 'Projects', 1),
                        _buildNavItem(
                          Icons.school_rounded,
                          'Learning Paths',
                          2,
                        ),
                      ]),

                      const SizedBox(height: 24),

                      _buildNavSection('TOOLS', [
                        _buildNavItem(
                          Icons.chat_bubble_rounded,
                          'AI Assistant',
                          3,
                        ),
                        _buildNavItem(Icons.code_rounded, 'Code Editor', 4),
                        _buildNavItem(Icons.quiz_rounded, 'Assessments', 5),
                      ]),

                      const SizedBox(height: 24),

                      _buildNavSection('SOCIAL', [
                        _buildNavItem(
                          Icons.leaderboard_rounded,
                          'Leaderboard',
                          6,
                        ),
                        _buildNavItem(Icons.people_rounded, 'Community', 7),
                      ]),
                    ],
                  ),
                ),

                // User Stats
                _buildUserStatsCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ...items,
      ],
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = selectedIndex == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => selectedIndex = index),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color:
                  isSelected
                      ? Colors.white.withOpacity(0.15)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border:
                  isSelected
                      ? Border.all(color: Colors.white.withOpacity(0.3))
                      : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color:
                      isSelected ? Colors.white : Colors.white.withOpacity(0.7),
                  size: 20,
                ),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: TextStyle(
                    color:
                        isSelected
                            ? Colors.white
                            : Colors.white.withOpacity(0.7),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserStatsCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF667EEA).withOpacity(0.3),
            const Color(0xFF764BA2).withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                color: Color(0xFFFFD700),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Level 12',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Text(
                '2,450 XP',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: 0.75,
            backgroundColor: Colors.white.withOpacity(0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
          ),
          const SizedBox(height: 8),
          Text(
            '550 XP to Level 13',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainDashboard(BuildContext context, bool isDesktop) {
    return Container(
      margin: EdgeInsets.only(right: 16, bottom: 16, left: isDesktop ? 0 : 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Hero Section
                  _buildHeroSection(),
                  const SizedBox(height: 32),

                  // Quick Stats
                  _buildQuickStats(isDesktop),
                  const SizedBox(height: 32),

                  // Main Content Grid
                  _buildContentGrid(isDesktop),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF667EEA).withOpacity(0.8),
            const Color(0xFF764BA2).withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good morning, John! ☀️',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ready to build\nsomething amazing?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildGlassButton(
                      'Generate App',
                      Icons.auto_awesome_rounded,
                      () {},
                      isPrimary: true,
                    ),
                    const SizedBox(width: 12),
                    _buildGlassButton(
                      'Continue Learning',
                      Icons.play_arrow_rounded,
                      () {},
                      isPrimary: false,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(60),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: const Icon(
              Icons.rocket_launch_rounded,
              size: 50,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassButton(
    String text,
    IconData icon,
    VoidCallback onPressed, {
    required bool isPrimary,
  }) {
    return Container(
      decoration: BoxDecoration(
        color:
            isPrimary
                ? Colors.white.withOpacity(0.2)
                : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats(bool isDesktop) {
    return GridView.count(
      crossAxisCount: isDesktop ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: isDesktop ? 1.3 : 1.1,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildGlassStatCard(
          'Active Projects',
          '8',
          Icons.folder_open_rounded,
          const Color(0xFF10B981),
        ),
        _buildGlassStatCard(
          'Completed',
          '24',
          Icons.check_circle_rounded,
          const Color(0xFF3B82F6),
        ),
        _buildGlassStatCard(
          'Learning Hours',
          '127',
          Icons.timer_rounded,
          const Color(0xFFF59E0B),
        ),
        _buildGlassStatCard(
          'Streak Days',
          '15',
          Icons.local_fire_department_rounded,
          const Color(0xFFEF4444),
        ),
      ],
    );
  }

  Widget _buildGlassStatCard(
    String title,
    String value,
    IconData icon,
    Color accentColor,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: 24),
              ),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentGrid(bool isDesktop) {
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _buildRecentProjectsCard(),
                const SizedBox(height: 24),
                _buildLearningPathsCard(),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                _buildAiAssistantCard(),
                const SizedBox(height: 24),
                _buildUpcomingCard(),
              ],
            ),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          _buildRecentProjectsCard(),
          const SizedBox(height: 24),
          _buildAiAssistantCard(),
          const SizedBox(height: 24),
          _buildLearningPathsCard(),
          const SizedBox(height: 24),
          _buildUpcomingCard(),
        ],
      );
    }
  }

  Widget _buildRecentProjectsCard() {
    return _buildGlassCard(
      title: 'Recent Projects',
      child: Column(
        children: [
          _buildProjectTile(
            'E-commerce Mobile App',
            'Flutter • 75% Complete',
            const Color(0xFF10B981),
            Icons.shopping_cart_rounded,
          ),
          const SizedBox(height: 16),
          _buildProjectTile(
            'Weather Dashboard',
            'React • Ready to Deploy',
            const Color(0xFF3B82F6),
            Icons.cloud_rounded,
          ),
          const SizedBox(height: 16),
          _buildProjectTile(
            'Task Management API',
            'Node.js • In Development',
            const Color(0xFFF59E0B),
            Icons.api_rounded,
          ),
          const SizedBox(height: 20),
          _buildGlassButton(
            'View All Projects',
            Icons.arrow_forward_rounded,
            () {},
            isPrimary: false,
          ),
        ],
      ),
    );
  }

  Widget _buildProjectTile(
    String name,
    String status,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: Colors.white.withOpacity(0.5),
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildAiAssistantCard() {
    return _buildGlassCard(
      title: 'AI Assistant',
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.smart_toy_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'How can I help you code today?',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Ask me anything...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                suffixIcon: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLearningPathsCard() {
    return _buildGlassCard(
      title: 'Learning Progress',
      child: Column(
        children: [
          _buildProgressItem(
            'React Native Mastery',
            0.75,
            const Color(0xFF06B6D4),
          ),
          const SizedBox(height: 16),
          _buildProgressItem('Node.js Backend', 0.45, const Color(0xFF10B981)),
          const SizedBox(height: 16),
          _buildProgressItem('Flutter Advanced', 0.90, const Color(0xFF3B82F6)),
          const SizedBox(height: 20),
          _buildGlassButton(
            'Continue Learning',
            Icons.play_arrow_rounded,
            () {},
            isPrimary: true,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressItem(String title, double progress, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingCard() {
    return _buildGlassCard(
      title: 'Upcoming',
      child: Column(
        children: [
          _buildUpcomingItem(
            'JavaScript Assessment',
            'Tomorrow, 2:00 PM',
            Icons.quiz_rounded,
            const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 12),
          _buildUpcomingItem(
            'Code Review Session',
            'Friday, 3:30 PM',
            Icons.code_rounded,
            const Color(0xFF8B5CF6),
          ),
          const SizedBox(height: 12),
          _buildUpcomingItem(
            'Team Standup',
            'Monday, 9:00 AM',
            Icons.people_rounded,
            const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required String title, required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopFAB() {
    return FloatingActionButton(
      onPressed: () {},
      backgroundColor: const Color(0xFF667EEA),
      elevation: 8,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF667EEA).withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFloatingNav() {
    return Container(
      height: 60,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMobileNavItem(Icons.dashboard_rounded, 0),
          _buildMobileNavItem(Icons.folder_rounded, 1),
          Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667EEA).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.add, color: Colors.white),
          ),
          _buildMobileNavItem(Icons.chat_bubble_rounded, 3),
          _buildMobileNavItem(Icons.person_rounded, 4),
        ],
      ),
    );
  }

  Widget _buildMobileNavItem(IconData icon, int index) {
    return IconButton(
      icon: Icon(
        icon,
        color:
            selectedIndex == index
                ? Colors.white
                : Colors.white.withOpacity(0.6),
      ),
      onPressed:
          () => setState(() {
            selectedIndex = index;
            pageController.jumpToPage(index);
          }),
    );
  }

  Widget _buildGlassBottomBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingItem(
    String title,
    String time,
    IconData icon,
    Color color,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          // Add your onTap logic here
          print('Upcoming item tapped: $title');
        },
        splashColor: color.withOpacity(0.2),
        highlightColor: Colors.white.withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      time,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withOpacity(0.3),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BackgroundPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.white.withOpacity(0.03)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;

    const step = 40.0;

    // Draw grid lines
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Draw subtle center gradient
    final center = Offset(size.width / 2, size.height / 2);
    final gradient = RadialGradient(
      colors: [const Color(0xFF667EEA).withOpacity(0.05), Colors.transparent],
    );
    canvas.drawCircle(
      center,
      size.width * 0.6,
      Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(center: center, radius: size.width * 0.6),
        ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
