import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Major world cities shown as small dots on the globe.
const _majorCities = <(double lat, double lng, String name)>[
  (40.71, -74.01, 'Нью-Йорк'),
  (34.05, -118.24, 'Лос-Анджелес'),
  (41.88, -87.63, 'Чикаго'),
  (29.76, -95.37, 'Хьюстон'),
  (33.45, -112.07, 'Финикс'),
  (49.28, -123.12, 'Ванкувер'),
  (43.65, -79.38, 'Торонто'),
  (51.51, -0.13, 'Лондон'),
  (48.86, 2.35, 'Париж'),
  (52.52, 13.41, 'Берлин'),
  (41.90, 12.50, 'Рим'),
  (40.42, -3.70, 'Мадрид'),
  (59.33, 18.07, 'Стокгольм'),
  (55.75, 37.62, 'Москва'),
  (50.45, 30.52, 'Киев'),
  (52.23, 21.01, 'Варшава'),
  (39.93, 32.86, 'Анкара'),
  (41.01, 28.98, 'Стамбул'),
  (25.20, 55.27, 'Дубай'),
  (28.61, 77.21, 'Дели'),
  (19.08, 72.88, 'Мумбаи'),
  (39.90, 116.40, 'Пекин'),
  (31.23, 121.47, 'Шанхай'),
  (22.32, 114.17, 'Гонконг'),
  (35.68, 139.69, 'Токио'),
  (37.57, 126.98, 'Сеул'),
  (1.35, 103.82, 'Сингапур'),
  (13.76, 100.50, 'Бангкок'),
  (-33.87, 151.21, 'Сидней'),
  (-37.81, 144.96, 'Мельбурн'),
  (30.04, 31.24, 'Каир'),
  (-1.29, 36.82, 'Найроби'),
  (-33.93, 18.42, 'Кейптаун'),
  (6.52, 3.38, 'Лагос'),
  (-23.55, -46.63, 'Сан-Паулу'),
  (-22.91, -43.17, 'Рио'),
  (-34.60, -58.38, 'Буэнос-Айрес'),
  (19.43, -99.13, 'Мехико'),
  (4.71, -74.07, 'Богота'),
  (-12.05, -77.04, 'Лима'),
];

// ═══════════════════════════════════════════════════════════════════════════
// Shared Earth texture cache — loaded once, used by all globe instances
// ═══════════════════════════════════════════════════════════════════════════
ui.Image? _cachedEarthTexture;
bool _textureLoading = false;

Future<ui.Image?> _loadEarthTexture() async {
  if (_cachedEarthTexture != null) return _cachedEarthTexture;
  if (_textureLoading) return null;
  _textureLoading = true;
  try {
    final data = await rootBundle.load('assets/images/earth_texture.jpg');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    _cachedEarthTexture = frame.image;
    return _cachedEarthTexture;
  } catch (_) {
    _textureLoading = false;
    return null;
  }
}

/// Interactive 3D globe with Earth texture and orthographic projection.
class GlobeWidget extends HookWidget {
  const GlobeWidget({
    super.key,
    required this.isConnected,
    required this.isConnecting,
    this.userCountryCode,
    this.vpnCountryCode,
    this.thirdCountryCode,
    this.viewLatNotifier,
    this.viewLngNotifier,
  });

  final bool isConnected;
  final bool isConnecting;
  final String? userCountryCode;
  final String? vpnCountryCode;
  final String? thirdCountryCode;
  final ValueNotifier<double>? viewLatNotifier;
  final ValueNotifier<double>? viewLngNotifier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final internalLat = useState(0.3);
    final internalLng = useState(0.2);

    final viewLat = viewLatNotifier ?? internalLat;
    final viewLng = viewLngNotifier ?? internalLng;
    final useInternalGestures = viewLatNotifier == null;

    // --- Load Earth texture ---
    final earthTexture = useState<ui.Image?>(_cachedEarthTexture);
    useEffect(() {
      if (earthTexture.value == null) {
        _loadEarthTexture().then((img) {
          if (img != null) earthTexture.value = img;
        });
      }
      return null;
    }, []);

    // --- Animations ---
    final pulseCtrl = useAnimationController(duration: const Duration(milliseconds: 1800));
    final arcCtrl = useAnimationController(duration: const Duration(milliseconds: 1200));
    final connectingCtrl = useAnimationController(duration: const Duration(milliseconds: 900));
    final particleCtrl = useAnimationController(duration: const Duration(milliseconds: 2400));
    final autoRotateCtrl = useAnimationController(duration: const Duration(milliseconds: 1500));

    useEffect(() {
      if (isConnected) { pulseCtrl.repeat(reverse: true); } else { pulseCtrl.stop(); pulseCtrl.value = 0; }
      return null;
    }, [isConnected]);

    useEffect(() {
      if (isConnected) { arcCtrl.forward(from: 0); } else { arcCtrl.reverse(); }
      return null;
    }, [isConnected]);

    useEffect(() {
      if (isConnecting && !isConnected) { connectingCtrl.repeat(reverse: true); }
      else { connectingCtrl.stop(); if (!isConnecting) connectingCtrl.value = 0; }
      return null;
    }, [isConnecting, isConnected]);

    useEffect(() {
      if (isConnected) { particleCtrl.repeat(); } else { particleCtrl.stop(); particleCtrl.value = 0; }
      return null;
    }, [isConnected]);

    // Auto-center to show points
    final autoStartLat = useRef(0.0);
    final autoStartLng = useRef(0.0);
    final autoTargetLat = useRef(0.0);
    final autoTargetLng = useRef(0.0);

    useEffect(() {
      if (isConnected || isConnecting) {
        final u = _getLatLng(userCountryCode);
        final v = _getLatLng(vpnCountryCode);
        final t = _getLatLng(thirdCountryCode);
        double tLat, tLng;
        final allPts = [if (u != null) u, if (v != null) v, if (t != null) t];
        if (allPts.length >= 2) {
          final avgLat = allPts.map((p) => p.$1).reduce((a, b) => a + b) / allPts.length;
          final avgLng = allPts.map((p) => p.$2).reduce((a, b) => a + b) / allPts.length;
          tLat = _deg2rad(avgLat);
          tLng = _deg2rad(avgLng);
        } else if (v != null) {
          tLat = _deg2rad(v.$1); tLng = _deg2rad(v.$2);
        } else if (u != null) {
          tLat = _deg2rad(u.$1); tLng = _deg2rad(u.$2);
        } else {
          return null;
        }
        autoStartLat.value = viewLat.value;
        autoStartLng.value = viewLng.value;
        autoTargetLat.value = tLat;
        autoTargetLng.value = tLng;
        autoRotateCtrl.forward(from: 0);
      }
      return null;
    }, [isConnected, isConnecting, userCountryCode, vpnCountryCode, thirdCountryCode]);

    useEffect(() {
      void listener() {
        final t = Curves.easeInOut.transform(autoRotateCtrl.value);
        viewLat.value = autoStartLat.value + (autoTargetLat.value - autoStartLat.value) * t;
        viewLng.value = autoStartLng.value + (autoTargetLng.value - autoStartLng.value) * t;
      }
      autoRotateCtrl.addListener(listener);
      return () => autoRotateCtrl.removeListener(listener);
    }, []);

    final userLatLng = _getLatLng(userCountryCode);
    final vpnLatLng = _getLatLng(vpnCountryCode);
    final thirdLatLng = _getLatLng(thirdCountryCode);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final r = min(w, h) / 2 * 0.68;

        Widget painter = ListenableBuilder(
          listenable: Listenable.merge([pulseCtrl, arcCtrl, connectingCtrl, particleCtrl, viewLat, viewLng]),
          builder: (context, _) {
            return CustomPaint(
              size: Size(w, h),
              painter: _GlobePainter(
                viewLat: viewLat.value,
                viewLng: viewLng.value,
                radius: r,
                userLatLng: userLatLng,
                vpnLatLng: vpnLatLng,
                thirdLatLng: thirdLatLng,
                isConnected: isConnected,
                isConnecting: isConnecting && !isConnected,
                pulseValue: pulseCtrl.value,
                arcProgress: arcCtrl.value,
                connectingPulse: connectingCtrl.value,
                particleProgress: particleCtrl.value,
                isDark: isDark,
                earthTexture: earthTexture.value,
              ),
            );
          },
        );

        if (useInternalGestures) {
          painter = GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanUpdate: (details) {
              final sensitivity = 1.2 / r;
              viewLng.value -= details.delta.dx * sensitivity;
              viewLat.value = (viewLat.value + details.delta.dy * sensitivity).clamp(-pi / 2, pi / 2);
            },
            child: painter,
          );
        }

        return painter;
      },
    );
  }

  (double lat, double lng)? _getLatLng(String? code) {
    if (code == null || code.isEmpty) return null;
    return _countryCoords[code.toUpperCase()];
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Globe CustomPainter — texture-mapped Earth
// ══════════════════════════════════════════════════════════════════════════════

class _GlobePainter extends CustomPainter {
  _GlobePainter({
    required this.viewLat,
    required this.viewLng,
    required this.radius,
    required this.userLatLng,
    required this.vpnLatLng,
    this.thirdLatLng,
    required this.isConnected,
    required this.isConnecting,
    required this.pulseValue,
    required this.arcProgress,
    required this.connectingPulse,
    required this.particleProgress,
    required this.isDark,
    this.earthTexture,
  });

  final double viewLat, viewLng, radius;
  final (double, double)? userLatLng, vpnLatLng, thirdLatLng;
  final bool isConnected, isConnecting, isDark;
  final double pulseValue, arcProgress, connectingPulse, particleProgress;
  final ui.Image? earthTexture;

  static const _userDotColor = Color(0xFF1A4A9B);
  static const _vpnDotColor = Color(0xFF30D158);
  static const _connectingColor = Color(0xFFB9A847);
  static const _thirdDotColor = Color(0xFF4FC3F7);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);

    // Clip to globe circle
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));

    if (earthTexture != null) {
      _drawTexturedGlobe(canvas, center);
    } else {
      _drawFallbackSurface(canvas, center);
    }
    _drawCityDots(canvas, center);
    _drawLighting(canvas, center);

    canvas.restore();

    _drawAtmosphere(canvas, center);

    // Arc: user → vpn
    if ((isConnected || isConnecting) && userLatLng != null && vpnLatLng != null && arcProgress > 0) {
      _drawGreatCircleArc(canvas, center, userLatLng!, vpnLatLng!, _userDotColor, _vpnDotColor);
    }
    // Arc: vpn → third (speed test server)
    if (isConnected && vpnLatLng != null && thirdLatLng != null && arcProgress >= 1.0) {
      _drawGreatCircleArc(canvas, center, vpnLatLng!, thirdLatLng!, _vpnDotColor, _thirdDotColor);
    }

    // User dot
    if (userLatLng != null) {
      final p = _project(userLatLng!.$1, userLatLng!.$2);
      if (p != null) _drawUserDot(canvas, Offset(cx + p.$1, cy + p.$2));
    }

    // VPN dot
    if (vpnLatLng != null && (isConnected || isConnecting)) {
      final p = _project(vpnLatLng!.$1, vpnLatLng!.$2);
      if (p != null) _drawVpnDot(canvas, Offset(cx + p.$1, cy + p.$2));
    }

    // Third dot (speed test server)
    if (thirdLatLng != null && isConnected) {
      final p = _project(thirdLatLng!.$1, thirdLatLng!.$2);
      if (p != null) _drawThirdDot(canvas, Offset(cx + p.$1, cy + p.$2));
    }
  }

  (double x, double y)? _project(double latDeg, double lngDeg) {
    final lat = _deg2rad(latDeg);
    final lng = _deg2rad(lngDeg);
    final cosLat = cos(lat);
    final sinLat = sin(lat);
    final cosLat0 = cos(viewLat);
    final sinLat0 = sin(viewLat);
    final dLng = lng - viewLng;
    final cosDLng = cos(dLng);
    final cosc = sinLat0 * sinLat + cosLat0 * cosLat * cosDLng;
    if (cosc <= 0) return null;
    return (radius * cosLat * sin(dLng), -radius * (cosLat0 * sinLat - sinLat0 * cosLat * cosDLng));
  }

  // ── Texture-mapped globe using drawVertices ──────────────────────────────

  void _drawTexturedGlobe(Canvas canvas, Offset center) {
    final img = earthTexture!;
    final imgW = img.width.toDouble();
    final imgH = img.height.toDouble();

    const latStep = 2.0;
    const lngStep = 2.0;
    const latSteps = 90; // 180 / 2
    const lngSteps = 180; // 360 / 2
    const gridSize = (latSteps + 1) * (lngSteps + 1);

    final positions = Float32List(gridSize * 2);
    final texCoords = Float32List(gridSize * 2);
    final visible = Uint8List(gridSize);
    final indexMap = Int32List(gridSize);
    var vertexCount = 0;

    for (int j = 0; j <= latSteps; j++) {
      final lat = 90.0 - j * latStep;
      for (int i = 0; i <= lngSteps; i++) {
        final gridIdx = j * (lngSteps + 1) + i;
        final lng = -180.0 + i * lngStep;
        final proj = _project(lat, lng);
        if (proj != null) {
          visible[gridIdx] = 1;
          indexMap[gridIdx] = vertexCount;
          final vi = vertexCount * 2;
          positions[vi] = center.dx + proj.$1;
          positions[vi + 1] = center.dy + proj.$2;
          texCoords[vi] = (lng + 180.0) / 360.0 * imgW;
          texCoords[vi + 1] = (90.0 - lat) / 180.0 * imgH;
          vertexCount++;
        } else {
          visible[gridIdx] = 0;
          indexMap[gridIdx] = -1;
        }
      }
    }

    if (vertexCount < 3) return;

    // Build triangle indices
    final indices = <int>[];
    for (int j = 0; j < latSteps; j++) {
      for (int i = 0; i < lngSteps; i++) {
        final gi0 = j * (lngSteps + 1) + i;
        final gi1 = gi0 + 1;
        final gi2 = gi0 + (lngSteps + 1);
        final gi3 = gi2 + 1;

        if (visible[gi0] == 1 && visible[gi1] == 1 && visible[gi2] == 1) {
          indices.addAll([indexMap[gi0], indexMap[gi1], indexMap[gi2]]);
        }
        if (visible[gi1] == 1 && visible[gi3] == 1 && visible[gi2] == 1) {
          indices.addAll([indexMap[gi1], indexMap[gi3], indexMap[gi2]]);
        }
      }
    }

    if (indices.isEmpty) return;

    // Trim position/texCoord arrays to actual vertex count
    final trimPos = Float32List.sublistView(positions, 0, vertexCount * 2);
    final trimTex = Float32List.sublistView(texCoords, 0, vertexCount * 2);

    final shader = ui.ImageShader(
      img,
      TileMode.clamp,
      TileMode.clamp,
      Matrix4.identity().storage,
    );

    final vertices = ui.Vertices.raw(
      VertexMode.triangles,
      trimPos,
      textureCoordinates: trimTex,
      indices: Uint16List.fromList(indices),
    );

    canvas.drawVertices(vertices, BlendMode.srcOver, Paint()..shader = shader);
  }

  // ── Fallback: simple blue globe while texture loads ──────────────────────

  void _drawFallbackSurface(Canvas canvas, Offset center) {
    final lightOffset = Offset(center.dx - radius * 0.35, center.dy - radius * 0.35);
    canvas.drawCircle(center, radius, Paint()
      ..shader = ui.Gradient.radial(lightOffset, radius * 2.2,
        [const Color(0xFF1B6AAF), const Color(0xFF0B3D6B)],
        [0.0, 1.0]));
  }

  // ── 3D Lighting overlay ─────────────────────────────────────────────────

  void _drawLighting(Canvas canvas, Offset center) {
    // Specular highlight — top-left
    final hlCenter = Offset(center.dx - radius * 0.3, center.dy - radius * 0.35);
    canvas.drawCircle(center, radius, Paint()
      ..shader = ui.Gradient.radial(hlCenter, radius * 0.8,
        [Colors.white.withValues(alpha: 0.12), Colors.white.withValues(alpha: 0.02), Colors.transparent],
        [0.0, 0.4, 1.0]));
    // Shadow — bottom-right edge darkening
    canvas.drawCircle(center, radius, Paint()
      ..shader = ui.Gradient.radial(center, radius,
        [Colors.transparent, Colors.transparent, Colors.black.withValues(alpha: 0.25)],
        [0.0, 0.7, 1.0]));
  }

  // ── Atmosphere ──────────────────────────────────────────────────────────

  void _drawAtmosphere(Canvas canvas, Offset center) {
    canvas.drawCircle(center, radius * 1.08, Paint()
      ..shader = ui.Gradient.radial(center, radius * 1.08,
        [Colors.transparent, Colors.transparent,
         const Color(0xFF4A9FE7).withValues(alpha: 0.15),
         const Color(0xFF4A9FE7).withValues(alpha: 0.05), Colors.transparent],
        [0.0, 0.88, 0.95, 1.0, 1.0]));
    canvas.drawCircle(center, radius, Paint()
      ..color = const Color(0xFF5AAFE7).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);
  }

  // ── City dots ───────────────────────────────────────────────────────────

  void _drawCityDots(Canvas canvas, Offset center) {
    final cx = center.dx;
    final cy = center.dy;
    final dotPaint = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;
    final glowPaint = Paint()
      ..color = const Color(0xFFFFD54F).withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    for (final city in _majorCities) {
      final p = _project(city.$1, city.$2);
      if (p != null) {
        final pos = Offset(cx + p.$1, cy + p.$2);
        canvas.drawCircle(pos, 2.5, glowPaint);
        canvas.drawCircle(pos, 1.2, dotPaint);
      }
    }
  }

  // ── Connection dots ─────────────────────────────────────────────────────

  void _drawUserDot(Canvas canvas, Offset c) {
    canvas.drawCircle(c, 14, Paint()..color = _userDotColor.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    canvas.drawCircle(c, 9, Paint()..color = _userDotColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke..strokeWidth = 2.0);
    canvas.drawCircle(c, 5, Paint()..color = _userDotColor);
    canvas.drawCircle(c, 2, Paint()..color = Colors.white.withValues(alpha: 0.95));
  }

  void _drawVpnDot(Canvas canvas, Offset c) {
    final col = isConnecting ? _connectingColor : _vpnDotColor;
    final pulse = isConnecting ? connectingPulse : pulseValue;

    final pr = 10 + pulse * 14;
    canvas.drawCircle(c, pr, Paint()..color = col.withValues(alpha: (0.25 * (1 - pulse * 0.7)).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke..strokeWidth = 1.5);
    if (isConnected) {
      final p2 = ((pulse + 0.5) % 1.0);
      canvas.drawCircle(c, 10 + p2 * 18, Paint()..color = col.withValues(alpha: (0.15 * (1 - p2 * 0.8)).clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke..strokeWidth = 1.0);
    }
    canvas.drawCircle(c, 8, Paint()..color = col.withValues(alpha: 0.2 + pulse * 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    canvas.drawCircle(c, 7, Paint()..color = col.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke..strokeWidth = 1.5);
    canvas.drawCircle(c, 4.5, Paint()..color = col);
    canvas.drawCircle(c, 1.8, Paint()..color = Colors.white.withValues(alpha: 0.9));
  }

  void _drawThirdDot(Canvas canvas, Offset c) {
    canvas.drawCircle(c, 10, Paint()..color = _thirdDotColor.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawCircle(c, 7, Paint()..color = _thirdDotColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke..strokeWidth = 1.5);
    canvas.drawCircle(c, 4.5, Paint()..color = _thirdDotColor);
    canvas.drawCircle(c, 1.8, Paint()..color = Colors.white.withValues(alpha: 0.9));
  }

  // ── Connection arc ──────────────────────────────────────────────────────

  void _drawGreatCircleArc(
    Canvas canvas,
    Offset center,
    (double, double) fromLatLng,
    (double, double) toLatLng,
    Color fromColor,
    Color toColor,
  ) {
    final cx = center.dx;
    final cy = center.dy;

    final lat1 = _deg2rad(fromLatLng.$1), lng1 = _deg2rad(fromLatLng.$2);
    final lat2 = _deg2rad(toLatLng.$1), lng2 = _deg2rad(toLatLng.$2);

    final x1 = cos(lat1) * cos(lng1), y1 = cos(lat1) * sin(lng1), z1 = sin(lat1);
    final x2 = cos(lat2) * cos(lng2), y2 = cos(lat2) * sin(lng2), z2 = sin(lat2);

    final dot = (x1 * x2 + y1 * y2 + z1 * z2).clamp(-1.0, 1.0);
    final omega = acos(dot);

    const segments = 64;
    final points = <Offset>[];
    final visibleFlags = <bool>[];

    for (int i = 0; i <= segments; i++) {
      final t = i / segments;
      double px, py, pz;
      if (omega.abs() < 1e-6) { px = x1; py = y1; pz = z1; }
      else {
        final so = sin(omega);
        final a = sin((1 - t) * omega) / so, b = sin(t * omega) / so;
        px = a * x1 + b * x2; py = a * y1 + b * y2; pz = a * z1 + b * z2;
      }
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

    final total = (arcProgress * segments).round();
    final arcPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeCap = StrokeCap.round;
    final glowPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 7.0..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    for (int i = 0; i < total; i++) {
      if (!visibleFlags[i] || !visibleFlags[i + 1]) continue;
      final t = i / segments;
      final c = Color.lerp(fromColor.withValues(alpha: 0.7), toColor.withValues(alpha: 0.7), t)!;
      arcPaint.color = c;
      canvas.drawLine(points[i], points[i + 1], arcPaint);
      glowPaint.color = c.withValues(alpha: 0.15);
      canvas.drawLine(points[i], points[i + 1], glowPaint);
    }

    if (arcProgress >= 1.0) {
      for (int p = 0; p < 3; p++) {
        final off = (particleProgress + p / 3.0) % 1.0;
        final idx = (off * segments).round().clamp(0, segments);
        if (idx < points.length && visibleFlags[idx]) {
          canvas.drawCircle(points[idx], 4, Paint()..color = toColor.withValues(alpha: 0.4)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
          canvas.drawCircle(points[idx], 2, Paint()..color = Colors.white.withValues(alpha: 0.95));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GlobePainter o) =>
      o.viewLat != viewLat || o.viewLng != viewLng || o.radius != radius ||
      o.pulseValue != pulseValue || o.arcProgress != arcProgress ||
      o.connectingPulse != connectingPulse || o.particleProgress != particleProgress ||
      o.isConnected != isConnected || o.isConnecting != isConnecting ||
      o.userLatLng != userLatLng || o.vpnLatLng != vpnLatLng || o.thirdLatLng != thirdLatLng ||
      o.earthTexture != earthTexture;
}
