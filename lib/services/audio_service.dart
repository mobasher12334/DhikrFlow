import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Service responsible for playing short audio feedback sounds.
///
/// Uses [AudioPlayer] in low-latency mode to ensure the click sound
/// fires immediately on successful voice recognition or manual tap.
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  final AudioPlayer _player = AudioPlayer();
  bool _initialized = false;

  /// Initializes the audio player with low-latency configuration.
  ///
  /// Must be called once during app startup before [playClick] is invoked.
  Future<void> init() async {
    if (_initialized) return;
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setVolume(1.0);
      _initialized = true;
    } catch (e) {
      debugPrint('[AudioService] init error: $e');
    }
  }

  /// Plays the short tactile click sound asset.
  ///
  /// Fire-and-forget — errors are silently swallowed to avoid disrupting the
  /// counter UX if the audio subsystem is unavailable.
  Future<void> playClick() async {
    try {
      await _player.play(AssetSource('audio/click.mp3'));
    } catch (e) {
      debugPrint('[AudioService] playClick error: $e');
    }
  }

  /// Releases underlying audio resources. Call on app dispose.
  Future<void> dispose() async {
    await _player.dispose();
  }
}
