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

  Uri _api([String? action, Map<String, String> extra = const {}]) =>
      Uri.parse('$_base/player_api.php').replace(
        queryParameters: {
          'username': account.username,
          'password': account.password,
          if (action != null) 'action': action,
          ...extra,
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

  /// Upcoming programmes for one live channel (title and description arrive
  /// base64-encoded from Xtream servers).
  Future<List<EpgEntry>> shortEpg(String streamId, {int limit = 6}) async {
    final data = await _getJson(
        _api('get_short_epg', {'stream_id': streamId, 'limit': '$limit'}));
    final list = data is Map ? data['epg_listings'] : null;
    if (list is! List) return const [];
    final entries = <EpgEntry>[];
    for (final m in list.whereType<Map>()) {
      final start = _time(m['start_timestamp']);
      final end = _time(m['stop_timestamp'] ?? m['end_timestamp']);
      if (start == null || end == null) continue;
      entries.add(EpgEntry(
        title: _decode(m['title']),
        description: _decode(m['description']),
        start: start,
        end: end,
      ));
    }
    entries.sort((a, b) => a.start.compareTo(b.start));
    return entries;
  }

  static DateTime? _time(Object? v) {
    final seconds = int.tryParse(v?.toString() ?? '');
    return seconds == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }

  static String _decode(Object? v) {
    final s = v?.toString() ?? '';
    if (s.isEmpty) return '';
    try {
      return utf8.decode(base64Decode(s), allowMalformed: true).trim();
    } catch (_) {
      return s; // not base64: use as is
    }
  }

  String streamUrl(String streamId) =>
      '$_base/live/${account.username}/${account.password}/$streamId.m3u8';

  // ---- movies (VOD) ---------------------------------------------------

  Future<List<Category>> vodCategories() => _categories('get_vod_categories');

  Future<List<VodItem>> vodStreams() async {
    final data = await _getJson(_api('get_vod_streams'));
    if (data is! List) return [];
    return data.whereType<Map>().map((m) {
      final id = m['stream_id'].toString();
      return VodItem(
        id: id,
        name: (m['name'] ?? 'Movie $id').toString().trim(),
        categoryId: (m['category_id'] ?? '').toString(),
        ext: _nonEmpty(m['container_extension']) ?? 'mp4',
        poster: _nonEmpty(m['stream_icon']),
        rating: double.tryParse((m['rating'] ?? '').toString()),
      );
    }).toList();
  }

  Future<VodDetail> vodInfo(String vodId) async {
    final data = await _getJson(_api('get_vod_info', {'vod_id': vodId}));
    final info = data is Map ? data['info'] : null;
    if (info is! Map) return const VodDetail();
    String s(String k) => (info[k] ?? '').toString().trim();
    final release = s('releasedate').isNotEmpty ? s('releasedate') : s('year');
    return VodDetail(
      plot: s('plot').isNotEmpty ? s('plot') : s('description'),
      genre: s('genre'),
      duration: s('duration'),
      cast: s('cast').isNotEmpty ? s('cast') : s('actors'),
      year: release.length >= 4 ? release.substring(0, 4) : release,
    );
  }

  String movieUrl(VodItem m) =>
      '$_base/movie/${account.username}/${account.password}/${m.id}.${m.ext}';

  // ---- series ----------------------------------------------------------

  Future<List<Category>> seriesCategories() =>
      _categories('get_series_categories');

  Future<List<SeriesItem>> seriesList() async {
    final data = await _getJson(_api('get_series'));
    if (data is! List) return [];
    return data.whereType<Map>().map((m) {
      final id = m['series_id'].toString();
      final release = (m['releaseDate'] ?? m['release_date'] ?? '').toString();
      return SeriesItem(
        id: id,
        name: (m['name'] ?? 'Series $id').toString().trim(),
        categoryId: (m['category_id'] ?? '').toString(),
        cover: _nonEmpty(m['cover']),
        rating: double.tryParse((m['rating'] ?? '').toString()),
        plot: (m['plot'] ?? '').toString().trim(),
        year: release.length >= 4 ? release.substring(0, 4) : release,
      );
    }).toList();
  }

  Future<SeriesDetail> seriesInfo(String seriesId) async {
    final data =
        await _getJson(_api('get_series_info', {'series_id': seriesId}));
    if (data is! Map) return const SeriesDetail(plot: '', seasons: {});
    final info = data['info'];
    final plot = info is Map ? (info['plot'] ?? '').toString().trim() : '';

    // "episodes" is normally {"1": [...], "2": [...]} but can be a plain list.
    final raw = data['episodes'];
    final groups = <MapEntry<String, dynamic>>[];
    if (raw is Map) {
      groups.addAll(raw.entries.map((e) => MapEntry(e.key.toString(), e.value)));
    } else if (raw is List) {
      for (var i = 0; i < raw.length; i++) {
        groups.add(MapEntry('${i + 1}', raw[i]));
      }
    }

    final seasons = <int, List<Episode>>{};
    for (final g in groups) {
      final list = g.value;
      if (list is! List) continue;
      for (final m in list.whereType<Map>()) {
        final epInfo = m['info'] is Map ? m['info'] as Map : const {};
        final season = int.tryParse((m['season'] ?? g.key).toString()) ??
            int.tryParse(g.key) ??
            1;
        final number = int.tryParse((m['episode_num'] ?? '').toString()) ?? 0;
        seasons.putIfAbsent(season, () => []).add(Episode(
              id: m['id'].toString(),
              title: (m['title'] ?? 'Episode $number').toString().trim(),
              season: season,
              number: number,
              ext: _nonEmpty(m['container_extension']) ?? 'mp4',
              plot: (epInfo['plot'] ?? '').toString().trim(),
              duration: (epInfo['duration'] ?? '').toString().trim(),
            ));
      }
    }
    for (final eps in seasons.values) {
      eps.sort((a, b) => a.number.compareTo(b.number));
    }
    final sorted = Map.fromEntries(
        seasons.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    return SeriesDetail(plot: plot, seasons: sorted);
  }

  String episodeUrl(Episode e) =>
      '$_base/series/${account.username}/${account.password}/${e.id}.${e.ext}';

  Future<List<Category>> _categories(String action) async {
    final data = await _getJson(_api(action));
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((m) => Category(
              id: m['category_id'].toString(),
              name: (m['category_name'] ?? 'Unnamed').toString(),
            ))
        .toList();
  }

  static String? _nonEmpty(Object? v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }
}
