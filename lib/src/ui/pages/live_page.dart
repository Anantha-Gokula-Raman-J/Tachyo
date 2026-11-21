import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../state/meter_controller.dart';
import '../theme/astryx_tokens.dart';
import '../widgets/widgets.dart';

class LivePage extends StatelessWidget {
  const LivePage({super.key, required this.controller});
  final MeterController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final t = AstryxTokens.of(context);
    final p = c.platform;
    final today = c.today;
    final unit = c.settings.unit;

    return ListView(
      padding: const EdgeInsets.all(AstryxTokens.space4),
      children: [
        if (c.error != null) ...[
          Panel(
            child: Text(c.error!, style: TextStyle(color: t.error)),
          ),
          const SizedBox(height: AstryxTokens.space3),
        ],
        LayoutBuilder(
          builder: (context, box) {
            final down = SpeedTile(
              key: const Key('download-tile'),
              label: 'Download',
              icon: Icons.south_rounded,
              color: t.download,
              muted: t.downloadMuted,
              bytesPerSecond: c.current.downBps,
              unit: unit,
              peak: c.peakDown,
              scale: c.settings.scale,
            );
            final up = SpeedTile(
              key: const Key('upload-tile'),
              label: 'Upload',
              icon: Icons.north_rounded,
              color: t.upload,
              muted: t.uploadMuted,
              bytesPerSecond: c.current.upBps,
              unit: unit,
              peak: c.peakUp,
              scale: c.settings.scale,
            );
            return Row(
              children: [
                Expanded(child: down),
                const SizedBox(width: AstryxTokens.space3),
                Expanded(child: up),
              ],
            );
          },
        ),
        const SizedBox(height: AstryxTokens.space3),
        Panel(
          child: SpeedChart(samples: c.history, capacity: MeterController.historyLength, unit: unit),
        ),
        const SizedBox(height: AstryxTokens.space3),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SectionLabel('Today'),
                  const Spacer(),
                  Text(
                    formatBytes(today.total),
                    style: TextStyle(fontWeight: FontWeight.w600, color: t.textPrimary, fontFeatures: tabular),
                  ),
                ],
              ),
              const SizedBox(height: AstryxTokens.space1),
              UsageRow(label: 'Wi‑Fi', icon: Icons.wifi_rounded, rx: today.wifiRx, tx: today.wifiTx),
              if (p.hasMobile)
                UsageRow(
                  label: 'Mobile',
                  icon: Icons.signal_cellular_alt_rounded,
                  rx: today.mobileRx,
                  tx: today.mobileTx,
                ),
              if (!p.hasMobile || today.other > 0)
                UsageRow(
                  label: p.otherLabel,
                  icon: Icons.settings_ethernet_rounded,
                  rx: today.otherRx,
                  tx: today.otherTx,
                ),
            ],
          ),
        ),
        const SizedBox(height: AstryxTokens.space3),
        Panel(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionLabel('This session'),
                    const SizedBox(height: AstryxTokens.space1),
                    Text(
                      '↓ ${formatBytes(c.sessionRx)}   ↑ ${formatBytes(c.sessionTx)}',
                      style: TextStyle(color: t.textPrimary, fontFeatures: tabular),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: c.resetSession, child: const Text('Reset')),
            ],
          ),
        ),
        const SizedBox(height: AstryxTokens.space3),
        if (!p.meterAlwaysOn) _MeterBanner(controller: c),
      ],
    );
  }
}

class _MeterBanner extends StatelessWidget {
  const _MeterBanner({required this.controller});
  final MeterController controller;

  @override
  Widget build(BuildContext context) {
    final t = AstryxTokens.of(context);
    final p = controller.platform;
    final on = controller.meterRunning;
    // The whole card toggles: accessibility merges it into one switch node, so
    // a tap anywhere (TalkBack, tests, fingers) must work, not only the thumb.
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => controller.setMeterEnabled(!on),
        child: Padding(
          padding: const EdgeInsets.all(AstryxTokens.space4),
          child: _content(t, p.meterLabel, on ? 'Running' : p.meterDescription, on),
        ),
      ),
    );
  }

  Widget _content(AstryxTokens t, String label, String subtitle, bool on) {
    return Row(
      children: [
        Icon(on ? Icons.speed_rounded : Icons.speed_outlined, color: on ? t.download : t.textSecondary),
        const SizedBox(width: AstryxTokens.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontWeight: FontWeight.w600, color: t.textPrimary),
              ),
              Text(subtitle, style: TextStyle(fontSize: 12, color: t.textSecondary)),
            ],
          ),
        ),
        Switch(key: const Key('meter-switch'), value: on, onChanged: controller.setMeterEnabled),
      ],
    );
  }
}
