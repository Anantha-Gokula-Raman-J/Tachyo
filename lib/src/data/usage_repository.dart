import 'dart:convert';
import 'dart:io';

import '../core/models.dart';
import '../platform/native_bridge.dart';

/// Per-day usage history.
abstract class UsageRepository {
  /// The last [days] days ending [today], newest first. Missing days are
  /// returned as zero records so charts have no gaps.
  Future<List<DailyUsage>> recent(int days, DateTime today);

  Future<void> add(String date, UsageDelta delta);

  /// Persist anything buffered (called on app pause/exit).
  Future<void> flush();
}

const historyDays = 90;

List<DailyUsage> fillDays(Map<String, DailyUsage> byDate, int days, DateTime today) {
  final out = <DailyUsage>[];
  for (var i = 0; i < days; i++) {
    final key = dayKey(DateTime(today.year, today.month, today.day - i));
    out.add(byDate[key]?.copy() ?? DailyUsage(date: key));
  }
  return out;
}

/// Windows (and tests with a temp file): JSON map of date -> record.
/// Writes are buffered and flushed at most every [flushEvery] adds.
class FileUsageRepository implements UsageRepository {
  FileUsageRepository(this.file, {this.flushEvery = 10});

  final File file;
  final int flushEvery;
  Map<String, DailyUsage>? _cache;
  int _pending = 0;

  Future<Map<String, DailyUsage>> _load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final map = <String, DailyUsage>{};
    try {
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            if (entry.value is Map) {
              final record = DailyUsage.fromMap({...entry.value as Map, 'date': entry.key});
              map[record.date] = record;
            }
          }
        }
      }
    } on Object {
      // Corrupt history: start fresh rather than crash the meter.
    }
    return _cache = map;
  }

  @override
  Future<List<DailyUsage>> recent(int days, DateTime today) async =>
      fillDays(await _load(), days, today);

  @override
  Future<void> add(String date, UsageDelta delta) async {
    if (delta.isEmpty) return;
    final map = await _load();
    map.putIfAbsent(date, () => DailyUsage(date: date)).add(delta);
    if (++_pending >= flushEvery) await flush();
  }

  @override
  Future<void> flush() async {
    final map = _cache;
    if (map == null || _pending == 0) return;
    _pending = 0;
    final keys = map.keys.toList()..sort();
    while (keys.length > historyDays) {
      map.remove(keys.removeAt(0));
    }
    final json = {for (final k in keys) k: (map[k]!.toMap()..remove('date'))};
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(json));
    await tmp.rename(file.path); // atomic replace: no half-written history
  }
}

/// Android: the native UsageStore is the source of truth (shared with the
/// meter service).
class NativeUsageRepository implements UsageRepository {
  NativeUsageRepository(this._bridge);
  final NativeBridge _bridge;

  @override
  Future<List<DailyUsage>> recent(int days, DateTime today) async {
    final rows = await _bridge.dailyUsage(days);
    return fillDays({for (final r in rows) r.date: r}, days, today);
  }

  @override
  Future<void> add(String date, UsageDelta delta) async {
    if (delta.isEmpty) return;
    await _bridge.addUsage(date, delta);
  }

  @override
  Future<void> flush() async {}
}

class MemoryUsageRepository implements UsageRepository {
  final Map<String, DailyUsage> data = {};

  @override
  Future<List<DailyUsage>> recent(int days, DateTime today) async => fillDays(data, days, today);

  @override
  Future<void> add(String date, UsageDelta delta) async =>
      data.putIfAbsent(date, () => DailyUsage(date: date)).add(delta);

  @override
  Future<void> flush() async {}
}
