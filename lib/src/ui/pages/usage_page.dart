import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../state/meter_controller.dart';
import '../theme/astryx_tokens.dart';
import '../widgets/widgets.dart';

class UsagePage extends StatelessWidget {
  const UsagePage({super.key, required this.controller});
  final MeterController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final t = AstryxTokens.of(context);
    final days = c.days;
    final week = _sum(days.take(7));
    final month = _sum(days);
    final maxDay = days.fold<int>(0, (m, d) => math.max(m, d.total));
    final p = c.platform;
    final paused = !c.meterRunning && p.hasMobile;

    return RefreshIndicator(
      onRefresh: c.refreshUsage,
      child: ListView(
        padding: const EdgeInsets.all(AstryxTokens.space4),
        children: [
          Row(children: [
            Expanded(child: _Total(label: 'Last 7 days', usage: week)),
            const SizedBox(width: AstryxTokens.space3),
            Expanded(child: _Total(label: 'Last 30 days', usage: month)),
          ]),
          if (paused) ...[
            const SizedBox(height: AstryxTokens.space3),
            Panel(
              child: Text(
                'Usage is counted while Tachyo is open. Turn on the ${p.meterLabel.toLowerCase()} to count it in the background too.',
                style: TextStyle(fontSize: 13, color: t.textSecondary),
              ),
            ),
          ],
          const SizedBox(height: AstryxTokens.space3),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: AstryxTokens.space4, vertical: AstryxTokens.space3),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const SectionLabel('Daily'),
                const Spacer(),
                _Key(color: t.download, text: 'Wi‑Fi'),
                const SizedBox(width: AstryxTokens.space3),
                _Key(color: p.hasMobile ? t.upload : t.textSecondary, text: p.hasMobile ? 'Mobile' : p.otherLabel),
              ]),
              const SizedBox(height: AstryxTokens.space2),
              for (final d in days) _DayBar(day: d, maxDay: maxDay, hasMobile: p.hasMobile),
            ]),
          ),
        ],
      ),
    );
  }

  static DailyUsage _sum(Iterable<DailyUsage> days) {
    final total = DailyUsage(date: 'sum');
    for (final d in days) {
      total.add(UsageDelta(
        wifiRx: d.wifiRx,
        wifiTx: d.wifiTx,
        mobileRx: d.mobileRx,
        mobileTx: d.mobileTx,
        otherRx: d.otherRx,
        otherTx: d.otherTx,
      ));
    }
    return total;
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.usage});
  final String label;
  final DailyUsage usage;

  @override
  Widget build(BuildContext context) {
    final t = AstryxTokens.of(context);
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionLabel(label),
        const SizedBox(height: AstryxTokens.space2),
        Text(formatBytes(usage.total),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: t.textPrimary, fontFeatures: tabular)),
        const SizedBox(height: AstryxTokens.space1),
        Text('↓ ${formatBytes(usage.totalRx)}  ↑ ${formatBytes(usage.totalTx)}',
            style: TextStyle(fontSize: 12, color: t.textSecondary, fontFeatures: tabular)),
      ]),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: AstryxTokens.space1),
        Text(text, style: TextStyle(fontSize: 12, color: AstryxTokens.of(context).textSecondary)),
      ]);
}

class _DayBar extends StatelessWidget {
  const _DayBar({required this.day, required this.maxDay, required this.hasMobile});
  final DailyUsage day;
  final int maxDay;
  final bool hasMobile;

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  String get _label {
    final parts = day.date.split('-');
    if (parts.length != 3) return day.date;
    final m = int.tryParse(parts[1]) ?? 1;
    return '${int.tryParse(parts[2]) ?? 0} ${_months[(m - 1).clamp(0, 11)]}';
  }

  @override
  Widget build(BuildContext context) {
    final t = AstryxTokens.of(context);
    final second = hasMobile ? day.mobile : day.other;
    final secondColor = hasMobile ? t.upload : t.textSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        SizedBox(width: 52, child: Text(_label, style: TextStyle(fontSize: 12, color: t.textSecondary))),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth;
            double frac(int v) => maxDay <= 0 ? 0 : v / maxDay;
            return ClipRRect(
              borderRadius: BorderRadius.circular(AstryxTokens.radiusInner),
              child: Container(
                height: 10,
                color: t.backgroundMuted,
                child: Row(children: [
                  Container(width: w * frac(day.wifi), color: t.download),
                  Container(width: w * frac(second), color: secondColor),
                ]),
              ),
            );
          }),
        ),
        SizedBox(
          width: 76,
          child: Text(formatBytes(day.total),
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12, color: t.textPrimary, fontFeatures: tabular)),
        ),
      ]),
    );
  }
}
