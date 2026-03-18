import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Luxury car-style speedometer inspired by Bentley/Ferrari instrument clusters.
/// Uses CustomPainter for all rendering. No text inside the dial — speed display
/// is handled externally (below the gauge).
class SpeedGauge extends StatefulWidget {
  final double speed; // Current speed in Mbps
  final double maxSpeed; // Maximum scale value (default 1000)
  final double size; // Widget diameter
  final String? phaseLabel; // Not rendered inside — for external use
  final bool isActive;

  const SpeedGauge({
    super.key,
    required this.speed,
    this.maxSpeed = 1000,
    this.size = 280,
    this.phaseLabel,
    this.isActive = false,
  });

  @override
  State<SpeedGauge> createState() => _SpeedGaugeState();
}

class _SpeedGaugeState extends State<SpeedGauge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _currentSpeed = 0;
  double _targetSpeed = 0;
  late SpringSimulation _simulation;
  double _simStartSpeed = 0;

  static const _spring = SpringDescription(mass: 1.0, stiffness: 120, damping: 14);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this);
    _controller.addListener(_onTick);
    _targetSpeed = widget.speed;
    _currentSpeed = 0;
  }

  @override
  void didUpdateWidget(SpeedGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.speed != widget.speed) {
      _targetSpeed = widget.speed;
      _simStartSpeed = _currentSpeed;
      _simulation = SpringSimulation(_spring, 0, 1, 0);
      _controller.reset();
      _controller.animateWith(_simulation);
    }
  }

  void _onTick() {
    setState(() {
      final t = _controller.value.clamp(0.0, 1.0);
      _currentSpeed = _simStartSpeed + (_targetSpeed - _simStartSpeed) * t;
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _LuxurySpeedometerPainter(
          speed: _currentSpeed,
          maxSpeed: widget.maxSpeed,
        ),
      ),
    );
  }
}

class _LuxurySpeedometerPainter extends CustomPainter {
  final double speed;
  final double maxSpeed;

  // 270° arc: starts at 135° (bottom-left), sweeps 270° to 45° (bottom-right)
  static const double _startAngle = 135 * pi / 180;
  static const double _sweepAngle = 270 * pi / 180;

  _LuxurySpeedometerPainter({
    required this.speed,
    required this.maxSpeed,
  });

  double _speedToFraction(double spd) {
    return (spd / maxSpeed).clamp(0.0, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = min(size.width, size.height) / 2;

    _drawBackground(canvas, center, outerRadius, size);
    _drawChromeRim(canvas, center, outerRadius);
    _drawColorArc(canvas, center, outerRadius * 0.78);
    _drawTicks(canvas, center, outerRadius);
    _drawNeedle(canvas, center, outerRadius);
    _drawCenterCap(canvas, center);
  }

  void _drawBackground(Canvas canvas, Offset center, double radius, Size size) {
    // Dark metallic gradient background
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF2A2A2E),
          const Color(0xFF1A1A1E),
          const Color(0xFF0F0F12),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius - 2, bgPaint);

    // Subtle brushed metal texture effect (concentric circles)
    final texturePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.3
      ..color = Colors.white.withValues(alpha: 0.03);
    for (double r = 20; r < radius - 10; r += 4) {
      canvas.drawCircle(center, r, texturePaint);
    }
  }

  void _drawChromeRim(Canvas canvas, Offset center, double radius) {
    // Outer chrome ring
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..shader = SweepGradient(
        colors: [
          const Color(0xFF888888),
          const Color(0xFFDDDDDD),
          const Color(0xFFFFFFFF),
          const Color(0xFFDDDDDD),
          const Color(0xFF888888),
          const Color(0xFF555555),
          const Color(0xFF888888),
        ],
        stops: const [0.0, 0.15, 0.3, 0.45, 0.6, 0.8, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius - 2));
    canvas.drawCircle(center, radius - 2, rimPaint);

    // Subtle glow behind rim
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = Colors.white.withValues(alpha: 0.05)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(center, radius - 2, glowPaint);
  }

  void _drawColorArc(Canvas canvas, Offset center, double radius) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final arcWidth = radius * 0.1;

    // Background arc (dark track)
    final bgArcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = arcWidth
      ..strokeCap = StrokeCap.butt
      ..color = Colors.white.withValues(alpha: 0.06);
    canvas.drawArc(rect, _startAngle, _sweepAngle, false, bgArcPaint);

    // Color zone segments
    final zones = <_ColorZone>[
      _ColorZone(0, 100, const Color(0xFF2196F3), const Color(0xFF42A5F5)),    // blue
      _ColorZone(100, 300, const Color(0xFF4CAF50), const Color(0xFF66BB6A)),   // green
      _ColorZone(300, 500, const Color(0xFFFFEB3B), const Color(0xFFFFC107)),   // yellow
      _ColorZone(500, 750, const Color(0xFFFF9800), const Color(0xFFFF5722)),   // orange
      _ColorZone(750, 1000, const Color(0xFFF44336), const Color(0xFFD32F2F)),  // red
    ];

    for (final zone in zones) {
      final startFrac = _speedToFraction(zone.start);
      final endFrac = _speedToFraction(zone.end);
      final zoneStartAngle = _startAngle + _sweepAngle * startFrac;
      final zoneSweepAngle = _sweepAngle * (endFrac - startFrac);

      final zonePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = arcWidth
        ..strokeCap = StrokeCap.butt
        ..shader = SweepGradient(
          startAngle: zoneStartAngle,
          endAngle: zoneStartAngle + zoneSweepAngle,
          colors: [zone.startColor, zone.endColor],
        ).createShader(rect);

      // Only draw up to current speed
      final speedFrac = _speedToFraction(speed);
      if (speedFrac <= startFrac) continue;
      final drawEndFrac = min(speedFrac, endFrac);
      final drawSweep = _sweepAngle * (drawEndFrac - startFrac);

      canvas.drawArc(rect, zoneStartAngle, drawSweep, false, zonePaint);
    }

    // Bright tip glow at current speed position
    if (speed > 0) {
      final fraction = _speedToFraction(speed);
      final angle = _startAngle + _sweepAngle * fraction;
      final tipX = center.dx + radius * cos(angle);
      final tipY = center.dy + radius * sin(angle);
      final tipPaint = Paint()
        ..color = _getSpeedColor(speed).withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(tipX, tipY), arcWidth * 0.8, tipPaint);
    }
  }

  Color _getSpeedColor(double spd) {
    if (spd <= 100) return const Color(0xFF2196F3);
    if (spd <= 300) return const Color(0xFF4CAF50);
    if (spd <= 500) return const Color(0xFFFFEB3B);
    if (spd <= 750) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  void _drawTicks(Canvas canvas, Offset center, double outerRadius) {
    final tickOuterR = outerRadius * 0.88;
    final majorTickInnerR = outerRadius * 0.78;
    final minorTickInnerR = outerRadius * 0.82;
    final labelR = outerRadius * 0.68;

    // Major ticks: 0, 100, 200, ..., 1000
    for (int i = 0; i <= 10; i++) {
      final value = i * 100.0;
      final fraction = _speedToFraction(value);
      final angle = _startAngle + _sweepAngle * fraction;

      final outerPt = Offset(center.dx + tickOuterR * cos(angle), center.dy + tickOuterR * sin(angle));
      final innerPt = Offset(center.dx + majorTickInnerR * cos(angle), center.dy + majorTickInnerR * sin(angle));

      final tickPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(innerPt, outerPt, tickPaint);

      // Number labels
      final labelPos = Offset(center.dx + labelR * cos(angle), center.dy + labelR * sin(angle));
      final textPainter = TextPainter(
        text: TextSpan(
          text: value.toInt().toString(),
          style: TextStyle(
            fontSize: outerRadius * 0.075,
            fontWeight: FontWeight.w300,
            color: Colors.white.withValues(alpha: 0.6),
            letterSpacing: -0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(labelPos.dx - textPainter.width / 2, labelPos.dy - textPainter.height / 2);
      textPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }

    // Minor ticks: every 50
    for (int i = 0; i <= 20; i++) {
      final value = i * 50.0;
      if (value % 100 == 0) continue; // skip major positions
      final fraction = _speedToFraction(value);
      final angle = _startAngle + _sweepAngle * fraction;

      final outerPt = Offset(center.dx + tickOuterR * cos(angle), center.dy + tickOuterR * sin(angle));
      final innerPt = Offset(center.dx + minorTickInnerR * cos(angle), center.dy + minorTickInnerR * sin(angle));

      final tickPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(innerPt, outerPt, tickPaint);
    }
  }

  void _drawNeedle(Canvas canvas, Offset center, double outerRadius) {
    final fraction = _speedToFraction(speed.clamp(0, maxSpeed));
    final angle = _startAngle + _sweepAngle * fraction;
    final needleLength = outerRadius * 0.72;
    final needleTailLength = outerRadius * 0.15;

    // Needle shadow
    canvas.save();
    canvas.translate(1.5, 2);
    final shadowPath = Path();
    final shadowTip = Offset(center.dx + needleLength * cos(angle), center.dy + needleLength * sin(angle));
    final shadowTail = Offset(center.dx - needleTailLength * cos(angle), center.dy - needleTailLength * sin(angle));
    final perpAngle = angle + pi / 2;
    final halfWidth = 3.0;
    final tailHalfWidth = 5.0;

    shadowPath.moveTo(shadowTip.dx + halfWidth * 0.3 * cos(perpAngle), shadowTip.dy + halfWidth * 0.3 * sin(perpAngle));
    shadowPath.lineTo(center.dx + tailHalfWidth * cos(perpAngle), center.dy + tailHalfWidth * sin(perpAngle));
    shadowPath.lineTo(shadowTail.dx + tailHalfWidth * 0.6 * cos(perpAngle), shadowTail.dy + tailHalfWidth * 0.6 * sin(perpAngle));
    shadowPath.lineTo(shadowTail.dx - tailHalfWidth * 0.6 * cos(perpAngle), shadowTail.dy - tailHalfWidth * 0.6 * sin(perpAngle));
    shadowPath.lineTo(center.dx - tailHalfWidth * cos(perpAngle), center.dy - tailHalfWidth * sin(perpAngle));
    shadowPath.lineTo(shadowTip.dx - halfWidth * 0.3 * cos(perpAngle), shadowTip.dy - halfWidth * 0.3 * sin(perpAngle));
    shadowPath.close();

    canvas.drawPath(
      shadowPath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.restore();

    // Needle body — sleek red
    final needlePath = Path();
    final tip = Offset(center.dx + needleLength * cos(angle), center.dy + needleLength * sin(angle));
    final tail = Offset(center.dx - needleTailLength * cos(angle), center.dy - needleTailLength * sin(angle));

    needlePath.moveTo(tip.dx + halfWidth * 0.3 * cos(perpAngle), tip.dy + halfWidth * 0.3 * sin(perpAngle));
    needlePath.lineTo(center.dx + tailHalfWidth * cos(perpAngle), center.dy + tailHalfWidth * sin(perpAngle));
    needlePath.lineTo(tail.dx + tailHalfWidth * 0.6 * cos(perpAngle), tail.dy + tailHalfWidth * 0.6 * sin(perpAngle));
    needlePath.lineTo(tail.dx - tailHalfWidth * 0.6 * cos(perpAngle), tail.dy - tailHalfWidth * 0.6 * sin(perpAngle));
    needlePath.lineTo(center.dx - tailHalfWidth * cos(perpAngle), center.dy - tailHalfWidth * sin(perpAngle));
    needlePath.lineTo(tip.dx - halfWidth * 0.3 * cos(perpAngle), tip.dy - halfWidth * 0.3 * sin(perpAngle));
    needlePath.close();

    final needlePaint = Paint()
      ..shader = ui.Gradient.linear(
        tail,
        tip,
        [const Color(0xFF8B0000), const Color(0xFFFF1744), const Color(0xFFFF1744)],
        [0.0, 0.4, 1.0],
      );
    canvas.drawPath(needlePath, needlePaint);

    // Bright edge highlight on needle
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = Colors.white.withValues(alpha: 0.15);
    canvas.drawPath(needlePath, edgePaint);
  }

  void _drawCenterCap(Canvas canvas, Offset center) {
    // Outer ring shadow
    canvas.drawCircle(
      center.translate(0.5, 1),
      12,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Chrome cap with gradient
    final capPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFEEEEEE),
          const Color(0xFFCCCCCC),
          const Color(0xFF999999),
          const Color(0xFF666666),
        ],
        stops: const [0.0, 0.3, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: 12));
    canvas.drawCircle(center, 12, capPaint);

    // Inner highlight
    canvas.drawCircle(
      center.translate(-2, -2),
      5,
      Paint()..color = Colors.white.withValues(alpha: 0.3),
    );

    // Chrome ring
    canvas.drawCircle(
      center,
      12,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.3),
    );
  }

  @override
  bool shouldRepaint(_LuxurySpeedometerPainter oldDelegate) =>
      speed != oldDelegate.speed || maxSpeed != oldDelegate.maxSpeed;
}

class _ColorZone {
  final double start;
  final double end;
  final Color startColor;
  final Color endColor;

  const _ColorZone(this.start, this.end, this.startColor, this.endColor);
}
