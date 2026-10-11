import 'dart:convert';

import 'models.dart';

class M3uPlaylist {
  const M3uPlaylist(this.categories, this.channels);
  final List<Category> categories;
  final List<Channel> channels;
}

/// Parses extended M3U / M3U8 playlists (#EXTINF entries).
class M3uParser {
  static final _attr = RegExp(r'([\w-]+)="([^"]*)"');

  static M3uPlaylist parse(String source) {
    final channels = <Channel>[];
    final groups = <String>[];
    Map<String, String>? attrs;
    String? title;

    for (final raw in const LineSplitter().convert(source)) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF')) {
        attrs = {
          for (final m in _attr.allMatches(line))
            m.group(1)!.toLowerCase(): m.group(2)!,
        };
        // The title follows the first comma after the last quoted attribute.
        final lastQuote = line.lastIndexOf('"');
        final comma = line.indexOf(',', lastQuote < 0 ? 0 : lastQuote);
        title = comma >= 0 ? line.substring(comma + 1).trim() : null;
      } else if (!line.startsWith('#')) {
        final a = attrs;
        if (a == null) continue;
        final group = (a['group-title'] ?? '').trim();
        final category = group.isEmpty ? 'Uncategorized' : group;
        if (!groups.contains(category)) groups.add(category);

        final fallback = a['tvg-name'] ?? 'Channel ${channels.length + 1}';
        final name = (title != null && title.isNotEmpty) ? title : fallback;
        final logo = (a['tvg-logo'] ?? '').trim();
        final epg = (a['tvg-id'] ?? '').trim();

        channels.add(Channel(
          id: '${channels.length}',
          name: name,
          categoryId: category,
          url: line,
          logo: logo.isEmpty ? null : logo,
          epgId: epg.isEmpty ? null : epg,
        ));
        attrs = null;
        title = null;
      }
    }

    return M3uPlaylist(
      [for (final g in groups) Category(id: g, name: g)],
      channels,
    );
  }
}
