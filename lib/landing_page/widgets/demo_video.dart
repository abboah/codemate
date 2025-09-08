import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

class DemoVideoWidget extends StatefulWidget {
  const DemoVideoWidget({Key? key}) : super(key: key);

  @override
  State<DemoVideoWidget> createState() => _DemoVideoWidgetState();
}

class _DemoVideoWidgetState extends State<DemoVideoWidget>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _initializeVideo();
  }

  void _initializeVideo() async {
    try {
      // Replace with your actual Supabase URL
    final supabase = Supabase.instance.client;

final videoUrl = supabase.storage
    .from('assets')
    .getPublicUrl('video/demo.mp4');

      
      
      _controller = VideoPlayerController.network(videoUrl);
      await _controller!.initialize();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // Auto-play silently with loop
        _controller!.setLooping(true);
        _controller!.setVolume(0.0); // Muted autoplay
        _controller!.play();
        _fadeController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Widget _buildLoadingShimmer() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF0A0A0A),
      ),
      child: Stack(
        children: [
          // Base shimmer
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1A1A1A),
                  const Color(0xFF2A2A2A),
                  const Color(0xFF1A1A1A),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
          // Animated shimmer overlay
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(seconds: 2),
            builder: (context, value, child) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment(-1.0 + 2.0 * value, 0.0),
                    end: Alignment(-0.5 + 2.0 * value, 0.0),
                    colors: [
                      Colors.transparent,
                      Colors.white.withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              );
            },
            onEnd: () {
              if (_isLoading) {
                setState(() {}); // Restart animation
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
    
      margin: const EdgeInsets.symmetric(horizontal: 180, vertical: 50),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(  mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [  const Color(0xFF1E40AF),
                                      const Color(0xFF2563EB),],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'See Robin in Action',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          
          // Video Container
          Container(
            width: double.infinity,
            height: 550,
            padding: EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF1F1F1F),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _isLoading
                  ? _buildLoadingShimmer()
                  : _hasError
                      ? _buildErrorState()
                      : _buildVideoPlayer(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video
          VideoPlayer(_controller!),
          
          // Subtle overlay for branding
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Text(
                'LIVE DEMO',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: child,
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: const Color(0xFF0A0A0A),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_camera_back_outlined,
              size: 48,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Demo temporarily unavailable',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _hasError = false;
                });
                _initializeVideo();
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                backgroundColor: Colors.white.withOpacity(0.1),
                foregroundColor: Colors.white.withOpacity(0.9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _fadeController.dispose();
    super.dispose();
  }
}