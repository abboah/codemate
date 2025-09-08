import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:codemate/themes/colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:codemate/providers/auth_provider.dart';
import 'package:codemate/components/settings_profile_modal.dart';
// Conditional import to access CanvasHtmlOverlayController on web and a no-op stub elsewhere
import 'package:codemate/widgets/canvas_html_preview_stub.dart'
    if (dart.library.html) 'package:codemate/widgets/canvas_html_preview_web.dart';

// Custom premium tooltip widget
class _PremiumTooltip extends StatefulWidget {
  final String message;
  final Widget child;

  const _PremiumTooltip({required this.message, required this.child});

  @override
  State<_PremiumTooltip> createState() => _PremiumTooltipState();
}

class _PremiumTooltipState extends State<_PremiumTooltip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  OverlayEntry? _overlayEntry;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _removeTooltip();
    _controller.dispose();
    super.dispose();
  }

  void _showTooltip() {
    if (_overlayEntry != null) return;

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: offset.dx + size.width + 12,
          top: offset.dy + (size.height / 2) - 20,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Opacity(
                    opacity: _opacityAnimation.value,
                    child: Material(
                      color: Colors.transparent,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1D29).withOpacity(0.95),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.15),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accent.withOpacity(0.1),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              widget.message,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    overlay.insert(_overlayEntry!);
    _controller.forward();
  }

  void _removeTooltip() {
    if (_overlayEntry != null) {
      _controller.reverse().then((_) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        if (!_isHovering) {
          _isHovering = true;
          Future.delayed(const Duration(milliseconds: 600), () {
            if (_isHovering && mounted) {
              _showTooltip();
            }
          });
        }
      },
      onExit: (_) {
        _isHovering = false;
        _removeTooltip();
      },
      child: widget.child,
    );
  }
}

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
  // Gap between top icon and the first navigation button in collapsed state
  final double gapBelowTopIcon;
  // When true, the whole collapsed width becomes the tap target for the top icon
  final bool expandTopIconHitBox;
  // Optional middle content (e.g., Playground history panel)
  final Widget? middle;

  const PremiumSidebar({
    super.key,
    required this.items,
    this.collapsedWidth = 70,
    this.expandedWidth = 240,
    this.topPadding = 16,
    this.gapBelowTopIcon = 18,
    this.expandTopIconHitBox = false,
    this.middle,
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
    // Ensure iframe is not left suspended
    try {
      CanvasHtmlOverlayController.instance.resume();
    } catch (_) {}
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
    Overlay.of(context, rootOverlay: true).insert(overlay);
    _overlay = overlay;
    _controller.forward(from: 0);
    // Suspend HTML iframe interactions (web preview) while the sidebar overlay is open
    try {
      CanvasHtmlOverlayController.instance.suspend();
    } catch (_) {}
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
      // Resume iframe interactions once the sidebar closes
      try {
        CanvasHtmlOverlayController.instance.resume();
      } catch (_) {}
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
          gradient: const LinearGradient(
            colors: [Color(0xFF0A0A0D), Color(0xFF0F0F12), Color(0xFF141418)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border(
            right: BorderSide(
              color: Colors.white.withOpacity(0.08),
              width: 1.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(2, 0),
            ),
            BoxShadow(
              color: AppColors.accent.withOpacity(0.05),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.only(top: widget.topPadding),
          child: Column(
            children: [
              // App icon with enhanced styling; optionally expand hitbox to full width
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showOverlay,
                  // Opaque hit test across full collapsed width if enabled
                  child: SizedBox(
                    width: double.infinity,
                    height: widget.expandTopIconHitBox ? 56 : 42,
                    child: Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF6366F1),
                              Color(0xFF8B5CF6),
                              Color(0xFFEC4899),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withOpacity(0.4),
                              blurRadius: 16,
                              spreadRadius: 2,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: const Color(0xFFEC4899).withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 4,
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
                  ),
                ),
              ),
              SizedBox(height: widget.gapBelowTopIcon),
              // Collapsed menu items (icons only)
              Expanded(
                child: ListView.separated(
                  itemCount: widget.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    final selected = item.selected;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      child: _PremiumTooltip(
                        message: item.label,
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            child: InkWell(
                              onTap: item.onTap,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color:
                                      selected
                                          ? AppColors.accent.withOpacity(0.15)
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color:
                                        selected
                                            ? AppColors.accent.withOpacity(0.4)
                                            : Colors.transparent,
                                    width: 1.5,
                                  ),
                                  boxShadow:
                                      selected
                                          ? [
                                            BoxShadow(
                                              color: AppColors.accent
                                                  .withOpacity(0.2),
                                              blurRadius: 12,
                                              spreadRadius: 2,
                                            ),
                                          ]
                                          : null,
                                ),
                                child: Icon(
                                  item.icon,
                                  color:
                                      selected
                                          ? AppColors.accent
                                          : Colors.white.withOpacity(0.75),
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              _buildUserProfile(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedOverlayContent() {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(16),
        bottomRight: Radius.circular(16),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF0A0A0D).withOpacity(0.95),
                const Color(0xFF0F0F12).withOpacity(0.95),
                const Color(0xFF141418).withOpacity(0.95),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border(
              right: BorderSide(
                color: Colors.white.withOpacity(0.12),
                width: 1.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(4, 0),
              ),
              BoxShadow(
                color: AppColors.accent.withOpacity(0.08),
                blurRadius: 16,
                spreadRadius: 4,
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
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF6366F1),
                              Color(0xFF8B5CF6),
                              Color(0xFFEC4899),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withOpacity(0.4),
                              blurRadius: 16,
                              spreadRadius: 2,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: const Color(0xFFEC4899).withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 4,
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
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final item = widget.items[index];
                            final selected = item.selected;
                            return InkWell(
                              onTap: () {
                                item.onTap();
                                _hideOverlay();
                              },
                              borderRadius: BorderRadius.circular(14),
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
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color:
                                        selected
                                            ? AppColors.accent.withOpacity(0.4)
                                            : Colors.transparent,
                                    width: 1.5,
                                  ),
                                  boxShadow:
                                      selected
                                          ? [
                                            BoxShadow(
                                              color: AppColors.accent
                                                  .withOpacity(0.2),
                                              blurRadius: 12,
                                              spreadRadius: 2,
                                            ),
                                          ]
                                          : null,
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
                                                  : Colors.white.withOpacity(
                                                    0.95,
                                                  ),
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
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.12),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
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
          child: _PremiumTooltip(
            message: 'Settings & Profile',
            child: InkWell(
              onTap: _showSettingsModal,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.15),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
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
