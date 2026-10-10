import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/aira_voice_service.dart';

/// Floating audio HUD showing live reading status, sound visualizer, and stop controls.
class AiraSpeechHUD extends StatefulWidget {
  final VoidCallback onStop;

  const AiraSpeechHUD({
    super.key,
    required this.onStop,
  });

  @override
  State<AiraSpeechHUD> createState() => _AiraSpeechHUDState();
}

class _AiraSpeechHUDState extends State<AiraSpeechHUD>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final voiceService = AiraVoiceService.instance;

    return ValueListenableBuilder<AiraVoiceState>(
      valueListenable: voiceService.stateNotifier,
      builder: (context, state, _) {
        if (state == AiraVoiceState.idle) {
          return const SizedBox.shrink();
        }

        final isSpeaking = state == AiraVoiceState.speaking;

        return ValueListenableBuilder<String>(
          valueListenable: voiceService.currentPhraseNotifier,
          builder: (context, phrase, _) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 260),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xEE0B132B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0x8800E5FF),
                      width: 1.2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x4400E5FF),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Sound wave equalizer bars
                      _buildEqualizer(isSpeaking),
                      const SizedBox(width: 10),

                      // Text info
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSpeaking
                                        ? const Color(0xFF00E5FF)
                                        : Colors.amberAccent,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isSpeaking ? 'AIRA Speaking' : 'AIRA Paused',
                                  style: const TextStyle(
                                    color: Color(0xFF00E5FF),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                            if (phrase.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                phrase,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Pause / Resume Button
                      InkWell(
                        onTap: () {
                          if (isSpeaking) {
                            voiceService.pause();
                          } else {
                            voiceService.resume();
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                          child: Icon(
                            isSpeaking ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Stop Button
                      InkWell(
                        onTap: () {
                          voiceService.stop();
                          widget.onStop();
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.redAccent.withValues(alpha: 0.2),
                          ),
                          child: const Icon(
                            Icons.stop_rounded,
                            size: 16,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEqualizer(bool isSpeaking) {
    if (!isSpeaking) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(4, (index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 1.2),
            width: 2.5,
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      );
    }

    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, _) {
        final val = _waveController.value;
        final heights = [
          6.0 + 8.0 * (val * 0.9).clamp(0.0, 1.0),
          14.0 - 8.0 * ((1 - val) * 0.8).clamp(0.0, 1.0),
          8.0 + 10.0 * (val * 1.1).clamp(0.0, 1.0),
          5.0 + 7.0 * ((1 - val) * 0.9).clamp(0.0, 1.0),
        ];

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(4, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.2),
              width: 2.5,
              height: heights[index],
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF),
                borderRadius: BorderRadius.circular(2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x6600E5FF),
                    blurRadius: 4,
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }
}
