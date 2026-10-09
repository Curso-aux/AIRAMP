import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Word descriptor for [TypewriterEffect] matching Aceternity UI's words schema:
/// ```ts
/// const words = [
///   { text: "Build" },
///   { text: "awesome" },
///   { text: "apps" },
///   { text: "with" },
///   { text: "Aceternity.", className: "text-blue-500 dark:text-blue-500" }
/// ];
/// ```
class TypewriterWord {
  final String text;
  final Color? color;
  final TextStyle? style;
  final String? className;

  const TypewriterWord({
    required this.text,
    this.color,
    this.style,
    this.className,
  });
}

/// Aceternity UI Typewriter Effect component for Flutter.
///
/// Animates words character-by-character with a persistent blinking neon cursor,
/// supporting per-word coloring, responsive typography, and optional looping.
class TypewriterEffect extends StatefulWidget {
  final List<TypewriterWord> words;
  final TextStyle? textStyle;
  final Color? cursorColor;
  final double cursorWidth;
  final double? cursorHeight;
  final Duration typingSpeed;
  final Duration cursorBlinkRate;
  final TextAlign textAlign;
  final bool loop;
  final Duration pauseDuration;
  final VoidCallback? onComplete;
  final bool forceAnimateInTest;

  const TypewriterEffect({
    super.key,
    required this.words,
    this.textStyle,
    this.cursorColor,
    this.cursorWidth = 3.5,
    this.cursorHeight,
    this.typingSpeed = const Duration(milliseconds: 70),
    this.cursorBlinkRate = const Duration(milliseconds: 530),
    this.textAlign = TextAlign.center,
    this.loop = false,
    this.pauseDuration = const Duration(seconds: 4),
    this.onComplete,
    this.forceAnimateInTest = false,
  });

  @override
  State<TypewriterEffect> createState() => _TypewriterEffectState();
}

class _TypewriterEffectState extends State<TypewriterEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _cursorController;
  Timer? _typingTimer;
  Timer? _pauseTimer;

  // Total characters across all words + spaces
  late List<_CharInfo> _allChars;
  int _visibleCount = 0;
  bool _isBackspacing = false;
  late final bool _isTest;

  @override
  void initState() {
    super.initState();
    _isTest = !kIsWeb &&
        Platform.environment.containsKey('FLUTTER_TEST') &&
        !widget.forceAnimateInTest;

    _cursorController = AnimationController(
      vsync: this,
      duration: widget.cursorBlinkRate,
    );

    _prepareChars();

    if (_isTest) {
      _visibleCount = _allChars.length;
      _cursorController.value = 1.0;
    } else {
      _cursorController.repeat(reverse: true);
      _startTyping();
    }
  }

  @override
  void didUpdateWidget(covariant TypewriterEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.words != widget.words) {
      _typingTimer?.cancel();
      _pauseTimer?.cancel();
      _prepareChars();
      if (_isTest) {
        _visibleCount = _allChars.length;
      } else {
        _visibleCount = 0;
        _isBackspacing = false;
        _startTyping();
      }
    }
  }

  void _prepareChars() {
    _allChars = [];
    for (int w = 0; w < widget.words.length; w++) {
      final word = widget.words[w];
      for (int c = 0; c < word.text.length; c++) {
        _allChars.add(_CharInfo(
          char: word.text[c],
          word: word,
          isSpace: false,
        ));
      }
      // Add space between words if not last word
      if (w < widget.words.length - 1) {
        _allChars.add(_CharInfo(
          char: ' ',
          word: word,
          isSpace: true,
        ));
      }
    }
  }

  void _startTyping() {
    _typingTimer?.cancel();
    _typingTimer = Timer.periodic(widget.typingSpeed, (_) {
      if (!mounted) return;

      if (!_isBackspacing) {
        if (_visibleCount < _allChars.length) {
          setState(() => _visibleCount++);
        } else {
          _typingTimer?.cancel();
          widget.onComplete?.call();
          if (widget.loop) {
            _pauseTimer = Timer(widget.pauseDuration, () {
              if (mounted) {
                _isBackspacing = true;
                _startTyping();
              }
            });
          }
        }
      } else {
        if (_visibleCount > 0) {
          setState(() => _visibleCount--);
        } else {
          _isBackspacing = false;
          _typingTimer?.cancel();
          _pauseTimer = Timer(const Duration(milliseconds: 500), () {
            if (mounted) _startTyping();
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _pauseTimer?.cancel();
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final defaultStyle = widget.textStyle ??
        TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
          height: 1.25,
        );

    final cursorColor = widget.cursorColor ?? AppTheme.primary;
    final cursorHeight = widget.cursorHeight ?? (defaultStyle.fontSize ?? 24) * 1.15;

    final spans = <InlineSpan>[];

    for (int i = 0; i < _visibleCount; i++) {
      final info = _allChars[i];
      final wordColor = info.word.color ??
          (info.word.className != null &&
                  info.word.className!.contains('blue')
              ? AppTheme.primary
              : null);

      final style = defaultStyle.merge(
        info.word.style ??
            (wordColor != null ? TextStyle(color: wordColor) : null),
      );

      spans.add(TextSpan(
        text: info.char,
        style: style,
      ));
    }

    if (!_isTest) {
      // Blinking Cursor WidgetSpan attached directly after visible text
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: AnimatedBuilder(
            animation: _cursorController,
            builder: (context, _) => Opacity(
              opacity: _cursorController.value > 0.4 ? 1.0 : 0.0,
              child: Container(
                margin: const EdgeInsets.only(left: 3),
                width: widget.cursorWidth,
                height: cursorHeight,
                decoration: BoxDecoration(
                  color: cursorColor,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: cursorColor.withValues(alpha: 0.5),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Text.rich(
      TextSpan(children: spans),
      textAlign: widget.textAlign,
    );
  }
}

class _CharInfo {
  final String char;
  final TypewriterWord word;
  final bool isSpace;

  const _CharInfo({
    required this.char,
    required this.word,
    required this.isSpace,
  });
}
