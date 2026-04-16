import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  /// Tracks whether the splash has already been shown this session.
  /// Prevents replaying the video if the route is revisited.
  static bool hasBeenShown = false;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _controller;
  Timer? _fallbackTimer;
  bool _navigated = false;

  static const _backgroundColor = Color(0xFF0A1628);

  @override
  void initState() {
    super.initState();

    // If splash was already shown, skip immediately
    if (SplashScreen.hasBeenShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _navigateToApp());
      return;
    }

    SplashScreen.hasBeenShown = true;
    _initVideo();

    // Fallback: navigate after 3 seconds regardless of video state
    _fallbackTimer = Timer(const Duration(seconds: 3), _navigateToApp);
  }

  Future<void> _initVideo() async {
    try {
      final controller = VideoPlayerController.asset(
        'assets/videos/splash_animation.mp4',
      );
      _controller = controller;

      await controller.initialize();
      if (!mounted) return;

      controller.addListener(_onVideoUpdate);
      setState(() {});
      await controller.play();
    } catch (_) {
      // If video fails to load, navigate immediately
      _navigateToApp();
    }
  }

  void _onVideoUpdate() {
    final controller = _controller;
    if (controller == null) return;

    // Navigate when video finishes playing
    if (controller.value.position >= controller.value.duration &&
        controller.value.duration > Duration.zero) {
      _navigateToApp();
    }
  }

  void _navigateToApp() {
    if (_navigated || !mounted) return;
    _navigated = true;
    // Navigate to /home — the existing redirect logic in the router
    // will handle redirecting to /intro if intro has not been completed.
    context.go('/home');
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _controller?.removeListener(_onVideoUpdate);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final isInitialized = controller?.value.isInitialized ?? false;

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Center(
        child: isInitialized
            ? AspectRatio(
                aspectRatio: controller!.value.aspectRatio,
                child: VideoPlayer(controller),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
