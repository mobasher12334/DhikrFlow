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
  int _lastTotalCount = 0;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Increment the counter by the given amount (default 1).
  ///
  /// SILENT MONK MODE: All haptic and audio feedbacks are removed during counting.
  Future<void> increment({int amount = 1}) async {
    _count += amount;
    _pulseTrigger = true;
    notifyListeners();

    // Reset pulse flag after a short delay so the animation can re-trigger
    await Future.delayed(const Duration(milliseconds: 100));
    _pulseTrigger = false;
    notifyListeners();

    if (_count >= _target && !_targetReached) {
      _targetReached = true;
      _saveHistory();
    }
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

    // Reset the buffer tracker on new session
    _lastTotalCount = 0;

    await _speech.listen(
      localeId: 'ar-SA',
      listenMode: stt.ListenMode.dictation,
      onDevice: true,
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
  /// **Text Buffer Differential Algorithm:**
  /// Analyzes the entire ongoing speech string and counts the TOTAL occurrences
  /// of the target Dhikr keywords. If the total frequency is greater than the
  /// last known frequency (`_lastTotalCount`), it increments the app counter
  /// by the exact difference.
  void _onSpeechResult(dynamic result) {
    if (!result.finalResult && result.recognizedWords.isEmpty) return;

    final recognizedText = (result.recognizedWords as String).trim();
    
    // Count how many times the keywords appear in the current buffer
    final currentTotalCount = _countWordFrequency(recognizedText);

    if (currentTotalCount > _lastTotalCount) {
      final diff = currentTotalCount - _lastTotalCount;
      increment(amount: diff);
      _lastTotalCount = currentTotalCount;
    }
  }

  /// Calculates the total frequency of any valid keyword in the given text.
  int _countWordFrequency(String text) {
    final normalisedText = _normaliseArabic(text);
    int totalMatches = 0;

    // Use predefined keywords, but if none exist (e.g. Custom Dhikr), use the arabic text itself.
    final targetPhrases = _dhikr.keywords.isNotEmpty 
        ? _dhikr.keywords 
        : [_dhikr.arabicText];

    // A simple approach: for each keyword, count its non-overlapping occurrences
    for (final phrase in targetPhrases) {
      final nk = _normaliseArabic(phrase);
      if (nk.isEmpty) continue;
      
      int index = 0;
      while (true) {
        index = normalisedText.indexOf(nk, index);
        if (index == -1) break;
        totalMatches++;
        index += nk.length; // move past the found keyword to avoid overlapping
      }
    }
    return totalMatches;
  }

  /// Strips common Arabic diacritics (tashkeel) to improve matching tolerance.
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
    _speech.cancel(); // Strictly kill engine
    super.dispose();
  }
}
