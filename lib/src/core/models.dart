// Core value types shared by every layer. Pure Dart: no Flutter imports, so
// they stay unit-testable and identical on Android and Windows.

/// Cumulative byte counters read from the OS since boot.
///
/// `rx`/`tx` are totals over every counted interface. The per-category
/// counters are subsets of the totals; whatever is left over is "other"
/// (Ethernet on Windows, never used on Android where everything that is not
/// mobile is reported as Wi-Fi).
class NetCounters {
  const NetCounters({
    required this.rx,
    required this.tx,
    this.wifiRx = 0,
    this.wifiTx = 0,
    this.mobileRx = 0,
    this.mobileTx = 0,
    required this.timestampMs,
  });

  final int rx;
  final int tx;
  final int wifiRx;
  final int wifiTx;
  final int mobileRx;
  final int mobileTx;
  final int timestampMs;

  int get otherRx => _nonNegative(rx - wifiRx - mobileRx);
  int get otherTx => _nonNegative(tx - wifiTx - mobileTx);

  factory NetCounters.fromMap(Map<Object?, Object?> map) {
    int read(String key) => (map[key] as num?)?.toInt() ?? 0;
    return NetCounters(
      rx: read('rx'),
      tx: read('tx'),
      wifiRx: read('wifiRx'),
      wifiTx: read('wifiTx'),
      mobileRx: read('mobileRx'),
      mobileTx: read('mobileTx'),
      timestampMs: read('t'),
    );
  }
}

/// One speed reading, in bytes per second.
class SpeedSample {
  const SpeedSample({required this.downBps, required this.upBps, required this.at});

  static final SpeedSample zero =
      SpeedSample(downBps: 0, upBps: 0, at: DateTime.fromMillisecondsSinceEpoch(0));

  final double downBps;
  final double upBps;
  final DateTime at;
}

/// Bytes transferred in one interval, split by connection category.
class UsageDelta {
  const UsageDelta({
    this.wifiRx = 0,
    this.wifiTx = 0,
    this.mobileRx = 0,
    this.mobileTx = 0,
    this.otherRx = 0,
    this.otherTx = 0,
  });

  final int wifiRx;
  final int wifiTx;
  final int mobileRx;
  final int mobileTx;
  final int otherRx;
  final int otherTx;

  bool get isEmpty =>
      wifiRx == 0 && wifiTx == 0 && mobileRx == 0 && mobileTx == 0 && otherRx == 0 && otherTx == 0;

  Map<String, int> toMap() => {
        'wifiRx': wifiRx,
        'wifiTx': wifiTx,
        'mobileRx': mobileRx,
        'mobileTx': mobileTx,
        'otherRx': otherRx,
        'otherTx': otherTx,
      };
}

/// Bytes used on one calendar day (local time), keyed by `yyyy-MM-dd`.
class DailyUsage {
  DailyUsage({
    required this.date,
    this.wifiRx = 0,
    this.wifiTx = 0,
    this.mobileRx = 0,
    this.mobileTx = 0,
    this.otherRx = 0,
    this.otherTx = 0,
  });

  final String date;
  int wifiRx;
  int wifiTx;
  int mobileRx;
  int mobileTx;
  int otherRx;
  int otherTx;

  int get wifi => wifiRx + wifiTx;
  int get mobile => mobileRx + mobileTx;
  int get other => otherRx + otherTx;
  int get totalRx => wifiRx + mobileRx + otherRx;
  int get totalTx => wifiTx + mobileTx + otherTx;
  int get total => totalRx + totalTx;

  void add(UsageDelta d) {
    wifiRx += d.wifiRx;
    wifiTx += d.wifiTx;
    mobileRx += d.mobileRx;
    mobileTx += d.mobileTx;
    otherRx += d.otherRx;
    otherTx += d.otherTx;
  }

  DailyUsage copy() => DailyUsage(
        date: date,
        wifiRx: wifiRx,
        wifiTx: wifiTx,
        mobileRx: mobileRx,
        mobileTx: mobileTx,
        otherRx: otherRx,
        otherTx: otherTx,
      );

  Map<String, Object> toMap() => {
        'date': date,
        'wifiRx': wifiRx,
        'wifiTx': wifiTx,
        'mobileRx': mobileRx,
        'mobileTx': mobileTx,
        'otherRx': otherRx,
        'otherTx': otherTx,
      };

  factory DailyUsage.fromMap(Map<Object?, Object?> map) {
    int read(String key) => (map[key] as num?)?.toInt() ?? 0;
    return DailyUsage(
      date: map['date'] as String? ?? '',
      wifiRx: read('wifiRx'),
      wifiTx: read('wifiTx'),
      mobileRx: read('mobileRx'),
      mobileTx: read('mobileTx'),
      otherRx: read('otherRx'),
      otherTx: read('otherTx'),
    );
  }
}

/// Local calendar day key, `yyyy-MM-dd`. Shared contract with the Android
/// service (UsageStore.dayKey) so both writers hit the same record.
String dayKey(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year.toString().padLeft(4, '0')}-${two(t.month)}-${two(t.day)}';
}

int _nonNegative(int v) => v < 0 ? 0 : v;
