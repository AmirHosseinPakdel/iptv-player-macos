import 'package:flutter/foundation.dart';

import 'models.dart';
import 'xtream_service.dart';

/// Lazy, cached, throttled programme-guide lookups (Xtream providers).
class EpgStore extends ChangeNotifier {
  static const _ttl = Duration(minutes: 10);
  static const _maxParallel = 3;

  XtreamService? _service;
  int _generation = 0;
  int _running = 0;
  final Map<String, List<EpgEntry>> _cache = {};
  final Map<String, DateTime> _fetchedAt = {};
  final Set<String> _inFlight = {};
  final List<String> _queue = [];

  bool get available => _service != null;

  /// Switches provider. Does not notify: called while the tree is building.
  void attach(XtreamService? service) {
    if (identical(service, _service)) return;
    _service = service;
    _generation++;
    _cache.clear();
    _fetchedAt.clear();
    _inFlight.clear();
    _queue.clear();
  }

  List<EpgEntry>? entries(String channelId) => _cache[channelId];

  /// Asks for a channel's guide; does nothing if it is fresh or already queued.
  void request(Channel channel) {
    if (_service == null) return;
    final id = channel.id;
    final last = _fetchedAt[id];
    if (last != null && DateTime.now().difference(last) < _ttl) return;
    if (_inFlight.contains(id) || _queue.contains(id)) return;
    _queue.add(id);
    _pump();
  }

  void _pump() {
    while (_running < _maxParallel && _queue.isNotEmpty) {
      final id = _queue.removeLast(); // newest request (visible item) first
      final service = _service;
      if (service == null) return;
      _running++;
      _inFlight.add(id);
      _load(id, service, _generation).whenComplete(() {
        _running--;
        _inFlight.remove(id);
        _pump();
      });
    }
  }

  Future<void> _load(String id, XtreamService service, int generation) async {
    try {
      final list = await service.shortEpg(id);
      if (generation != _generation) return;
      _cache[id] = list;
      _fetchedAt[id] = DateTime.now();
    } catch (_) {
      if (generation != _generation) return;
      _cache[id] = const [];
      // Retry a failed lookup after about two minutes instead of hammering.
      _fetchedAt[id] = DateTime.now().subtract(_ttl - const Duration(minutes: 2));
    }
    notifyListeners();
  }
}

EpgEntry? nowOf(List<EpgEntry>? list, DateTime t) =>
    list?.where((e) => e.isOn(t)).firstOrNull;

EpgEntry? nextOf(List<EpgEntry>? list, DateTime t) =>
    list?.where((e) => e.start.isAfter(t)).firstOrNull;

/// HH:mm in the viewer's local time.
String clock(DateTime t) {
  final l = t.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}
