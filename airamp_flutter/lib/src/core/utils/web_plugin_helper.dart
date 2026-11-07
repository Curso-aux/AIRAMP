import 'web_plugin_helper_stub.dart'
    if (dart.library.html) 'web_plugin_helper_web.dart'
    if (dart.library.js_interop) 'web_plugin_helper_web.dart';

void ensureWebPluginsInitialized() {
  registerWebPlugins();
}


