import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class EntranceAnimation extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset beginOffset;
  final double beginScale;

  const EntranceAnimation({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 550),
    this.beginOffset = const Offset(0, 0.12),
    this.beginScale = 0.97,
  });

  @override
  State<EntranceAnimation> createState() => _EntranceAnimationState();
}

class _EntranceAnimationState extends State<EntranceAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curved;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _curved = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _delayTimer = Timer(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) return widget.child;

    return FadeTransition(
      opacity: _curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: widget.beginOffset,
          end: Offset.zero,
        ).animate(_curved),
        child: ScaleTransition(
          scale: Tween<double>(
            begin: widget.beginScale,
            end: 1,
          ).animate(_curved),
          child: widget.child,
        ),
      ),
    );
  }
}

class SoftPageTransitionsBuilder extends PageTransitionsBuilder {
  const SoftPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.settings.name == Navigator.defaultRouteName) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.06, 0.025),
          end: Offset.zero,
        ).animate(curved),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
          child: child,
        ),
      ),
    );
  }
}

class AnimatedPastelBackground extends StatefulWidget {
  final Widget child;
  final List<Color> colors;

  const AnimatedPastelBackground({
    super.key,
    required this.child,
    this.colors = const [
      Color(0xFFFFDDE8),
      Color(0xFFDDF2FF),
      Color(0xFFE8E0FF),
      Color(0xFFFFF1C9),
    ],
  });

  @override
  State<AnimatedPastelBackground> createState() =>
      _AnimatedPastelBackgroundState();
}

class _AnimatedPastelBackgroundState extends State<AnimatedPastelBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFFF8FBFF)),
        IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _PastelBackgroundPainter(
                progress: reduceMotion
                    ? const AlwaysStoppedAnimation<double>(0.18)
                    : _controller,
                colors: widget.colors,
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _PastelBackgroundPainter extends CustomPainter {
  final Animation<double> progress;
  final List<Color> colors;

  _PastelBackgroundPainter({required this.progress, required this.colors})
    : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value * math.pi * 2;
    final shortest = math.min(size.width, size.height);

    for (var index = 0; index < colors.length; index++) {
      final phase = t + index * 1.65;
      final center = Offset(
        size.width * (0.18 + index * 0.22) + math.sin(phase) * 42,
        size.height * (0.18 + (index.isEven ? 0.09 : 0.17)) +
            math.cos(phase * 0.72) * 100,
      );
      final radius = shortest * (0.30 + index * 0.025);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            colors[index].withValues(alpha: 0.34),
            colors[index].withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }

    final particlePaint = Paint()..color = Colors.white.withValues(alpha: 0.5);
    for (var index = 0; index < 12; index++) {
      final phase = t * (0.35 + index % 3 * 0.08) + index * 2.1;
      final x = (index * 97.0 + math.sin(phase) * 28) % size.width;
      final baseY = (index * 173.0) % size.height;
      final y = (baseY - progress.value * size.height * 0.34) % size.height;
      canvas.drawCircle(Offset(x, y), 2.5 + index % 3, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PastelBackgroundPainter oldDelegate) =>
      oldDelegate.colors != colors;
}

class GentleFloat extends StatefulWidget {
  final Widget child;
  final double distance;

  const GentleFloat({super.key, required this.child, this.distance = 7});

  @override
  State<GentleFloat> createState() => _GentleFloatState();
}

class _GentleFloatState extends State<GentleFloat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) return widget.child;
    return AnimatedBuilder(
      animation: _animation,
      child: widget.child,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -widget.distance * _animation.value),
        child: Transform.rotate(
          angle: math.sin(_animation.value * math.pi) * 0.012,
          child: child,
        ),
      ),
    );
  }
}
