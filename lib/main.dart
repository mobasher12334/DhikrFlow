import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/history_entry.dart';
import 'screens/home_page.dart';
import 'services/audio_service.dart';
import 'services/haptic_service.dart';
import 'theme/app_theme.dart';

/// DhikrFlow entry point.
///
/// Initialisation order:
///   1. Flutter bindings
///   2. Hive database (opens 'history' box with [HistoryEntry] adapter)
///   3. [AudioService] (prepares low-latency player)
///   4. [HapticService] (queries device vibration capability)
///   5. Run app
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait mode for a focused tasbih experience
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Hive setup
  await Hive.initFlutter();
  Hive.registerAdapter(HistoryEntryAdapter());
  await Hive.openBox<HistoryEntry>('history');

  // Services
  await AudioService.instance.init();
  await HapticService.instance.init();

  runApp(const DhikrFlowApp());
}

class DhikrFlowApp extends StatelessWidget {
  const DhikrFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DhikrFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomePage(),
    );
  }
}
