import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iptv_app/models.dart';
import 'package:iptv_app/xtream_service.dart';

void main() {
  const account = Account(
    name: 'Test',
    kind: AccountKind.xtream,
    server: 'example.com:8080/',
    username: 'u',
    password: 'p',
  );

  XtreamService serviceFor(Object body) => XtreamService(
        account,
        client: MockClient((_) async => http.Response(jsonEncode(body), 200)),
      );

  test('vodStreams parses movies and builds the movie URL', () async {
    final service = serviceFor([
      {
        'stream_id': 7,
        'name': ' The Movie ',
        'category_id': '3',
        'container_extension': 'mkv',
        'stream_icon': 'http://x/p.jpg',
        'rating': '7.5',
      },
      {'stream_id': 8, 'name': 'Other', 'category_id': '3'},
    ]);
    final movies = await service.vodStreams();
    expect(movies.length, 2);
    expect(movies[0].name, 'The Movie');
    expect(movies[0].rating, 7.5);
    expect(movies[1].ext, 'mp4'); // default container
    expect(service.movieUrl(movies[0]),
        'http://example.com:8080/movie/u/p/7.mkv');
  });

  test('seriesInfo groups episodes by season and sorts them', () async {
    final service = serviceFor({
      'info': {'plot': 'A show'},
      'episodes': {
        '2': [
          {
            'id': '21',
            'title': 'S2E1',
            'episode_num': 1,
            'container_extension': 'mp4'
          },
        ],
        '1': [
          {
            'id': '12',
            'title': 'S1E2',
            'episode_num': 2,
            'container_extension': 'mkv',
            'info': {'plot': 'Second', 'duration': '00:42:00'},
          },
          {'id': '11', 'title': 'S1E1', 'episode_num': 1},
        ],
      },
    });
    final detail = await service.seriesInfo('5');
    expect(detail.plot, 'A show');
    expect(detail.seasons.keys.toList(), [1, 2]);
    expect(detail.seasons[1]!.map((e) => e.title), ['S1E1', 'S1E2']);
    expect(detail.seasons[1]![1].duration, '00:42:00');
    expect(service.episodeUrl(detail.seasons[1]![1]),
        'http://example.com:8080/series/u/p/12.mkv');
  });

  test('seriesInfo tolerates a list-shaped episodes field', () async {
    final service = serviceFor({
      'episodes': [
        [
          {'id': '1', 'title': 'Pilot', 'episode_num': 1},
        ],
      ],
    });
    final detail = await service.seriesInfo('9');
    expect(detail.seasons[1]!.single.title, 'Pilot');
  });
}
