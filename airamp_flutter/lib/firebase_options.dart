// File generated for AIRAMP Firebase configuration.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC5W7a4lOwSrdS27n8G3mfDmqgTbxfBFhs',
    appId: '1:156822326046:web:03e651e72a4bf67413570f',
    messagingSenderId: '156822326046',
    projectId: 'aira-app-database',
    authDomain: 'aira-app-database.firebaseapp.com',
    storageBucket: 'aira-app-database.firebasestorage.app',
    measurementId: 'G-K6FW07JLFC',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC5W7a4lOwSrdS27n8G3mfDmqgTbxfBFhs',
    appId: '1:156822326046:android:03e651e72a4bf67413570f',
    messagingSenderId: '156822326046',
    projectId: 'aira-app-database',
    storageBucket: 'aira-app-database.firebasestorage.app',
  );
}
