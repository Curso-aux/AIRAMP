// Emulator Configuration for AIRAMP Semester Renewal Testing
// Enables switching between standalone in-memory mode and live Firebase Emulator.

class EmulatorConfig {
  static const bool isEmulatorMode = bool.fromEnvironment(
    'USE_FIREBASE_EMULATOR',
    defaultValue: false,
  );

  static const String firestoreHost = 'localhost';
  static const int firestorePort = 8080;
  static const int authPort = 9099;
  static const int storagePort = 9199;
  static const int uiPort = 4000;
  static const String projectId = 'airamp-renewal-test';

  static String get firestoreRestBaseUrl =>
      'http://$firestoreHost:$firestorePort/v1/projects/$projectId/databases/(default)/documents';

  static String get firestoreClearEndpoint =>
      'http://$firestoreHost:$firestorePort/emulator/v1/projects/$projectId/databases/(default)/documents';

  static String get authRestBaseUrl =>
      'http://$firestoreHost:$authPort/identitytoolkit.googleapis.com/v1';
}
