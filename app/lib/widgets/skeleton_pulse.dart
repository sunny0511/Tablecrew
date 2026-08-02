import 'package:flutter/material.dart';
import 'package:tablecrew/core/theme/color_tokens.dart';
import 'package:tablecrew/core/theme/spacing_tokens.dart';

/// The "gentle pulsing skeleton in Card Cream tones" loading treatment
/// `docs/DESIGN_SYSTEM.md` §8 specifies in place of a spinner ("a spinner
/// communicates 'wait, something is processing,' a soft pulse communicates
/// 'we're getting your table ready'"). Used both as a small inline shape
/// (Screens 2/3/5's buttons/fields morphing into an inline pulse in place
/// of their normal content) and, via [width]/[height], as a full-width bar
/// (Screen 1's post-800ms loading indicator).
///
/// Respects the OS reduced-motion setting (Screen 1's Accessibility Notes)
/// by rendering a static, non-animating fill instead of pulsing when
/// [MediaQuery.disableAnimationsOf] is true.
///
/// Added Milestone F5.
class SkeletonPulse extends StatefulWidget {
  /// Creates a skeleton-pulse shape of [width] x [height].
  const SkeletonPulse({required this.width, required this.height, super.key});

  /// The shape's width, or `double.infinity` to fill the available width.
  final double width;

  /// The shape's height.
  final double height;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final shape = DecoratedBox(
      decoration: BoxDecoration(
        color: TCColors.neutral50,
        borderRadius: BorderRadius.circular(TCSpacing.radiusControl),
      ),
    );

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: reduceMotion
          ? Opacity(opacity: 0.7, child: shape)
          : AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: 0.4 + (_controller.value * 0.5),
                  child: child,
                );
              },
              child: shape,
            ),
    );
  }
}
