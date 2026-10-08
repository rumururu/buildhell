import 'dart:convert';

/// 기기 변경용 저장 코드. `BH1.<base64>.<체크섬>` 형식.
class SaveCode {
  static const _prefix = 'BH1';

  static String encode(Map<String, dynamic> json) {
    final body = base64Url.encode(utf8.encode(jsonEncode(json)));
    return '$_prefix.$body.${_fnv1a(body).toRadixString(16)}';
  }

  /// 잘못된 코드면 null.
  static Map<String, dynamic>? decode(String code) {
    final parts = code.trim().split('.');
    if (parts.length != 3 || parts[0] != _prefix) return null;
    if (_fnv1a(parts[1]).toRadixString(16) != parts[2]) return null;
    try {
      final decoded = jsonDecode(utf8.decode(base64Url.decode(parts[1])));
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static int _fnv1a(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      // h * 0x01000193 mod 2^32. 웹(JS)에서도 2^53을 넘지 않도록 나눠서 곱한다.
      h = (h * 0x193 + ((h * 0x100) % 0x10000) * 0x10000) % 0x100000000;
    }
    return h;
  }
}
