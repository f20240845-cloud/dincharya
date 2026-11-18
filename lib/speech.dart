import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Continuous dictation on top of the phone's own speech recogniser.
/// The recogniser stops at every pause, so this restarts it until [stop] is called.
/// Each pause-separated phrase becomes one entry in [chunks].
class Dictation extends ChangeNotifier {
  static final SpeechToText _stt = SpeechToText();
  static bool _initialised = false;
  static bool _available = false;
  static Dictation? _owner;

  bool active = false;
  String localeId = 'en_IN';
  final List<String> chunks = [];
  String partial = '';
  String? error;
  int _silent = 0;
  bool _restarting = false;

  bool get available => _available;

  /// Everything heard so far, phrases separated by full stops.
  String get text {
    final parts = [...chunks, if (partial.trim().isNotEmpty) partial.trim()];
    return parts.join('. ');
  }

  Future<bool> start(String locale) async {
    error = null;
    localeId = locale;
    _owner = this;
    if (!_initialised) {
      try {
        _available = await _stt.initialize(
          onStatus: (s) => _owner?._onStatus(s),
          onError: (e) => _owner?._onError(e),
        );
      } catch (e) {
        _available = false;
        error = 'Speech recognition could not start: $e';
      }
      _initialised = _available;
    }
    if (!_available) {
      error ??= 'Speech recognition is not available. Check microphone permission and that '
          'Google speech services are installed.';
      notifyListeners();
      return false;
    }
    chunks.clear();
    partial = '';
    _silent = 0;
    active = true;
    notifyListeners();
    await _listen();
    return true;
  }

  Future<void> _listen() async {
    if (!active) return;
    try {
      await _stt.listen(
        onResult: _onResult,
        localeId: localeId,
        listenFor: const Duration(minutes: 3),
        pauseFor: const Duration(seconds: 5),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
        ),
      );
    } catch (e) {
      error = 'Could not listen: $e';
      active = false;
      notifyListeners();
    }
  }

  void _onResult(SpeechRecognitionResult r) {
    if (_owner != this) return;
    final words = r.recognizedWords.trim();
    if (r.finalResult) {
      if (words.isNotEmpty && (chunks.isEmpty || chunks.last != words)) {
        chunks.add(words);
      }
      if (words.isNotEmpty) _silent = 0;
      partial = '';
    } else {
      partial = words;
    }
    notifyListeners();
  }

  void _onStatus(String status) {
    if (status == 'done' && active) _restart();
  }

  void _onError(SpeechRecognitionError e) {
    final soft = e.errorMsg == 'error_no_match' || e.errorMsg == 'error_speech_timeout';
    if (active && soft) {
      _silent++;
      if (_silent >= 3) {
        active = false; // three silent rounds in a row: stop instead of beeping forever
        notifyListeners();
      } else {
        _restart();
      }
      return;
    }
    if (active) {
      error = 'Speech error: ${e.errorMsg}';
      active = false;
      notifyListeners();
    }
  }

  void _restart() {
    if (_restarting) return;
    _restarting = true;
    Future.delayed(const Duration(milliseconds: 350), () async {
      _restarting = false;
      if (!active || _owner != this) return;
      if (partial.trim().isNotEmpty) {
        chunks.add(partial.trim());
        partial = '';
      }
      if (_stt.isListening) return;
      await _listen();
    });
  }

  Future<void> stop() async {
    if (!active && !_stt.isListening) return;
    active = false;
    notifyListeners();
    try {
      await _stt.stop();
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 450));
    if (partial.trim().isNotEmpty) {
      chunks.add(partial.trim());
      partial = '';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    if (_owner == this) {
      active = false;
      _stt.cancel();
      _owner = null;
    }
    super.dispose();
  }
}
