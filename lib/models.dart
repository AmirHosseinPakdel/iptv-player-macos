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
