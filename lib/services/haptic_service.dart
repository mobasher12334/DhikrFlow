import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

/// Service wrapping the Vibration plugin with semantic patterns.
///
/// Two distinct patterns are used to build haptic vocabulary:
/// - [successCount]: a short crisp tap for each dhikr increment.
/// - [targetReached]: a rhythmic triple-burst for full target completion.
class HapticService {
  HapticService._();
  static final HapticService instance = HapticService._();

  bool _hasVibrator = false;

  /// Checks device capability once at startup.
  Future<void> init() async {
    try {
      _hasVibrator = (await Vibration.hasVibrator()) ?? false;
    } catch (e) {
      debugPrint('[HapticService] init error: $e');
    }
  }

  /// Fires a short 40 ms tap — called on every successful dhikr count.
  Future<void> successCount() async {
    if (!_hasVibrator) return;
    try {
      Vibration.vibrate(duration: 40);
    } catch (e) {
      debugPrint('[HapticService] successCount error: $e');
    }
  }

  /// Fires a triple rhythmic burst — called when the user reaches their target.
  ///
  /// Pattern: [40ms ON, 60ms OFF, 40ms ON, 60ms OFF, 80ms ON]
  Future<void> targetReached() async {
    if (!_hasVibrator) return;
    try {
      Vibration.vibrate(pattern: [0, 40, 60, 40, 60, 80]);
    } catch (e) {
      debugPrint('[HapticService] targetReached error: $e');
    }
  }
}
