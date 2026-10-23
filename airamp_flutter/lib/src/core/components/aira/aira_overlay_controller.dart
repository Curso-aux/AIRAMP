import 'package:flutter/foundation.dart';

/// Global controller to temporarily suppress the floating assistant during modals or full-screen overlays.
class AiraOverlayController {
  static final ValueNotifier<bool> isHidden = ValueNotifier<bool>(false);

  static void hide() {
    isHidden.value = true;
  }

  static void show() {
    isHidden.value = false;
  }
}
