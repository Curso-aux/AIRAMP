import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/theme/app_theme.dart';

/// Renders an authentic, scannable QR Code that exactly matches the ESP32 OLED display (Version 3, ECC Low).
class HubQrCodeWidget extends StatelessWidget {
  final String qrData;
  final String hubSsid;
  final String hubIp;
  final double size;
  final bool showLabels;

  const HubQrCodeWidget({
    super.key,
    required this.qrData,
    this.hubSsid = 'AIRAMP-HUB-01',
    this.hubIp = '192.168.4.1',
    this.size = 200,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
          ),
          child: Center(
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              errorCorrectionLevel: QrErrorCorrectLevel.L,
              size: size - 24,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF0F172A),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF0F172A),
              ),
              errorStateBuilder: (cxt, err) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'QR Display Error\n$err',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10, color: Colors.red),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (showLabels) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi, size: 14, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  'SSID: $hubSsid',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(width: 10),
                Text('•', style: TextStyle(color: AppTheme.textMuted)),
                const SizedBox(width: 10),
                Text(
                  hubIp,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
