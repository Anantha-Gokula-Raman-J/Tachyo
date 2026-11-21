import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../theme/astryx_tokens.dart';

const tabular = [FontFeature.tabularFigures()];

/// Card with an Astryx container radius and hairline border.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(AstryxTokens.space4)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: padding, child: child));
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = AstryxTokens.of(context);
    return Text(
      text.toUpperCase(),
      style: TextStyle(fontSize: 11, letterSpacing: 0.8, fontWeight: FontWeight.w600, color: t.textSecondary),
    );
  }
}

/// Big live value for one direction.
class SpeedTile extends StatelessWidget {
  const SpeedTile({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.muted,
    required this.bytesPerSecond,
    required this.unit,
    required this.peak,
    this.scale = SpeedScale.auto,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color muted;
  final double bytesPerSecond;
  final SpeedUnit unit;
  final double peak;
  final SpeedScale scale;

  @override
  Widget build(BuildContext context) {
    final t = AstryxTokens.of(context);
    final f = formatSpeed(bytesPerSecond, unit, scale);
    final p = formatSpeed(peak, unit, scale);
    return Semantics(
      label: '$label ${f.value} ${f.unit}',
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(AstryxTokens.space1),
                decoration: BoxDecoration(color: muted, borderRadius: BorderRadius.circular(AstryxTokens.radiusInner)),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: AstryxTokens.space2),
              Text(label, style: TextStyle(color: t.textSecondary, fontWeight: FontWeight.w500)),
            ]),
            const SizedBox(height: AstryxTokens.space3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(f.value,
                      style: TextStyle(
                          fontSize: 40, height: 1, fontWeight: FontWeight.w600, color: t.textPrimary, fontFeatures: tabular)),
                  const SizedBox(width: AstryxTokens.space1),
                  Text(f.unit, style: TextStyle(fontSize: 15, color: t.textSecondary, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(height: AstryxTokens.space2),
            Text('Peak $p', style: TextStyle(fontSize: 12, color: t.textSecondary, fontFeatures: tabular)),
          ],
        ),
      ),
    );
  }
}

/// Two-series line chart of the last N samples (download + upload).
class SpeedChart extends StatelessWidget {
  const SpeedChart({super.key, required this.samples, required this.capacity, required this.unit});
  final List<SpeedSample> samples;
  final int capacity;
  final SpeedUnit unit;

  @override
  Widget build(BuildContext context) {
    final t = AstryxTokens.of(context);
    final maxV = samples.fold<double>(0, (m, s) => math.max(m, math.max(s.downBps, s.upBps)));
    final top = formatSpeed(maxV, unit);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const SectionLabel('Last 60 seconds'),
          const Spacer(),
          Text('max $top', style: TextStyle(fontSize: 12, color: t.textSecondary, fontFeatures: tabular)),
        ]),
        const SizedBox(height: AstryxTokens.space3),
        SizedBox(
          height: 120,
          child: CustomPaint(
            size: Size.infinite,
            painter: _ChartPainter(samples, capacity, maxV, t),
          ),
        ),
        const SizedBox(height: AstryxTokens.space2),
        Row(children: [
          _Legend(color: t.download, text: 'Download'),
          const SizedBox(width: AstryxTokens.space4),
          _Legend(color: t.upload, text: 'Upload'),
        ]),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 3, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: AstryxTokens.space1),
        Text(text, style: TextStyle(fontSize: 12, color: AstryxTokens.of(context).textSecondary)),
      ]);
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.samples, this.capacity, this.maxV, this.t);
  final List<SpeedSample> samples;
  final int capacity;
  final double maxV;
  final AstryxTokens t;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = t.border
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (samples.length < 2 || maxV <= 0) return;
    final scale = maxV * 1.15;
    final step = size.width / math.max(1, capacity - 1);
    final start = size.width - step * (samples.length - 1);

    void series(double Function(SpeedSample) pick, Color color) {
      final path = Path();
      for (var i = 0; i < samples.length; i++) {
        final x = start + step * i;
        final y = size.height - (pick(samples[i]) / scale) * size.height;
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      final fill = Path.from(path)
        ..lineTo(start + step * (samples.length - 1), size.height)
        ..lineTo(start, size.height)
        ..close();
      canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.12));
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
    }

    series((s) => s.upBps, t.upload);
    series((s) => s.downBps, t.download);
  }

  @override
  bool shouldRepaint(_ChartPainter old) => true;
}

/// Label + value row used in usage summaries.
class UsageRow extends StatelessWidget {
  const UsageRow({super.key, required this.label, required this.rx, required this.tx, this.icon});
  final String label;
  final int rx;
  final int tx;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = AstryxTokens.of(context);
    final style = TextStyle(fontSize: 13, color: t.textSecondary, fontFeatures: tabular);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AstryxTokens.space2),
      child: Row(children: [
        if (icon != null) ...[Icon(icon, size: 18, color: t.textSecondary), const SizedBox(width: AstryxTokens.space2)],
        Expanded(child: Text(label, style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w500))),
        Text('↓ ${formatBytes(rx)}', style: style),
        const SizedBox(width: AstryxTokens.space3),
        Text('↑ ${formatBytes(tx)}', style: style),
        const SizedBox(width: AstryxTokens.space3),
        SizedBox(
          width: 76,
          child: Text(formatBytes(rx + tx),
              textAlign: TextAlign.right,
              style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w600, fontFeatures: tabular)),
        ),
      ]),
    );
  }
}
