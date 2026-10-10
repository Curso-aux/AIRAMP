import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'aira_web_speech.dart';

enum AiraVoiceState { idle, speaking, paused, error }

/// Dual-engine Text-To-Speech service for AIRA:
/// Modeled to sound humanized, natural, warm, and expressive as a young girl.
class AiraVoiceService {
  AiraVoiceService._();
  static final AiraVoiceService instance = AiraVoiceService._();

  final FlutterTts _tts = FlutterTts();
  bool _isTtsInitialized = false;

  final ValueNotifier<AiraVoiceState> stateNotifier =
      ValueNotifier<AiraVoiceState>(AiraVoiceState.idle);

  final ValueNotifier<String> currentPhraseNotifier =
      ValueNotifier<String>('');

  final ValueNotifier<double> progressNotifier =
      ValueNotifier<double>(0.0);

  AiraVoiceState get state => stateNotifier.value;
  bool get isSpeaking => stateNotifier.value == AiraVoiceState.speaking;

  List<String> _sentenceQueue = [];
  int _currentSentenceIndex = 0;
  bool _cancelRequested = false;

  Future<void> init() async {
    if (kIsWeb) {
      AiraWebSpeech.init();
      return;
    }

    if (_isTtsInitialized) return;

    try {
      // Original young girl pitch: 1.40
      await _tts.setPitch(1.40);

      // Original natural conversational speaking tempo
      await _tts.setSpeechRate(0.50);

      await _tts.setVolume(1.0);
      await _tts.setLanguage('en-US');

      // Best effort voice lookup for high-definition neural voices on Android
      try {
        final dynamic rawVoices = await _tts.getVoices;
        if (rawVoices is List) {
          final voices = rawVoices.cast<dynamic>();
          dynamic bestVoice;
          int highestScore = -1;

          for (final v in voices) {
            final name = (v['name'] ?? '').toString().toLowerCase();
            final locale = (v['locale'] ?? '').toString().toLowerCase();

            if (!locale.contains('en')) continue;

            int score = 0;
            // High-definition WaveNet / Neural network voice models on Android
            if (name.contains('network') || name.contains('neural') || name.contains('natural')) {
              score += 100;
            }
            if (name.contains('sfg') || name.contains('iol') || name.contains('tpd')) {
              score += 70;
            }
            if (name.contains('female') || name.contains('girl')) {
              score += 50;
            }
            if (locale.contains('en-us') || locale.contains('en_us')) {
              score += 30;
            }

            if (score > highestScore) {
              highestScore = score;
              bestVoice = v;
            }
          }

          if (bestVoice != null) {
            await _tts.setVoice({
              'name': bestVoice['name'].toString(),
              'locale': bestVoice['locale'].toString(),
            });
            debugPrint('[AiraVoice] Selected neural voice: ${bestVoice['name']}');
          }
        }
      } catch (e) {
        debugPrint('[AiraVoice] Voice selection note: $e');
      }

      _tts.setStartHandler(() {
        if (!_cancelRequested) {
          stateNotifier.value = AiraVoiceState.speaking;
        }
      });

      _tts.setCompletionHandler(() {
        _onSentenceFinished();
      });

      _tts.setCancelHandler(() {
        if (_cancelRequested) {
          stateNotifier.value = AiraVoiceState.idle;
          currentPhraseNotifier.value = '';
          progressNotifier.value = 0.0;
        }
      });

      _tts.setPauseHandler(() {
        stateNotifier.value = AiraVoiceState.paused;
      });

      _tts.setContinueHandler(() {
        stateNotifier.value = AiraVoiceState.speaking;
      });

      _tts.setErrorHandler((msg) {
        debugPrint('[AiraVoice] TTS error: $msg');
        _onSentenceFinished();
      });

      _isTtsInitialized = true;
      debugPrint('[AiraVoice] Native TTS initialized successfully');
    } catch (e) {
      debugPrint('[AiraVoice] Init exception: $e');
    }
  }

  /// Splits structured screen text into fluent, humanized sentences and reads them sequentially.
  Future<void> speakScreen(String fullText) async {
    _cancelRequested = false;

    if (fullText.trim().isEmpty) {
      debugPrint('[AiraVoice] Empty text to speak');
      return;
    }

    _sentenceQueue = _cleanAndSegmentText(fullText);
    _currentSentenceIndex = 0;

    if (_sentenceQueue.isEmpty) return;

    stateNotifier.value = AiraVoiceState.speaking;
    progressNotifier.value = 0.0;

    if (kIsWeb) {
      _speakNextSentenceWeb();
    } else {
      await init();
      _speakNextSentenceNative();
    }
  }

  void _speakNextSentenceWeb() {
    if (_cancelRequested) {
      stateNotifier.value = AiraVoiceState.idle;
      return;
    }

    if (_currentSentenceIndex >= _sentenceQueue.length) {
      stateNotifier.value = AiraVoiceState.idle;
      currentPhraseNotifier.value = '';
      progressNotifier.value = 1.0;
      return;
    }

    final sentence = _sentenceQueue[_currentSentenceIndex];
    currentPhraseNotifier.value = sentence;
    progressNotifier.value = _sentenceQueue.isNotEmpty
        ? (_currentSentenceIndex / _sentenceQueue.length)
        : 0.0;
    stateNotifier.value = AiraVoiceState.speaking;

    AiraWebSpeech.speak(
      sentence,
      pitch: 1.45, // Original first young girl pitch
      rate: 1.0,   // Original natural conversational tempo
      onStart: () {
        if (!_cancelRequested) {
          stateNotifier.value = AiraVoiceState.speaking;
        }
      },
      onEnd: () {
        _onSentenceFinished();
      },
      onError: (err) {
        debugPrint('[AiraVoice] Web Speech Error: $err');
        _onSentenceFinished();
      },
    );
  }

  Future<void> _speakNextSentenceNative() async {
    if (_cancelRequested) {
      stateNotifier.value = AiraVoiceState.idle;
      return;
    }

    if (_currentSentenceIndex >= _sentenceQueue.length) {
      stateNotifier.value = AiraVoiceState.idle;
      currentPhraseNotifier.value = '';
      progressNotifier.value = 1.0;
      return;
    }

    final sentence = _sentenceQueue[_currentSentenceIndex];
    currentPhraseNotifier.value = sentence;
    progressNotifier.value = _sentenceQueue.isNotEmpty
        ? (_currentSentenceIndex / _sentenceQueue.length)
        : 0.0;
    stateNotifier.value = AiraVoiceState.speaking;

    try {
      await _tts.speak(sentence);
    } catch (e) {
      debugPrint('[AiraVoice] Native speak error: $e');
      if (e.toString().contains('MissingPluginException')) {
        currentPhraseNotifier.value = 'Please re-run app to compile native TTS';
      }
      _onSentenceFinished();
    }
  }

  void _onSentenceFinished() {
    if (_cancelRequested) return;
    _currentSentenceIndex++;
    if (_currentSentenceIndex < _sentenceQueue.length) {
      // Original natural pause between sentences (120ms)
      Future.delayed(const Duration(milliseconds: 120), () {
        if (!_cancelRequested && stateNotifier.value == AiraVoiceState.speaking) {
          if (kIsWeb) {
            _speakNextSentenceWeb();
          } else {
            _speakNextSentenceNative();
          }
        }
      });
    } else {
      stateNotifier.value = AiraVoiceState.idle;
      currentPhraseNotifier.value = '';
      progressNotifier.value = 1.0;
    }
  }

  Future<void> stop() async {
    _cancelRequested = true;
    _sentenceQueue.clear();
    _currentSentenceIndex = 0;
    currentPhraseNotifier.value = '';
    progressNotifier.value = 0.0;
    stateNotifier.value = AiraVoiceState.idle;

    if (kIsWeb) {
      AiraWebSpeech.stop();
    } else {
      try {
        await _tts.stop();
      } catch (_) {}
    }
  }

  Future<void> pause() async {
    stateNotifier.value = AiraVoiceState.paused;
    if (kIsWeb) {
      AiraWebSpeech.pause();
    } else {
      try {
        await _tts.pause();
      } catch (_) {}
    }
  }

  Future<void> resume() async {
    if (stateNotifier.value == AiraVoiceState.paused) {
      stateNotifier.value = AiraVoiceState.speaking;
      if (kIsWeb) {
        AiraWebSpeech.resume();
      } else {
        try {
          await _tts.speak(currentPhraseNotifier.value);
        } catch (_) {}
      }
    }
  }

  /// Cleans and formats text into conversational, natural English sentences
  List<String> _cleanAndSegmentText(String raw) {
    // 1. Humanize acronyms and screen symbols so they are pronounced naturally
    String cleaned = raw
        .replaceAll(RegExp(r'\bAIRAMP\b'), 'Air amp')
        .replaceAll(RegExp(r'\bAIRA\b'), 'Aira')
        .replaceAll(RegExp(r'&'), ' and ')
        .replaceAll(RegExp(r'%'), ' percent ')
        .replaceAll(RegExp(r'\+'), ' plus ')
        .replaceAll(RegExp(r'\bNo\.\b|\bno\.\b'), 'Number ')
        .replaceAll(RegExp(r'\bQty\b|\bqty\b'), 'Quantity ')
        .replaceAll(RegExp(r'\bAvg\b|\bavg\b'), 'Average ')
        .replaceAll(RegExp(r'\bMin\b|\bmin\b'), 'Minute ')
        .replaceAll(RegExp(r'\bSec\b|\bsec\b'), 'Second ')
        .replaceAll(RegExp(r'\bHrs?\b|\bhrs?\b'), 'Hours ')
        .replaceAll(RegExp(r'\bw/\b'), 'with ')
        .replaceAll(RegExp(r'\bw/o\b'), 'without ')
        .replaceAll(RegExp(r'\bvs\b|\bvs\.\b'), 'versus ')
        .replaceAll(RegExp(r'[\u2022\u25cf\u25aa\u2023]'), ', ')
        .replaceAll(RegExp(r'[|/\\_~`>#*]'), ' ')
        .replaceAll(RegExp(r'-{2,}'), ', ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // 2. Break by sentence boundaries with punctuation
    final rawSentences = cleaned.split(RegExp(r'(?<=[.!?])\s+|\n+'));
    final results = <String>[];

    for (final s in rawSentences) {
      final trimmed = s.trim();
      if (trimmed.length > 1 && !RegExp(r'^[\d\W]+$').hasMatch(trimmed)) {
        if (trimmed.length > 160) {
          final chunks = _breakLongSentence(trimmed, 130);
          results.addAll(chunks);
        } else {
          results.add(trimmed);
        }
      }
    }

    return results;
  }

  List<String> _breakLongSentence(String text, int maxLength) {
    final words = text.split(' ');
    final chunks = <String>[];
    var current = StringBuffer();

    for (final word in words) {
      if ((current.length + word.length + 1) > maxLength && current.isNotEmpty) {
        chunks.add(current.toString().trim());
        current = StringBuffer();
      }
      current.write('$word ');
    }
    if (current.isNotEmpty) {
      chunks.add(current.toString().trim());
    }
    return chunks;
  }
}
