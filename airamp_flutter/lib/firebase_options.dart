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
    apiKey: 'AIzaSyDVz4mcgxDT0AHbLUFSQc9YNhRYgZ-eAtw',
    appId: '1:486787192480:web:69017c792fd0f695651bc5',
    messagingSenderId: '486787192480',
    projectId: 'aira-demo-live',
    authDomain: 'aira-demo-live.firebaseapp.com',
    storageBucket: 'aira-demo-live.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCD7usspGqXEnW4l2DoUWy8iDeQDdYlKyc',
    appId: '1:486787192480:android:3a719741896542f3651bc5',
    messagingSenderId: '486787192480',
    projectId: 'aira-demo-live',
    storageBucket: 'aira-demo-live.firebasestorage.app',
  );
}
