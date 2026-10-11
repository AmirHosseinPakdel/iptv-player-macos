import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// GitHub repository that publishes the releases (public).
const kUpdateRepo = 'AmirHosseinPakdel/iptv-player-macos';

/// auto  = small fixes (x.y.Z) install silently, bigger ones ask first
/// ask   = always ask
/// off   = never check by itself
enum UpdateMode { auto, ask, off }

enum UpdatePhase { idle, checking, available, downloading, upToDate, error }

class ReleaseInfo {
  const ReleaseInfo({
    required this.version,
    required this.notes,
    required this.zipUrl,
    this.shaUrl,
    this.mandatory = false,
  });
  final String version;
  final String notes;
  final String zipUrl;
  final String? shaUrl;

  /// The release notes contain the marker `<!-- mandatory -->`.
  final bool mandatory;
}

/// Checks GitHub Releases, downloads the new app and swaps it in.
/// No app store involved. Installing only works in a release build of the
/// macOS app that is not sandboxed (see docs/UPDATES.md).
class UpdateService extends ChangeNotifier {
  SharedPreferences? _prefs;
  Timer? _timer;

  String current = '0.0.0';
  UpdateMode mode = UpdateMode.auto;
  UpdatePhase phase = UpdatePhase.idle;
  ReleaseInfo? release;
  double progress = 0;
  bool promptPending = false;
  bool revealFallback = false; // could not replace the app: folder was opened
  DateTime? lastChecked;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    current = (await PackageInfo.fromPlatform()).version;
    final m = prefs.getString('updateMode');
    mode = UpdateMode.values.firstWhere((e) => e.name == m,
        orElse: () => UpdateMode.auto);
    // First check shortly after start, then a few times a day.
    Future.delayed(const Duration(seconds: 6), check);
    _timer = Timer.periodic(const Duration(hours: 6), (_) => check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> setMode(UpdateMode value) async {
    mode = value;
    notifyListeners();
    await _prefs?.setString('updateMode', value.name);
  }

  /// True once, so the UI shows the dialog only a single time.
  bool consumePrompt() {
    final p = promptPending;
    promptPending = false;
    return p;
  }

  Future<void> skipThisVersion() async {
    final r = release;
    if (r != null) await _prefs?.setString('skipUpdate', r.version);
    phase = UpdatePhase.idle;
    notifyListeners();
  }

  // ---- checking ----------------------------------------------------------

  static List<int> _parse(String v) {
    final clean = v.replaceFirst(RegExp(r'^[vV]'), '').split('+').first;
    final parts = clean.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts;
  }

  /// >0 when [a] is newer than [b].
  static int compare(String a, String b) {
    final x = _parse(a), y = _parse(b);
    for (var i = 0; i < 3; i++) {
      if (x[i] != y[i]) return x[i].compareTo(y[i]);
    }
    return 0;
  }

  Future<void> check({bool manual = false}) async {
    if (!manual && mode == UpdateMode.off) return;
    if (phase == UpdatePhase.checking || phase == UpdatePhase.downloading) return;
    phase = UpdatePhase.checking;
    notifyListeners();
    try {
      final res = await http.get(
        Uri.parse('https://api.github.com/repos/$kUpdateRepo/releases/latest'),
        headers: {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'iptv-player-updater',
        },
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw Exception('http ${res.statusCode}');
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final tag = (json['tag_name'] as String?) ?? '';
      final notes = (json['body'] as String?) ?? '';
      String? zip, sha;
      for (final a in (json['assets'] as List? ?? const [])) {
        final name = (a['name'] as String?) ?? '';
        final url = a['browser_download_url'] as String?;
        if (url == null) continue;
        if (name.endsWith('-macos.zip')) zip = url;
        if (name.endsWith('-macos.zip.sha256')) sha = url;
      }
      lastChecked = DateTime.now();
      if (zip == null || compare(tag, current) <= 0) {
        phase = UpdatePhase.upToDate;
        release = null;
        notifyListeners();
        return;
      }
      final info = ReleaseInfo(
        version: tag.replaceFirst(RegExp(r'^[vV]'), ''),
        notes: notes.replaceAll('<!-- mandatory -->', '').trim(),
        zipUrl: zip,
        shaUrl: sha,
        mandatory: notes.contains('<!-- mandatory -->'),
      );
      release = info;

      if (!manual &&
          !info.mandatory &&
          _prefs?.getString('skipUpdate') == info.version) {
        phase = UpdatePhase.idle;
        notifyListeners();
        return;
      }

      final a = _parse(info.version), b = _parse(current);
      final smallFix = a[0] == b[0] && a[1] == b[1];
      if (mode == UpdateMode.auto && smallFix && !info.mandatory && !manual) {
        // Minor change: fetch it quietly, install on the next start.
        phase = UpdatePhase.idle;
        notifyListeners();
        await _download(info, quiet: true);
        return;
      }
      phase = UpdatePhase.available;
      promptPending = true;
      notifyListeners();
    } catch (e) {
      debugPrint('update check failed: ${e.runtimeType}');
      phase = manual ? UpdatePhase.error : UpdatePhase.idle;
      notifyListeners();
    }
  }

  // ---- downloading -------------------------------------------------------

  String get _baseDir {
    final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
    return '$home/Library/Application Support/iptv_app_updates';
  }

  /// Downloads, verifies and unpacks the release. Returns the new .app path.
  Future<String?> _download(ReleaseInfo info, {bool quiet = false}) async {
    if (!Platform.isMacOS) return null;
    final dir = Directory('$_baseDir/${info.version}');
    final stagedApp = '${dir.path}/app/iptv_app.app';
    if (Directory(stagedApp).existsSync()) return stagedApp;

    if (!quiet) {
      phase = UpdatePhase.downloading;
      progress = 0;
      notifyListeners();
    }
    try {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      dir.createSync(recursive: true);
      final zipFile = File('${dir.path}/update.zip');

      final client = http.Client();
      try {
        final req = http.Request('GET', Uri.parse(info.zipUrl));
        final resp = await client.send(req).timeout(const Duration(seconds: 30));
        if (resp.statusCode != 200) throw Exception('http ${resp.statusCode}');
        final total = resp.contentLength ?? 0;
        var got = 0;
        final sink = zipFile.openWrite();
        await for (final chunk in resp.stream) {
          sink.add(chunk);
          got += chunk.length;
          if (!quiet && total > 0) {
            progress = got / total;
            notifyListeners();
          }
        }
        await sink.close();
      } finally {
        client.close();
      }

      // Integrity check against the published SHA-256 (when there is one).
      if (info.shaUrl != null) {
        final shaText = (await http.get(Uri.parse(info.shaUrl!))).body;
        final expected = shaText.trim().split(RegExp(r'\s+')).first.toLowerCase();
        final actual = (await sha256.bind(zipFile.openRead()).first).toString();
        if (expected != actual) throw Exception('checksum mismatch');
      }

      final out = Directory('${dir.path}/app')..createSync();
      final r = await Process.run('/usr/bin/ditto', ['-x', '-k', zipFile.path, out.path]);
      if (r.exitCode != 0) throw Exception('unzip failed');
      zipFile.deleteSync();
      // The zip may contain the app under any name: normalise to iptv_app.app.
      final apps = out
          .listSync()
          .whereType<Directory>()
          .where((d) => d.path.endsWith('.app'))
          .toList();
      if (apps.isEmpty) throw Exception('no app in update');
      if (apps.first.path != stagedApp) apps.first.renameSync(stagedApp);

      if (quiet) {
        await _prefs?.setString('stagedUpdate', '${info.version}|$stagedApp');
      }
      return stagedApp;
    } catch (e) {
      debugPrint('update download failed: ${e.runtimeType}');
      if (!quiet) {
        phase = UpdatePhase.error;
        notifyListeners();
      }
      return null;
    }
  }

  // ---- installing --------------------------------------------------------

  /// The user pressed "Update and restart".
  Future<void> installNow() async {
    final info = release;
    if (info == null) return;
    final app = await _download(info);
    if (app == null) return;
    final ok = await _spawnInstaller(app);
    if (!ok) {
      phase = UpdatePhase.error;
      notifyListeners();
    }
  }

  /// Path of the running .app bundle (null when not running from one).
  static String? get _bundlePath {
    final exe = Platform.resolvedExecutable;
    const marker = '.app/Contents/MacOS/';
    final i = exe.indexOf(marker);
    return i < 0 ? null : exe.substring(0, i + 4);
  }

  /// Starts a tiny helper that waits for this app to quit, swaps the bundle
  /// and opens the new version. Returns false if it cannot be done safely.
  Future<bool> _spawnInstaller(String newApp) async {
    final dest = _bundlePath;
    if (!Platform.isMacOS || !kReleaseMode || dest == null) {
      // flutter run / debug build: never touch the build folder.
      debugPrint('update: install skipped (not a release build)');
      return false;
    }
    final parent = Directory(dest).parent.path;
    try {
      File('$parent/.iptv_write_test').writeAsStringSync('x');
      File('$parent/.iptv_write_test').deleteSync();
    } catch (_) {
      // No permission to replace the app: show the new one in Finder instead.
      revealFallback = true;
      await Process.run('/usr/bin/open', ['-R', newApp]);
      notifyListeners();
      return false;
    }
    final script = File('$_baseDir/install.sh');
    script.parent.createSync(recursive: true);
    script.writeAsStringSync(r'''#!/bin/bash
PID="$1"; NEW="$2"; DEST="$3"
while kill -0 "$PID" 2>/dev/null; do sleep 0.3; done
rm -rf "$DEST.old"
if mv "$DEST" "$DEST.old" && mv "$NEW" "$DEST"; then
  xattr -dr com.apple.quarantine "$DEST" 2>/dev/null
  rm -rf "$DEST.old"
else
  [ -d "$DEST.old" ] && [ ! -d "$DEST" ] && mv "$DEST.old" "$DEST"
fi
open "$DEST"
''');
    await Process.start(
      '/bin/bash',
      [script.path, '$pid', newApp, dest],
      mode: ProcessStartMode.detached,
    );
    exit(0);
  }

  /// Called before the UI starts: if a silent update was staged earlier,
  /// install it now (the app restarts once, within a second or two).
  static Future<void> applyStagedIfAny() async {
    if (!Platform.isMacOS || !kReleaseMode) return;
    final prefs = await SharedPreferences.getInstance();
    final staged = prefs.getString('stagedUpdate');
    if (staged == null) return;
    await prefs.remove('stagedUpdate'); // never loop, even if it fails
    final i = staged.indexOf('|');
    if (i < 0) return;
    final version = staged.substring(0, i);
    final path = staged.substring(i + 1);
    final cur = (await PackageInfo.fromPlatform()).version;
    if (compare(version, cur) <= 0 || !Directory(path).existsSync()) return;
    final svc = UpdateService().._prefs = prefs;
    await svc._spawnInstaller(path);
  }
}
