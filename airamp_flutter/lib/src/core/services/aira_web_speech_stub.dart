import 'package:flutter/foundation.dart';

/// Stub implementation for non-web platforms.
class AiraWebSpeech {
  static bool get isSupported => false;

  static void init() {}

  static void speak(
    String text, {
    double pitch = 1.45,
    double rate = 1.0,
    VoidCallback? onStart,
    VoidCallback? onEnd,
    ValueChanged<String>? onError,
  }) {}

  static void stop() {}

  static void pause() {}

  static void resume() {}
}
