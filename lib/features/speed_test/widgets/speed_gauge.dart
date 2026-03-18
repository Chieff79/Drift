import 'dart:math';

import 'package:flutter/material.dart';

/// Scale markings for the speedometer
const List<double> _scaleValues = [0, 50, 100, 250, 500, 750, 1000];

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
  final double size; // Widget size (width and height)
  final String? phaseLabel; // e.g. "Download", "Upload", "Ping"

  const SpeedGauge({
    super.key,
    required this.speed,
    this.maxSpeed = 1000,
    this.isActive = false,
    this.size = 260,
    this.phaseLabel,
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
      duration: const Duration(milliseconds: 600),
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
        final scaleFactor = widget.size / 260;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _SpeedometerPainter(
              speed: currentSpeed,
              maxSpeed: widget.maxSpeed,
              isActive: widget.isActive,
              onSurfaceColor: theme.colorScheme.onSurface,
              surfaceColor: theme.colorScheme.surface,
              brightness: theme.brightness,
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(top: scaleFactor * 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currentSpeed > 0 ? currentSpeed.toStringAsFixed(1) : '0',
                      style: TextStyle(
                        fontSize: 42 * scaleFactor,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: 2 * scaleFactor),
                    Text(
                      'Мбит/с',
                      style: TextStyle(
                        fontSize: 13 * scaleFactor,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    if (widget.phaseLabel != null) ...[
                      SizedBox(height: 4 * scaleFactor),
                      Text(
                        widget.phaseLabel!,
                        style: TextStyle(
                          fontSize: 12 * scaleFactor,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.primary.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SpeedometerPainter extends CustomPainter {
  final double speed;
  final double maxSpeed;
  final bool isActive;
  final Color onSurfaceColor;
  final Color surfaceColor;
  final Brightness brightness;

  // 270° arc: starts at 135° (bottom-left), sweeps 270° to 45° (bottom-right)
  static const double startAngle = 135 * pi / 180;
  static const double sweepAngle = 270 * pi / 180;

  _SpeedometerPainter({
    required this.speed,
    required this.maxSpeed,
    required this.isActive,
    required this.onSurfaceColor,
    required this.surfaceColor,
    required this.brightness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 16;

    _drawBackgroundArc(canvas, center, radius);
    _drawColorArc(canvas, center, radius);
    _drawTicks(canvas, center, radius);
    _drawNeedle(canvas, center, radius);
    _drawCenterDot(canvas, center);
  }

  void _drawBackgroundArc(Canvas canvas, Offset center, double radius) {
    final bgPaint = Paint()
      ..color = onSurfaceColor.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );
  }

  void _drawColorArc(Canvas canvas, Offset center, double radius) {
    if (speed <= 0) return;

    final fraction = _speedToFraction(speed, maxSpeed);
    final currentSweep = sweepAngle * fraction;

    // Draw colored gradient arc up to current speed
    // Green → Yellow → Orange → Red
    final rect = Rect.fromCircle(center: center, radius: radius);

    final gradient = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + sweepAngle,
      colors: const [
        Color(0xFF4CAF50), // green
        Color(0xFF8BC34A), // light green
        Color(0xFFFFEB3B), // yellow
        Color(0xFFFF9800), // orange
        Color(0xFFF44336), // red
      ],
      stops: const [0.0, 0.2, 0.4, 0.65, 1.0],
    );

    final arcPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, currentSweep, false, arcPaint);
  }

  void _drawTicks(Canvas canvas, Offset center, double radius) {
    for (final value in _scaleValues) {
      final fraction = _speedToFraction(value, maxSpeed);
      final angle = startAngle + sweepAngle * fraction;

      // Major tick
      final outerR = radius + 10;
      final innerR = radius - 10;
      final tickPaint = Paint()
        ..color = onSurfaceColor.withValues(alpha: 0.3)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      final outerPoint = Offset(
        center.dx + outerR * cos(angle),
        center.dy + outerR * sin(angle),
      );
      final innerPoint = Offset(
        center.dx + innerR * cos(angle),
        center.dy + innerR * sin(angle),
      );
      canvas.drawLine(innerPoint, outerPoint, tickPaint);

      // Label
      final labelR = radius - 24;
      final labelPos = Offset(
        center.dx + labelR * cos(angle),
        center.dy + labelR * sin(angle),
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: value.toInt().toString(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: onSurfaceColor.withValues(alpha: 0.45),
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

    // Minor ticks between major ones
    final minorTickPaint = Paint()
      ..color = onSurfaceColor.withValues(alpha: 0.12)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < _scaleValues.length - 1; i++) {
      final startVal = _scaleValues[i];
      final endVal = _scaleValues[i + 1];
      final midVal = (startVal + endVal) / 2;
      final fraction = _speedToFraction(midVal, maxSpeed);
      final angle = startAngle + sweepAngle * fraction;

      final outerR = radius + 6;
      final innerR = radius - 6;
      final outerPoint = Offset(
        center.dx + outerR * cos(angle),
        center.dy + outerR * sin(angle),
      );
      final innerPoint = Offset(
        center.dx + innerR * cos(angle),
        center.dy + innerR * sin(angle),
      );
      canvas.drawLine(innerPoint, outerPoint, minorTickPaint);
    }
  }

  void _drawNeedle(Canvas canvas, Offset center, double radius) {
    final fraction = _speedToFraction(speed.clamp(0, maxSpeed), maxSpeed);
    final needleAngle = startAngle + sweepAngle * fraction;

    final needleLength = radius - 30;

    // Needle shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final shadowTip = Offset(
      center.dx + needleLength * cos(needleAngle) + 1,
      center.dy + needleLength * sin(needleAngle) + 1,
    );
    canvas.drawLine(center, shadowTip, shadowPaint..strokeWidth = 3);

    // Needle body
    final needlePaint = Paint()
      ..color = brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.9)
          : Colors.red.shade700
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final needleTip = Offset(
      center.dx + needleLength * cos(needleAngle),
      center.dy + needleLength * sin(needleAngle),
    );

    canvas.drawLine(center, needleTip, needlePaint);

    // Needle tip dot
    final tipDotPaint = Paint()
      ..color = needlePaint.color;
    canvas.drawCircle(needleTip, 3, tipDotPaint);
  }

  void _drawCenterDot(Canvas canvas, Offset center) {
    // Center hub
    final hubOuterPaint = Paint()
      ..color = onSurfaceColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 8, hubOuterPaint);

    final hubInnerPaint = Paint()
      ..color = brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.8)
          : Colors.red.shade700
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 5, hubInnerPaint);
  }

  @override
  bool shouldRepaint(_SpeedometerPainter oldDelegate) =>
      speed != oldDelegate.speed ||
      isActive != oldDelegate.isActive ||
      brightness != oldDelegate.brightness;
}
