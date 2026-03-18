import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vosk_flutter/vosk_flutter.dart';

import '../models/dhikr_model.dart';
import '../models/history_entry.dart';
import '../services/vosk_service.dart';

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

  Recognizer? _recognizer;
  SpeechService? _speechService;
  
  String _entireSessionText = '';
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

  /// Internal: initialise Vosk and begin a continuous listening session.
  Future<void> _startListening() async {
    if (!VoskService.instance.isReady) {
      await VoskService.instance.init();
    }

    _recognizer = await VoskService.instance.createRecognizer();
    _speechService = await VoskService.instance.initSpeechService(_recognizer!);

    _micActive = true;
    _entireSessionText = '';
    _lastTotalCount = 0;
    notifyListeners();

    _speechService!.onPartial().listen((e) {
      if (!_micActive) return;
      final map = jsonDecode(e);
      final partialText = map['partial'] ?? '';
      _processCumulativeText('$_entireSessionText $partialText');
    });

    _speechService!.onResult().listen((e) {
      if (!_micActive) return;
      final map = jsonDecode(e);
      final finalText = map['text'] ?? '';
      _entireSessionText = '$_entireSessionText $finalText'.trim();
      _processCumulativeText(_entireSessionText);
    });

    await _speechService!.start();
  }

  /// Internal: gracefully stop the listening session and clean up Vosk streams.
  Future<void> _stopListening() async {
    _micActive = false;
    notifyListeners();
    
    if (_speechService != null) {
      await _speechService!.stop();
      await _speechService!.dispose();
      _speechService = null;
    }
    if (_recognizer != null) {
      _recognizer!.dispose();
      _recognizer = null;
    }
  }

  /// Forcibly stops the microphone without notifying (used on screen dispose).
  Future<void> forceStopMicrophone() async {
    await _stopListening();
  }

  /// Analyzes the cumulative speech string and matches the total Dhikr occurrences.
  void _processCumulativeText(String text) {
    if (text.trim().isEmpty) return;
    
    final currentTotalCount = _countWordFrequency(text);

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
    forceStopMicrophone();
    super.dispose();
  }
}
