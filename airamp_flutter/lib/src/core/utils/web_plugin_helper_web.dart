import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shared_preferences_web/shared_preferences_web.dart';

void registerWebPlugins() {
  try {
    SharedPreferencesStorePlatform.instance = SharedPreferencesPlugin();
  } catch (_) {
    try {
      SharedPreferencesPlugin.registerWith(webPluginRegistrar);
    } catch (_) {}
  }
}


