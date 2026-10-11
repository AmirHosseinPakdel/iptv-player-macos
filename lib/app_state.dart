import 'dart:async';
import 'dart:convert';
import 'dart:math' show min;

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/l10n.dart';
import 'm3u_parser.dart';
import 'models.dart';
import 'xtream_service.dart';

const kAll = '__all';
const kFavorites = '__fav';
const kRecent = '__recent';

enum LoadState { idle, loading, ready, error }

class AppState extends ChangeNotifier {
  AppState() {
    _errorSub = player.stream.error.listen(_onPlayerError);
    _completedSub = player.stream.completed.listen((done) {
      if (done) _retryPlayback();
    });
    // Playback counts as started once the position starts moving.
    _positionSub = player.stream.position.listen((pos) {
      if (_awaitingStart && pos > Duration.zero) _onStarted();
    });
    // A stream that stays in "buffering" for too long is restarted.
    _bufferingSub = player.stream.buffering.listen((buffering) {
      _stallTimer?.cancel();
      if (buffering && current != null) {
        _stallTimer = Timer(
          Duration(seconds: weakInternet ? 45 : 25),
          _retryPlayback,
        );
      }
    });
  }

  final Player player = Player();
  late final VideoController video = VideoController(player);

  SharedPreferences? _prefs;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<bool>? _bufferingSub;
  Timer? _retryTimer;
  Timer? _stallTimer;
  int _retries = 0;
  int _attempt = 0; // which stream URL variant is currently being tried
  bool _awaitingStart = false;
  bool _flip = false; // learned: this provider prefers the other stream format

  /// Bigger buffer, lower quality, patient timeouts: for slow connections.
  bool weakInternet = false;

  bool initialized = false;
  Locale? locale; // null = follow the system language
  List<Account> accounts = [];
  Account? active;
  LoadState state = LoadState.idle;
  IptvException? error;

  List<Category> categories = [];
  List<Channel> channels = [];
  Map<String, int> categoryCounts = {};

  String selection = kAll;
  String query = '';
  Channel? current;
  String? playbackError;
  Set<String> favorites = {};
  List<String> recent = [];

  // ---- startup & persistence ------------------------------------------

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    weakInternet = prefs.getBool('weakInternet') ?? false;
    _applyNetworkProfile();

    final lang = prefs.getString('locale');
    if (lang != null && L10n.nativeNames.containsKey(lang)) {
      locale = Locale(lang);
    }

    accounts = (prefs.getStringList('accounts') ?? [])
        .map((s) => Account.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
    initialized = true;
    notifyListeners();

    if (accounts.isNotEmpty) {
      final lastId = prefs.getString('lastAccount');
      final account =
          accounts.firstWhere((a) => a.id == lastId, orElse: () => accounts.first);
      await connect(account);
    }
  }

  Future<void> setLocale(Locale? value) async {
    locale = value;
    notifyListeners();
    if (value == null) {
      await _prefs?.remove('locale');
    } else {
      await _prefs?.setString('locale', value.languageCode);
    }
  }

  Future<void> _saveAccounts() => _prefs!
      .setStringList('accounts', accounts.map((a) => jsonEncode(a.toJson())).toList());

  // ---- accounts --------------------------------------------------------

  /// Connects and, on success, remembers the account.
  Future<void> signIn(Account account) async {
    await connect(account);
    if (state == LoadState.ready) {
      accounts = [...accounts.where((a) => a.id != account.id), account];
      await _saveAccounts();
    }
  }

  Future<void> connect(Account account) async {
    state = LoadState.loading;
    error = null;
    notifyListeners();
    try {
      if (account.kind == AccountKind.xtream) {
        final service = XtreamService(account);
        await service.authenticate();
        categories = await service.liveCategories();
        channels = await service.liveChannels();
      } else {
        final playlist = M3uParser.parse(await _download(account.server));
        categories = playlist.categories;
        channels = playlist.channels;
        if (channels.isEmpty) throw IptvException('errUnexpected');
      }

      categoryCounts = {};
      for (final c in channels) {
        categoryCounts[c.categoryId] = (categoryCounts[c.categoryId] ?? 0) + 1;
      }
      active = account;
      favorites = (_prefs?.getStringList('fav:${account.id}') ?? []).toSet();
      recent = _prefs?.getStringList('recent:${account.id}') ?? [];
      _flip = _prefs?.getBool('flip:${account.id}') ?? false;
      selection = kAll;
      query = '';
      await _prefs?.setString('lastAccount', account.id);
      state = LoadState.ready;
    } on IptvException catch (e) {
      error = e;
      state = LoadState.error;
    } catch (_) {
      error = IptvException('errGeneric');
      state = LoadState.error;
    }
    notifyListeners();
  }

  Future<String> _download(String url) async {
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 40));
      if (res.statusCode != 200) {
        throw IptvException('errHttp', code: res.statusCode);
      }
      return utf8.decode(res.bodyBytes, allowMalformed: true);
    } on IptvException {
      rethrow;
    } catch (_) {
      throw IptvException('errUnreachable');
    }
  }

  Future<void> signOut() async {
    await player.stop();
    _retryTimer?.cancel();
    _stallTimer?.cancel();
    active = null;
    current = null;
    playbackError = null;
    channels = [];
    categories = [];
    state = LoadState.idle;
    await _prefs?.remove('lastAccount');
    notifyListeners();
  }

  Future<void> removeAccount(Account account) async {
    accounts = accounts.where((a) => a.id != account.id).toList();
    await _saveAccounts();
    notifyListeners();
  }

  // ---- browsing --------------------------------------------------------

  void select(String value) {
    selection = value;
    notifyListeners();
  }

  void setQuery(String value) {
    query = value;
    notifyListeners();
  }

  List<Channel> get visibleChannels {
    Iterable<Channel> list = channels;
    switch (selection) {
      case kAll:
        break;
      case kFavorites:
        list = list.where((c) => favorites.contains(c.id));
        break;
      case kRecent:
        final byId = {for (final c in channels) c.id: c};
        list = recent.map((id) => byId[id]).whereType<Channel>();
        break;
      default:
        list = list.where((c) => c.categoryId == selection);
    }
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((c) => c.name.toLowerCase().contains(q));
    }
    return list.toList();
  }

  bool isFavorite(Channel c) => favorites.contains(c.id);

  Future<void> toggleFavorite(Channel c) async {
    if (!favorites.add(c.id)) favorites.remove(c.id);
    notifyListeners();
    final a = active;
    if (a != null) await _prefs?.setStringList('fav:${a.id}', favorites.toList());
  }

  // ---- playback --------------------------------------------------------

  /// Tunes libmpv for unreliable networks. Values depend on [weakInternet].
  Future<void> _applyNetworkProfile() async {
    final p = player.platform as dynamic;
    Future<void> set(String key, String value) async {
      try {
        await p.setProperty(key, value);
      } catch (_) {
        // Property not supported by this libmpv build: ignore.
      }
    }

    final weak = weakInternet;
    await set('cache', 'yes');
    await set('demuxer-max-bytes', weak ? '268435456' : '134217728');
    await set('demuxer-max-back-bytes', '33554432');
    await set('demuxer-readahead-secs', weak ? '120' : '60');
    await set('cache-secs', weak ? '120' : '60');
    await set('cache-pause', 'yes');
    await set('cache-pause-wait', weak ? '8' : '3');
    await set('network-timeout', '20');
    await set('hls-bitrate', weak ? 'min' : 'max');
    await set(
      'stream-lavf-o',
      'reconnect=1,reconnect_streamed=1,reconnect_on_network_error=1,'
          'reconnect_delay_max=5',
    );
  }

  Future<void> setWeakInternet(bool value) async {
    weakInternet = value;
    notifyListeners();
    await _prefs?.setBool('weakInternet', value);
    await _applyNetworkProfile();
    final c = current;
    if (c != null) await _open(c, 0); // restart with the new profile
  }

  Future<void> play(Channel c) async {
    current = c;
    playbackError = null;
    _retries = 0;
    _retryTimer?.cancel();
    _stallTimer?.cancel();
    recent = [c.id, ...recent.where((id) => id != c.id)].take(30).toList();
    final a = active;
    if (a != null) _prefs?.setStringList('recent:${a.id}', recent);
    notifyListeners();
    await _open(c, 0);
  }

  Future<void> _open(Channel c, int attempt) async {
    _attempt = attempt;
    _awaitingStart = true;
    await player.open(Media(_urlFor(c, attempt)));
  }

  /// Xtream servers differ: some only serve `.ts`, others only `.m3u8`.
  /// Even attempts use the preferred format, odd attempts the other one.
  String _urlFor(Channel c, int attempt) {
    if (active?.kind != AccountKind.xtream) return c.url;
    if (attempt.isEven != _flip) return c.url;
    if (c.url.endsWith('.m3u8')) {
      return '${c.url.substring(0, c.url.length - 5)}.ts';
    }
    if (c.url.endsWith('.ts')) {
      return '${c.url.substring(0, c.url.length - 3)}.m3u8';
    }
    return c.url;
  }

  void _onStarted() {
    _awaitingStart = false;
    final hadError = playbackError != null;
    playbackError = null;
    _retries = 0;
    if (_attempt.isOdd) {
      // The alternate format worked: use it first from now on.
      _flip = !_flip;
      final a = active;
      if (a != null) _prefs?.setBool('flip:${a.id}', _flip);
    }
    _attempt = 0;
    if (hadError) notifyListeners();
  }

  /// Jump forward or back inside the stream (works within the live buffer).
  Future<void> seekBy(Duration delta) async {
    final target = player.state.position + delta;
    await player.seek(target < Duration.zero ? Duration.zero : target);
  }

  /// Switch to the next (+1) or previous (-1) channel in the visible list.
  Future<void> step(int delta) async {
    final list = visibleChannels;
    if (list.isEmpty) return;
    final i = current == null ? -1 : list.indexWhere((c) => c.id == current!.id);
    await play(list[(i + delta) % list.length]);
  }

  void _onPlayerError(String message) {
    if (current == null) return;
    // The raw message can contain the stream URL (with credentials): log it
    // with URLs removed and never keep or show it.
    debugPrint(
        'Playback error: ${message.replaceAll(RegExp(r'https?://\S+'), '<url>')}');
    playbackError = 'playback';
    notifyListeners();
    _retryPlayback();
  }

  /// Live streams drop now and then: reopen with a growing delay (max 10 s),
  /// alternating stream formats, for up to 40 attempts.
  void _retryPlayback() {
    final c = current;
    if (c == null || _retries >= 40) return;
    _retries++;
    final attempt = _retries;
    final delay = Duration(seconds: attempt == 1 ? 1 : min(attempt * 2, 10));
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      if (current?.id == c.id) _open(c, attempt);
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _errorSub?.cancel();
    _completedSub?.cancel();
    _positionSub?.cancel();
    _bufferingSub?.cancel();
    _stallTimer?.cancel();
    player.dispose();
    super.dispose();
  }
}
