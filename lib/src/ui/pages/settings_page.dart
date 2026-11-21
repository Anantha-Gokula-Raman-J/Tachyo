import 'package:flutter/material.dart';

import '../../app_info.dart';
import '../../core/format.dart';
import '../../state/meter_controller.dart';
import '../theme/astryx_tokens.dart';
import '../widgets/app_logo.dart';
import '../widgets/widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.controller});
  final MeterController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final p = c.platform;
    final t = AstryxTokens.of(context);
    final s = c.settings;

    return ListView(
      padding: const EdgeInsets.all(AstryxTokens.space4),
      children: [
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionLabel('Units'),
            const SizedBox(height: AstryxTokens.space3),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<SpeedUnit>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: SpeedUnit.bits, label: Text('Bits  (Kbps, Mbps)')),
                  ButtonSegment(value: SpeedUnit.bytes, label: Text('Bytes  (KB/s, MB/s)')),
                ],
                selected: {s.unit},
                onSelectionChanged: (v) => c.updateSettings(s.copyWith(unit: v.first)),
              ),
            ),
            const SizedBox(height: AstryxTokens.space4),
            const SectionLabel('Speed format'),
            const SizedBox(height: AstryxTokens.space1),
            Text(
              s.scale == SpeedScale.auto
                  ? 'Auto switches between ${scaleLabel(SpeedScale.base, s.unit)}, '
                      '${scaleLabel(SpeedScale.kilo, s.unit)} and ${scaleLabel(SpeedScale.mega, s.unit)} by size.'
                  : 'Every speed is shown in ${scaleLabel(s.scale, s.unit)}.',
              style: TextStyle(fontSize: 12, color: t.textSecondary),
            ),
            const SizedBox(height: AstryxTokens.space3),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<SpeedScale>(
                key: const Key('scale-picker'),
                showSelectedIcon: false,
                segments: [
                  for (final scale in SpeedScale.values)
                    ButtonSegment(value: scale, label: Text(scaleLabel(scale, s.unit))),
                ],
                selected: {s.scale},
                onSelectionChanged: (v) => c.updateSettings(s.copyWith(scale: v.first)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: AstryxTokens.space3),
        Panel(
          padding: const EdgeInsets.symmetric(vertical: AstryxTokens.space2),
          child: Column(children: [
            if (!p.meterAlwaysOn)
              SwitchListTile(
                title: Text(p.meterLabel),
                subtitle: Text(p.meterDescription),
                value: c.meterRunning,
                onChanged: c.setMeterEnabled,
              ),
            if (p.supportsFloating) ...[
              SwitchListTile(
                key: const Key('floating-switch'),
                title: const Text('Floating meter'),
                subtitle: const Text('Small see-through speed strip on the desktop. Drag to move, '
                    'double-click to open Tachyo, right-click for the menu.'),
                value: s.floatingMeter,
                onChanged: (v) => c.updateSettings(s.copyWith(floatingMeter: v)),
              ),
              SwitchListTile(
                title: const Text('Keep floating meter on top'),
                subtitle: const Text('Stay in front of other windows (hidden during full-screen apps)'),
                value: s.alwaysOnTop,
                onChanged: s.floatingMeter ? (v) => c.updateSettings(s.copyWith(alwaysOnTop: v)) : null,
              ),
            ],
            if (p.supportsBootStart)
              SwitchListTile(
                key: const Key('boot-switch'),
                title: Text(p.bootStartLabel),
                subtitle: Text(p.bootStartDescription),
                value: s.bootStart,
                onChanged: (v) => c.updateSettings(s.copyWith(bootStart: v)),
              ),
            if (p.meterAlwaysOn)
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: Text(p.meterLabel),
                subtitle: const Text('Closing the window keeps Tachyo running in the tray. '
                    'To quit, right-click the tray icon and choose Exit.'),
              ),
          ]),
        ),
        const SizedBox(height: AstryxTokens.space3),
        Panel(
          child: Row(children: [
            const AppLogo(size: 48),
            const SizedBox(width: AstryxTokens.space3),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(AppInfo.name, style: TextStyle(fontWeight: FontWeight.w600, color: t.textPrimary)),
                Text('${AppInfo.tagline} · v${AppInfo.version}',
                    style: TextStyle(fontSize: 12, color: t.textSecondary)),
                Text(AppInfo.license, style: TextStyle(fontSize: 12, color: t.textSecondary)),
              ]),
            ),
            TextButton(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: AppInfo.name,
                applicationVersion: AppInfo.version,
                applicationLegalese: '© ${AppInfo.year} ${AppInfo.authors} · MIT License\n'
                    'Free, no ads, no accounts. Usage data stays on your device; only a '
                    'speed test you start talks to a test server.',
              ),
              child: const Text('Licenses'),
            ),
          ]),
        ),
      ],
    );
  }
}
