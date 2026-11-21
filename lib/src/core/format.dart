// Speed and size formatting. The Android service (SpeedFormat.kt) mirrors
// formatSpeed/compactSpeed for the status-bar icon; keep both in step.

enum SpeedUnit { bytes, bits }

/// Display scale: [auto] picks B/s, KB/s or MB/s by size (default); the others
/// keep one unit (bits: bps, Kbps, Mbps). Stored as its index.
enum SpeedScale { auto, base, kilo, mega }

/// Unit label for a fixed scale, for settings UI ("KB/s" or "Kbps").
String scaleLabel(SpeedScale scale, SpeedUnit unit) => scale == SpeedScale.auto
    ? 'Auto'
    : (unit == SpeedUnit.bits ? _bitSpeedUnits : _byteSpeedUnits)[scale.index - 1];

class FormattedValue {
  const FormattedValue(this.value, this.unit);
  final String value;
  final String unit;

  @override
  String toString() => '$value $unit';
}

const _byteSpeedUnits = ['B/s', 'KB/s', 'MB/s', 'GB/s'];
const _bitSpeedUnits = ['bps', 'Kbps', 'Mbps', 'Gbps'];
const _sizeUnits = ['B', 'KB', 'MB', 'GB', 'TB'];

/// Bytes per second -> human value. Bytes use a 1024 base, bits a 1000 base
/// (the conventions people see in file managers and ISP plans respectively).
FormattedValue formatSpeed(double bytesPerSecond, SpeedUnit unit, [SpeedScale scale = SpeedScale.auto]) {
  final safe = bytesPerSecond.isFinite && bytesPerSecond > 0 ? bytesPerSecond : 0.0;
  final bits = unit == SpeedUnit.bits;
  final base = bits ? 1000.0 : 1024.0;
  final units = bits ? _bitSpeedUnits : _byteSpeedUnits;
  var v = bits ? safe * 8 : safe;
  var i = 0;
  if (scale != SpeedScale.auto) {
    i = scale.index - 1;
    for (var k = 0; k < i; k++) {
      v /= base;
    }
    return FormattedValue(bits ? _bitDecimals(v, i == 0) : _decimals(v, i == 0), units[i]);
  }
  while (v >= base && i < units.length - 1) {
    v /= base;
    i++;
  }
  // Promote 1000..1023 KB/s to "0.98 MB/s" style so values never show 4
  // digits; for bits also 999.95+ Kbps, which would round to "1000.0".
  if ((v >= 1000 || (bits && v >= 999.95)) && i < units.length - 1) {
    v /= base;
    i++;
  }
  return FormattedValue(bits ? _bitDecimals(v, i == 0) : _decimals(v, i == 0), units[i]);
}

/// Bits read like ISP plans and other meters: one decimal ("144.4 Mbps",
/// "103.3 Kbps"); plain bps and values of 1000+ (fixed scale) are whole numbers.
String _bitDecimals(double v, bool integerOnly) =>
    integerOnly || v >= 1000 ? v.round().toString() : v.toStringAsFixed(1);

/// At most three significant characters for the tiny status-bar / tray icon.
/// A fixed [scale] is kept while the value fits (< 1000); larger values fall
/// back to auto so the icon never needs more than three digits.
FormattedValue compactSpeed(double bytesPerSecond, SpeedUnit unit, [SpeedScale scale = SpeedScale.auto]) {
  var f = formatSpeed(bytesPerSecond, unit, scale);
  if ((double.tryParse(f.value) ?? 0) >= 1000) f = formatSpeed(bytesPerSecond, unit);
  final v = double.tryParse(f.value) ?? 0;
  final text = v >= 10 ? v.round().toString() : v.toStringAsFixed(1);
  final shortUnit = f.unit.replaceAll('/s', '').replaceAll('ps', '');
  return FormattedValue(text == '0.0' ? '0' : text, shortUnit);
}

/// Byte count -> "1.25 GB".
String formatBytes(int bytes) {
  var v = bytes < 0 ? 0.0 : bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < _sizeUnits.length - 1) {
    v /= 1024;
    i++;
  }
  return '${_decimals(v, i == 0)} ${_sizeUnits[i]}';
}

String _decimals(double v, bool integerOnly) {
  if (integerOnly) return v.round().toString();
  if (v < 10) return v.toStringAsFixed(2);
  if (v < 100) return v.toStringAsFixed(1);
  return v.round().toString();
}
