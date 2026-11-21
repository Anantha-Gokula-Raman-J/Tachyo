import 'models.dart';

class SampleResult {
  const SampleResult(this.speed, this.delta);
  final SpeedSample speed;
  final UsageDelta delta;
}

/// Turns successive cumulative counters into speeds and usage deltas.
///
/// Returns null for the first reading, for a non-advancing clock, and when the
/// totals go backwards (reboot, adapter reset, counter wrap): that interval is
/// dropped rather than reported as a huge or negative spike.
class SpeedSampler {
  NetCounters? _last;

  void reset() => _last = null;

  SampleResult? push(NetCounters current) {
    final prev = _last;
    _last = current;
    if (prev == null) return null;
    final dtMs = current.timestampMs - prev.timestampMs;
    if (dtMs <= 0) return null;
    final dRx = current.rx - prev.rx;
    final dTx = current.tx - prev.tx;
    if (dRx < 0 || dTx < 0) return null;

    int pos(int v) => v < 0 ? 0 : v;
    final wifiRx = pos(current.wifiRx - prev.wifiRx);
    final wifiTx = pos(current.wifiTx - prev.wifiTx);
    final mobileRx = pos(current.mobileRx - prev.mobileRx);
    final mobileTx = pos(current.mobileTx - prev.mobileTx);
    final delta = UsageDelta(
      wifiRx: wifiRx,
      wifiTx: wifiTx,
      mobileRx: mobileRx,
      mobileTx: mobileTx,
      otherRx: pos(dRx - wifiRx - mobileRx),
      otherTx: pos(dTx - wifiTx - mobileTx),
    );
    final speed = SpeedSample(
      downBps: dRx * 1000 / dtMs,
      upBps: dTx * 1000 / dtMs,
      at: DateTime.fromMillisecondsSinceEpoch(current.timestampMs),
    );
    return SampleResult(speed, delta);
  }
}
