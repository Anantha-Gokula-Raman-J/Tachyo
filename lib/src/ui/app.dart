import 'package:flutter/material.dart';

import '../app_info.dart';
import '../speedtest/speed_test_controller.dart';
import '../state/meter_controller.dart';
import 'pages/live_page.dart';
import 'pages/settings_page.dart';
import 'pages/speed_test_page.dart';
import 'pages/usage_page.dart';
import 'theme/astryx_tokens.dart';
import 'widgets/app_logo.dart';

class TachyoApp extends StatelessWidget {
  const TachyoApp({super.key, required this.controller, required this.speedTest});
  final MeterController controller;
  final SpeedTestController speedTest;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => HomeShell(controller: controller, speedTest: speedTest),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller, required this.speedTest});
  final MeterController controller;
  final SpeedTestController speedTest;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      widget.controller.pause();
    }
    if (state == AppLifecycleState.resumed) widget.controller.refreshUsage();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final t = AstryxTokens.of(context);
    final pages = [
      LivePage(controller: c),
      UsagePage(controller: c),
      SpeedTestPage(controller: widget.speedTest, meter: c),
      SettingsPage(controller: c),
    ];
    const titles = ['Live', 'Usage', 'Speed test', 'Settings'];
    return Scaffold(
      appBar: AppBar(
        titleSpacing: AstryxTokens.space4,
        title: Row(children: [
          const AppLogo(size: 28),
          const SizedBox(width: AstryxTokens.space2),
          Text(AppInfo.name, style: TextStyle(fontWeight: FontWeight.w700, color: t.textPrimary)),
          const SizedBox(width: AstryxTokens.space2),
          Flexible(
            child: Text('· ${titles[_tab]}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: t.textSecondary, fontWeight: FontWeight.w400)),
          ),
        ]),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: c.ready ? pages[_tab] : const Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.speed_outlined), selectedIcon: Icon(Icons.speed_rounded), label: 'Live'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart_rounded), label: 'Usage'),
          NavigationDestination(
              icon: Icon(Icons.network_check_outlined),
              selectedIcon: Icon(Icons.network_check_rounded),
              label: 'Test'),
          NavigationDestination(
              icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune_rounded), label: 'Settings'),
        ],
      ),
    );
  }
}
