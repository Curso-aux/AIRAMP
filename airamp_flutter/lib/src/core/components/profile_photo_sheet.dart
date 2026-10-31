import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/application/auth_provider.dart';
import '../theme/app_theme.dart';
import 'app_toast.dart';
import 'user_avatar_widget.dart';

class ProfilePhotoSheet extends StatefulWidget {
  final String currentPhoto;
  final String fullName;
  final ValueChanged<String> onPhotoSelected;

  const ProfilePhotoSheet({
    super.key,
    required this.currentPhoto,
    required this.fullName,
    required this.onPhotoSelected,
  });

  static Future<void> show({
    required BuildContext context,
    required WidgetRef ref,
    required String currentPhoto,
    required String fullName,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProfilePhotoSheet(
        currentPhoto: currentPhoto,
        fullName: fullName,
        onPhotoSelected: (newPhoto) async {
          Navigator.of(ctx).pop();
          try {
            await ref.read(authProvider.notifier).updateProfile(
                  profileImage: newPhoto,
                );
            if (context.mounted) {
              AppToast.showSuccess(
                context,
                newPhoto.isEmpty
                    ? 'Profile photo reset to default initial.'
                    : 'Profile photo updated successfully!',
              );
            }
          } catch (e) {
            if (context.mounted) {
              AppToast.showError(context, 'Failed to update profile photo: $e');
            }
          }
        },
      ),
    );
  }

  @override
  State<ProfilePhotoSheet> createState() => _ProfilePhotoSheetState();
}

class _ProfilePhotoSheetState extends State<ProfilePhotoSheet> {
  bool _isProcessing = false;
  String? _previewPhoto;

  @override
  void initState() {
    super.initState();
    _previewPhoto = widget.currentPhoto;
  }

  Future<void> _handleUploadFromDevice() async {
    setState(() => _isProcessing = true);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'gif'],
      );

      if (files.isEmpty) {
        if (mounted) setState(() => _isProcessing = false);
        return;
      }

      final file = files.first;
      final rawBytes = await file.readAsBytes();

      if (rawBytes.isEmpty) {
        if (mounted) {
          setState(() => _isProcessing = false);
          AppToast.showError(context, 'Could not read image file.');
        }
        return;
      }

      // Smoothly downscale to 256x256 using Flutter's native UI codec to keep sync snappy (<40KB)
      final compressedBytes = await _compressImageBytes(rawBytes, targetSize: 256);
      final base64String = base64Encode(compressedBytes);
      final dataUrl = 'data:image/png;base64,$base64String';

      setState(() {
        _previewPhoto = dataUrl;
        _isProcessing = false;
      });

      widget.onPhotoSelected(dataUrl);
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        AppToast.showError(context, 'Failed to pick image: $e');
      }
    }
  }

  Future<Uint8List> _compressImageBytes(Uint8List original, {int targetSize = 256}) async {
    try {
      final codec = await ui.instantiateImageCodec(
        original,
        targetWidth: targetSize,
        targetHeight: targetSize,
      );
      final frame = await codec.getNextFrame();
      final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
    } catch (_) {}
    return original;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initial = widget.fullName.isNotEmpty ? widget.fullName[0].toUpperCase() : 'S';
    final hasCustomPhoto = _previewPhoto != null && _previewPhoto!.trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppTheme.border, width: 1),
          left: BorderSide(color: AppTheme.border, width: 1),
          right: BorderSide(color: AppTheme.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customize Profile Photo',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.text,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Choose a styled avatar or upload from your device',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 20, color: AppTheme.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Center Avatar Preview
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.6),
                        width: 2.5,
                      ),
                    ),
                    child: UserAvatarWidget(
                      imageSource: _previewPhoto,
                      fallbackInitial: initial,
                      size: 84,
                      fontSize: 34,
                    ),
                  ),
                  if (_isProcessing)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Upload from Device Button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _handleUploadFromDevice,
                icon: const Icon(Icons.photo_library_outlined, size: 19),
                label: const Text(
                  'Upload Photo from Gallery / Device',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Section Label: Preset Characters
            Row(
              children: [
                Icon(Icons.palette_outlined, size: 15, color: AppTheme.textMuted),
                const SizedBox(width: 6),
                Text(
                  'OR SELECT AN AVATAR STYLE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Grid of Presets
            SizedBox(
              height: 104,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: kAvatarPresets.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final preset = kAvatarPresets[index];
                  final isSelected = _previewPhoto == preset.id;

                  return GestureDetector(
                    onTap: _isProcessing
                        ? null
                        : () {
                            setState(() => _previewPhoto = preset.id);
                            widget.onPhotoSelected(preset.id);
                          },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? AppTheme.primary : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: preset.gradientColors,
                              ),
                            ),
                            child: Icon(
                              preset.icon,
                              size: 26,
                              color: preset.iconColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          preset.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? AppTheme.text : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // Reset to default initial button (if customized)
            if (hasCustomPhoto)
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () {
                          setState(() => _previewPhoto = '');
                          widget.onPhotoSelected('');
                        },
                  icon: Icon(Icons.refresh_rounded, size: 16, color: AppTheme.textMuted),
                  label: Text(
                    'Reset to Default Letter Initial',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
