import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/als_logo.dart';
import 'home_shell.dart';

/// Startup experience.
///
/// The main screen ([HomeShell]) is built and living **behind** the splash from
/// the very first frame. The green splash overlay sits on top, shows the Cal
/// Poly logo while the app initializes, then quickly zooms/fades away to reveal
/// the already-loaded main screen underneath — so the reveal feels like one
/// continuous motion into the app rather than a second screen loading.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _exit;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _wordmarkOpacity;

  // Exit / reveal.
  late final Animation<double> _logoZoom; // logo pushes toward the camera
  late final Animation<double> _curtainScale; // green field scales up + fades
  late final Animation<double> _curtainFade;
  late final Animation<double> _homeScale; // subtle parallax on the main screen

  bool _showOverlay = true;

  @override
  void initState() {
    super.initState();

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _exit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    _logoScale = CurvedAnimation(parent: _intro, curve: Curves.easeOutBack)
        .drive(Tween(begin: 0.8, end: 1.0));
    _logoOpacity = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );
    _wordmarkOpacity = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
    );

    _logoZoom = CurvedAnimation(parent: _exit, curve: Curves.easeIn)
        .drive(Tween(begin: 1.0, end: 2.6));
    _curtainScale = CurvedAnimation(parent: _exit, curve: Curves.easeIn)
        .drive(Tween(begin: 1.0, end: 1.18));
    _curtainFade = CurvedAnimation(parent: _exit, curve: Curves.easeIn);
    _homeScale = CurvedAnimation(parent: _exit, curve: Curves.easeOut)
        .drive(Tween(begin: 1.06, end: 1.0));

    _runSequence();
  }

  Future<void> _runSequence() async {
    await _intro.forward();
    // Brief initialization window.
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    await _exit.forward();
    if (!mounted) return;
    setState(() => _showOverlay = false);
  }

  @override
  void dispose() {
    _intro.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // The real app, already alive behind the splash.
          AnimatedBuilder(
            animation: _exit,
            builder: (context, child) {
              final revealing = _exit.value > 0;
              return Transform.scale(
                scale: revealing ? _homeScale.value : 1.0,
                child: Opacity(
                  opacity: revealing ? _exit.value.clamp(0.0, 1.0) : 0.0,
                  child: child,
                ),
              );
            },
            child: const HomeShell(),
          ),
          if (_showOverlay)
            AnimatedBuilder(
              animation: Listenable.merge([_intro, _exit]),
              builder: (context, _) => _buildOverlay(context),
            ),
        ],
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    const green = AppTheme.alsGreen;
    final overlayOpacity = (1.0 - _curtainFade.value).clamp(0.0, 1.0);

    return Opacity(
      opacity: overlayOpacity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Transform.scale(
            scale: _curtainScale.value,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1C5A44), green, Color(0xFF0E3325)],
                ),
              ),
            ),
          ),
          Center(
            child: Transform.scale(
              scale: _logoScale.value * _logoZoom.value,
              child: FadeTransition(
                opacity: _logoOpacity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ALSLogo(
                      width: MediaQuery.sizeOf(context).width * 0.66,
                      onSurface: true,
                    ),
                    const SizedBox(height: 30),
                    FadeTransition(
                      opacity: _wordmarkOpacity,
                      child: const Text(
                        'ASSISTIVE LISTENING',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'serif',
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 3.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
