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

enum Section { live, movies, series }

class AppState extends ChangeNotifier {
  AppState() {
    _errorSub = player.stream.error.listen(_onPlayerError);
    _completedSub = player.stream.completed.listen((done) {
      if (!done) return;
      if (currentIsLive) {
        _retryPlayback();
      } else {
        _markWatched(current?.id);
        _clearPosition(current?.id);
        notifyListeners();
      }
    });
    // Playback counts as started once the position starts moving.
    _positionSub = player.stream.position.listen((pos) {
      if (_awaitingStart && pos > Duration.zero) _onStarted();
      if (!currentIsLive) _maybeSavePosition(pos);
    });
    // Jump to the saved position as soon as the movie length is known.
    _durationSub = player.stream.duration.listen((d) {
      final target = _pendingSeek;
      if (target != null && d > Duration.zero) {
        _pendingSeek = null;
        player.seek(target);
      }
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
    _volumeSub = player.stream.volume.listen((v) {
      if (rememberVolume) _prefs?.setDouble('volume', v);
    });
  }

  final FocusNode playerFocus = FocusNode(debugLabel: 'player');
  final Player player = Player();
  late final VideoController video = VideoController(player);

  SharedPreferences? _prefs;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _bufferingSub;
  StreamSubscription<double>? _volumeSub;
  Timer? _retryTimer;
  Timer? _stallTimer;
  int _retries = 0;
  int _attempt = 0; // which stream URL variant is currently being tried
  bool _awaitingStart = false;
  bool _flip = false; // learned: this provider prefers the other stream format
  Duration? _pendingSeek;
  DateTime _lastSave = DateTime.fromMillisecondsSinceEpoch(0);

  // ---- settings (remembered between launches) ---------------------------

  /// Bigger buffer, lower quality, patient timeouts: for slow connections.
  bool weakInternet = false;
  bool showSidebar = true;
  bool showChannels = true;
  bool sortAz = false;
  int skipSeconds = 15; // on-screen skip buttons
  int arrowSeconds = 5; // left / right arrow keys
  bool arrowLinked = false; // arrows use the skip-button value
  String userAgent = '';
  bool rememberVolume = true;
  bool wheelVolume = true;
  String startupPage = 'last'; // 'last' or '<section>:<selection>'
  bool autoPlayLast = false;
  bool collapseQuick = false; // sidebar: All / Favorites / Recent group
  bool collapseCats = false; // sidebar: category list
  String subLang = 'fa';
  int refreshHours = 6; // 0 = never refresh automatically
  DateTime? lastUpdated;
  bool refreshing = false;
  Timer? _refreshTimer;
  int subColor = 0xFFFFFFFF;

  bool initialized = false;
  Locale? locale; // null = follow the system language
  List<Account> accounts = [];
  Account? active;
  LoadState state = LoadState.idle;
  IptvException? error;
  XtreamService? xtreamService; // null for M3U playlists (live TV only)

  bool get hasVod => xtreamService != null;

  // ---- live TV ----------------------------------------------------------

  List<Category> categories = [];
  List<Channel> channels = [];
  Map<String, int> categoryCounts = {};
  String selection = kAll;
  Set<String> favorites = {};
  Set<String> favMovies = {};
  Set<String> favSeries = {};
  Duration? resumePrompt; // set while the "resume or start over" countdown runs
  List<String> recent = [];

  // ---- movies & series --------------------------------------------------

  Section section = Section.live;

  LoadState moviesState = LoadState.idle;
  List<Category> movieCategories = [];
  List<VodItem> movies = [];
  Map<String, int> movieCounts = {};
  String movieSelection = kAll;

  LoadState seriesState = LoadState.idle;
  List<Category> seriesCategories = [];
  List<SeriesItem> seriesItems = [];
  Map<String, int> seriesCounts = {};
  String seriesSelection = kAll;

  // ---- search, hidden items, playback -------------------------------------

  String query = '';
  Set<String> hiddenChannels = {};
  Set<String> hiddenCategories = {}; // entries look like "live:12"

  Channel? current;
  bool currentIsLive = true;
  bool vodBrowse = true; // movies/series: show the poster grid, not the player
  String? playbackError;

  // ---- startup & persistence ------------------------------------------

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    weakInternet = prefs.getBool('weakInternet') ?? false;
    showSidebar = prefs.getBool('showSidebar') ?? true;
    showChannels = prefs.getBool('showChannels') ?? true;
    sortAz = prefs.getBool('sortAz') ?? false;
    skipSeconds = prefs.getInt('skipSeconds') ?? 15;
    arrowSeconds = prefs.getInt('arrowSeconds') ?? 5;
    arrowLinked = prefs.getBool('arrowLinked') ?? false;
    userAgent = prefs.getString('userAgent') ?? '';
    rememberVolume = prefs.getBool('rememberVolume') ?? true;
    wheelVolume = prefs.getBool('wheelVolume') ?? true;
    startupPage = prefs.getString('startupPage') ?? 'last';
    autoPlayLast = prefs.getBool('autoPlayLast') ?? false;
    collapseQuick = prefs.getBool('collapseQuick') ?? false;
    collapseCats = prefs.getBool('collapseCats') ?? false;
    refreshHours = prefs.getInt('refreshHours') ?? 6;
    subLang = prefs.getString('subLang') ?? 'fa';
    subColor = prefs.getInt('subColor') ?? 0xFFFFFFFF;
    final savedVolume = prefs.getDouble('volume');
    if (rememberVolume && savedVolume != null) {
      await player.setVolume(savedVolume.clamp(0, 100).toDouble());
    }
    _applyNetworkProfile();
    _applySubtitlePrefs();

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

  void toggleSidebar() {
    showSidebar = !showSidebar;
    notifyListeners();
    _prefs?.setBool('showSidebar', showSidebar);
  }

  void toggleChannels() {
    showChannels = !showChannels;
    notifyListeners();
    _prefs?.setBool('showChannels', showChannels);
  }

  void toggleSort() {
    sortAz = !sortAz;
    notifyListeners();
    _prefs?.setBool('sortAz', sortAz);
  }

  int get keySeconds => arrowLinked ? skipSeconds : arrowSeconds;

  void setArrowSeconds(int value) {
    arrowSeconds = value;
    notifyListeners();
    _prefs?.setInt('arrowSeconds', value);
  }

  void setArrowLinked(bool value) {
    arrowLinked = value;
    notifyListeners();
    _prefs?.setBool('arrowLinked', value);
  }

  void setSkipSeconds(int value) {
    skipSeconds = value;
    notifyListeners();
    _prefs?.setInt('skipSeconds', value);
  }

  Future<void> setUserAgent(String value) async {
    userAgent = value.trim();
    notifyListeners();
    await _prefs?.setString('userAgent', userAgent);
    await _applyNetworkProfile();
  }

  void setRememberVolume(bool value) {
    rememberVolume = value;
    notifyListeners();
    _prefs?.setBool('rememberVolume', value);
    if (value) _prefs?.setDouble('volume', player.state.volume);
  }

  void setWheelVolume(bool value) {
    wheelVolume = value;
    notifyListeners();
    _prefs?.setBool('wheelVolume', value);
  }

  static const _langCodes = {
    'fa': 'fa,fas,per,persian',
    'en': 'en,eng,english',
    'de': 'de,deu,ger,german',
    'ar': 'ar,ara,arabic',
    'tr': 'tr,tur,turkish',
    'fr': 'fr,fra,fre,french',
    'es': 'es,spa,spanish',
    'ru': 'ru,rus,russian',
  };
  static List<String> get subtitleLanguages => _langCodes.keys.toList();

  Future<void> _mpv(String key, String value) async {
    try {
      await (player.platform as dynamic).setProperty(key, value);
    } catch (_) {}
  }

  Future<void> _applySubtitlePrefs() async {
    await _mpv('slang', _langCodes[subLang] ?? subLang);
    // Persian subtitle files are often Windows-1256 instead of UTF-8.
    await _mpv('sub-codepage', 'utf8:cp1256');
  }

  Future<void> setSubLang(String value) async {
    subLang = value;
    notifyListeners();
    await _prefs?.setString('subLang', value);
    await _applySubtitlePrefs();
  }

  void setSubColor(int value) {
    subColor = value;
    notifyListeners();
    _prefs?.setInt('subColor', value);
  }

  /// Loads a subtitle file picked by the user and switches to it.
  Future<void> addSubtitleFile(String path) async {
    await player.setSubtitleTrack(SubtitleTrack.uri(path, title: path.split('/').last));
  }

  void nudgeVolume(double delta) {
    final v = (player.state.volume + delta).clamp(0, 100).toDouble();
    player.setVolume(v);
  }

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
      if (active != null && active!.id != account.id) {
        await player.stop();
        current = null;
        playbackError = null;
      }
      if (account.kind == AccountKind.xtream) {
        final service = XtreamService(account);
        xtreamService = service;
        await service.authenticate();
        categories = await service.liveCategories();
        channels = await service.liveChannels();
      } else {
        xtreamService = null;
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
      favMovies = (_prefs?.getStringList('favm:${account.id}') ?? []).toSet();
      favSeries = (_prefs?.getStringList('favs:${account.id}') ?? []).toSet();
      hiddenChannels =
          (_prefs?.getStringList('hidech:${account.id}') ?? []).toSet();
      hiddenCategories =
          (_prefs?.getStringList('hidecat:${account.id}') ?? []).toSet();
      _flip = _prefs?.getBool('flip:${account.id}') ?? false;
      selection = kAll;
      query = '';

      // Movies and series are loaded on first use.
      section = Section.live;
      moviesState = LoadState.idle;
      movieCategories = [];
      movies = [];
      movieCounts = {};
      movieSelection = kAll;
      seriesState = LoadState.idle;
      seriesCategories = [];
      seriesItems = [];
      seriesCounts = {};
      seriesSelection = kAll;

      await _prefs?.setString('lastAccount', account.id);
      state = LoadState.ready;
      lastUpdated = DateTime.now();
      _startRefreshTimer();
    } on IptvException catch (e) {
      error = e;
      state = LoadState.error;
    } catch (_) {
      error = IptvException('errGeneric');
      state = LoadState.error;
    }
    notifyListeners();
    if (state == LoadState.ready) await _applyStartup();
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
    _pendingSeek = null;
    active = null;
    xtreamService = null;
    current = null;
    playbackError = null;
    channels = [];
    categories = [];
    movies = [];
    seriesItems = [];
    state = LoadState.idle;
    await _prefs?.remove('lastAccount');
    notifyListeners();
  }

  Future<void> removeAccount(Account account) async {
    accounts = accounts.where((a) => a.id != account.id).toList();
    await _saveAccounts();
    notifyListeners();
  }

  // ---- sections: movies & series ---------------------------------------

  Future<void> setSection(Section value) async {
    if (value != Section.live && !hasVod) return;
    if (value == Section.live && !currentIsLive) closeVod();
    section = value;
    query = '';
    if (value != Section.live) vodBrowse = true;
    _prefs?.setString('lastSection', value.name);
    notifyListeners();
    if (value == Section.movies && moviesState == LoadState.idle) {
      await _loadMovies();
    } else if (value == Section.series && seriesState == LoadState.idle) {
      await _loadSeries();
    }
  }

  void setRefreshHours(int hours) {
    refreshHours = hours;
    notifyListeners();
    _prefs?.setInt('refreshHours', hours);
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final last = lastUpdated;
      if (refreshHours <= 0 || last == null || refreshing) return;
      if (DateTime.now().difference(last) >= Duration(hours: refreshHours)) {
        refreshContent();
      }
    });
  }

  /// Re-downloads channels (and movies/series if opened) without
  /// interrupting playback. Failures keep the old lists.
  Future<void> refreshContent() async {
    final account = active;
    if (account == null || refreshing || state != LoadState.ready) return;
    refreshing = true;
    notifyListeners();
    try {
      List<Category> cats;
      List<Channel> chans;
      if (account.kind == AccountKind.xtream) {
        final service = xtreamService ?? XtreamService(account);
        cats = await service.liveCategories();
        chans = await service.liveChannels();
      } else {
        final playlist = M3uParser.parse(await _download(account.server));
        cats = playlist.categories;
        chans = playlist.channels;
      }
      if (active?.id == account.id && chans.isNotEmpty) {
        categories = cats;
        channels = chans;
        categoryCounts = {};
        for (final c in chans) {
          categoryCounts[c.categoryId] = (categoryCounts[c.categoryId] ?? 0) + 1;
        }
        if (moviesState == LoadState.ready) await _loadMovies(quiet: true);
        if (seriesState == LoadState.ready) await _loadSeries(quiet: true);
        lastUpdated = DateTime.now();
      }
    } catch (_) {
      // Keep what we have; the next attempt happens on the timer.
    }
    refreshing = false;
    notifyListeners();
  }

  // ---- startup page ------------------------------------------------------

  /// All fixed choices offered in Settings (besides "last used").
  static const startupPresets = <String>[
    'live:$kAll',
    'live:$kFavorites',
    'live:$kRecent',
    'movies:$kAll',
    'movies:$kFavorites',
    'series:$kAll',
    'series:$kFavorites',
  ];

  Future<void> setStartupPage(String value) async {
    startupPage = value;
    notifyListeners();
    await _prefs?.setString('startupPage', value);
  }

  /// Remembers the page that is open right now as the startup page.
  Future<void> useCurrentPageAtStartup() =>
      setStartupPage('${section.name}:$currentSelection');

  void toggleQuick() {
    collapseQuick = !collapseQuick;
    notifyListeners();
    _prefs?.setBool('collapseQuick', collapseQuick);
  }

  void toggleCats() {
    collapseCats = !collapseCats;
    notifyListeners();
    _prefs?.setBool('collapseCats', collapseCats);
  }

  Future<void> setAutoPlayLast(bool value) async {
    autoPlayLast = value;
    notifyListeners();
    await _prefs?.setBool('autoPlayLast', value);
  }

  bool _selectionValid(Section s, String sel) {
    switch (sel) {
      case kAll:
        return true;
      case kFavorites:
        return switch (s) {
          Section.live => favorites.isNotEmpty,
          Section.movies => favMovies.isNotEmpty,
          Section.series => favSeries.isNotEmpty,
        };
      case kRecent:
        return s == Section.live && recent.isNotEmpty;
      default:
        final cats = switch (s) {
          Section.live => categories,
          Section.movies => movieCategories,
          Section.series => seriesCategories,
        };
        return cats.any((c) => c.id == sel) &&
            !isCategoryHidden(s, sel);
    }
  }

  /// Opens the page chosen in Settings (or the last one) after sign-in.
  /// Anything that does not exist (no movies on M3U, no favorites yet,
  /// a removed category) falls back to the nearest sensible page.
  Future<void> _applyStartup() async {
    final a = active;
    if (a == null) return;
    var sec = Section.live;
    var sel = kAll;
    if (startupPage == 'last') {
      final name = _prefs?.getString('lastSection');
      sec = Section.values
          .firstWhere((s) => s.name == name, orElse: () => Section.live);
      sel = _prefs?.getString('lastSel:${a.id}:${sec.name}') ?? kAll;
    } else {
      final i = startupPage.indexOf(':');
      final name = i < 0 ? startupPage : startupPage.substring(0, i);
      sec = Section.values
          .firstWhere((s) => s.name == name, orElse: () => Section.live);
      sel = i < 0 ? kAll : startupPage.substring(i + 1);
    }
    if (sec != Section.live && !hasVod) {
      sec = Section.live;
      sel = kAll;
    }
    await setSection(sec); // loads movies / series when needed
    if (!_selectionValid(sec, sel)) sel = kAll;
    select(sel);

    if (autoPlayLast && sec == Section.live) {
      final id = _prefs?.getString('lastChannel:${a.id}');
      final match = channels.where((c) => c.id == id);
      if (match.isNotEmpty) await play(match.first);
    }
  }

  Future<void> reloadSection() async {
    if (section == Section.movies) {
      moviesState = LoadState.idle;
      await _loadMovies();
    } else if (section == Section.series) {
      seriesState = LoadState.idle;
      await _loadSeries();
    }
  }

  Future<void> _loadMovies({bool quiet = false}) async {
    final service = xtreamService;
    if (service == null) return;
    if (!quiet) {
      moviesState = LoadState.loading;
      notifyListeners();
    }
    try {
      final cats = await service.vodCategories();
      final items = await service.vodStreams();
      if (xtreamService != service) return; // account changed meanwhile
      movieCategories = cats;
      movies = items;
      movieCounts = {};
      for (final m in items) {
        movieCounts[m.categoryId] = (movieCounts[m.categoryId] ?? 0) + 1;
      }
      moviesState = LoadState.ready;
    } catch (_) {
      if (!quiet) moviesState = LoadState.error;
    }
    notifyListeners();
  }

  Future<void> _loadSeries({bool quiet = false}) async {
    final service = xtreamService;
    if (service == null) return;
    if (!quiet) {
      seriesState = LoadState.loading;
      notifyListeners();
    }
    try {
      final cats = await service.seriesCategories();
      final items = await service.seriesList();
      if (xtreamService != service) return;
      seriesCategories = cats;
      seriesItems = items;
      seriesCounts = {};
      for (final s in items) {
        seriesCounts[s.categoryId] = (seriesCounts[s.categoryId] ?? 0) + 1;
      }
      seriesState = LoadState.ready;
    } catch (_) {
      if (!quiet) seriesState = LoadState.error;
    }
    notifyListeners();
  }

  // ---- browsing --------------------------------------------------------

  void select(String value) {
    // Picking a category while a movie/episode plays closes the player.
    if (section != Section.live && !vodBrowse) closeVod();
    switch (section) {
      case Section.live:
        selection = value;
      case Section.movies:
        movieSelection = value;
      case Section.series:
        seriesSelection = value;
    }
    final a = active;
    if (a != null) {
      _prefs?.setString('lastSel:${a.id}:${section.name}', value);
    }
    notifyListeners();
  }

  String get currentSelection => switch (section) {
        Section.live => selection,
        Section.movies => movieSelection,
        Section.series => seriesSelection,
      };

  void setQuery(String value) {
    query = value;
    notifyListeners();
  }

  bool isCategoryHidden(Section s, String id) =>
      hiddenCategories.contains('${s.name}:$id');

  List<Channel> get visibleChannels {
    Iterable<Channel> list = channels.where((c) =>
        !hiddenChannels.contains(c.id) &&
        !isCategoryHidden(Section.live, c.categoryId));
    switch (selection) {
      case kAll:
        break;
      case kFavorites:
        list = list.where((c) => favorites.contains(c.id));
        break;
      case kRecent:
        final byId = {for (final c in list) c.id: c};
        list = recent.map((id) => byId[id]).whereType<Channel>();
        break;
      default:
        list = list.where((c) => c.categoryId == selection);
    }
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((c) => c.name.toLowerCase().contains(q));
    }
    final result = list.toList();
    if (sortAz && selection != kRecent) {
      result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return result;
  }

  List<VodItem> get visibleMovies {
    Iterable<VodItem> list = movies
        .where((m) => !isCategoryHidden(Section.movies, m.categoryId));
    if (movieSelection == kFavorites) {
      list = list.where((m) => favMovies.contains(m.id));
    } else if (movieSelection != kAll) {
      list = list.where((m) => m.categoryId == movieSelection);
    }
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      final names = {
        for (final c in movieCategories) c.id: c.name.toLowerCase()
      };
      list = list.where((m) =>
          m.name.toLowerCase().contains(q) ||
          (names[m.categoryId] ?? '').contains(q));
    }
    final result = list.toList();
    if (sortAz) {
      result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return result;
  }

  List<SeriesItem> get visibleSeries {
    Iterable<SeriesItem> list = seriesItems
        .where((s) => !isCategoryHidden(Section.series, s.categoryId));
    if (seriesSelection == kFavorites) {
      list = list.where((s) => favSeries.contains(s.id));
    } else if (seriesSelection != kAll) {
      list = list.where((s) => s.categoryId == seriesSelection);
    }
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      final names = {
        for (final c in seriesCategories) c.id: c.name.toLowerCase()
      };
      list = list.where((s) =>
          s.name.toLowerCase().contains(q) ||
          (names[s.categoryId] ?? '').contains(q));
    }
    final result = list.toList();
    if (sortAz) {
      result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return result;
  }

  Future<void> toggleFavMovie(String id) async {
    if (!favMovies.add(id)) favMovies.remove(id);
    notifyListeners();
    final a = active;
    if (a != null) await _prefs?.setStringList('favm:${a.id}', favMovies.toList());
  }

  Future<void> toggleFavSeries(String id) async {
    if (!favSeries.add(id)) favSeries.remove(id);
    notifyListeners();
    final a = active;
    if (a != null) await _prefs?.setStringList('favs:${a.id}', favSeries.toList());
  }

  bool isFavorite(Channel c) => favorites.contains(c.id);

  Future<void> toggleFavorite(Channel c) async {
    if (!favorites.add(c.id)) favorites.remove(c.id);
    notifyListeners();
    final a = active;
    if (a != null) await _prefs?.setStringList('fav:${a.id}', favorites.toList());
  }

  // ---- hiding ------------------------------------------------------------

  Future<void> hideChannel(Channel c) async {
    hiddenChannels = {...hiddenChannels, c.id};
    notifyListeners();
    final a = active;
    if (a != null) {
      await _prefs?.setStringList('hidech:${a.id}', hiddenChannels.toList());
    }
  }

  Future<void> hideCategory(Section s, String categoryId) async {
    hiddenCategories = {...hiddenCategories, '${s.name}:$categoryId'};
    if (currentSelection == categoryId) select(kAll);
    notifyListeners();
    final a = active;
    if (a != null) {
      await _prefs?.setStringList('hidecat:${a.id}', hiddenCategories.toList());
    }
  }

  Future<void> showAllHidden() async {
    hiddenChannels = {};
    hiddenCategories = {};
    notifyListeners();
    final a = active;
    if (a != null) {
      await _prefs?.remove('hidech:${a.id}');
      await _prefs?.remove('hidecat:${a.id}');
    }
  }

  int get hiddenCount => hiddenChannels.length + hiddenCategories.length;

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
    await set('user-agent', userAgent.isEmpty ? 'libmpv' : userAgent);
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
    currentIsLive = true;
    resumePrompt = null;
    _pendingSeek = null;
    playbackError = null;
    _retries = 0;
    _retryTimer?.cancel();
    _stallTimer?.cancel();
    recent = [c.id, ...recent.where((id) => id != c.id)].take(30).toList();
    final a = active;
    if (a != null) {
      _prefs?.setStringList('recent:${a.id}', recent);
      _prefs?.setString('lastChannel:${a.id}', c.id);
    }
    notifyListeners();
    await _open(c, 0);
  }

  /// Plays a movie or episode, resuming where it was left (unless [fromStart]).
  /// [key] identifies the item for the saved position, e.g. "m:12" or "e:340".
  Future<void> playVod(String key, String title, String url,
      {bool fromStart = false, String? seriesId}) async {
    if (fromStart) _clearPosition(key);
    final saved = fromStart ? null : resumePosition(key);
    resumePrompt = (saved != null && saved > const Duration(seconds: 20)) ? saved : null;
    final a = active;
    if (seriesId != null && a != null) {
      _prefs?.setString('lastep:${a.id}:$seriesId', key);
    }
    current = Channel(id: key, name: title, categoryId: '', url: url);
    currentIsLive = false;
    vodBrowse = false;
    playbackError = null;
    _retries = 0;
    _retryTimer?.cancel();
    _stallTimer?.cancel();
    notifyListeners();
    await _open(current!, 0);
  }

  /// Leaves the movie/episode player and returns to the poster grid.
  Future<void> closeVod() async {
    resumePrompt = null;
    _retryTimer?.cancel();
    _stallTimer?.cancel();
    await player.stop();
    current = null;
    currentIsLive = true;
    playbackError = null;
    vodBrowse = true;
    notifyListeners();
  }

  Future<void> _open(Channel c, int attempt) async {
    _attempt = attempt;
    _awaitingStart = true;
    _pendingSeek = null;
    await player.open(Media(_urlFor(c, attempt)), play: resumePrompt == null);
  }

  /// Xtream servers differ: some only serve `.ts`, others only `.m3u8`.
  /// Even attempts use the preferred format, odd attempts the other one.
  String _urlFor(Channel c, int attempt) {
    if (!currentIsLive || active?.kind != AccountKind.xtream) return c.url;
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
    if (currentIsLive && _attempt.isOdd) {
      // The alternate format worked: use it first from now on.
      _flip = !_flip;
      final a = active;
      if (a != null) _prefs?.setBool('flip:${a.id}', _flip);
    }
    _attempt = 0;
    if (hadError) notifyListeners();
  }

  // ---- resume positions --------------------------------------------------

  /// Countdown finished or "Resume now": jump to the saved spot and play.
  Future<void> resumeNow() async {
    final p = resumePrompt;
    if (p == null) return;
    resumePrompt = null;
    notifyListeners();
    if (player.state.duration > Duration.zero) {
      await player.seek(p);
    } else {
      _pendingSeek = p;
    }
    await player.play();
  }

  Future<void> startOverNow() async {
    resumePrompt = null;
    _clearPosition(current?.id);
    notifyListeners();
    await player.play();
  }

  bool isWatched(String key) => _prefs?.getBool('watched:${active?.id}:$key') ?? false;

  void _markWatched(String? key) {
    if (key != null && active != null) {
      _prefs?.setBool('watched:${active!.id}:$key', true);
    }
  }

  String? lastEpisodeKey(String seriesId) =>
      _prefs?.getString('lastep:${active?.id}:$seriesId');

  String _posKey(String key) => 'pos:${active?.id}:$key';

  Duration? resumePosition(String key) {
    final seconds = _prefs?.getInt(_posKey(key));
    return seconds == null ? null : Duration(seconds: seconds);
  }

  void _clearPosition(String? key) {
    if (key != null) _prefs?.remove(_posKey(key));
  }

  void _maybeSavePosition(Duration pos) {
    final c = current;
    if (c == null || active == null) return;
    final now = DateTime.now();
    if (now.difference(_lastSave) < const Duration(seconds: 10)) return;
    _lastSave = now;
    final total = player.state.duration;
    if (total > Duration.zero && pos > total * 0.95) {
      _markWatched(c.id);
      _clearPosition(c.id); // watched to the end
    } else if (pos > const Duration(seconds: 20)) {
      _prefs?.setInt(_posKey(c.id), pos.inSeconds);
    }
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

  /// Streams drop now and then: reopen with a growing delay (max 10 s),
  /// alternating stream formats for live TV, for up to 40 attempts.
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
    playerFocus.dispose();
    _refreshTimer?.cancel();
    _retryTimer?.cancel();
    _errorSub?.cancel();
    _completedSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _bufferingSub?.cancel();
    _volumeSub?.cancel();
    _stallTimer?.cancel();
    player.dispose();
    super.dispose();
  }
}
