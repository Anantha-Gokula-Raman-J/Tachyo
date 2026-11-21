import 'dart:convert';
import 'dart:io';

import 'models.dart';

/// Saved speed test results, newest first.
abstract class SpeedTestHistory {
  static const keep = 50;

  Future<List<SpeedTestResult>> load();
  Future<void> add(SpeedTestResult result);
  Future<void> clear();
}

/// JSON file. The file is resolved lazily because on Android its folder
/// comes from the platform channel.
class FileSpeedTestHistory implements SpeedTestHistory {
  FileSpeedTestHistory(File file) : _resolve = (() async => file);
  FileSpeedTestHistory.lazy(this._resolve);

  final Future<File> Function() _resolve;

  @override
  Future<List<SpeedTestResult>> load() async {
    try {
      final file = await _resolve();
      if (!await file.exists()) return [];
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return [];
      return decoded.map(SpeedTestResult.fromMap).whereType<SpeedTestResult>().toList();
    } on Object {
      return []; // unreadable history never blocks a test
    }
  }

  @override
  Future<void> add(SpeedTestResult result) async {
    final all = [result, ...await load()].take(SpeedTestHistory.keep).toList();
    await _write(all);
  }

  @override
  Future<void> clear() => _write(const []);

  Future<void> _write(List<SpeedTestResult> all) async {
    final file = await _resolve();
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode([for (final r in all) r.toMap()]));
    await tmp.rename(file.path);
  }
}

class MemorySpeedTestHistory implements SpeedTestHistory {
  final List<SpeedTestResult> items = [];

  @override
  Future<List<SpeedTestResult>> load() async => List.of(items);

  @override
  Future<void> add(SpeedTestResult result) async {
    items.insert(0, result);
    if (items.length > SpeedTestHistory.keep) items.removeLast();
  }

  @override
  Future<void> clear() async => items.clear();
}
