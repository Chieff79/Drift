import 'dart:math';

import 'package:flutter/material.dart';

// Scale markings with logarithmic positions
const List<double> _scaleValues = [0, 10, 25, 50, 100, 250, 500];

/// Convert a speed value to a 0..1 fraction using logarithmic scale
double _speedToFraction(double speed, double maxSpeed) {
  if (speed <= 0) return 0;
  if (speed >= maxSpeed) return 1;
  return log(1 + speed) / log(1 + maxSpeed);
}

class SpeedGauge extends StatefulWidget {
  final double speed; // Current speed in Mbps
  final double maxSpeed; // Maximum scale value
  final bool isActive;

  const SpeedGauge({
    super.key,
    required this.speed,
    this.maxSpeed = 500,
    this.isActive = false,
  });

  @override
  State<SpeedGauge> createState() => _SpeedGaugeState();
}

class _SpeedGaugeState extends State<SpeedGauge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _speedAnimation;
  double _previousSpeed = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _speedAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(SpeedGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.speed != widget.speed) {
      _previousSpeed = _speedAnimation.value;
      _speedAnimation = Tween<double>(
        begin: _previousSpeed,
        end: widget.speed,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _speedAnimation,
      builder: (context, child) {
        final currentSpeed = _speedAnimation.value;
        return SizedBox(
          width: 260,
          height: 260,
          child: CustomPaint(
            painter: _GaugePainter(
              speed: currentSpeed,
              maxSpeed: widget.maxSpeed,
              isActive: widget.isActive,
              primaryColor: theme.colorScheme.primary,
              surfaceColor: theme.colorScheme.surface,
              onSurfaceColor: theme.colorScheme.onSurface,
              brightness: theme.brightness,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentSpeed > 0 ? currentSpeed.toStringAsFixed(1) : '0',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w300,
                      color: theme.colorScheme.onSurface,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mbps',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double speed;
  final double maxSpeed;
  final bool isActive;
  final Color primaryColor;
  final Color surfaceColor;
  final Color onSurfaceColor;
  final Brightness brightness;

  static const double startAngle = 135 * pi / 180; // 135 degrees
  static const double sweepAngle = 270 * pi / 180; // 270 degrees

  _GaugePainter({
    required this.speed,
    required this.maxSpeed,
    required this.isActive,
    required this.primaryColor,
    required this.surfaceColor,
    required this.onSurfaceColor,
    required this.brightness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 20;

    _drawBackground(canvas, center, radius);
    _drawScaleMarks(canvas, center, radius);
    _drawSpeedArc(canvas, center, radius);
  }

  void _drawBackground(Canvas canvas, Offset center, double radius) {
    final bgPaint = Paint()
      ..color = onSurfaceColor.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );
  }

  void _drawScaleMarks(Canvas canvas, Offset center, double radius) {
    final markPaint = Paint()
      ..color = onSurfaceColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final value in _scaleValues) {
      final fraction = _speedToFraction(value, maxSpeed);
      final angle = startAngle + sweepAngle * fraction;
      final innerR = radius - 20;
      final outerR = radius - 8;

      final inner = Offset(
        center.dx + innerR * cos(angle),
        center.dy + innerR * sin(angle),
      );
      final outer = Offset(
        center.dx + outerR * cos(angle),
        center.dy + outerR * sin(angle),
      );
      canvas.drawLine(inner, outer, markPaint);

      // Draw label
      final labelR = radius - 30;
      final labelPos = Offset(
        center.dx + labelR * cos(angle),
        center.dy + labelR * sin(angle),
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: value.toInt().toString(),
          style: TextStyle(
            fontSize: 9,
            color: onSurfaceColor.withValues(alpha: 0.4),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(
        labelPos.dx - textPainter.width / 2,
        labelPos.dy - textPainter.height / 2,
      );
      textPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  void _drawSpeedArc(Canvas canvas, Offset center, double radius) {
    if (speed <= 0) return;

    final fraction = _speedToFraction(speed, maxSpeed);
    final currentSweep = sweepAngle * fraction;

    // Gradient arc
    final gradient = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + sweepAngle,
      colors: [
        const Color(0xFF4FC3F7), // light blue
        primaryColor,
        const Color(0xFFAB47BC), // purple
        const Color(0xFFEC407A), // pink
      ],
      stops: const [0.0, 0.33, 0.66, 1.0],
    );

    final rect = Rect.fromCircle(center: center, radius: radius);

    final arcPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, currentSweep, false, arcPaint);

    // Glow effect at the tip
    final tipAngle = startAngle + currentSweep;
    final tipPos = Offset(
      center.dx + radius * cos(tipAngle),
      center.dy + radius * sin(tipAngle),
    );

    final glowPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(tipPos, 6, glowPaint);

    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(tipPos, 3, dotPaint);
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) =>
      speed != oldDelegate.speed ||
      isActive != oldDelegate.isActive ||
      brightness != oldDelegate.brightness;
}
