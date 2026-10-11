import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_app/m3u_parser.dart';

void main() {
  const sample = '''
#EXTM3U
#EXTINF:-1 tvg-id="news.de" tvg-logo="http://x/logo.png" group-title="News, DE",Tagesschau 24
http://example.com/live/1.m3u8
#EXTINF:-1 group-title="Sports",Sport One
http://example.com/live/2.ts
#EXTINF:-1,No Group
http://example.com/live/3.m3u8
''';

  test('parses channels, groups and attributes', () {
    final list = M3uParser.parse(sample);
    expect(list.channels.length, 3);
    expect(list.channels[0].name, 'Tagesschau 24');
    expect(list.channels[0].logo, 'http://x/logo.png');
    expect(list.channels[0].epgId, 'news.de');
    expect(list.channels[0].categoryId, 'News, DE');
    expect(list.channels[2].categoryId, 'Uncategorized');
    expect(list.categories.map((c) => c.name),
        ['News, DE', 'Sports', 'Uncategorized']);
  });

  test('ignores URLs without an EXTINF line', () {
    final list = M3uParser.parse('#EXTM3U\nhttp://example.com/a.m3u8\n');
    expect(list.channels, isEmpty);
  });
}
