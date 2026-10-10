// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

/// Direct browser-native Web Speech API implementation for Chrome Web.
/// Restored to AIRA's original beloved young girl voice (en-US, pitch 1.45, rate 1.0).
class AiraWebSpeech {
  static bool get isSupported => html.window.speechSynthesis != null;

  static List<html.SpeechSynthesisVoice> _cachedVoices = [];
  static bool _hasInitialized = false;

  static void init() {
    if (_hasInitialized) return;
    _hasInitialized = true;
    final synth = html.window.speechSynthesis;
    if (synth == null) return;
    _cachedVoices = synth.getVoices();
    try {
      synth.addEventListener('voiceschanged', (html.Event event) {
        _cachedVoices = synth.getVoices();
        debugPrint('[AiraWebSpeech] Chrome voices ready: ${_cachedVoices.length}');
      });
    } catch (_) {}
  }

  static void speak(
    String text, {
    double pitch = 1.45,
    double rate = 1.0,
    VoidCallback? onStart,
    VoidCallback? onEnd,
    ValueChanged<String>? onError,
  }) {
    final synth = html.window.speechSynthesis;
    if (synth == null) {
      onError?.call('SpeechSynthesis not available in browser');
      return;
    }

    init();

    try {
      synth.cancel(); // Cancel any lingering speech

      final utterance = html.SpeechSynthesisUtterance(text);
      utterance.pitch = pitch;
      utterance.rate = rate;
      utterance.lang = 'en-US';

      // Pick natural English female / child voice if available (original voice selection)
      final voices = _cachedVoices.isNotEmpty ? _cachedVoices : synth.getVoices();
      if (voices.isNotEmpty) {
        for (final v in voices) {
          final name = (v.name ?? '').toLowerCase();
          final lang = (v.lang ?? '').toLowerCase();
          if (lang.contains('en')) {
            if (name.contains('female') ||
                name.contains('girl') ||
                name.contains('samantha') ||
                name.contains('victoria') ||
                name.contains('zira') ||
                name.contains('google us english')) {
              utterance.voice = v;
              debugPrint('[AiraWebSpeech] Selected original girl voice: ${v.name}');
              break;
            }
          }
        }
      }

      if (onStart != null) {
        utterance.onStart.listen((_) => onStart());
      }

      if (onEnd != null) {
        utterance.onEnd.listen((_) => onEnd());
      }

      utterance.onError.listen((e) {
        debugPrint('[AiraWebSpeech] Error event: $e');
        onError?.call('Utterance error: $e');
      });

      synth.speak(utterance);
      debugPrint('[AiraWebSpeech] Dispatched utterance: "${text.substring(0, text.length > 40 ? 40 : text.length)}..."');
    } catch (e) {
      debugPrint('[AiraWebSpeech] Exception: $e');
      onError?.call(e.toString());
    }
  }

  static void stop() {
    html.window.speechSynthesis?.cancel();
  }

  static void pause() {
    html.window.speechSynthesis?.pause();
  }

  static void resume() {
    html.window.speechSynthesis?.resume();
  }
}
