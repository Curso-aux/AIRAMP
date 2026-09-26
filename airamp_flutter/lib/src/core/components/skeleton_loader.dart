import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A high-performance, fluid shimmer effect container.
///
/// Wraps any widget tree (e.g. skeleton shapes) and sweeps an animated
/// metallic gradient across all child elements simultaneously.
class AppShimmer extends StatefulWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration duration;

  const AppShimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1400),
  });

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final base = widget.baseColor ??
        (isDark ? const Color(0xFF192D4A) : const Color(0xFFE2E8F0));
    final highlight = widget.highlightColor ??
        (isDark ? const Color(0xFF2A4368) : const Color(0xFFF8FAFC));

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final progress = _controller.value;
            // Sweep smoothly from off-screen left to off-screen right
            return LinearGradient(
              begin: Alignment(-2.0 + (4.0 * progress), -0.2),
              end: Alignment(-0.5 + (4.0 * progress), 0.2),
              colors: [
                base,
                highlight,
                base,
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A versatile skeleton bone shape with automatic theme adaptation.
/// Can be used standalone or grouped inside an [AppShimmer].
class SkeletonLoader extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;
  final BoxShape shape;
  final Color? color;
  final bool animateStandalone;

  const SkeletonLoader({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
    this.color,
    this.animateStandalone = true,
  });

  /// Circular skeleton shape (e.g. avatars, circular badges).
  const SkeletonLoader.circle({
    super.key,
    required double size,
    this.color,
    this.animateStandalone = true,
  })  : width = size,
        height = size,
        borderRadius = null,
        shape = BoxShape.circle;

  /// Multi-line text placeholder bone.
  static Widget text({
    int lines = 1,
    double height = 14,
    double spacing = 6,
    double? width,
    BorderRadius? borderRadius,
  }) {
    if (lines <= 1) {
      return SkeletonLoader(
        width: width,
        height: height,
        borderRadius: borderRadius ?? BorderRadius.circular(4),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(lines, (index) {
        final isLast = index == lines - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : spacing),
          child: SkeletonLoader(
            width: isLast && width == null ? 140 : width,
            height: height,
            borderRadius: borderRadius ?? BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.animateStandalone) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = widget.color ??
        (isDark ? const Color(0xFF192D4A) : const Color(0xFFE2E8F0));
    final highlightColor = isDark ? const Color(0xFF2A4368) : const Color(0xFFF8FAFC);

    final boxDecoration = BoxDecoration(
      color: baseColor,
      shape: widget.shape,
      borderRadius: widget.shape == BoxShape.circle
          ? null
          : (widget.borderRadius ?? BorderRadius.circular(8)),
    );

    if (_controller == null) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: boxDecoration,
      );
    }

    return AnimatedBuilder(
      animation: _controller!,
      builder: (context, _) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final progress = _controller!.value;
            return LinearGradient(
              begin: Alignment(-2.0 + (4.0 * progress), -0.2),
              end: Alignment(-0.5 + (4.0 * progress), 0.2),
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: boxDecoration,
          ),
        );
      },
    );
  }
}

/// A shimmering list tile placeholder (leading avatar + title/subtitle + trailing badge).
class SkeletonListTile extends StatelessWidget {
  final bool hasLeading;
  final bool hasTrailing;
  final double leadingSize;
  final EdgeInsetsGeometry? contentPadding;

  const SkeletonListTile({
    super.key,
    this.hasLeading = true,
    this.hasTrailing = true,
    this.leadingSize = 42,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          if (hasLeading) ...[
            SkeletonLoader(
              width: leadingSize,
              height: leadingSize,
              borderRadius: BorderRadius.circular(12),
              animateStandalone: false,
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SkeletonLoader(
                  width: 160,
                  height: 14,
                  borderRadius: BorderRadius.circular(4),
                  animateStandalone: false,
                ),
                const SizedBox(height: 8),
                SkeletonLoader(
                  width: 100,
                  height: 11,
                  borderRadius: BorderRadius.circular(4),
                  animateStandalone: false,
                ),
              ],
            ),
          ),
          if (hasTrailing) ...[
            const SizedBox(width: 12),
            SkeletonLoader(
              width: 50,
              height: 22,
              borderRadius: BorderRadius.circular(12),
              animateStandalone: false,
            ),
          ],
        ],
      ),
    );
  }
}

/// A shimmering card placeholder with header, body content, and footer.
class SkeletonCard extends StatelessWidget {
  final double? height;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const SkeletonCard({
    super.key,
    this.height,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: height,
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SkeletonLoader(
                width: 36,
                height: 36,
                borderRadius: BorderRadius.circular(10),
                animateStandalone: false,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLoader(
                      width: 140,
                      height: 14,
                      borderRadius: BorderRadius.circular(4),
                      animateStandalone: false,
                    ),
                    const SizedBox(height: 6),
                    SkeletonLoader(
                      width: 80,
                      height: 10,
                      borderRadius: BorderRadius.circular(4),
                      animateStandalone: false,
                    ),
                  ],
                ),
              ),
              SkeletonLoader(
                width: 60,
                height: 24,
                borderRadius: BorderRadius.circular(8),
                animateStandalone: false,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SkeletonLoader(
            width: double.infinity,
            height: 12,
            borderRadius: BorderRadius.circular(4),
            animateStandalone: false,
          ),
          const SizedBox(height: 8),
          SkeletonLoader(
            width: 200,
            height: 12,
            borderRadius: BorderRadius.circular(4),
            animateStandalone: false,
          ),
        ],
      ),
    );
  }
}

/// A shimmering list view of [itemCount] skeleton tiles wrapped in a single [AppShimmer].
class SkeletonListView extends StatelessWidget {
  final int itemCount;
  final EdgeInsetsGeometry? padding;
  final Widget Function(BuildContext, int)? itemBuilder;

  const SkeletonListView({
    super.key,
    this.itemCount = 6,
    this.padding,
    this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: padding ?? const EdgeInsets.all(16),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: itemBuilder ?? (_, _) => const SkeletonCard(),
      ),
    );
  }
}
