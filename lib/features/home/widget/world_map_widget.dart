import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Country capital approximate coordinates (lat, lng).
/// Used to place dots on the equirectangular world map.
const _countryCoords = <String, (double lat, double lng)>{
  'RU': (55.75, 37.62),  // Москва
  'NL': (52.37, 4.90),   // Амстердам
  'US': (38.90, -77.04), // Вашингтон
  'DE': (52.52, 13.41),  // Берлин
  'FR': (48.86, 2.35),   // Париж
  'GB': (51.51, -0.13),  // Лондон
  'UA': (50.45, 30.52),  // Киев
  'KZ': (51.17, 71.43),  // Астана
  'BY': (53.90, 27.57),  // Минск
  'TR': (39.93, 32.86),  // Анкара
  'CN': (39.90, 116.40), // Пекин
  'JP': (35.68, 139.69), // Токио
  'SG': (1.35, 103.82),  // Сингапур
  'FI': (60.17, 24.94),  // Хельсинки
  'SE': (59.33, 18.07),  // Стокгольм
  'CH': (46.95, 7.45),   // Берн
  'CA': (45.42, -75.70), // Оттава
  'AU': (-33.87, 151.21),// Сидней
  'BR': (-15.79, -47.88),// Бразилиа
  'IN': (28.61, 77.21),  // Нью-Дели
  'IT': (41.90, 12.50),  // Рим
  'ES': (40.42, -3.70),  // Мадрид
  'PL': (52.23, 21.01),  // Варшава
  'CZ': (50.08, 14.44),  // Прага
  'AT': (48.21, 16.37),  // Вена
  'NO': (59.91, 10.75),  // Осло
  'DK': (55.68, 12.57),  // Копенгаген
  'PT': (38.72, -9.14),  // Лиссабон
  'IE': (53.35, -6.26),  // Дублин
  'HK': (22.32, 114.17), // Гонконг
  'KR': (37.57, 126.98), // Сеул
  'TW': (25.03, 121.57), // Тайбэй
  'AR': (-34.60, -58.38),// Буэнос-Айрес
  'MX': (19.43, -99.13), // Мехико
  'ZA': (-33.93, 18.42), // Кейптаун
  'EG': (30.04, 31.24),  // Каир
  'AE': (25.20, 55.27),  // Дубай
  'IL': (31.77, 35.22),  // Иерусалим
  'TH': (13.76, 100.50), // Бангкок
  'VN': (21.03, 105.85), // Ханой
  'ID': (-6.21, 106.85), // Джакарта
  'MY': (3.14, 101.69),  // Куала-Лумпур
  'PH': (14.60, 120.98), // Манила
  'RO': (44.43, 26.10),  // Бухарест
  'BG': (42.70, 23.32),  // София
  'HU': (47.50, 19.04),  // Будапешт
  'GR': (37.98, 23.73),  // Афины
  'HR': (45.81, 15.98),  // Загреб
  'RS': (44.79, 20.47),  // Белград
  'LT': (54.69, 25.28),  // Вильнюс
  'LV': (56.95, 24.11),  // Рига
  'EE': (59.44, 24.75),  // Таллин
  'GE': (41.69, 44.80),  // Тбилиси
  'AM': (40.18, 44.51),  // Ереван
  'AZ': (40.41, 49.87),  // Баку
  'UZ': (41.30, 69.28),  // Ташкент
  'MD': (47.01, 28.86),  // Кишинёв
  'IS': (64.15, -21.94), // Рейкьявик
  'NZ': (-41.29, 174.78),// Веллингтон
  'CL': (-33.45, -70.67),// Сантьяго
  'CO': (4.71, -74.07),  // Богота
  'PE': (-12.05, -77.04),// Лима
};

/// Convert lat/lng to relative position (0..1, 0..1) on an equirectangular map.
Offset _latLngToRelative(double lat, double lng) {
  // Equirectangular projection
  // x: -180..+180 → 0..1
  // y: +90..-90 → 0..1  (top = +90)
  final x = (lng + 180) / 360;
  final y = (90 - lat) / 180;
  return Offset(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0));
}

/// Interactive world map showing VPN connection points and route.
class WorldMapWidget extends HookWidget {
  const WorldMapWidget({
    super.key,
    required this.isConnected,
    required this.isConnecting,
    this.userCountryCode,
    this.vpnCountryCode,
  });

  final bool isConnected;
  final bool isConnecting;
  final String? userCountryCode;
  final String? vpnCountryCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Pulse animation for the VPN dot
    final pulseController = useAnimationController(
      duration: const Duration(milliseconds: 1800),
    );
    useEffect(() {
      if (isConnected) {
        pulseController.repeat(reverse: true);
      } else {
        pulseController.stop();
        pulseController.value = 0;
      }
      return null;
    }, [isConnected]);

    // Arc animation progress
    final arcController = useAnimationController(
      duration: const Duration(milliseconds: 1200),
    );
    useEffect(() {
      if (isConnected) {
        arcController.forward(from: 0);
      } else {
        arcController.reverse();
      }
      return null;
    }, [isConnected]);

    // Connecting pulse
    final connectingController = useAnimationController(
      duration: const Duration(milliseconds: 900),
    );
    useEffect(() {
      if (isConnecting && !isConnected) {
        connectingController.repeat(reverse: true);
      } else {
        connectingController.stop();
        if (!isConnecting) connectingController.value = 0;
      }
      return null;
    }, [isConnecting, isConnected]);

    // Particle animation for data flow along arc
    final particleController = useAnimationController(
      duration: const Duration(milliseconds: 2400),
    );
    useEffect(() {
      if (isConnected) {
        particleController.repeat();
      } else {
        particleController.stop();
        particleController.value = 0;
      }
      return null;
    }, [isConnected]);

    final userPos = _getPosition(userCountryCode);
    final vpnPos = _getPosition(vpnCountryCode);

    // Animated opacity for the map — brighter when connected
    final mapOpacity = isConnected ? 0.18 : 0.09;

    return ListenableBuilder(
      listenable: Listenable.merge([
        pulseController,
        arcController,
        connectingController,
        particleController,
      ]),
      builder: (context, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // Full-screen map background image
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 600),
                child: Image.asset(
                  'assets/images/world_map.png',
                  fit: BoxFit.cover,
                  color: isDark
                      ? Colors.white.withValues(alpha: mapOpacity)
                      : Colors.grey.withValues(alpha: isConnected ? 0.35 : 0.18),
                  colorBlendMode: isDark ? BlendMode.srcIn : BlendMode.srcATop,
                ),
              ),
            ),

            // Custom paint overlay: dots, arcs, particles
            Positioned.fill(
              child: CustomPaint(
                painter: _MapPainter(
                  userPos: userPos,
                  vpnPos: vpnPos,
                  isConnected: isConnected,
                  isConnecting: isConnecting && !isConnected,
                  pulseValue: pulseController.value,
                  arcProgress: arcController.value,
                  connectingPulse: connectingController.value,
                  particleProgress: particleController.value,
                  isDark: isDark,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Offset? _getPosition(String? countryCode) {
    if (countryCode == null || countryCode.isEmpty) return null;
    final coords = _countryCoords[countryCode.toUpperCase()];
    if (coords == null) return null;
    return _latLngToRelative(coords.$1, coords.$2);
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.userPos,
    required this.vpnPos,
    required this.isConnected,
    required this.isConnecting,
    required this.pulseValue,
    required this.arcProgress,
    required this.connectingPulse,
    required this.particleProgress,
    required this.isDark,
  });

  final Offset? userPos;
  final Offset? vpnPos;
  final bool isConnected;
  final bool isConnecting;
  final double pulseValue;
  final double arcProgress;
  final double connectingPulse;
  final double particleProgress;
  final bool isDark;

  static const _userDotColor = Color(0xFF1A4A9B);
  static const _vpnDotColor = Color(0xFF30D158);
  static const _connectingColor = Color(0xFFB9A847);
  static const _arcColor = Color(0xFF30D158);

  @override
  void paint(Canvas canvas, Size size) {
    // Convert relative positions to actual pixel positions
    final userPixel = userPos != null
        ? Offset(userPos!.dx * size.width, userPos!.dy * size.height)
        : null;
    final vpnPixel = vpnPos != null
        ? Offset(vpnPos!.dx * size.width, vpnPos!.dy * size.height)
        : null;

    // Draw connection arc
    if (isConnected && userPixel != null && vpnPixel != null && arcProgress > 0) {
      _drawArc(canvas, size, userPixel, vpnPixel);
    }

    // Draw user dot
    if (userPixel != null) {
      _drawUserDot(canvas, userPixel);
    }

    // Draw VPN dot
    if (vpnPixel != null && (isConnected || isConnecting)) {
      _drawVpnDot(canvas, vpnPixel);
    }
  }

  void _drawUserDot(Canvas canvas, Offset center) {
    // Outer glow
    final glowPaint = Paint()
      ..color = _userDotColor.withValues(alpha: .15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, 12, glowPaint);

    // Outer ring
    final ringPaint = Paint()
      ..color = _userDotColor.withValues(alpha: .25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, 8, ringPaint);

    // Inner dot
    final dotPaint = Paint()
      ..color = _userDotColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4, dotPaint);

    // White center
    final whitePaint = Paint()
      ..color = Colors.white.withValues(alpha: .9)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 1.5, whitePaint);
  }

  void _drawVpnDot(Canvas canvas, Offset center) {
    final dotColor = isConnecting ? _connectingColor : _vpnDotColor;
    final pulse = isConnecting ? connectingPulse : pulseValue;

    // Pulsing outer ring
    final pulseRadius = 10 + pulse * 14;
    final pulseAlpha = (0.25 * (1.0 - pulse * 0.7)).clamp(0.0, 1.0);
    final pulsePaint = Paint()
      ..color = dotColor.withValues(alpha: pulseAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, pulseRadius, pulsePaint);

    // Second pulse ring (delayed)
    if (isConnected) {
      final pulse2 = ((pulse + 0.5) % 1.0);
      final pulse2Radius = 10 + pulse2 * 18;
      final pulse2Alpha = (0.15 * (1.0 - pulse2 * 0.8)).clamp(0.0, 1.0);
      final pulse2Paint = Paint()
        ..color = dotColor.withValues(alpha: pulse2Alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(center, pulse2Radius, pulse2Paint);
    }

    // Glow
    final glowPaint = Paint()
      ..color = dotColor.withValues(alpha: .2 + pulse * 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, 8, glowPaint);

    // Outer ring
    final ringPaint = Paint()
      ..color = dotColor.withValues(alpha: .4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, 7, ringPaint);

    // Inner dot
    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 4.5, dotPaint);

    // White center
    final whitePaint = Paint()
      ..color = Colors.white.withValues(alpha: .9)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 1.8, whitePaint);
  }

  void _drawArc(Canvas canvas, Size size, Offset from, Offset to) {
    // Calculate control point for curved arc (upward bend)
    final mid = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
    final distance = (to - from).distance;
    final bendAmount = distance * 0.35;
    final controlPoint = Offset(mid.dx, mid.dy - bendAmount);

    // Draw the arc path
    final path = Path();
    path.moveTo(from.dx, from.dy);
    path.quadraticBezierTo(controlPoint.dx, controlPoint.dy, to.dx, to.dy);

    // Extract sub-path based on animation progress
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    final length = metric.length;

    // Animated arc line
    final subPath = metric.extractPath(0, length * arcProgress);

    // Gradient along arc
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..shader = ui.Gradient.linear(
        from,
        to,
        [
          _userDotColor.withValues(alpha: .6),
          _arcColor.withValues(alpha: .6),
        ],
      );
    canvas.drawPath(subPath, arcPaint);

    // Glow along arc
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
      ..shader = ui.Gradient.linear(
        from,
        to,
        [
          _userDotColor.withValues(alpha: .1),
          _arcColor.withValues(alpha: .1),
        ],
      );
    canvas.drawPath(subPath, glowPaint);

    // Data particle flowing along the arc
    if (arcProgress >= 1.0) {
      _drawDataParticles(canvas, metric, length);
    }
  }

  void _drawDataParticles(Canvas canvas, ui.PathMetric metric, double length) {
    // Draw 3 particles at different positions along the arc
    for (int i = 0; i < 3; i++) {
      final offset = (particleProgress + i / 3.0) % 1.0;
      final tangent = metric.getTangentForOffset(offset * length);
      if (tangent == null) continue;

      final pos = tangent.position;

      // Particle glow
      final glowPaint = Paint()
        ..color = _arcColor.withValues(alpha: .3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(pos, 4, glowPaint);

      // Particle dot
      final dotPaint = Paint()
        ..color = Colors.white.withValues(alpha: .9)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue ||
        oldDelegate.arcProgress != arcProgress ||
        oldDelegate.connectingPulse != connectingPulse ||
        oldDelegate.particleProgress != particleProgress ||
        oldDelegate.isConnected != isConnected ||
        oldDelegate.isConnecting != isConnecting ||
        oldDelegate.userPos != userPos ||
        oldDelegate.vpnPos != vpnPos;
  }
}
