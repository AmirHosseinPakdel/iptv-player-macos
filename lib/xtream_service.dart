import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Minimal client for the Xtream Codes `player_api.php` API (live TV only).
class XtreamService {
  XtreamService(this.account, {http.Client? client})
      : _client = client ?? http.Client();

  final Account account;
  final http.Client _client;

  String get _base {
    var s = account.server.trim();
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'http://$s';
    }
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  Uri _api([String? action]) => Uri.parse('$_base/player_api.php').replace(
        queryParameters: {
          'username': account.username,
          'password': account.password,
          if (action != null) 'action': action,
        },
      );

  Future<dynamic> _getJson(Uri uri) async {
    final http.Response res;
    try {
      res = await _client.get(uri).timeout(const Duration(seconds: 25));
    } catch (_) {
      throw IptvException('errUnreachable');
    }
    if (res.statusCode != 200) {
      throw IptvException('errHttp', code: res.statusCode);
    }
    try {
      return jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      throw IptvException('errUnexpected');
    }
  }

  Future<void> authenticate() async {
    final data = await _getJson(_api());
    final info = data is Map ? data['user_info'] : null;
    if (info is! Map || info['auth'].toString() != '1') {
      throw IptvException('errLogin');
    }
  }

  Future<List<Category>> liveCategories() async {
    final data = await _getJson(_api('get_live_categories'));
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((m) => Category(
              id: m['category_id'].toString(),
              name: (m['category_name'] ?? 'Unnamed').toString(),
            ))
        .toList();
  }

  Future<List<Channel>> liveChannels() async {
    final data = await _getJson(_api('get_live_streams'));
    if (data is! List) return [];
    return data.whereType<Map>().map((m) {
      final id = m['stream_id'].toString();
      return Channel(
        id: id,
        name: (m['name'] ?? 'Channel $id').toString().trim(),
        categoryId: (m['category_id'] ?? '').toString(),
        logo: _nonEmpty(m['stream_icon']),
        epgId: _nonEmpty(m['epg_channel_id']),
        url: streamUrl(id),
      );
    }).toList();
  }

  String streamUrl(String streamId) =>
      '$_base/live/${account.username}/${account.password}/$streamId.m3u8';

  static String? _nonEmpty(Object? v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }
}
