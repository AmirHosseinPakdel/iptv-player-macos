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
    server: 'example.com:8080',
    username: 'u',
    password: 'p',
  );

  test('shortEpg decodes base64 titles and unix timestamps', () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters['action'], 'get_short_epg');
      expect(request.url.queryParameters['stream_id'], '42');
      return http.Response(
        jsonEncode({
          'epg_listings': [
            {
              'title': base64Encode(utf8.encode('Evening News')),
              'description': base64Encode(utf8.encode('Daily headlines')),
              'start_timestamp': '1700003600',
              'stop_timestamp': '1700007200',
            },
            {
              'title': base64Encode(utf8.encode('Morning Show')),
              'description': '',
              'start_timestamp': '1700000000',
              'stop_timestamp': '1700003600',
            },
          ],
        }),
        200,
      );
    });

    final list = await XtreamService(account, client: client).shortEpg('42');

    expect(list.length, 2);
    expect(list.first.title, 'Morning Show'); // sorted by start time
    expect(list.last.title, 'Evening News');
    expect(list.last.description, 'Daily headlines');
    expect(list.last.end.difference(list.last.start), const Duration(hours: 1));
  });

  test('EpgEntry progress and isOn', () {
    final start = DateTime(2026, 1, 1, 20);
    final e = EpgEntry(
      title: 'Show',
      description: '',
      start: start,
      end: start.add(const Duration(hours: 2)),
    );
    expect(e.isOn(start.add(const Duration(minutes: 30))), isTrue);
    expect(e.isOn(start.add(const Duration(hours: 3))), isFalse);
    expect(e.progress(start.add(const Duration(hours: 1))), closeTo(0.5, 0.001));
    expect(e.progress(start.subtract(const Duration(hours: 1))), 0);
  });
}
