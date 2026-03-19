import 'dart:io';

import 'package:hiddify/features/proxy/model/ip_info_entity.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'real_ip_notifier.g.dart';

/// Fetches the user's REAL IP address (before VPN) using direct HTTP connections.
/// This bypasses any proxy/VPN by using HttpClient with no proxy setting.
@riverpod
class RealIpNotifier extends _$RealIpNotifier {
  static const _apis = [
    'https://ipapi.co/json/',
    'https://api.ip.sb/geoip',
    'https://ipwho.is/',
  ];

  @override
  Future<IpInfo?> build() {
    return _fetchRealIp();
  }

  Future<IpInfo?> _fetchRealIp() async {
    for (final url in _apis) {
      try {
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 8)
          ..findProxy = (uri) => 'DIRECT'; // bypass any system proxy

        final request = await client.getUrl(Uri.parse(url));
        request.headers.set('User-Agent', 'Mozilla/5.0');
        request.headers.set('Accept', 'application/json');
        final response = await request.close().timeout(const Duration(seconds: 8));

        if (response.statusCode != 200) {
          client.close();
          continue;
        }

        final body = await response.transform(const SystemEncoding().decoder).join();
        client.close();

        // Simple JSON parsing without external deps
        final ip = _extractField(body, ['ip', '"ip"']);
        final countryCode = _extractField(body, ['country_code', '"country_code"', 'country', '"country"']);
        final city = _extractField(body, ['city', '"city"']);
        final org = _extractField(body, ['org', '"org"', 'asn_organization', '"asn_organization"']);
        final timezone = _extractField(body, ['timezone', '"timezone"']);

        if (ip != null && ip.isNotEmpty && countryCode != null && countryCode.isNotEmpty) {
          return IpInfo(
            ip: ip,
            countryCode: countryCode,
            city: city,
            org: org,
            timezone: timezone,
          );
        }
      } catch (_) {
        // try next API
      }
    }
    return null;
  }

  /// Very simple field extractor for JSON — avoids importing another package.
  String? _extractField(String body, List<String> fieldNames) {
    for (final name in fieldNames) {
      final cleanName = name.replaceAll('"', '');
      // try "key":"value" and "key": "value"
      final patterns = [
        RegExp('"$cleanName"\\s*:\\s*"([^"]+)"'),
        RegExp('"$cleanName"\\s*:\\s*([^,}\\s]+)'),
      ];
      for (final pattern in patterns) {
        final match = pattern.firstMatch(body);
        if (match != null && match.group(1) != null) {
          return match.group(1)!.trim().replaceAll('"', '');
        }
      }
    }
    return null;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchRealIp);
  }
}
