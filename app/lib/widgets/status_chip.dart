import 'package:flutter/material.dart';
import 'package:tablecrew/core/theme/rsvp_status_colors.dart';
import 'package:tablecrew/core/theme/spacing_tokens.dart';
import 'package:tablecrew/core/theme/type_tokens.dart';

/// The RSVP/Table status chip named in `docs/DESIGN_SYSTEM.md` §4.3 —
/// "small pill-shaped chips (full corner radius, height 24px)... always
/// paired with a text label (never color alone — see Accessibility,
/// section 6)."
///
/// `status` drives both the color (`rsvpStatusColor`) and the fill-vs-
/// outline treatment (`rsvpStatusIsOutlined`) per §4.3's rule that
/// Waitlisted alone renders outlined, to "visually de-emphasize a
/// pending/uncertain state relative to a confirmed one." `label` is the
/// caller-supplied display text (e.g. "Going," "Waitlisted") — this widget
/// does not hard-code label strings itself, since exact copy is
/// `docs/COPY_GUIDELINES.md`'s ownership, not the design-system layer's.
class StatusChip extends StatelessWidget {
  /// Creates a status chip for [status], labeled with [label].
  const StatusChip({required this.status, required this.label, super.key});

  /// Which of the five display states (per `docs/DESIGN_SYSTEM.md` §1.3)
  /// this chip represents.
  final RsvpDisplayStatus status;

  /// The chip's visible text — see the class doc comment on why this isn't
  /// derived from [status] internally.
  final String label;

  static const _height = 24.0;

  @override
  Widget build(BuildContext context) {
    final color = rsvpStatusColor(status);
    final outlined = rsvpStatusIsOutlined(status);
    // §4.3's one filled exception: Not Going pairs its Warm Grey fill with
    // ink text, not the cream text every other filled chip uses (Warm Grey
    // is too light for cream text to meet §6's contrast standard against).
    final isNotGoing = status == RsvpDisplayStatus.notGoing;
    final scheme = Theme.of(context).colorScheme;
    final textColor =
        outlined ? color : (isNotGoing ? scheme.onSurface : scheme.surface);

    return Semantics(
      label: label,
      child: Container(
        height: _height,
        padding: const EdgeInsets.symmetric(horizontal: TCSpacing.sm),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : color,
          border: outlined ? Border.all(color: color, width: 1.5) : null,
          borderRadius: BorderRadius.circular(_height / 2),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TCTextStyles.caption.copyWith(color: textColor),
        ),
      ),
    );
  }
}
