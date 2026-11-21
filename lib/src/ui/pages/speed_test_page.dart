import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../speedtest/models.dart';
import '../../speedtest/speed_test_controller.dart';
import '../../state/meter_controller.dart';
import '../theme/astryx_tokens.dart';
import '../widgets/widgets.dart';

/// Internet speed test: latency, download and upload against a public test
/// server, with a dial, the four results and a history of past runs.
class SpeedTestPage extends StatefulWidget {
  const SpeedTestPage({super.key, required this.controller, required this.meter});
  final SpeedTestController controller;

  /// For the user's bits/bytes choice.
  final MeterController meter;

  @override
  State<SpeedTestPage> createState() => _SpeedTestPageState();
}

class _SpeedTestPageState extends State<SpeedTestPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final c = widget.controller;
    final t = AstryxTokens.of(context);
    final unit = widget.meter.settings.unit;
    final p = c.progress;
    final uploading = p.phase == SpeedTestPhase.upload;
    final tone = uploading ? t.upload : t.download;

    // Speed tests are read in one unit (Mbps or MB/s) so runs compare easily.
    FormattedValue speed(double bps) => formatSpeed(bps, unit, SpeedScale.mega);
    // While running: the live speed. Afterwards the dial rests on the download result.
    final shown = p.running ? p.currentBps : (p.phase == SpeedTestPhase.done ? (p.downBps ?? 0) : 0.0);
    final live = speed(shown);

    return ListView(
      padding: const EdgeInsets.all(AstryxTokens.space4),
      children: [
        Panel(
          child: Column(children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: AspectRatio(
                  aspectRatio: 1.15,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: _dialValue(shown, unit)),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    builder: (context, value, _) => Stack(children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: SpeedDialPainter(
                            value: value,
                            stops: _stops(unit),
                            color: tone,
                            track: t.backgroundMuted,
                            labelColor: t.textSecondary,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const SizedBox(height: AstryxTokens.space4),
                          Text(
                            live.value,
                            key: const Key('dial-value'),
                            style: TextStyle(
                                fontSize: 44,
                                height: 1,
                                fontWeight: FontWeight.w600,
                                color: t.textPrimary,
                                fontFeatures: tabular),
                          ),
                          const SizedBox(height: AstryxTokens.space1),
                          Text(live.unit, style: TextStyle(fontSize: 13, color: t.textSecondary)),
                          // Other speed tests report megabits: show that too in bytes mode.
                          if (unit == SpeedUnit.bytes && shown > 0)
                            Text(
                              '= ${formatSpeed(shown, SpeedUnit.bits, SpeedScale.mega).value} Mbps',
                              key: const Key('dial-mbps'),
                              style: TextStyle(fontSize: 12, color: t.textSecondary, fontFeatures: tabular),
                            ),
                          const SizedBox(height: AstryxTokens.space2),
                          if (p.running)
                            Icon(uploading ? Icons.north_rounded : Icons.south_rounded, size: 18, color: tone),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AstryxTokens.space2),
            Text(
              _status(p),
              key: const Key('test-status'),
              textAlign: TextAlign.center,
              style: TextStyle(color: p.phase == SpeedTestPhase.error ? t.error : t.textSecondary),
            ),
            if (p.running) ...[
              const SizedBox(height: AstryxTokens.space2),
              LinearProgressIndicator(
                value: _overall(p),
                minHeight: 3,
                color: tone,
                backgroundColor: t.backgroundMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ],
            const SizedBox(height: AstryxTokens.space3),
            SizedBox(
              width: 200,
              child: c.running
                  ? OutlinedButton.icon(
                      key: const Key('test-cancel'),
                      onPressed: c.cancel,
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('Cancel'),
                    )
                  : FilledButton.icon(
                      key: const Key('test-start'),
                      onPressed: c.start,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(p.phase == SpeedTestPhase.idle ? 'Start test' : 'Test again'),
                    ),
            ),
          ]),
        ),
        const SizedBox(height: AstryxTokens.space3),
        Row(children: [
          Expanded(child: _Metric(label: 'Ping', value: _ms(p.pingMs), unit: 'ms', icon: Icons.timer_outlined)),
          const SizedBox(width: AstryxTokens.space2),
          Expanded(child: _Metric(label: 'Jitter', value: _ms(p.jitterMs), unit: 'ms', icon: Icons.swap_vert_rounded)),
        ]),
        const SizedBox(height: AstryxTokens.space2),
        Row(children: [
          Expanded(
            child: _Metric(
              label: 'Download',
              value: p.downBps == null ? '–' : speed(p.downBps!).value,
              unit: speed(0).unit,
              icon: Icons.south_rounded,
              color: t.download,
            ),
          ),
          const SizedBox(width: AstryxTokens.space2),
          Expanded(
            child: _Metric(
              label: 'Upload',
              value: p.upBps == null ? '–' : speed(p.upBps!).value,
              unit: speed(0).unit,
              icon: Icons.north_rounded,
              color: t.upload,
            ),
          ),
        ]),
        const SizedBox(height: AstryxTokens.space4),
        Row(children: [
          const Expanded(child: SectionLabel('History')),
          if (c.results.isNotEmpty) TextButton(onPressed: c.running ? null : c.clearHistory, child: const Text('Clear')),
        ]),
        const SizedBox(height: AstryxTokens.space2),
        if (c.results.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AstryxTokens.space3),
            child: Text('No tests yet.', style: TextStyle(color: t.textSecondary)),
          )
        else
          Panel(
            padding: const EdgeInsets.symmetric(vertical: AstryxTokens.space1),
            child: Column(children: [
              for (final r in c.results.take(20))
                ListTile(
                  dense: true,
                  title: Text(
                    '↓ ${speed(r.downBps)}    ↑ ${speed(r.upBps)}',
                    style: TextStyle(color: t.textPrimary, fontFeatures: tabular),
                  ),
                  subtitle: Text(
                    '${_date(r.time)} · ping ${_ms(r.pingMs)} ms'
                    '${r.server.isEmpty ? '' : ' · ${r.server}'} · ${formatBytes(r.bytesUsed)}'
                    '${r.network.isEmpty ? '' : '\n${r.network}'}',
                    style: TextStyle(color: t.textSecondary, fontSize: 12),
                  ),
                ),
            ]),
          ),
        const SizedBox(height: AstryxTokens.space4),
        Text(
          'Tests run against Cloudflare\'s public speed test servers (speed.cloudflare.com), which see your '
          'IP address like any website; the provider name comes from that address, so no location '
          'permission is needed. Ping is the lowest of 20 round trips. A test moves roughly 50–500 MB depending on your speed; on mobile '
          'data it counts toward your plan.',
          style: TextStyle(fontSize: 12, color: t.textSecondary),
        ),
      ],
    );
  }

  static String _status(SpeedTestProgress p) {
    switch (p.phase) {
      case SpeedTestPhase.idle:
        return 'Measure ping, download and upload speed.';
      case SpeedTestPhase.latency:
        return 'Measuring latency…';
      case SpeedTestPhase.download:
        return 'Testing download…';
      case SpeedTestPhase.upload:
        return 'Testing upload…';
      case SpeedTestPhase.done:
        final where = p.server.isEmpty ? '' : 'Server ${p.server} · ';
        final network = p.network.isEmpty ? '' : '\n${p.network}';
        return '${where}used ${formatBytes(p.bytesUsed)}$network';
      case SpeedTestPhase.error:
        return p.error ?? 'The test failed.';
    }
  }

  /// Whole-test progress: latency 10 %, download 50 %, upload 40 %.
  static double _overall(SpeedTestProgress p) => switch (p.phase) {
        SpeedTestPhase.latency => 0.1 * p.phaseFraction,
        SpeedTestPhase.download => 0.1 + 0.5 * p.phaseFraction,
        SpeedTestPhase.upload => 0.6 + 0.4 * p.phaseFraction,
        _ => 1,
      };

  static String _ms(double? v) => v == null ? '–' : (v < 10 ? v.toStringAsFixed(1) : v.round().toString());

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static String _date(DateTime d) =>
      '${d.day} ${_months[d.month - 1]}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// Dial scale in the display unit (Mbps or MB/s).
  static List<double> _stops(SpeedUnit unit) => unit == SpeedUnit.bits
      ? const [0, 1, 5, 10, 20, 50, 100, 250, 500, 1000]
      : const [0, 0.1, 0.5, 1, 2.5, 5, 10, 25, 50, 100];

  static double _dialValue(double bps, SpeedUnit unit) =>
      unit == SpeedUnit.bits ? bps * 8 / 1e6 : bps / (1024 * 1024);
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.unit, required this.icon, this.color});
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = AstryxTokens.of(context);
    return Panel(
      padding: const EdgeInsets.all(AstryxTokens.space3),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: color ?? t.textSecondary),
          const SizedBox(width: AstryxTokens.space1),
          Text(label, style: TextStyle(fontSize: 12, color: t.textSecondary)),
        ]),
        const SizedBox(height: AstryxTokens.space1),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(value,
              key: Key('metric-$label'),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: t.textPrimary, fontFeatures: tabular)),
          const SizedBox(width: AstryxTokens.space1),
          Text(unit, style: TextStyle(fontSize: 12, color: t.textSecondary)),
        ]),
      ]),
    );
  }
}

/// 270° dial with a non-linear scale (equal spacing between [stops]), the
/// same arc geometry as the app logo.
class SpeedDialPainter extends CustomPainter {
  SpeedDialPainter({
    required this.value,
    required this.stops,
    required this.color,
    required this.track,
    required this.labelColor,
  });

  final double value;
  final List<double> stops;
  final Color color;
  final Color track;
  final Color labelColor;

  static const _start = math.pi * 0.75;
  static const _sweep = math.pi * 1.5;

  /// 0..1 position of [v] on the dial.
  static double fraction(double v, List<double> stops) {
    if (v <= stops.first) return 0;
    for (var i = 1; i < stops.length; i++) {
      if (v <= stops[i]) {
        final local = (v - stops[i - 1]) / (stops[i] - stops[i - 1]);
        return (i - 1 + local) / (stops.length - 1);
      }
    }
    return 1;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.min(size.width / 2, size.height / 1.7) * 0.92;
    final center = Offset(size.width / 2, size.height * 0.53);
    final stroke = radius * 0.1;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, _start, _sweep, false, base..color = track);
    final f = fraction(value, stops);
    if (f > 0) {
      canvas.drawArc(rect, _start, _sweep * f, false, base..color = color);
    }

    // Scale labels inside the arc.
    for (var i = 0; i < stops.length; i++) {
      final angle = _start + _sweep * i / (stops.length - 1);
      final at = center + Offset(math.cos(angle), math.sin(angle)) * (radius - stroke * 1.9);
      final s = stops[i];
      final text = s == s.roundToDouble() ? s.round().toString() : s.toString();
      final tp = TextPainter(
        text: TextSpan(text: text, style: TextStyle(fontSize: radius * 0.075, color: labelColor)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(SpeedDialPainter old) =>
      old.value != value || old.color != color || old.track != track || old.stops != stops;
}
