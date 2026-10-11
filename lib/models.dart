enum AccountKind { xtream, m3u }

class Account {
  const Account({
    required this.name,
    required this.kind,
    required this.server,
    this.username = '',
    this.password = '',
  });

  final String name;
  final AccountKind kind;

  /// Xtream: the server address. M3U: the playlist URL.
  final String server;
  final String username;
  final String password;

  String get id => '${kind.name}|$server|$username';

  Map<String, dynamic> toJson() => {
        'name': name,
        'kind': kind.name,
        'server': server,
        'username': username,
        'password': password,
      };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        name: json['name'] as String? ?? 'Account',
        kind: AccountKind.values.firstWhere(
          (k) => k.name == json['kind'],
          orElse: () => AccountKind.xtream,
        ),
        server: json['server'] as String? ?? '',
        username: json['username'] as String? ?? '',
        password: json['password'] as String? ?? '',
      );
}

class Category {
  const Category({required this.id, required this.name});
  final String id;
  final String name;
}

class Channel {
  const Channel({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.url,
    this.logo,
    this.epgId,
  });

  final String id;
  final String name;
  final String categoryId;
  final String url;
  final String? logo;
  final String? epgId;
}

/// An error with a localizable [key] (see L10n.error) and an optional HTTP [code].
class IptvException implements Exception {
  IptvException(this.key, {this.code});
  final String key;
  final int? code;

  @override
  String toString() => key;
}

/// One programme in the guide.
class EpgEntry {
  const EpgEntry({
    required this.title,
    required this.description,
    required this.start,
    required this.end,
  });

  final String title;
  final String description;
  final DateTime start;
  final DateTime end;

  bool isOn(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  /// 0.0 to 1.0 for how far into the programme [t] is.
  double progress(DateTime t) {
    final total = end.difference(start).inSeconds;
    if (total <= 0) return 0;
    return (t.difference(start).inSeconds / total).clamp(0.0, 1.0).toDouble();
  }
}

/// A movie (VOD) entry from an Xtream server.
class VodItem {
  const VodItem({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.ext,
    this.poster,
    this.rating,
  });

  final String id;
  final String name;
  final String categoryId;
  final String ext; // container extension, e.g. mkv or mp4
  final String? poster;
  final double? rating;
}

/// Extra movie details, loaded when a movie is opened.
class VodDetail {
  const VodDetail({
    this.plot = '',
    this.genre = '',
    this.duration = '',
    this.cast = '',
    this.year = '',
  });

  final String plot;
  final String genre;
  final String duration;
  final String cast;
  final String year;
}

/// A series entry from an Xtream server.
class SeriesItem {
  const SeriesItem({
    required this.id,
    required this.name,
    required this.categoryId,
    this.cover,
    this.rating,
    this.plot = '',
    this.year = '',
  });

  final String id;
  final String name;
  final String categoryId;
  final String? cover;
  final double? rating;
  final String plot;
  final String year;
}

class Episode {
  const Episode({
    required this.id,
    required this.title,
    required this.season,
    required this.number,
    required this.ext,
    this.plot = '',
    this.duration = '',
  });

  final String id;
  final String title;
  final int season;
  final int number;
  final String ext;
  final String plot;
  final String duration;
}

/// Seasons (sorted) mapped to their episodes (sorted by number).
class SeriesDetail {
  const SeriesDetail({required this.plot, required this.seasons});
  final String plot;
  final Map<int, List<Episode>> seasons;
}
