import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Country capital approximate coordinates (lat, lng) in degrees.
const _countryCoords = <String, (double lat, double lng)>{
  'RU': (55.75, 37.62),
  'NL': (52.37, 4.90),
  'US': (38.90, -77.04),
  'DE': (52.52, 13.41),
  'FR': (48.86, 2.35),
  'GB': (51.51, -0.13),
  'UA': (50.45, 30.52),
  'KZ': (51.17, 71.43),
  'BY': (53.90, 27.57),
  'TR': (39.93, 32.86),
  'CN': (39.90, 116.40),
  'JP': (35.68, 139.69),
  'SG': (1.35, 103.82),
  'FI': (60.17, 24.94),
  'SE': (59.33, 18.07),
  'CH': (46.95, 7.45),
  'CA': (45.42, -75.70),
  'AU': (-33.87, 151.21),
  'BR': (-15.79, -47.88),
  'IN': (28.61, 77.21),
  'IT': (41.90, 12.50),
  'ES': (40.42, -3.70),
  'PL': (52.23, 21.01),
  'CZ': (50.08, 14.44),
  'AT': (48.21, 16.37),
  'NO': (59.91, 10.75),
  'DK': (55.68, 12.57),
  'PT': (38.72, -9.14),
  'IE': (53.35, -6.26),
  'HK': (22.32, 114.17),
  'KR': (37.57, 126.98),
  'TW': (25.03, 121.57),
  'AR': (-34.60, -58.38),
  'MX': (19.43, -99.13),
  'ZA': (-33.93, 18.42),
  'EG': (30.04, 31.24),
  'AE': (25.20, 55.27),
  'IL': (31.77, 35.22),
  'TH': (13.76, 100.50),
  'VN': (21.03, 105.85),
  'ID': (-6.21, 106.85),
  'MY': (3.14, 101.69),
  'PH': (14.60, 120.98),
  'RO': (44.43, 26.10),
  'BG': (42.70, 23.32),
  'HU': (47.50, 19.04),
  'GR': (37.98, 23.73),
  'HR': (45.81, 15.98),
  'RS': (44.79, 20.47),
  'LT': (54.69, 25.28),
  'LV': (56.95, 24.11),
  'EE': (59.44, 24.75),
  'GE': (41.69, 44.80),
  'AM': (40.18, 44.51),
  'AZ': (40.41, 49.87),
  'UZ': (41.30, 69.28),
  'MD': (47.01, 28.86),
  'IS': (64.15, -21.94),
  'NZ': (-41.29, 174.78),
  'CL': (-33.45, -70.67),
  'CO': (4.71, -74.07),
  'PE': (-12.05, -77.04),
};

double _deg2rad(double deg) => deg * pi / 180.0;

/// Interactive 3D globe with orthographic projection, replacing the flat map.
class GlobeWidget extends HookWidget {
  const GlobeWidget({
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

    // --- View center state (lat0, lng0 in radians) ---
    final viewLat = useState(0.3); // ~17 degrees north
    final viewLng = useState(0.2); // ~11 degrees east

    // --- Drag state ---
    final dragStartLat = useRef(0.0);
    final dragStartLng = useRef(0.0);
    final globeRadius = useRef(100.0);

    // --- Pulse animation for VPN dot ---
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

    // --- Arc animation progress ---
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

    // --- Connecting pulse (yellow) ---
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

    // --- Particle animation ---
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

    // --- Auto-rotate animation ---
    final autoRotateController = useAnimationController(
      duration: const Duration(milliseconds: 1500),
    );
    final autoRotateStartLat = useRef(0.0);
    final autoRotateStartLng = useRef(0.0);
    final autoRotateTargetLat = useRef(0.0);
    final autoRotateTargetLng = useRef(0.0);

    // Auto-center when connected
    useEffect(() {
      if (isConnected || isConnecting) {
        final userCoords = _getLatLng(userCountryCode);
        final vpnCoords = _getLatLng(vpnCountryCode);
        double targetLat;
        double targetLng;
        if (userCoords != null && vpnCoords != null) {
          targetLat = _deg2rad((userCoords.$1 + vpnCoords.$1) / 2);
          targetLng = _deg2rad((userCoords.$2 + vpnCoords.$2) / 2);
        } else if (vpnCoords != null) {
          targetLat = _deg2rad(vpnCoords.$1);
          targetLng = _deg2rad(vpnCoords.$2);
        } else if (userCoords != null) {
          targetLat = _deg2rad(userCoords.$1);
          targetLng = _deg2rad(userCoords.$2);
        } else {
          return null;
        }

        autoRotateStartLat.value = viewLat.value;
        autoRotateStartLng.value = viewLng.value;
        autoRotateTargetLat.value = targetLat;
        autoRotateTargetLng.value = targetLng;
        autoRotateController.forward(from: 0);
      }
      return null;
    }, [isConnected, isConnecting, userCountryCode, vpnCountryCode]);

    useEffect(() {
      void listener() {
        final t = Curves.easeInOut.transform(autoRotateController.value);
        viewLat.value = autoRotateStartLat.value +
            (autoRotateTargetLat.value - autoRotateStartLat.value) * t;
        viewLng.value = autoRotateStartLng.value +
            (autoRotateTargetLng.value - autoRotateStartLng.value) * t;
      }

      autoRotateController.addListener(listener);
      return () => autoRotateController.removeListener(listener);
    }, []);

    // Get lat/lng in radians for user and VPN
    final userLatLng = _getLatLng(userCountryCode);
    final vpnLatLng = _getLatLng(vpnCountryCode);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final r = min(w, h) / 2 * 0.85;
        globeRadius.value = r;

        return GestureDetector(
          onPanStart: (details) {
            dragStartLat.value = viewLat.value;
            dragStartLng.value = viewLng.value;
          },
          onPanUpdate: (details) {
            final sensitivity = 1.2 / r;
            viewLng.value -= details.delta.dx * sensitivity;
            viewLat.value =
                (viewLat.value + details.delta.dy * sensitivity)
                    .clamp(-pi / 2, pi / 2);
          },
          child: ListenableBuilder(
            listenable: Listenable.merge([
              pulseController,
              arcController,
              connectingController,
              particleController,
            ]),
            builder: (context, child) {
              return CustomPaint(
                size: Size(w, h),
                painter: _GlobePainter(
                  viewLat: viewLat.value,
                  viewLng: viewLng.value,
                  radius: r,
                  userLatLng: userLatLng,
                  vpnLatLng: vpnLatLng,
                  isConnected: isConnected,
                  isConnecting: isConnecting && !isConnected,
                  pulseValue: pulseController.value,
                  arcProgress: arcController.value,
                  connectingPulse: connectingController.value,
                  particleProgress: particleController.value,
                  isDark: isDark,
                ),
              );
            },
          ),
        );
      },
    );
  }

  (double lat, double lng)? _getLatLng(String? code) {
    if (code == null || code.isEmpty) return null;
    return _countryCoords[code.toUpperCase()];
  }
}

// ──────────────────────────────────────────────
// Globe CustomPainter
// ──────────────────────────────────────────────

class _GlobePainter extends CustomPainter {
  _GlobePainter({
    required this.viewLat,
    required this.viewLng,
    required this.radius,
    required this.userLatLng,
    required this.vpnLatLng,
    required this.isConnected,
    required this.isConnecting,
    required this.pulseValue,
    required this.arcProgress,
    required this.connectingPulse,
    required this.particleProgress,
    required this.isDark,
  });

  final double viewLat; // radians
  final double viewLng; // radians
  final double radius;
  final (double, double)? userLatLng; // degrees
  final (double, double)? vpnLatLng; // degrees
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

  // Simplified continent outlines (lat, lng) in degrees
  static const _continentOutlines = <List<(double, double)>>[
    // Africa
    [
      (37.0, -10.0), (36.0, 0.0), (37.5, 10.0), (33.0, 12.0),
      (32.0, 25.0), (31.5, 32.0), (29.0, 33.0), (22.0, 36.0),
      (12.0, 44.0), (11.0, 50.0), (2.0, 46.0), (-1.0, 42.0),
      (-11.0, 40.0), (-15.0, 40.5), (-25.0, 35.0), (-34.0, 26.0),
      (-34.5, 18.0), (-29.0, 16.0), (-18.0, 12.0), (-12.0, 14.0),
      (-6.0, 12.0), (4.0, 10.0), (5.0, 3.0), (4.0, -3.0),
      (6.0, -5.0), (5.0, -10.0), (10.0, -15.0), (15.0, -17.0),
      (21.0, -17.0), (26.0, -15.0), (33.0, -8.0), (36.0, -5.0),
      (37.0, -10.0),
    ],
    // Europe
    [
      (36.0, -10.0), (38.0, -8.0), (43.0, -9.0), (44.0, -1.0),
      (48.0, -5.0), (51.0, 2.0), (54.0, 6.0), (57.0, 8.0),
      (58.0, 6.0), (63.0, 5.0), (71.0, 26.0), (70.0, 30.0),
      (65.0, 30.0), (60.0, 30.0), (56.0, 38.0), (50.0, 40.0),
      (47.0, 38.0), (42.0, 42.0), (41.0, 29.0), (38.0, 24.0),
      (40.0, 18.0), (45.0, 14.0), (44.0, 8.0), (43.0, 5.0),
      (42.0, 3.0), (37.0, -2.0), (36.0, -5.0), (36.0, -10.0),
    ],
    // Asia
    [
      (42.0, 42.0), (47.0, 38.0), (50.0, 40.0), (56.0, 38.0),
      (60.0, 30.0), (65.0, 30.0), (70.0, 30.0), (71.0, 26.0),
      (70.0, 50.0), (68.0, 70.0), (72.0, 100.0), (71.0, 130.0),
      (68.0, 140.0), (65.0, 170.0), (60.0, 163.0), (55.0, 155.0),
      (55.0, 135.0), (50.0, 130.0), (46.0, 140.0), (43.0, 145.0),
      (40.0, 132.0), (35.0, 129.0), (34.0, 132.0), (31.0, 131.0),
      (35.0, 120.0), (30.0, 120.0), (22.0, 108.0), (22.0, 100.0),
      (10.0, 105.0), (1.0, 104.0), (7.0, 98.0), (16.0, 97.0),
      (22.0, 88.0), (28.0, 87.0), (28.0, 77.0), (23.0, 70.0),
      (25.0, 62.0), (22.0, 60.0), (25.0, 57.0), (27.0, 50.0),
      (29.0, 48.0), (30.0, 48.0), (33.0, 44.0), (37.0, 42.0),
      (42.0, 42.0),
    ],
    // North America
    [
      (70.0, -165.0), (72.0, -130.0), (70.0, -100.0), (65.0, -90.0),
      (60.0, -95.0), (55.0, -85.0), (50.0, -90.0), (48.0, -89.0),
      (46.0, -82.0), (42.0, -82.0), (40.0, -74.0), (35.0, -75.0),
      (30.0, -81.0), (25.0, -80.0), (25.0, -90.0), (20.0, -87.0),
      (15.0, -83.0), (10.0, -84.0), (8.0, -77.0), (10.0, -75.0),
      (12.0, -72.0), (11.0, -62.0), (18.0, -63.0), (20.0, -73.0),
      (25.0, -77.0), (30.0, -85.0), (30.0, -90.0), (29.0, -95.0),
      (26.0, -97.0), (20.0, -105.0), (23.0, -110.0), (30.0, -113.0),
      (32.0, -117.0), (38.0, -122.0), (48.0, -124.0), (54.0, -130.0),
      (57.0, -135.0), (60.0, -140.0), (60.0, -147.0), (63.0, -152.0),
      (66.0, -164.0), (70.0, -165.0),
    ],
    // South America
    [
      (12.0, -72.0), (10.0, -75.0), (8.0, -77.0), (0.0, -80.0),
      (-5.0, -81.0), (-15.0, -75.0), (-18.0, -70.0), (-23.0, -70.0),
      (-27.0, -71.0), (-33.0, -72.0), (-40.0, -72.0), (-46.0, -75.0),
      (-52.0, -70.0), (-55.0, -68.0), (-55.0, -65.0), (-50.0, -65.0),
      (-42.0, -63.0), (-38.0, -57.0), (-35.0, -54.0), (-33.0, -53.0),
      (-23.0, -43.0), (-15.0, -39.0), (-7.0, -35.0), (-2.0, -42.0),
      (0.0, -50.0), (5.0, -60.0), (8.0, -62.0), (11.0, -62.0),
      (12.0, -72.0),
    ],
    // Australia
    [
      (-12.0, 130.0), (-14.0, 127.0), (-18.0, 122.0), (-22.0, 114.0),
      (-28.0, 114.0), (-35.0, 117.0), (-35.0, 137.0), (-38.0, 145.0),
      (-37.0, 150.0), (-28.0, 153.0), (-23.0, 150.0), (-19.0, 147.0),
      (-16.0, 145.0), (-14.0, 143.0), (-12.0, 141.0), (-11.0, 136.0),
      (-12.0, 130.0),
    ],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);

    // Clip to globe circle
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));

    // --- Globe surface fill with limb darkening ---
    _drawGlobeSurface(canvas, center);

    // --- Grid lines ---
    _drawGridLines(canvas, center);

    // --- Continent outlines ---
    _drawContinents(canvas, center);

    canvas.restore(); // end clip

    // --- Atmosphere glow (drawn outside clip so it extends beyond the globe) ---
    _drawAtmosphere(canvas, center);

    // --- Great circle arc ---
    if ((isConnected || isConnecting) &&
        userLatLng != null &&
        vpnLatLng != null &&
        arcProgress > 0) {
      _drawGreatCircleArc(canvas, center);
    }

    // --- User dot ---
    if (userLatLng != null) {
      final proj = _project(userLatLng!.$1, userLatLng!.$2);
      if (proj != null) {
        _drawUserDot(canvas, Offset(cx + proj.$1, cy + proj.$2));
      }
    }

    // --- VPN dot ---
    if (vpnLatLng != null && (isConnected || isConnecting)) {
      final proj = _project(vpnLatLng!.$1, vpnLatLng!.$2);
      if (proj != null) {
        _drawVpnDot(canvas, Offset(cx + proj.$1, cy + proj.$2));
      }
    }
  }

  // ── Orthographic projection ──
  // Returns (x, y) screen offset from center, or null if on the back side.
  // Input lat/lng in DEGREES.
  (double x, double y)? _project(double latDeg, double lngDeg) {
    final lat = _deg2rad(latDeg);
    final lng = _deg2rad(lngDeg);
    final lat0 = viewLat;
    final lng0 = viewLng;

    final cosLat = cos(lat);
    final sinLat = sin(lat);
    final cosLat0 = cos(lat0);
    final sinLat0 = sin(lat0);
    final dLng = lng - lng0;
    final cosDLng = cos(dLng);

    // Visibility check
    final cosc = sinLat0 * sinLat + cosLat0 * cosLat * cosDLng;
    if (cosc <= 0) return null;

    final x = radius * cosLat * sin(dLng);
    final y = -radius * (cosLat0 * sinLat - sinLat0 * cosLat * cosDLng);

    return (x, y);
  }

  // ── Globe surface ──
  void _drawGlobeSurface(Canvas canvas, Offset center) {
    final surfacePaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius,
        [
          isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.grey.withValues(alpha: 0.08),
          isDark
              ? Colors.white.withValues(alpha: 0.015)
              : Colors.grey.withValues(alpha: 0.02),
        ],
        [0.0, 1.0],
      );
    canvas.drawCircle(center, radius, surfacePaint);
  }

  // ── Atmosphere glow ──
  void _drawAtmosphere(Canvas canvas, Offset center) {
    final glowPaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius * 1.15,
        [
          Colors.transparent,
          const Color(0xFF4A8FE7).withValues(alpha: 0.0),
          const Color(0xFF4A8FE7).withValues(alpha: 0.06),
          const Color(0xFF4A8FE7).withValues(alpha: 0.02),
          Colors.transparent,
        ],
        [0.0, 0.82, 0.92, 1.0, 1.0],
      )
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 1.15, glowPaint);

    // Thin rim
    final rimPaint = Paint()
      ..color = const Color(0xFF4A8FE7).withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius, rimPaint);
  }

  // ── Grid lines ──
  void _drawGridLines(Canvas canvas, Offset center) {
    final cx = center.dx;
    final cy = center.dy;

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: isDark ? 0.05 : 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Meridians (every 30 degrees longitude)
    for (double lngDeg = -180; lngDeg < 180; lngDeg += 30) {
      final path = Path();
      var started = false;
      for (double latDeg = -90; latDeg <= 90; latDeg += 2) {
        final p = _project(latDeg, lngDeg);
        if (p != null) {
          if (!started) {
            path.moveTo(cx + p.$1, cy + p.$2);
            started = true;
          } else {
            path.lineTo(cx + p.$1, cy + p.$2);
          }
        } else {
          started = false;
        }
      }
      canvas.drawPath(path, gridPaint);
    }

    // Parallels (every 30 degrees latitude)
    for (double latDeg = -60; latDeg <= 60; latDeg += 30) {
      final path = Path();
      var started = false;
      for (double lngDeg = -180; lngDeg <= 180; lngDeg += 2) {
        final p = _project(latDeg, lngDeg);
        if (p != null) {
          if (!started) {
            path.moveTo(cx + p.$1, cy + p.$2);
            started = true;
          } else {
            path.lineTo(cx + p.$1, cy + p.$2);
          }
        } else {
          started = false;
        }
      }
      canvas.drawPath(path, gridPaint);
    }
  }

  // ── Continent outlines ──
  void _drawContinents(Canvas canvas, Offset center) {
    final cx = center.dx;
    final cy = center.dy;

    final continentPaint = Paint()
      ..color = Colors.white.withValues(alpha: isDark ? 0.20 : 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeJoin = StrokeJoin.round;

    for (final outline in _continentOutlines) {
      final path = Path();
      var started = false;
      for (final point in outline) {
        final p = _project(point.$1, point.$2);
        if (p != null) {
          if (!started) {
            path.moveTo(cx + p.$1, cy + p.$2);
            started = true;
          } else {
            path.lineTo(cx + p.$1, cy + p.$2);
          }
        } else {
          // Point on back side — break the path
          started = false;
        }
      }
      canvas.drawPath(path, continentPaint);
    }
  }

  // ── User dot ──
  void _drawUserDot(Canvas canvas, Offset center) {
    // Outer glow
    final glowPaint = Paint()
      ..color = _userDotColor.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center, 12, glowPaint);

    // Outer ring
    final ringPaint = Paint()
      ..color = _userDotColor.withValues(alpha: 0.25)
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
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 1.5, whitePaint);
  }

  // ── VPN dot ──
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

    // Second pulse ring
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
      ..color = dotColor.withValues(alpha: 0.2 + pulse * 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(center, 8, glowPaint);

    // Outer ring
    final ringPaint = Paint()
      ..color = dotColor.withValues(alpha: 0.4)
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
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 1.8, whitePaint);
  }

  // ── Great circle arc with gradient and particles ──
  void _drawGreatCircleArc(Canvas canvas, Offset center) {
    if (userLatLng == null || vpnLatLng == null) return;

    final cx = center.dx;
    final cy = center.dy;

    // Spherical interpolation points
    final lat1 = _deg2rad(userLatLng!.$1);
    final lng1 = _deg2rad(userLatLng!.$2);
    final lat2 = _deg2rad(vpnLatLng!.$1);
    final lng2 = _deg2rad(vpnLatLng!.$2);

    // Convert to 3D cartesian for slerp
    final x1 = cos(lat1) * cos(lng1);
    final y1 = cos(lat1) * sin(lng1);
    final z1 = sin(lat1);
    final x2 = cos(lat2) * cos(lng2);
    final y2 = cos(lat2) * sin(lng2);
    final z2 = sin(lat2);

    // Angle between the two points
    final dot = (x1 * x2 + y1 * y2 + z1 * z2).clamp(-1.0, 1.0);
    final omega = acos(dot);

    const segments = 64;
    final points = <Offset>[];
    final visibleFlags = <bool>[];

    // Parameter t values along the arc
    final tValues = <double>[];

    for (int i = 0; i <= segments; i++) {
      final t = i / segments;
      tValues.add(t);

      double px, py, pz;
      if (omega.abs() < 1e-6) {
        // Points are essentially the same
        px = x1;
        py = y1;
        pz = z1;
      } else {
        final sinOmega = sin(omega);
        final a = sin((1 - t) * omega) / sinOmega;
        final b = sin(t * omega) / sinOmega;
        px = a * x1 + b * x2;
        py = a * y1 + b * y2;
        pz = a * z1 + b * z2;
      }

      // Convert back to lat/lng degrees
      final lat = asin(pz.clamp(-1.0, 1.0)) * 180 / pi;
      final lng = atan2(py, px) * 180 / pi;

      final proj = _project(lat, lng);
      if (proj != null) {
        points.add(Offset(cx + proj.$1, cy + proj.$2));
        visibleFlags.add(true);
      } else {
        points.add(Offset.zero);
        visibleFlags.add(false);
      }
    }

    // Draw the arc as polyline segments (only visible portions)
    final totalVisible = (arcProgress * segments).round();

    // Arc gradient paint
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final glowArcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    for (int i = 0; i < totalVisible; i++) {
      if (!visibleFlags[i] || !visibleFlags[i + 1]) continue;

      final t = i / segments;
      // Gradient from user color to vpn color
      final color = Color.lerp(
        _userDotColor.withValues(alpha: 0.6),
        _vpnDotColor.withValues(alpha: 0.6),
        t,
      )!;

      arcPaint.color = color;
      canvas.drawLine(points[i], points[i + 1], arcPaint);

      glowArcPaint.color = color.withValues(alpha: 0.1);
      canvas.drawLine(points[i], points[i + 1], glowArcPaint);
    }

    // Data particles flowing along the arc
    if (arcProgress >= 1.0) {
      for (int p = 0; p < 3; p++) {
        final pOffset = (particleProgress + p / 3.0) % 1.0;
        final idx = (pOffset * segments).round().clamp(0, segments);
        if (idx < points.length && visibleFlags[idx]) {
          final pos = points[idx];

          // Particle glow
          final particleGlow = Paint()
            ..color = _vpnDotColor.withValues(alpha: 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
          canvas.drawCircle(pos, 4, particleGlow);

          // Particle dot
          final particleDot = Paint()
            ..color = Colors.white.withValues(alpha: 0.9)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(pos, 2, particleDot);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GlobePainter oldDelegate) {
    return oldDelegate.viewLat != viewLat ||
        oldDelegate.viewLng != viewLng ||
        oldDelegate.radius != radius ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.arcProgress != arcProgress ||
        oldDelegate.connectingPulse != connectingPulse ||
        oldDelegate.particleProgress != particleProgress ||
        oldDelegate.isConnected != isConnected ||
        oldDelegate.isConnecting != isConnecting ||
        oldDelegate.userLatLng != userLatLng ||
        oldDelegate.vpnLatLng != vpnLatLng;
  }
}
