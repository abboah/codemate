import 'package:flutter/material.dart';

class RobinDashboardModern extends StatefulWidget {
  const RobinDashboardModern({Key? key}) : super(key: key);

  @override
  State<RobinDashboardModern> createState() => _RobinDashboardModernState();
}

class _RobinDashboardModernState extends State<RobinDashboardModern> {
  int selectedIndex = 0;
  bool isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 800 && screenWidth <= 1200;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Row(
        children: [
          // Adaptive Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: isDesktop ? (isExpanded ? 280 : 80) : (isTablet ? 80 : 0),
            child: _buildSidebar(context, isDesktop),
          ),

          // Main Content
          Expanded(
            child: Column(
              children: [
                _buildTopBar(context, isDesktop),
                Expanded(child: _buildMainContent(context, isDesktop)),
              ],
            ),
          ),
        ],
      ),

      // Mobile Bottom Navigation
      bottomNavigationBar: screenWidth <= 800 ? _buildBottomNav() : null,

      // Floating Action Button for Quick Actions
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: const Color(0xFF6366F1),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Project'),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, bool isDesktop) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F1419),
        border: Border(right: BorderSide(color: Color(0xFF1F2937), width: 1)),
      ),
      child: Column(
        children: [
          // Logo Section
          Container(
            height: 80,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.code_rounded, color: Colors.white),
                ),
                if (isExpanded) ...[
                  const SizedBox(width: 12),
                  const Text(
                    'Robin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildNavItem(Icons.dashboard_rounded, 'Dashboard', 0),
                _buildNavItem(Icons.folder_rounded, 'Projects', 1),
                _buildNavItem(Icons.school_rounded, 'Learning', 2),
                _buildNavItem(Icons.chat_bubble_rounded, 'AI Assistant', 3),
                _buildNavItem(Icons.code_rounded, 'Code Editor', 4),
                _buildNavItem(Icons.quiz_rounded, 'Assessments', 5),
                _buildNavItem(Icons.leaderboard_rounded, 'Leaderboard', 6),

                const SizedBox(height: 24),
                const Divider(color: Color(0xFF1F2937)),
                const SizedBox(height: 12),

                _buildNavItem(Icons.settings_rounded, 'Settings', 7),
                _buildNavItem(Icons.help_rounded, 'Help', 8),
              ],
            ),
          ),

          // User Profile Section
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF6366F1),
                  child: const Text(
                    'JD',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                if (isExpanded) ...[
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'John Developer',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Level 12',
                          style: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = selectedIndex == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => selectedIndex = index),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color:
                  isSelected ? const Color(0xFF6366F1).withOpacity(0.1) : null,
              borderRadius: BorderRadius.circular(12),
              border:
                  isSelected
                      ? Border.all(
                        color: const Color(0xFF6366F1).withOpacity(0.3),
                      )
                      : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color:
                      isSelected
                          ? const Color(0xFF6366F1)
                          : const Color(0xFF9CA3AF),
                  size: 20,
                ),
                if (isExpanded) ...[
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      color:
                          isSelected
                              ? const Color(0xFF6366F1)
                              : const Color(0xFF9CA3AF),
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool isDesktop) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF0F1419),
        border: Border(bottom: BorderSide(color: Color(0xFF1F2937), width: 1)),
      ),
      child: Row(
        children: [
          if (!isDesktop)
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.menu, color: Colors.white),
            ),

          const Text(
            'Dashboard',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const Spacer(),

          // Search Bar
          Container(
            width: 300,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search projects, paths...',
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Notifications
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_rounded,
              color: Color(0xFF9CA3AF),
            ),
          ),

          // Theme Toggle
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.brightness_6_rounded,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, bool isDesktop) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section
          _buildWelcomeSection(),
          const SizedBox(height: 32),

          // Stats Overview
          _buildStatsOverview(isDesktop),
          const SizedBox(height: 32),

          // Quick Actions & Recent Projects
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _buildQuickActions()),
              const SizedBox(width: 24),
              Expanded(flex: 3, child: _buildRecentProjects()),
            ],
          ),

          const SizedBox(height: 32),

          // Learning Progress & AI Chat Preview
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildLearningProgress()),
              const SizedBox(width: 24),
              Expanded(child: _buildAiChatPreview()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome back, John! 👋',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ready to build something amazing today?',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Start New Project'),
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
            ),
            child: const Icon(
              Icons.rocket_launch_rounded,
              size: 60,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsOverview(bool isDesktop) {
    return GridView.count(
      crossAxisCount: isDesktop ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: isDesktop ? 1.5 : 1.2,
      children: [
        _buildStatCard(
          'Projects',
          '12',
          Icons.folder_rounded,
          const Color(0xFF10B981),
        ),
        _buildStatCard(
          'Completed',
          '8',
          Icons.check_circle_rounded,
          const Color(0xFF3B82F6),
        ),
        _buildStatCard(
          'In Progress',
          '4',
          Icons.schedule_rounded,
          const Color(0xFFF59E0B),
        ),
        _buildStatCard(
          'XP Points',
          '2,450',
          Icons.star_rounded,
          const Color(0xFF8B5CF6),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF374151), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Icon(Icons.more_vert, color: Color(0xFF9CA3AF), size: 16),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF374151), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildActionButton(
            'Generate New App',
            'AI-powered project scaffolding',
            Icons.auto_awesome_rounded,
            const Color(0xFF6366F1),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            'Continue Learning',
            'Resume React Native path',
            Icons.play_arrow_rounded,
            const Color(0xFF10B981),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            'Ask AI Assistant',
            'Get help with your code',
            Icons.chat_bubble_rounded,
            const Color(0xFF8B5CF6),
          ),
          const SizedBox(height: 12),
          _buildActionButton(
            'Take Assessment',
            'Test your JavaScript skills',
            Icons.quiz_rounded,
            const Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF374151).withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF4B5563), width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFF9CA3AF),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentProjects() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF374151), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Projects',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text(
                  'View All',
                  style: TextStyle(color: Color(0xFF6366F1)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildProjectCard(
            'E-commerce Mobile App',
            'Flutter • Firebase',
            'In Progress',
            const Color(0xFF10B981),
            0.75,
          ),
          const SizedBox(height: 16),
          _buildProjectCard(
            'Weather Dashboard',
            'React • Node.js',
            'Completed',
            const Color(0xFF3B82F6),
            1.0,
          ),
          const SizedBox(height: 16),
          _buildProjectCard(
            'Task Management API',
            'Python • FastAPI',
            'In Progress',
            const Color(0xFFF59E0B),
            0.45,
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(
    String name,
    String tech,
    String status,
    Color statusColor,
    double progress,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF374151).withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4B5563), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tech,
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: const Color(0xFF4B5563),
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLearningProgress() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF374151), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Learning Progress',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildLearningPath(
            'React Native Mastery',
            0.65,
            const Color(0xFF06B6D4),
          ),
          const SizedBox(height: 16),
          _buildLearningPath('Node.js Backend', 0.30, const Color(0xFF10B981)),
          const SizedBox(height: 16),
          _buildLearningPath('Flutter Advanced', 0.85, const Color(0xFF3B82F6)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              minimumSize: const Size(double.infinity, 44),
            ),
            child: const Text('Continue Learning'),
          ),
        ],
      ),
    );
  }

  Widget _buildLearningPath(String name, double progress, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: const Color(0xFF4B5563),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }

  Widget _buildAiChatPreview() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF374151), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'AI Assistant',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildChatMessage(
            'How do I implement authentication in Flutter?',
            true,
          ),
          const SizedBox(height: 12),
          _buildChatMessage(
            'I can help you implement authentication! Here are the main approaches...',
            false,
          ),
          const SizedBox(height: 20),
          TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Ask me anything...',
              hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
              suffixIcon: const Icon(Icons.send, color: Color(0xFF6366F1)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF4B5563)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF4B5563)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF6366F1)),
              ),
              filled: true,
              fillColor: const Color(0xFF374151).withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatMessage(String message, bool isUser) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isUser) ...[
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  isUser
                      ? const Color(0xFF6366F1).withOpacity(0.1)
                      : const Color(0xFF374151).withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ),
        if (isUser) ...[
          const SizedBox(width: 12),
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFF6366F1),
            child: Text(
              'JD',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1F2937),
        border: Border(top: BorderSide(color: Color(0xFF374151), width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) => setState(() => selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        selectedItemColor: const Color(0xFF6366F1),
        unselectedItemColor: const Color(0xFF9CA3AF),
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_rounded),
            label: 'Projects',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school_rounded),
            label: 'Learning',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_rounded),
            label: 'AI Chat',
          ),
        ],
      ),
    );
  }
}
