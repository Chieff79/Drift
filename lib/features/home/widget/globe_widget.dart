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

/// Interactive 3D globe with orthographic projection.
///
/// Supports external rotation control via [viewLatNotifier] / [viewLngNotifier].
/// If not provided, manages its own internal state with gesture detection.
class GlobeWidget extends HookWidget {
  const GlobeWidget({
    super.key,
    required this.isConnected,
    required this.isConnecting,
    this.userCountryCode,
    this.vpnCountryCode,
    this.viewLatNotifier,
    this.viewLngNotifier,
  });

  final bool isConnected;
  final bool isConnecting;
  final String? userCountryCode;
  final String? vpnCountryCode;

  /// If provided, the parent controls rotation. Otherwise, internal GestureDetector is used.
  final ValueNotifier<double>? viewLatNotifier;
  final ValueNotifier<double>? viewLngNotifier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Internal state — used when no external notifiers provided
    final internalLat = useState(0.3);
    final internalLng = useState(0.2);

    final viewLat = viewLatNotifier ?? internalLat;
    final viewLng = viewLngNotifier ?? internalLng;
    final useInternalGestures = viewLatNotifier == null;

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

    // Auto-center to show both points
    final autoStartLat = useRef(0.0);
    final autoStartLng = useRef(0.0);
    final autoTargetLat = useRef(0.0);
    final autoTargetLng = useRef(0.0);

    useEffect(() {
      if (isConnected || isConnecting) {
        final u = _getLatLng(userCountryCode);
        final v = _getLatLng(vpnCountryCode);
        double tLat, tLng;
        if (u != null && v != null) {
          tLat = _deg2rad((u.$1 + v.$1) / 2);
          tLng = _deg2rad((u.$2 + v.$2) / 2);
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
    }, [isConnected, isConnecting, userCountryCode, vpnCountryCode]);

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final r = min(w, h) / 2 * 0.85;

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
                isConnected: isConnected,
                isConnecting: isConnecting && !isConnected,
                pulseValue: pulseCtrl.value,
                arcProgress: arcCtrl.value,
                connectingPulse: connectingCtrl.value,
                particleProgress: particleCtrl.value,
                isDark: isDark,
              ),
            );
          },
        );

        // If using internal gestures (speed test page), wrap in GestureDetector
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
// Globe CustomPainter
// ══════════════════════════════════════════════════════════════════════════════

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

  final double viewLat, viewLng, radius;
  final (double, double)? userLatLng, vpnLatLng;
  final bool isConnected, isConnecting, isDark;
  final double pulseValue, arcProgress, connectingPulse, particleProgress;

  static const _userDotColor = Color(0xFF1A4A9B);
  static const _vpnDotColor = Color(0xFF30D158);
  static const _connectingColor = Color(0xFFB9A847);

  // ────────────────────────────────────────────────────────────────
  // Improved continent outlines with more points for accuracy
  // ────────────────────────────────────────────────────────────────
  static const _continents = <List<(double, double)>>[
    // ── Africa ──
    [(35.8, -5.9), (36.4, -2.8), (37.1, -1.0), (36.8, 3.3), (37.3, 9.8), (36.9, 11.1),
     (34.0, 11.5), (33.0, 12.0), (32.5, 15.0), (31.8, 24.8), (31.5, 32.0), (29.0, 33.2),
     (27.2, 34.0), (23.5, 35.5), (18.0, 38.5), (14.0, 42.5), (12.0, 43.5), (11.5, 49.5),
     (5.0, 48.0), (2.0, 45.5), (-1.0, 41.7), (-4.0, 40.3), (-8.0, 39.6), (-11.0, 40.4),
     (-15.0, 40.5), (-20.0, 35.2), (-25.5, 35.0), (-30.0, 31.0), (-33.9, 25.6),
     (-34.8, 20.0), (-34.2, 18.3), (-31.0, 17.0), (-29.0, 16.5), (-23.0, 14.5),
     (-17.0, 12.3), (-12.5, 13.7), (-8.5, 13.0), (-5.0, 12.0), (0.0, 10.0),
     (4.3, 8.5), (4.7, 5.5), (5.0, 2.7), (6.3, 1.3), (6.0, -2.5), (5.0, -4.0),
     (4.5, -7.5), (5.0, -9.5), (7.5, -12.5), (8.5, -13.3), (10.0, -15.0),
     (12.0, -16.7), (13.5, -16.5), (15.5, -16.5), (20.0, -17.0), (21.5, -17.1),
     (24.0, -16.0), (27.5, -13.2), (30.0, -9.8), (32.0, -9.0), (33.5, -7.5),
     (35.2, -6.0), (35.8, -5.9)],

    // ── Europe (mainland) ──
    [(36.0, -5.6), (36.7, -6.4), (37.0, -8.0), (38.7, -9.5), (40.0, -8.9), (43.2, -9.3),
     (43.5, -8.2), (43.3, -3.0), (43.4, -1.8), (46.0, -1.2), (47.3, -2.5), (48.5, -4.8),
     (48.8, -3.0), (49.0, -1.2), (49.4, 0.0), (50.0, 1.6), (51.0, 2.5), (53.5, 5.3),
     (54.5, 6.5), (54.8, 8.3), (56.0, 8.1), (57.1, 8.6), (58.1, 7.0), (59.0, 5.3),
     (61.0, 5.0), (62.5, 6.0), (64.0, 12.0), (67.5, 15.0), (69.0, 16.0), (70.0, 20.0),
     (71.0, 25.8), (70.1, 28.0), (69.0, 29.0), (67.0, 29.0), (65.0, 29.5), (63.0, 30.0),
     (61.0, 29.0), (60.0, 28.5), (60.0, 30.0), (59.5, 31.0), (58.0, 34.0), (56.0, 38.0),
     (54.0, 40.0), (52.0, 41.0), (50.0, 40.0), (48.0, 38.5), (47.0, 38.5),
     (45.5, 37.0), (44.0, 40.0), (42.0, 41.5), (41.5, 32.0), (41.2, 29.0),
     (40.0, 26.0), (38.5, 24.0), (37.8, 23.7), (36.5, 23.0), (36.5, 28.0),
     (36.0, 28.0), (35.5, 24.5), (36.5, 22.5), (38.0, 21.5), (39.5, 20.0),
     (40.5, 19.5), (42.0, 18.5), (44.0, 15.5), (45.5, 13.7), (44.0, 12.5),
     (43.5, 10.2), (44.2, 8.5), (43.8, 7.5), (43.0, 5.5), (43.0, 3.3),
     (42.3, 3.2), (41.5, 2.0), (40.5, 0.5), (38.0, -0.5), (37.5, -1.5),
     (36.7, -2.3), (36.0, -5.6)],

    // ── Great Britain ──
    [(50.0, -5.5), (50.8, -1.0), (51.5, 1.3), (52.5, 1.7), (53.0, 0.0),
     (53.5, -0.5), (54.5, -1.2), (55.0, -1.6), (56.0, -3.0), (57.5, -5.5),
     (58.5, -5.0), (58.6, -3.0), (57.5, -2.0), (57.0, -2.0), (56.5, -3.0),
     (55.8, -5.4), (55.0, -4.8), (54.0, -5.0), (53.2, -4.5), (52.5, -4.0),
     (51.5, -5.0), (50.0, -5.5)],

    // ── Asia (mainland) ──
    [(42.0, 41.5), (44.0, 40.0), (45.5, 37.0), (47.0, 38.5), (48.0, 38.5),
     (50.0, 40.0), (52.0, 41.0), (54.0, 40.0), (56.0, 38.0), (58.0, 34.0),
     (59.5, 31.0), (60.0, 30.0), (60.0, 28.5), (61.0, 29.0), (63.0, 30.0),
     (65.0, 29.5), (67.0, 29.0), (69.0, 29.0), (70.0, 35.0), (70.0, 45.0),
     (69.0, 55.0), (68.0, 65.0), (68.5, 75.0), (71.0, 85.0), (73.0, 95.0),
     (73.5, 105.0), (72.0, 115.0), (71.5, 128.0), (71.0, 135.0), (68.0, 140.0),
     (67.0, 153.0), (64.5, 163.0), (62.0, 170.0), (61.0, 165.0), (59.5, 163.0),
     (56.0, 155.0), (54.5, 143.0), (53.0, 142.0), (51.0, 140.5), (49.0, 138.0),
     (48.5, 135.0), (46.5, 135.0), (44.0, 132.0), (43.0, 131.5), (42.5, 130.5),
     (40.0, 124.5), (38.5, 121.5), (35.5, 119.5), (30.5, 122.0), (28.0, 121.5),
     (25.0, 119.5), (23.0, 117.0), (22.0, 113.5), (21.5, 110.5), (21.5, 108.0),
     (18.5, 106.0), (16.0, 108.5), (12.0, 109.3), (8.5, 104.5), (1.0, 104.5),
     (1.3, 103.5), (4.0, 101.0), (6.0, 100.0), (7.0, 98.5), (10.0, 98.0),
     (14.0, 98.0), (16.5, 97.0), (20.0, 93.0), (22.0, 89.0), (22.0, 87.0),
     (24.0, 89.0), (26.0, 89.0), (28.0, 87.0), (28.0, 84.0), (27.0, 82.0),
     (28.5, 77.0), (24.5, 69.5), (23.5, 68.5), (24.0, 67.0), (25.0, 62.0),
     (25.5, 60.0), (22.0, 59.5), (22.5, 56.0), (23.5, 55.0), (24.5, 51.5),
     (26.5, 50.5), (27.0, 49.5), (29.5, 48.5), (30.5, 47.5), (31.0, 47.0),
     (33.0, 44.5), (36.0, 43.0), (37.5, 42.5), (40.0, 44.0), (42.0, 41.5)],

    // ── Japan ──
    [(31.0, 131.0), (33.0, 131.5), (33.5, 133.0), (34.3, 135.0), (35.0, 136.5),
     (35.5, 137.0), (36.5, 137.5), (37.0, 138.0), (38.5, 139.5), (39.5, 140.0),
     (40.0, 140.0), (41.0, 140.5), (41.5, 141.0), (43.0, 145.0), (44.0, 145.5),
     (45.5, 142.0), (43.5, 141.5), (42.0, 141.0), (41.0, 139.5), (39.5, 138.5),
     (37.0, 136.5), (35.5, 135.5), (34.5, 134.0), (33.0, 130.5), (31.0, 131.0)],

    // ── North America ──
    [(68.0, -168.0), (71.0, -157.0), (71.5, -140.0), (70.0, -130.0), (69.5, -120.0),
     (72.0, -115.0), (72.0, -100.0), (70.0, -92.0), (68.0, -87.0), (65.0, -85.0),
     (63.0, -82.0), (60.0, -78.0), (58.0, -77.0), (56.0, -80.0), (52.0, -80.0),
     (50.0, -85.0), (48.5, -89.0), (47.0, -88.0), (46.0, -84.5), (44.5, -82.5),
     (43.0, -82.5), (42.0, -83.0), (41.5, -82.5), (42.5, -79.0), (43.5, -76.5),
     (44.5, -75.5), (44.0, -72.0), (43.0, -70.5), (42.0, -70.0), (41.0, -72.0),
     (40.5, -74.0), (38.5, -75.0), (37.0, -76.0), (35.0, -75.5), (33.5, -78.0),
     (32.0, -80.5), (30.5, -81.5), (29.0, -81.0), (27.5, -80.5), (25.5, -80.0),
     (25.0, -80.5), (24.5, -81.8), (25.5, -81.5), (26.5, -82.0), (28.5, -83.0),
     (29.0, -84.5), (29.5, -85.5), (30.0, -86.0), (30.0, -88.5), (29.0, -89.5),
     (29.5, -91.0), (29.0, -93.5), (27.8, -97.0), (25.8, -97.2),
     (22.5, -98.0), (20.0, -97.0), (19.0, -96.0), (18.5, -95.0), (18.0, -93.0),
     (18.5, -91.0), (20.5, -87.0), (21.5, -87.5), (21.0, -90.0), (19.5, -90.5),
     (18.0, -89.0), (16.5, -88.5), (15.5, -84.0), (14.0, -83.5), (13.0, -84.0),
     (11.0, -83.5), (10.0, -84.0), (9.0, -84.0), (8.5, -82.5), (8.0, -77.5),
     (7.0, -77.8), (8.0, -77.0), (9.5, -76.0), (10.5, -75.5), (11.0, -74.5),
     (12.0, -72.0), (12.0, -70.0), (11.0, -65.0), (10.5, -61.0),
     (18.0, -63.0), (18.5, -66.0), (20.0, -73.0), (23.0, -76.0),
     (25.0, -77.5), (26.0, -79.0), (30.5, -81.0), (32.0, -80.0),
     (38.5, -75.5), (40.5, -74.0), (42.0, -70.0), (43.5, -66.0), (45.0, -62.0),
     (46.5, -61.0), (47.0, -65.0), (49.0, -67.0), (47.5, -69.0), (47.0, -70.5),
     (49.0, -66.5), (49.5, -64.0), (47.8, -62.0), (46.0, -60.0), (45.5, -61.5),
     (44.5, -63.5), (44.0, -66.0), (50.0, -57.0), (51.5, -55.5), (53.5, -56.0),
     (57.0, -62.0), (60.5, -64.5), (64.0, -68.0), (66.0, -62.0), (70.0, -55.0),
     (73.0, -58.0), (75.0, -65.0), (78.0, -72.0), (80.0, -85.0), (77.0, -95.0),
     (75.0, -95.0), (73.0, -95.0), (70.0, -100.0), (68.0, -107.0), (70.0, -115.0),
     (72.0, -125.0), (71.0, -137.0), (69.5, -140.5), (68.5, -149.0), (66.0, -164.0),
     (68.0, -168.0)],

    // ── South America ──
    [(12.0, -72.0), (11.0, -74.5), (10.5, -75.5), (9.0, -77.0), (7.0, -77.8),
     (3.0, -78.0), (1.0, -80.0), (-1.0, -80.0), (-3.5, -80.5), (-5.0, -81.0),
     (-6.5, -81.0), (-10.0, -78.0), (-15.0, -75.5), (-17.0, -72.5), (-18.0, -70.0),
     (-22.0, -70.0), (-23.5, -70.5), (-27.0, -70.5), (-30.0, -71.5), (-33.0, -72.0),
     (-38.0, -73.5), (-41.0, -73.5), (-43.5, -73.5), (-46.0, -75.5), (-48.0, -75.5),
     (-52.0, -72.0), (-53.0, -70.5), (-54.0, -69.0), (-55.0, -67.0), (-55.5, -65.5),
     (-54.5, -64.0), (-52.0, -68.5), (-50.0, -66.0), (-45.0, -65.5), (-42.0, -63.0),
     (-38.5, -58.5), (-37.0, -56.5), (-35.0, -54.5), (-33.0, -53.0), (-28.0, -48.5),
     (-23.0, -43.0), (-20.0, -40.0), (-15.0, -39.0), (-12.5, -38.0), (-9.0, -35.0),
     (-5.5, -35.0), (-2.5, -42.0), (-1.5, -48.5), (0.0, -50.0), (2.0, -53.0),
     (5.0, -58.0), (6.5, -60.0), (8.0, -62.0), (10.5, -61.0), (11.0, -65.0),
     (12.0, -70.0), (12.0, -72.0)],

    // ── Australia ──
    [(-12.5, 130.5), (-12.5, 132.0), (-14.5, 135.5), (-14.0, 137.5), (-12.0, 136.0),
     (-11.0, 132.0), (-12.0, 130.0), (-14.5, 127.0), (-16.0, 124.0),
     (-18.0, 122.0), (-20.0, 119.0), (-22.0, 114.0), (-25.0, 113.5),
     (-28.0, 114.0), (-31.0, 115.0), (-34.0, 115.5), (-35.0, 117.5), (-35.0, 118.5),
     (-34.5, 120.0), (-33.5, 124.0), (-33.0, 130.0), (-34.0, 136.0), (-35.5, 137.5),
     (-36.0, 138.5), (-37.0, 140.0), (-38.0, 142.0), (-38.5, 146.0), (-37.5, 149.5),
     (-34.0, 151.5), (-30.0, 153.0), (-27.0, 153.5), (-24.5, 152.0), (-22.0, 150.0),
     (-19.5, 147.5), (-17.0, 146.0), (-16.0, 145.5), (-14.5, 144.0), (-13.0, 143.5),
     (-12.5, 141.5), (-12.5, 140.0), (-11.0, 137.0), (-12.5, 136.0),
     (-14.0, 137.0), (-14.5, 135.5), (-12.5, 132.0), (-12.5, 130.5)],

    // ── India (subcontinent) ──
    [(28.5, 77.0), (27.0, 75.0), (24.5, 69.0), (23.5, 68.5), (21.0, 72.5),
     (19.0, 73.0), (15.5, 74.0), (12.0, 75.0), (8.0, 77.0), (8.5, 80.0),
     (10.0, 80.0), (13.0, 80.5), (15.5, 80.0), (17.5, 83.5), (19.5, 85.0),
     (21.5, 87.0), (22.0, 89.0), (24.0, 89.0), (26.0, 89.0), (28.0, 87.0),
     (28.5, 84.0), (27.0, 82.0), (28.5, 77.0)],

    // ── Madagascar ──
    [(-12.0, 49.3), (-15.5, 50.5), (-19.0, 49.0), (-22.0, 47.5),
     (-24.0, 47.0), (-25.5, 45.5), (-24.0, 44.0), (-21.5, 43.5),
     (-18.0, 44.0), (-15.5, 47.0), (-12.5, 49.0), (-12.0, 49.3)],

    // ── New Zealand (both islands) ──
    [(-34.5, 173.0), (-36.5, 175.0), (-38.0, 178.0), (-39.0, 178.0),
     (-41.0, 176.5), (-41.5, 175.0), (-40.5, 173.0), (-39.0, 174.0),
     (-38.0, 175.5), (-36.0, 174.5), (-34.5, 173.0)],
    [(-41.5, 172.0), (-42.5, 171.0), (-44.0, 169.0), (-46.0, 167.0),
     (-47.0, 168.5), (-46.5, 170.0), (-44.5, 171.5), (-43.0, 172.5),
     (-41.5, 174.5), (-41.5, 172.0)],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);

    // Clip to globe
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));

    _drawGlobeSurface(canvas, center);
    _drawGridLines(canvas, center);
    _drawContinents(canvas, center);
    _drawCityDots(canvas, center);

    canvas.restore();

    _drawAtmosphere(canvas, center);

    // Arc
    if ((isConnected || isConnecting) && userLatLng != null && vpnLatLng != null && arcProgress > 0) {
      _drawGreatCircleArc(canvas, center);
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

  void _drawGlobeSurface(Canvas canvas, Offset center) {
    canvas.drawCircle(center, radius, Paint()
      ..shader = ui.Gradient.radial(center, radius,
        [isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.withValues(alpha: 0.08),
         isDark ? Colors.white.withValues(alpha: 0.015) : Colors.grey.withValues(alpha: 0.02)],
        [0.0, 1.0]));
  }

  void _drawAtmosphere(Canvas canvas, Offset center) {
    canvas.drawCircle(center, radius * 1.12, Paint()
      ..shader = ui.Gradient.radial(center, radius * 1.12,
        [Colors.transparent, const Color(0xFF4A8FE7).withValues(alpha: 0.0),
         const Color(0xFF4A8FE7).withValues(alpha: 0.06),
         const Color(0xFF4A8FE7).withValues(alpha: 0.02), Colors.transparent],
        [0.0, 0.85, 0.93, 1.0, 1.0]));
    canvas.drawCircle(center, radius, Paint()
      ..color = const Color(0xFF4A8FE7).withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0);
  }

  void _drawGridLines(Canvas canvas, Offset center) {
    final cx = center.dx;
    final cy = center.dy;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: isDark ? 0.04 : 0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (double lngDeg = -180; lngDeg < 180; lngDeg += 30) {
      final path = Path();
      var started = false;
      for (double latDeg = -90; latDeg <= 90; latDeg += 3) {
        final p = _project(latDeg, lngDeg);
        if (p != null) {
          if (!started) { path.moveTo(cx + p.$1, cy + p.$2); started = true; }
          else { path.lineTo(cx + p.$1, cy + p.$2); }
        } else { started = false; }
      }
      canvas.drawPath(path, paint);
    }
    for (double latDeg = -60; latDeg <= 60; latDeg += 30) {
      final path = Path();
      var started = false;
      for (double lngDeg = -180; lngDeg <= 180; lngDeg += 3) {
        final p = _project(latDeg, lngDeg);
        if (p != null) {
          if (!started) { path.moveTo(cx + p.$1, cy + p.$2); started = true; }
          else { path.lineTo(cx + p.$1, cy + p.$2); }
        } else { started = false; }
      }
      canvas.drawPath(path, paint);
    }
  }

  void _drawContinents(Canvas canvas, Offset center) {
    final cx = center.dx;
    final cy = center.dy;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: isDark ? 0.22 : 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeJoin = StrokeJoin.round;

    for (final outline in _continents) {
      final path = Path();
      var started = false;
      for (final pt in outline) {
        final p = _project(pt.$1, pt.$2);
        if (p != null) {
          if (!started) { path.moveTo(cx + p.$1, cy + p.$2); started = true; }
          else { path.lineTo(cx + p.$1, cy + p.$2); }
        } else { started = false; }
      }
      canvas.drawPath(path, paint);
    }
  }

  void _drawCityDots(Canvas canvas, Offset center) {
    final cx = center.dx;
    final cy = center.dy;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: isDark ? 0.15 : 0.10)
      ..style = PaintingStyle.fill;

    for (final city in _majorCities) {
      final p = _project(city.$1, city.$2);
      if (p != null) {
        canvas.drawCircle(Offset(cx + p.$1, cy + p.$2), 1.5, paint);
      }
    }
  }

  void _drawUserDot(Canvas canvas, Offset c) {
    canvas.drawCircle(c, 12, Paint()..color = _userDotColor.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawCircle(c, 8, Paint()..color = _userDotColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke..strokeWidth = 1.5);
    canvas.drawCircle(c, 4, Paint()..color = _userDotColor);
    canvas.drawCircle(c, 1.5, Paint()..color = Colors.white.withValues(alpha: 0.9));
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

  void _drawGreatCircleArc(Canvas canvas, Offset center) {
    if (userLatLng == null || vpnLatLng == null) return;
    final cx = center.dx;
    final cy = center.dy;

    final lat1 = _deg2rad(userLatLng!.$1), lng1 = _deg2rad(userLatLng!.$2);
    final lat2 = _deg2rad(vpnLatLng!.$1), lng2 = _deg2rad(vpnLatLng!.$2);

    final x1 = cos(lat1) * cos(lng1), y1 = cos(lat1) * sin(lng1), z1 = sin(lat1);
    final x2 = cos(lat2) * cos(lng2), y2 = cos(lat2) * sin(lng2), z2 = sin(lat2);

    final dot = (x1 * x2 + y1 * y2 + z1 * z2).clamp(-1.0, 1.0);
    final omega = acos(dot);

    const segments = 64;
    final points = <Offset>[];
    final visible = <bool>[];

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
        visible.add(true);
      } else {
        points.add(Offset.zero);
        visible.add(false);
      }
    }

    final total = (arcProgress * segments).round();
    final arcPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 2.0..strokeCap = StrokeCap.round;
    final glowPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 6.0..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    for (int i = 0; i < total; i++) {
      if (!visible[i] || !visible[i + 1]) continue;
      final t = i / segments;
      final c = Color.lerp(_userDotColor.withValues(alpha: 0.6), _vpnDotColor.withValues(alpha: 0.6), t)!;
      arcPaint.color = c;
      canvas.drawLine(points[i], points[i + 1], arcPaint);
      glowPaint.color = c.withValues(alpha: 0.1);
      canvas.drawLine(points[i], points[i + 1], glowPaint);
    }

    if (arcProgress >= 1.0) {
      for (int p = 0; p < 3; p++) {
        final off = (particleProgress + p / 3.0) % 1.0;
        final idx = (off * segments).round().clamp(0, segments);
        if (idx < points.length && visible[idx]) {
          canvas.drawCircle(points[idx], 4, Paint()..color = _vpnDotColor.withValues(alpha: 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
          canvas.drawCircle(points[idx], 2, Paint()..color = Colors.white.withValues(alpha: 0.9));
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
      o.userLatLng != userLatLng || o.vpnLatLng != vpnLatLng;
}
