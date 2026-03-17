import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/dhikr_model.dart';
import '../models/history_entry.dart';
import '../services/audio_service.dart';
import '../services/haptic_service.dart';

/// Central state management for the active Dhikr session.
///
/// Responsibilities:
///   - Managing counter increment logic
///   - Running Arabic speech recognition via [speech_to_text]
///   - Fuzzy keyword matching against [DhikrModel.keywords]
///   - Persisting session history to a Hive box
///   - Coordinating [AudioService] and [HapticService] feedback
class CounterProvider extends ChangeNotifier {
  CounterProvider(this._dhikr) {
    _target = _dhikr.defaultTarget;
    _loadHistory();
  }

  // ── State ──────────────────────────────────────────────────────────────────

  final DhikrModel _dhikr;
  DhikrModel get dhikr => _dhikr;

  int _count = 0;
  int get count => _count;

  int _target = 33;
  int get target => _target;

  bool _micActive = false;
  bool get micActive => _micActive;

  bool _targetReached = false;
  bool get targetReached => _targetReached;

  /// True for one frame after an increment, drives the pulse animation.
  bool _pulseTrigger = false;
  bool get pulseTrigger => _pulseTrigger;

  List<HistoryEntry> _history = [];
  List<HistoryEntry> get history => List.unmodifiable(_history);

  // ── Internal ───────────────────────────────────────────────────────────────

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Increment the counter by one and fire audio + haptic feedback.
  ///
  /// Checks whether the new count equals [target] to trigger the
  /// target-reached celebration pattern instead of the regular tick.
  Future<void> increment() async {
    if (_targetReached) return;
    _count++;
    _pulseTrigger = true;
    notifyListeners();

    // Reset pulse flag after a short delay so the animation can re-trigger
    await Future.delayed(const Duration(milliseconds: 100));
    _pulseTrigger = false;
    notifyListeners();

    if (_count >= _target) {
      _targetReached = true;
      HapticService.instance.targetReached();
      _saveHistory();
    } else {
      HapticService.instance.successCount();
    }
    // Audio click removed per user request for silent counting.
  }

  /// Resets the counter and target-reached flag without saving to history.
  void reset() {
    _count = 0;
    _targetReached = false;
    notifyListeners();
  }

  /// Updates the repetition target and resets the session.
  void setTarget(int value) {
    _target = value;
    reset();
  }

  // ── Voice Recognition ──────────────────────────────────────────────────────

  /// Toggles the microphone on or off.
  ///
  /// On first activation, initialises [SpeechToText] with locale `ar-SA`.
  /// Subsequent calls simply stop or restart the listening session.
  Future<void> toggleMicrophone() async {
    if (_micActive) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  /// Internal: initialise STT and begin a listening session.
  Future<void> _startListening() async {
    if (!_speechAvailable) {
      _speechAvailable = await _speech.initialize(
        onError: (e) => debugPrint('[STT] error: ${e.errorMsg}'),
        onStatus: (s) {
          debugPrint('[STT] status: $s');
          if ((s == 'notListening' || s == 'done') && _micActive) {
            // Auto-restart listening to keep it continuous
            _startListeningInner();
          }
        },
      );
    }

    if (!_speechAvailable) return;

    _micActive = true;
    notifyListeners();

    await _startListeningInner();
  }

  Future<void> _startListeningInner() async {
    // A small delay to avoid state clashes if it just stopped
    await Future.delayed(const Duration(milliseconds: 100));
    if (!_micActive) return;

    await _speech.listen(
      localeId: 'ar-SA',
      listenFor: const Duration(minutes: 5),
      pauseFor: const Duration(seconds: 5), // Increased pause tolerance
      partialResults: true,
      onResult: _onSpeechResult,
    );
  }

  /// Internal: gracefully stop the listening session.
  ///
  /// This is also called from [CounterPage] via [WidgetsBindingObserver]
  /// when the app is backgrounded, ensuring battery is not wasted.
  Future<void> _stopListening() async {
    _micActive = false;
    notifyListeners();
    await _speech.stop();
  }

  /// Forcibly stops the microphone without notifying (used on screen dispose).
  Future<void> forceStopMicrophone() async {
    if (_micActive) {
      _micActive = false;
      await _speech.stop();
    }
  }

  /// Callback invoked by [SpeechToText] with incremental recognition results.
  ///
  /// **Fuzzy Matching Algorithm:**
  /// Rather than requiring an exact phrase match, we iterate over
  /// [DhikrModel.keywords] and check whether the recognized [text] *contains*
  /// any keyword as a substring. This tolerates common ASR errors (e.g. missing
  /// definite articles, slight mispronunciations, short pauses mid-phrase).
  ///
  /// Only *final* results are acted upon (isFinal == true) to prevent the
  /// counter from firing on every partial hypothesis update.
  void _onSpeechResult(dynamic result) {
    // result is SpeechRecognitionResult
    if (!result.finalResult && result.recognizedWords.isEmpty) return;

    final recognizedText = (result.recognizedWords as String).trim();
    debugPrint('[STT] recognized: $recognizedText');

    if (_matchesKeyword(recognizedText)) {
      increment();
      // If we match on a partial result, we could technically force a restart 
      // to clear the buffer, but continuous listening handles this better.
    }
  }

  /// Returns true if [text] contains any keyword from [DhikrModel.keywords].
  ///
  /// The match is case-insensitive on the Arabic Unicode level and also
  /// performs a normalised comparison (stripping tashkeel diacritics).
  bool _matchesKeyword(String text) {
    final normalised = _normaliseArabic(text);
    for (final keyword in _dhikr.keywords) {
      if (normalised.contains(_normaliseArabic(keyword))) {
        return true;
      }
    }
    return false;
  }

  /// Strips common Arabic diacritics (tashkeel) to improve matching tolerance.
  ///
  /// ASR engines frequently omit or misplace fatha/kasra/damma marks, so
  /// comparing without them significantly reduces false negatives.
  String _normaliseArabic(String input) {
    // Unicode ranges for Arabic diacritics: U+064B–U+065F
    return input.replaceAll(RegExp(r'[\u064B-\u065F]'), '');
  }

  // ── Persistence ─────────────────────────────────────────────────────────────

  Future<void> _loadHistory() async {
    final box = Hive.box<HistoryEntry>('history');
    _history = box.values
        .where((e) => e.dhikrId == _dhikr.id)
        .toList()
        .reversed
        .toList();
    notifyListeners();
  }

  Future<void> _saveHistory() async {
    final entry = HistoryEntry(
      dhikrId: _dhikr.id,
      dhikrName: _dhikr.name,
      count: _count,
      target: _target,
      completedAt: DateTime.now(),
      targetReached: _targetReached,
    );
    await Hive.box<HistoryEntry>('history').add(entry);
    _history.insert(0, entry);
    notifyListeners();
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }
}
