import 'package:codemate/widgets/app_showcase_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:codemate/themes/colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:codemate/providers/auth_provider.dart';
import 'package:codemate/components/settings_profile_modal.dart';
import 'package:showcaseview/showcaseview.dart';

class PremiumSidebarItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  PremiumSidebarItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });
}

class PremiumSidebar extends ConsumerStatefulWidget {
  final List<PremiumSidebarItem> items;
  final double collapsedWidth;
  final double expandedWidth;
  final double topPadding;
  // Optional middle content (e.g., Playground history panel)
  final Widget? middle;
  final GlobalKey? navKey;
  final GlobalKey? settingsKey;
  final GlobalKey? profileKey;

  const PremiumSidebar({
    super.key,
    required this.items,
    this.collapsedWidth = 70,
    this.expandedWidth = 240,
    this.topPadding = 16,
    this.middle,
    this.navKey,
    this.settingsKey,
    this.profileKey,
  });

  @override
  ConsumerState<PremiumSidebar> createState() => _PremiumSidebarState();
}

class _PremiumSidebarState extends ConsumerState<PremiumSidebar>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _overlay;
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _showing = false;

  String _getInitials(String fullName) {
    if (fullName.isEmpty) return '??';
    List<String> names = fullName.split(" ");
    String initials = "";
    if (names.isNotEmpty) {
      initials += names[0][0];
    }
    if (names.length > 1) {
      initials += names[names.length - 1][0];
    }
    return initials.toUpperCase();
  }

  void _showSettingsModal() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => const SettingsProfileModal(),
    );
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(-0.05, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    try {
      _overlay?.remove();
    } catch (_) {}
    _overlay = null;
    _controller.dispose();
    super.dispose();
  }

  void _insertOverlay() {
    if (_overlay != null) return;
    final overlay = OverlayEntry(
      builder: (ctx) {
        final size = MediaQuery.of(ctx).size;
        return Positioned(
          left: 0,
          top: 0,
          width: widget.expandedWidth,
          height: size.height,
          child: MouseRegion(
            onExit: (_) => _hideOverlay(),
            child: Material(
              color: Colors.transparent,
              child: SlideTransition(
                position: _slide,
                child: FadeTransition(
                  opacity: _fade,
                  child: _buildExpandedOverlayContent(),
                ),
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(overlay);
    _overlay = overlay;
    _controller.forward(from: 0);
  }

  void _hideOverlay() {
    if (_overlay == null) return;
    _controller.reverse().whenComplete(() {
      try {
        _overlay?.remove();
      } catch (_) {}
      _overlay = null;
      if (mounted)
        setState(() {
          _showing = false;
        });
    });
  }

  void _showOverlay() {
    if (_showing) return;
    setState(() {
      _showing = true;
    });
    _insertOverlay();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      //  onEnter: (_) => _showOverlay(),
      child: Container(
        width: widget.collapsedWidth,
        decoration: BoxDecoration(
          color: const Color(0xFF0F0F12),
          border: Border(
            right: BorderSide(color: Colors.white.withOpacity(0.06)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(2, 0),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.only(top: widget.topPadding),
          child: Column(
            children: [
              // App icon with enhanced styling
              InkWell(
                onTap: () => _showOverlay(),
                child: widget.navKey != null ? Showcase.withWidget(
                  key: widget.navKey!,
                  container: AppShowcaseWidget(title: 'Sidebar', description: 'Click here to expand the sidebar. You can access all main sections from here.'),
                  height: 150,
                  width: 250,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.accent.withOpacity(0.8),
                          AppColors.accent.withOpacity(0.4),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.accent.withOpacity(0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ) : Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accent.withOpacity(0.8),
                        AppColors.accent.withOpacity(0.4),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.accent.withOpacity(0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              // Collapsed menu items (icons only)
              Expanded(
                child: ListView.separated(
                  itemCount: widget.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    final selected = item.selected;
                    Widget navIcon = Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      child: Tooltip(
                        message: item.label,
                        preferBelow: false,
                        child: InkWell(
                          onTap: item.onTap,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  selected
                                      ? AppColors.accent.withOpacity(0.15)
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    selected
                                        ? AppColors.accent.withOpacity(0.3)
                                        : Colors.transparent,
                              ),
                            ),
                            child: Icon(
                              item.icon,
                              color:
                                  selected
                                      ? AppColors.accent
                                      : Colors.white.withOpacity(0.7),
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    );
                    // Only wrap the first nav item (main navigation) in Showcase
                    if (index == 0 && widget.navKey != null) {
                      navIcon = navIcon;
                    }
                    return navIcon;
                  },
                ),
              ),
              const SizedBox(height: 10),
              // Settings/Profile button
              if (widget.settingsKey != null)
                Showcase(
                  key: widget.settingsKey!,
                  title: 'Settings',
                  description: 'Customize your experience and preferences.',
                  child: _buildUserProfile(),
                )
              else
                _buildUserProfile(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedOverlayContent() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F12),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: SafeArea(
        left: true,
        top: false, // let it overlap AppBar area
        bottom: true,
        child: Padding(
          padding: EdgeInsets.only(top: widget.topPadding),
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: 14),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.accent.withOpacity(0.8),
                          AppColors.accent.withOpacity(0.4),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.accent.withOpacity(0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Robin',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Main area: navigation list takes its intrinsic height; middle panel fills the remaining space
              Expanded(
                child: Column(
                  children: [
                    // Navigation items sized to content
                    ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final item = widget.items[index];
                        final selected = item.selected;
                        return InkWell(
                          onTap: () {
                            item.onTap();
                            _hideOverlay();
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 14,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  selected
                                      ? AppColors.accent.withOpacity(0.15)
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    selected
                                        ? AppColors.accent.withOpacity(0.3)
                                        : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  item.icon,
                                  color:
                                      selected
                                          ? AppColors.accent
                                          : Colors.white.withOpacity(0.85),
                                  size: 22,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    item.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      color:
                                          selected
                                              ? Colors.white
                                              : Colors.white.withOpacity(0.95),
                                      fontSize: 14,
                                      fontWeight:
                                          selected
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    // Middle panel slot (e.g., history on Playground) fills remaining vertical space
                    if (widget.middle != null) ...[
                      const SizedBox(height: 8),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.08),
                            ),
                          ),
                          child: widget.middle!,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Bottom profile
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _buildExpandedUserProfile(),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserProfile() {
    final authUser = ref.watch(authUserProvider);

    return authUser.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();

        final initials = _getInitials(user.userMetadata?['full_name'] ?? '');
        final avatarUrl = user.userMetadata?['avatar_url'] as String?;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: Tooltip(
            message: 'Settings & Profile',
            preferBelow: false,
            child: InkWell(
              onTap: _showSettingsModal,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.accent.withOpacity(0.2),
                  backgroundImage:
                      avatarUrl != null && avatarUrl.isNotEmpty
                          ? NetworkImage(avatarUrl)
                          : null,
                  child:
                      avatarUrl == null || avatarUrl.isEmpty
                          ? Text(
                            initials,
                            style: GoogleFonts.poppins(
                              color: AppColors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                          : null,
                ),
              ),
            ),
          ),
        );
      },
      loading:
          () => Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.all(8),
            child: const CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey,
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildExpandedUserProfile() {
    final authUser = ref.watch(authUserProvider);

    return authUser.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();

        final initials = _getInitials(user.userMetadata?['full_name'] ?? '');
        final avatarUrl = user.userMetadata?['avatar_url'] as String?;
        final fullName = user.userMetadata?['full_name'] as String? ?? 'User';

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          child: InkWell(
            onTap: _showSettingsModal,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.accent.withOpacity(0.2),
                    backgroundImage:
                        avatarUrl != null && avatarUrl.isNotEmpty
                            ? NetworkImage(avatarUrl)
                            : null,
                    child:
                        avatarUrl == null || avatarUrl.isEmpty
                            ? Text(
                              initials,
                              style: GoogleFonts.poppins(
                                color: AppColors.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                            : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Settings & Profile',
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.settings_outlined,
                    color: Colors.white.withOpacity(0.5),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading:
          () => Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey,
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Loading...',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
