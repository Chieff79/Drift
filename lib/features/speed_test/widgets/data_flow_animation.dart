import 'dart:math';

import 'package:flutter/material.dart';

enum DataFlowDirection { idle, download, upload }

class DataFlowAnimation extends StatefulWidget {
  final DataFlowDirection direction;
  final double speed; // Mbps — controls particle velocity
  final String leftLabel;
  final String rightLabel;
  final double height;

  const DataFlowAnimation({
    super.key,
    this.direction = DataFlowDirection.idle,
    this.speed = 0,
    this.leftLabel = '',
    this.rightLabel = '',
    this.height = 120,
  });

  @override
  State<DataFlowAnimation> createState() => _DataFlowAnimationState();
}

class _Particle {
  double x; // 0..1 normalized position along the path
  double yOffset; // random vertical offset from center
  double size;
  double opacity;

  _Particle({
    required this.x,
    required this.yOffset,
    required this.size,
    required this.opacity,
  });
}

class _DataFlowAnimationState extends State<DataFlowAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final Random _random = Random();
  static const int _maxParticles = 40;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_updateParticles);

    if (widget.direction != DataFlowDirection.idle) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(DataFlowAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.direction != oldWidget.direction) {
      if (widget.direction == DataFlowDirection.idle) {
        _controller.stop();
        _particles.clear();
      } else {
        _particles.clear();
        _controller.repeat();
      }
    }
  }

  void _updateParticles() {
    if (widget.direction == DataFlowDirection.idle) return;

    // Speed factor: higher speed = faster particles + more particles
    final speedFactor = (widget.speed / 100).clamp(0.1, 5.0);
    final particleSpeed = 0.008 * speedFactor;
    final spawnRate = (speedFactor * 2).clamp(1.0, 6.0).toInt();

    // Spawn new particles
    if (_particles.length < _maxParticles) {
      for (int i = 0; i < spawnRate; i++) {
        if (_particles.length >= _maxParticles) break;
        _particles.add(_Particle(
          x: widget.direction == DataFlowDirection.download ? 1.0 : 0.0,
          yOffset: (_random.nextDouble() - 0.5) * 0.6,
          size: 2.0 + _random.nextDouble() * 3.0,
          opacity: 0.4 + _random.nextDouble() * 0.6,
        ));
      }
    }

    // Move particles
    for (final p in _particles) {
      if (widget.direction == DataFlowDirection.download) {
        p.x -= particleSpeed;
      } else {
        p.x += particleSpeed;
      }
    }

    // Remove particles that have gone past the edge
    _particles.removeWhere((p) => p.x < -0.05 || p.x > 1.05);

    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: widget.height,
      child: CustomPaint(
        painter: _DataFlowPainter(
          particles: _particles,
          direction: widget.direction,
          primaryColor: theme.colorScheme.primary,
          secondaryColor: theme.colorScheme.secondary,
          brightness: theme.brightness,
          leftLabel: widget.leftLabel,
          rightLabel: widget.rightLabel,
          onSurfaceColor: theme.colorScheme.onSurface,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _DataFlowPainter extends CustomPainter {
  final List<_Particle> particles;
  final DataFlowDirection direction;
  final Color primaryColor;
  final Color secondaryColor;
  final Brightness brightness;
  final String leftLabel;
  final String rightLabel;
  final Color onSurfaceColor;

  _DataFlowPainter({
    required this.particles,
    required this.direction,
    required this.primaryColor,
    required this.secondaryColor,
    required this.brightness,
    required this.leftLabel,
    required this.rightLabel,
    required this.onSurfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final leftX = 40.0;
    final rightX = size.width - 40.0;
    final pathWidth = rightX - leftX;

    // Draw connection line
    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          primaryColor.withValues(alpha: 0.15),
          secondaryColor.withValues(alpha: 0.15),
        ],
      ).createShader(Rect.fromLTWH(leftX, centerY - 1, pathWidth, 2))
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(leftX, centerY), Offset(rightX, centerY), linePaint);

    // Draw endpoint circles
    _drawEndpoint(canvas, Offset(leftX, centerY), true);
    _drawEndpoint(canvas, Offset(rightX, centerY), false);

    // Draw labels
    _drawLabel(canvas, leftLabel, Offset(leftX, centerY + 24), size);
    _drawLabel(canvas, rightLabel, Offset(rightX, centerY + 24), size);

    // Draw particles
    for (final p in particles) {
      final px = leftX + p.x * pathWidth;
      final py = centerY + p.yOffset * 30;

      // Gradient color based on position
      final t = p.x;
      final color = Color.lerp(
        const Color(0xFF4FC3F7),
        const Color(0xFFAB47BC),
        t,
      )!.withValues(alpha: p.opacity);

      // Glow
      final glowPaint = Paint()
        ..color = color.withValues(alpha: p.opacity * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(px, py), p.size + 2, glowPaint);

      // Particle
      final particlePaint = Paint()..color = color;
      canvas.drawCircle(Offset(px, py), p.size, particlePaint);
    }
  }

  void _drawEndpoint(Canvas canvas, Offset center, bool isLeft) {
    // Outer glow
    final glowPaint = Paint()
      ..color = (isLeft ? primaryColor : secondaryColor).withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, 12, glowPaint);

    // Filled circle
    final fillPaint = Paint()
      ..color = (isLeft ? primaryColor : secondaryColor).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 8, fillPaint);

    // Border
    final borderPaint = Paint()
      ..color = (isLeft ? primaryColor : secondaryColor).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, 8, borderPaint);

    // Inner dot
    final dotPaint = Paint()
      ..color = isLeft ? primaryColor : secondaryColor;
    canvas.drawCircle(center, 3, dotPaint);
  }

  void _drawLabel(Canvas canvas, String text, Offset position, Size size) {
    if (text.isEmpty) return;
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 11,
          color: onSurfaceColor.withValues(alpha: 0.6),
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width / 2);

    canvas.save();
    canvas.translate(
      position.dx - textPainter.width / 2,
      position.dy,
    );
    textPainter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DataFlowPainter oldDelegate) => true;
}
