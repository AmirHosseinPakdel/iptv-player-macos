import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models.dart';
import 'translations.dart';

/// Lightweight localization: a key lookup with English fallback.
class L10n {
  const L10n(this.locale);
  final Locale locale;

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('fa'),
    Locale('de'),
    Locale('zh'),
    Locale('es'),
    Locale('fr'),
    Locale('ar'),
    Locale('tr'),
    Locale('ru'),
    Locale('pt'),
    Locale('it'),
    Locale('hi'),
  ];

  /// Each language written in itself, for the language picker.
  static const nativeNames = <String, String>{
    'en': 'English',
    'fa': 'فارسی',
    'de': 'Deutsch',
    'zh': '中文',
    'es': 'Español',
    'fr': 'Français',
    'ar': 'العربية',
    'tr': 'Türkçe',
    'ru': 'Русский',
    'pt': 'Português',
    'it': 'Italiano',
    'hi': 'हिन्दी',
  };

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

  static L10n of(BuildContext context) =>
      Localizations.of<L10n>(context, L10n) ?? const L10n(Locale('en'));

  String _t(String key, [Map<String, String> args = const {}]) {
    var s = translations[locale.languageCode]?[key] ??
        translations['en']![key] ??
        key;
    args.forEach((k, v) => s = s.replaceAll('{$k}', v));
    return s;
  }

  String error(IptvException e) => e.key == 'errHttp'
      ? _t('errHttp', {'code': '${e.code}'})
      : _t(e.key);

  String get signIn => _t('signIn');
  String get accountName => _t('accountName');
  String get xtreamLogin => _t('xtreamLogin');
  String get m3uPlaylist => _t('m3uPlaylist');
  String get serverUrl => _t('serverUrl');
  String get playlistUrl => _t('playlistUrl');
  String get username => _t('username');
  String get password => _t('password');
  String get connect => _t('connect');
  String get connecting => _t('connecting');
  String get savedAccounts => _t('savedAccounts');
  String get allChannels => _t('allChannels');
  String get favorites => _t('favorites');
  String get recentlyWatched => _t('recentlyWatched');
  String get categories => _t('categories');
  String get searchChannels => _t('searchChannels');
  String get noChannels => _t('noChannels');
  String get selectChannel => _t('selectChannel');
  String get signOut => _t('signOut');
  String get language => _t('language');
  String get systemDefault => _t('systemDefault');
  String get playbackProblem => _t('playbackProblem');
  String get play => _t('play');
  String get pause => _t('pause');
  String get addFavorite => _t('addFavorite');
  String get removeFavorite => _t('removeFavorite');
  String get fullscreen => _t('fullscreen');
  String get previousChannel => _t('previousChannel');
  String get nextChannel => _t('nextChannel');
  String get weakInternet => _t('weakInternet');
  String get guide => _t('guide');
  String get epgNow => _t('epgNow');
  String get epgNext => _t('epgNext');
  String get noGuide => _t('noGuide');
  String get toggleCategories => _t('toggleCategories');
  String get toggleChannels => _t('toggleChannels');
  String get navLive => _t('navLive');
  String get navMovies => _t('navMovies');
  String get navSeries => _t('navSeries');
  String get settings => _t('settings');
  String get userAgent => _t('userAgent');
  String get skipDuration => _t('skipDuration');
  String get rememberVolume => _t('rememberVolume');
  String get wheelVolume => _t('wheelVolume');
  String get updatesTitle => _t('updatesTitle');
  String get installUpdate => _t('installUpdate');
  String get later => _t('later');
  String get skipVersion => _t('skipVersion');
  String get downloading => _t('downloading');
  String get upToDate => _t('upToDate');
  String get checkUpdates => _t('checkUpdates');
  String get updatesMode => _t('updatesMode');
  String get updModeAuto => _t('updModeAuto');
  String get updModeAsk => _t('updModeAsk');
  String get updModeOff => _t('updModeOff');
  String get updateFailed => _t('updateFailed');
  String get revealUpdate => _t('revealUpdate');
  String get releaseNotes => _t('releaseNotes');
  String newVersion(String v) => _t('newVersion', {'v': v});
  String versionLabel(String v) => _t('versionLabel', {'v': v});
  String get tabGeneral => _t('tabGeneral');
  String get tabPlayback => _t('tabPlayback');
  String get tabAccounts => _t('tabAccounts');
  String get descWeak => _t('descWeak');
  String get descUserAgent => _t('descUserAgent');
  String get descSubLang => _t('descSubLang');
  String get descAutoUpdate => _t('descAutoUpdate');
  String get descStartup => _t('descStartup');
  String get subtitlePreview => _t('subtitlePreview');
  String get removeAccount => _t('removeAccount');
  String get activeNow => _t('activeNow');
  String get done => _t('done');
  String get arrowSkip => _t('arrowSkip');
  String get arrowLinked => _t('arrowLinked');
  String get startupPage => _t('startupPage');
  String get startLast => _t('startLast');
  String get startCustom => _t('startCustom');
  String get useCurrentPage => _t('useCurrentPage');
  String get autoPlayLast => _t('autoPlayLast');
  String get searchMovies => _t('searchMovies');
  String get searchSeries => _t('searchSeries');
  String get resumeNow => _t('resumeNow');
  String get continueEpisode => _t('continueEpisode');
  String get watched => _t('watched');
  String resumeIn(String time, int n) => _t('resumeIn', {'time': time, 'n': '$n'});
  String get allMovies => _t('allMovies');
  String get allSeries => _t('allSeries');
  String get account => _t('account');
  String get updateNow => _t('updateNow');
  String get autoUpdate => _t('autoUpdate');
  String get updating => _t('updating');
  String get neverUpdated => _t('neverUpdated');
  String lastUpdatedAt(String time) => _t('lastUpdatedAt', {'time': time});
  String everyNHours(int n) => _t('everyNHours', {'n': '$n'});
  String get subtitles => _t('subtitles');
  String get audioTrack => _t('audioTrack');
  String get subtitleTrack => _t('subtitleTrack');
  String get subtitleLanguage => _t('subtitleLanguage');
  String get subtitleColor => _t('subtitleColor');
  String get addSubtitle => _t('addSubtitle');
  String get trackOff => _t('trackOff');
  String get trackAuto => _t('trackAuto');
  String get noTracks => _t('noTracks');
  String get hideChannel => _t('hideChannel');
  String get hideCategory => _t('hideCategory');
  String get showHidden => _t('showHidden');
  String get sortAz => _t('sortAz');
  String get addSource => _t('addSource');
  String get noPlot => _t('noPlot');
  String get startOver => _t('startOver');
  String get loadingMore => _t('loadingMore');
  String seekBackN(int n) => _t('seekBack', {'n': '$n'});
  String seekForwardN(int n) => _t('seekForward', {'n': '$n'});
  String resumeFrom(String time) => _t('resumeFrom', {'time': time});
  String seasonN(int n) => _t('seasonN', {'n': '$n'});
  String get errUnreachable => _t('errUnreachable');
  String get errUnexpected => _t('errUnexpected');
  String get errLogin => _t('errLogin');
  String get errGeneric => _t('errGeneric');
  String get fieldRequired => _t('fieldRequired');
  String get welcomeTitle => _t('welcomeTitle');
  String get welcomeSubtitle => _t('welcomeSubtitle');
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  bool isSupported(Locale locale) =>
      translations.containsKey(locale.languageCode);

  @override
  Future<L10n> load(Locale locale) => SynchronousFuture<L10n>(L10n(locale));

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

extension L10nContext on BuildContext {
  L10n get l10n => L10n.of(this);
}
