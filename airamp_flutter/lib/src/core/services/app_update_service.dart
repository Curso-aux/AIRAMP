import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class AppUpdateInfo {
  final bool hasUpdate;
  final String currentVersion;
  final int currentBuildNumber;
  final String latestVersion;
  final int latestBuildNumber;
  final String releaseNotes;
  final String apkUrl;
  final String pwaUrl;

  const AppUpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    required this.currentBuildNumber,
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.releaseNotes,
    required this.apkUrl,
    required this.pwaUrl,
  });
}

/// Centralized service managing cross-platform updates for AIRA Platform.
/// Coordinates between Firebase Hosting, PWA web runtime, and hosted Android APKs.
class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  // Current client build information (kept aligned with pubspec.yaml version: 1.0.0+1)
  static const String currentVersion = '1.0.0';
  static const int currentBuildNumber = 1;

  static const String updateMetadataUrl = 'https://aira-app-database.web.app/downloads/version.json';
  static const String hostedWebUrl = 'https://aira-app-database.web.app';
  static const String defaultApkUrl = 'https://aira-app-database.web.app/downloads/aira-latest.apk';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 4),
    receiveTimeout: const Duration(seconds: 4),
  ));

  /// Checks Firebase Hosting for a newer application build.
  Future<AppUpdateInfo> checkForUpdate() async {
    try {
      final response = await _dio.get(
        '$updateMetadataUrl?_t=${DateTime.now().millisecondsSinceEpoch}',
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        final latestVersion = data['version']?.toString() ?? currentVersion;
        final latestBuild = int.tryParse(data['build_number']?.toString() ?? '1') ?? 1;
        final releaseNotes = data['release_notes']?.toString() ?? 'Bug fixes and performance improvements.';
        final apkUrl = data['apk_url']?.toString() ?? defaultApkUrl;
        final pwaUrl = data['pwa_url']?.toString() ?? hostedWebUrl;

        final hasUpdate = latestBuild > currentBuildNumber;

        return AppUpdateInfo(
          hasUpdate: hasUpdate,
          currentVersion: currentVersion,
          currentBuildNumber: currentBuildNumber,
          latestVersion: latestVersion,
          latestBuildNumber: latestBuild,
          releaseNotes: releaseNotes,
          apkUrl: apkUrl,
          pwaUrl: pwaUrl,
        );
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Note checking updates: $e');
    }

    return const AppUpdateInfo(
      hasUpdate: false,
      currentVersion: currentVersion,
      currentBuildNumber: currentBuildNumber,
      latestVersion: currentVersion,
      latestBuildNumber: currentBuildNumber,
      releaseNotes: '',
      apkUrl: defaultApkUrl,
      pwaUrl: hostedWebUrl,
    );
  }

  /// Launches the hosted APK download URL in device browser or package installer.
  Future<bool> downloadLatestApk([String? apkUrl]) async {
    final target = Uri.parse(apkUrl ?? defaultApkUrl);
    try {
      return await launchUrl(target, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[AppUpdateService] Error launching APK URL: $e');
      return false;
    }
  }

  /// Prompts the user with a styled dialog if a newer build is hosted on Firebase.
  Future<void> promptUpdateIfAvailable(BuildContext context, {bool showNoUpdateMessage = false}) async {
    final info = await checkForUpdate();
    if (!context.mounted) return;

    if (info.hasUpdate) {
      showUpdateDialog(context, info);
    } else if (showNoUpdateMessage) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You are already running the latest version of AIRA (v$currentVersion).'),
          backgroundColor: AppTheme.primary,
        ),
      );
    }
  }

  /// Displays the update modal dialog.
  void showUpdateDialog(BuildContext context, AppUpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3), width: 1.5),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.system_update_rounded, color: AppTheme.primary, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Update Available',
                    style: TextStyle(
                      color: AppTheme.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'v${info.currentVersion}  →  v${info.latestVersion}',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A new build of the AIRA Platform is hosted on Firebase. Updating ensures you have the latest features, security fixes, and SMTP performance upgrades.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            if (info.releaseNotes.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What\'s New:',
                      style: TextStyle(
                        color: AppTheme.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      info.releaseNotes,
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (kIsWeb)
              Text(
                'Tip: On web, refreshing or closing other tabs will immediately load the latest version.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
              )
            else
              Text(
                'Tapping "Download & Install" will fetch the official APK directly from Firebase Hosting.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Later', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              if (kIsWeb) {
                // In Web browser, reload window or open hosted web
                launchUrl(Uri.parse(hostedWebUrl), mode: LaunchMode.platformDefault);
              } else {
                downloadLatestApk(info.apkUrl);
              }
            },
            icon: Icon(kIsWeb ? Icons.refresh : Icons.download_rounded, size: 18),
            label: Text(kIsWeb ? 'Refresh App' : 'Download & Install'),
          ),
        ],
      ),
    );
  }

  /// Displays instructions for adding AIRA to iOS / Android Home Screen as a native PWA app.
  static void showInstallPwaInstructions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.install_mobile_rounded, color: AppTheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Install AIRA on iOS & Android',
                    style: TextStyle(color: AppTheme.text, fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'AIRA is configured as a Progressive Web App (PWA). You can install it on your device without an app store:',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            _buildStepRow(
              step: '1',
              title: 'On Apple iPhone / iPad (Safari)',
              description: 'Tap the Share icon at the bottom of Safari, then choose "Add to Home Screen".',
            ),
            const SizedBox(height: 12),
            _buildStepRow(
              step: '2',
              title: 'On Android (Chrome)',
              description: 'Tap the three-dots menu (⋮) at top-right, then select "Install app" or "Add to Home screen".',
            ),
            const SizedBox(height: 12),
            _buildStepRow(
              step: '3',
              title: 'Instant Updates',
              description: 'Whenever school administrators deploy updates to Firebase Hosting, your installed app updates automatically!',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Got It', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildStepRow({required String step, required String title, required String description}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Text(
            step,
            style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: AppTheme.text, fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 2),
              Text(description, style: TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }
}
