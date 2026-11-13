import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_theme.dart';
import 'aira_action_toast.dart';

/// Reusable camera QR Code Scanner Dialog for Section Enrollment Keys.
/// Works on Mobile (Android, iOS) and Web browsers with live camera access.
class AiraQrScannerDialog extends StatefulWidget {
  final ValueChanged<String> onKeyScanned;
  final String title;
  final String subtitle;
  final String? initialKey;

  const AiraQrScannerDialog({
    super.key,
    required this.onKeyScanned,
    this.title = 'Scan Section QR Code',
    this.subtitle = 'Point camera at classroom projector or teacher display',
    this.initialKey,
  });

  /// Static helper to launch the scanner modal
  static Future<void> show({
    required BuildContext context,
    required ValueChanged<String> onKeyScanned,
    String title = 'Scan Section QR Code',
    String subtitle = 'Point camera at classroom projector or teacher display',
    String? initialKey,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AiraQrScannerDialog(
        onKeyScanned: onKeyScanned,
        title: title,
        subtitle: subtitle,
        initialKey: initialKey,
      ),
    );
  }

  /// Extracts clean enrollment key from raw string or URL (e.g., 'SEC-SAPH12')
  static String sanitizeKey(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return '';

    // Check if it's a URL query param (e.g. ?key=SEC-SAPH12 or /join/SEC-SAPH12)
    final uri = Uri.tryParse(text);
    if (uri != null) {
      if (uri.queryParameters.containsKey('key')) {
        return uri.queryParameters['key']!.trim().toUpperCase();
      }
      if (uri.pathSegments.isNotEmpty) {
        final last = uri.pathSegments.last.trim();
        if (last.toUpperCase().startsWith('SEC-')) {
          return last.toUpperCase();
        }
      }
    }

    // RegEx match for SEC-XXX format
    final match = RegExp(r'(SEC-[A-Za-z0-9_-]+)', caseSensitive: false).firstMatch(text);
    if (match != null) {
      return match.group(1)!.toUpperCase();
    }

    return text.toUpperCase();
  }

  @override
  State<AiraQrScannerDialog> createState() => _AiraQrScannerDialogState();
}

class _AiraQrScannerDialogState extends State<AiraQrScannerDialog>
    with SingleTickerProviderStateMixin {
  late MobileScannerController _scannerController;
  late AnimationController _animController;
  late Animation<double> _scanLineAnim;
  late TextEditingController _manualKeyController;

  bool _hasScanned = false;
  bool _torchOn = false;
  bool _showManualInput = false;

  @override
  void initState() {
    super.initState();
    _manualKeyController = TextEditingController(text: widget.initialKey ?? '');
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _scanLineAnim = Tween<double>(begin: 0.10, end: 0.90).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _scannerController.dispose();
    _manualKeyController.dispose();
    super.dispose();
  }

  void _handleBarcodeDetect(BarcodeCapture capture) {
    if (_hasScanned) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.trim().isNotEmpty) {
        final sanitized = AiraQrScannerDialog.sanitizeKey(raw);
        if (sanitized.isNotEmpty) {
          _hasScanned = true;
          HapticFeedback.mediumImpact();
          _deliverKey(sanitized);
          break;
        }
      }
    }
  }

  void _deliverKey(String key) {
    Navigator.of(context, rootNavigator: true).pop();
    widget.onKeyScanned(key);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppTheme.primary;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 440;
    final boxSize = (screenWidth - 72.0).clamp(240.0, 310.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: isDark ? 0.20 : 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: primary.withValues(alpha: 0.25),
                          width: 1.2,
                        ),
                      ),
                      child: Icon(
                        Icons.qr_code_scanner_rounded,
                        color: primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontSize: isSmall ? 15 : 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppTheme.darkText : AppTheme.lightText,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => Navigator.pop(context),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, thickness: 1),

              // Viewfinder / Camera View
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  children: [
                    Container(
                      width: boxSize,
                      height: boxSize,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: primary.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.12),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Live MobileScanner Stream
                            MobileScanner(
                              controller: _scannerController,
                              onDetect: _handleBarcodeDetect,
                              errorBuilder: (context, error) {
                                return Container(
                                  color: const Color(0xFF0F172A),
                                  padding: const EdgeInsets.all(20),
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppTheme.warning.withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.videocam_off_outlined,
                                          color: AppTheme.warning,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      const Text(
                                        'Camera Inactive / Denied',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Enable camera permission or type the enrollment key below.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.7),
                                          fontSize: 11,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),

                            // 4 Corner Alignment Brackets
                            _ViewfinderBrackets(boxSize: boxSize),

                            // Animated Laser Line
                            AnimatedBuilder(
                              animation: _scanLineAnim,
                              builder: (context, _) {
                                return Positioned(
                                  top: boxSize * _scanLineAnim.value,
                                  left: 24,
                                  right: 24,
                                  child: Container(
                                    height: 2.5,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          primary.withValues(alpha: 0.0),
                                          primary,
                                          primary.withValues(alpha: 0.0),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: primary.withValues(alpha: 0.8),
                                          blurRadius: 10,
                                          spreadRadius: 1.5,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),

                            // Camera Switch toggle (top left)
                            Positioned(
                              top: 10,
                              left: 10,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.45),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white24, width: 0.8),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.cameraswitch_outlined,
                                        color: Colors.white70,
                                        size: 18,
                                      ),
                                      onPressed: () => _scannerController.switchCamera(),
                                      tooltip: 'Switch Camera',
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Flashlight / Torch toggle (top right)
                            Positioned(
                              top: 10,
                              right: 10,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _torchOn
                                          ? const Color(0xFFF59E0B).withValues(alpha: 0.28)
                                          : Colors.black.withValues(alpha: 0.45),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _torchOn ? const Color(0xFFF59E0B) : Colors.white24,
                                        width: 1.0,
                                      ),
                                    ),
                                    child: IconButton(
                                      icon: Icon(
                                        _torchOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
                                        color: _torchOn ? const Color(0xFFF59E0B) : Colors.white70,
                                        size: 18,
                                      ),
                                      onPressed: () async {
                                        await _scannerController.toggleTorch();
                                        if (mounted) setState(() => _torchOn = !_torchOn);
                                      },
                                      tooltip: _torchOn ? 'Turn off Torch' : 'Turn on Torch',
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Center Alignment Pill
                            Positioned(
                              bottom: 12,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.65),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white24, width: 0.8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: primary,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: primary.withValues(alpha: 0.8),
                                                blurRadius: 6,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Align QR code inside frame',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Manual Fallback Toggle Button
                    InkWell(
                      onTap: () {
                        setState(() => _showManualInput = !_showManualInput);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showManualInput ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_outlined,
                              size: 16,
                              color: primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _showManualInput ? 'Hide manual key entry' : 'Or type enrollment key manually',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Collapsible Manual Key Input Bar
                    if (_showManualInput) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _manualKeyController,
                              textCapitalization: TextCapitalization.characters,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDark ? AppTheme.darkText : AppTheme.lightText,
                                letterSpacing: 1.0,
                              ),
                              decoration: InputDecoration(
                                hintText: 'e.g. SEC-SAPH12',
                                hintStyle: TextStyle(
                                  color: AppTheme.textMuted.withValues(alpha: 0.6),
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                prefixIcon: Icon(Icons.key_rounded, size: 16, color: primary),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.content_paste_rounded, size: 16),
                                  tooltip: 'Paste from clipboard',
                                  onPressed: () async {
                                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                                    if (data?.text != null && data!.text!.trim().isNotEmpty) {
                                      _manualKeyController.text = AiraQrScannerDialog.sanitizeKey(data.text!);
                                    }
                                  },
                                ),
                                filled: true,
                                fillColor: isDark ? AppTheme.darkInputBg : const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                                ),
                              ),
                              onSubmitted: (val) {
                                final clean = AiraQrScannerDialog.sanitizeKey(val);
                                if (clean.isNotEmpty) {
                                  _deliverKey(clean);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              final clean = AiraQrScannerDialog.sanitizeKey(_manualKeyController.text);
                              if (clean.isNotEmpty) {
                                _deliverKey(clean);
                              } else {
                                AiraActionToast.show(
                                  context,
                                  title: 'Key Required',
                                  message: 'Please enter a valid section key.',
                                  type: AiraToastType.warning,
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewfinderBrackets extends StatelessWidget {
  final double boxSize;

  const _ViewfinderBrackets({required this.boxSize});

  @override
  Widget build(BuildContext context) {
    const double length = 26;
    const double stroke = 3.5;
    final color = AppTheme.primary;

    return Stack(
      children: [
        // Top-Left
        Positioned(
          top: 14,
          left: 14,
          child: Container(
            width: length,
            height: stroke,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
        ),
        Positioned(
          top: 14,
          left: 14,
          child: Container(
            width: stroke,
            height: length,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
        ),
        // Top-Right
        Positioned(
          top: 14,
          right: 14,
          child: Container(
            width: length,
            height: stroke,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
        ),
        Positioned(
          top: 14,
          right: 14,
          child: Container(
            width: stroke,
            height: length,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
        ),
        // Bottom-Left
        Positioned(
          bottom: 14,
          left: 14,
          child: Container(
            width: length,
            height: stroke,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
        ),
        Positioned(
          bottom: 14,
          left: 14,
          child: Container(
            width: stroke,
            height: length,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
        ),
        // Bottom-Right
        Positioned(
          bottom: 14,
          right: 14,
          child: Container(
            width: length,
            height: stroke,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
        ),
        Positioned(
          bottom: 14,
          right: 14,
          child: Container(
            width: stroke,
            height: length,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
        ),
      ],
    );
  }
}
