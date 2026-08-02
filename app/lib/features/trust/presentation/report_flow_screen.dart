import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tablecrew/core/theme/spacing_tokens.dart';
import 'package:tablecrew/core/theme/type_tokens.dart';
import 'package:tablecrew/data/trust_repository.dart';
import 'package:tablecrew/features/trust/application/report_flow_controller.dart';

/// Screen 27 (Report Flow), `docs/SCREEN_SPECIFICATIONS.md`.
///
/// Reachable within 2 taps from any screen showing another person — this
/// milestone wires that entry point from Table Detail's attendee rows
/// (`table_detail_screen.dart`'s `_AttendeeRow` overflow menu, added in the
/// same chunk as this screen); other entry points named in the spec
/// (Discover Table Preview, Crew Detail's roster, Crew Chat, the Live
/// Table Screen's roster) don't have a built screen to reach it from yet
/// (Discover is Milestone F7; Crew Detail/Chat and Live Table are F8) and
/// will wire the same route once they exist.
///
/// **Disclosed scope cut:** no evidence/screenshot attachment field.
/// `docs/DATABASE.md` §3.6's `reports/{reportId}` schema has no field for
/// one at all (`reasonCode`, `severity`, `isDuressSignal`, `details`,
/// `status`, `assignedTo`, `resolutionNotes` — no attachment/photo field),
/// and no upload pipeline exists for this purpose — building one is a real
/// schema + Storage-path design decision, not something to guess at inside
/// this chunk. The spec calls the attachment "optional but recommended,"
/// so its absence doesn't block the flow's actual purpose.
///
/// Added Milestone F6 (Trust & Safety client chunk).
class ReportFlowScreen extends ConsumerStatefulWidget {
  /// Creates the Report Flow screen for [targetId], a user uid if
  /// [targetType] is `"user"` or a Table id if `"table"`.
  const ReportFlowScreen({
    required this.targetType,
    required this.targetId,
    required this.targetDisplayName,
    super.key,
  });

  /// `"user"` or `"table"` — which callable is used and whether the
  /// inline block toggle is offered at all (never for a Table target).
  final String targetType;

  /// The reported user's uid, or the reported Table's id.
  final String targetId;

  /// Shown in the screen's headline ("Report {name}").
  final String targetDisplayName;

  @override
  ConsumerState<ReportFlowScreen> createState() => _ReportFlowScreenState();
}

class _ReportFlowScreenState extends ConsumerState<ReportFlowScreen> {
  final _detailsController = TextEditingController();
  ReportReasonCode? _reasonCode;
  bool _alsoBlock = false;
  bool _blockToggleTouched = false;

  String get _targetRef => '${widget.targetType}:${widget.targetId}';

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  bool get _detailsRequired => _reasonCode == ReportReasonCode.offPlatform;

  bool get _canSubmit {
    final reason = _reasonCode;
    if (reason == null) return false;
    if (_detailsRequired && _detailsController.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  void _selectReason(ReportReasonCode reason) {
    setState(() {
      _reasonCode = reason;
      // Screen 27: the block toggle "pre-checked by default when
      // Harassment or the off-platform reason is selected, present-but-
      // unchecked for lower-severity reasons" — but only until the user
      // has touched it themselves; a user who deliberately unchecks it
      // shouldn't have that choice silently overridden by picking a
      // different higher-severity reason afterward.
      if (!_blockToggleTouched) {
        _alsoBlock = reason == ReportReasonCode.harassment ||
            reason == ReportReasonCode.offPlatform;
      }
    });
  }

  Future<void> _submit() async {
    final reason = _reasonCode;
    if (reason == null) return;
    await ref.read(reportFlowControllerProvider(_targetRef).notifier).submit(
          reasonCode: reason,
          details: _detailsController.text.trim().isEmpty
              ? null
              : _detailsController.text.trim(),
          alsoBlock: widget.targetType == 'user' && _alsoBlock,
        );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reportState = ref.watch(reportFlowControllerProvider(_targetRef));

    if (reportState.status == ReportFlowStatus.succeeded) {
      return _ReportConfirmation(onDone: () => Navigator.of(context).pop());
    }

    final submitting = reportState.status == ReportFlowStatus.submitting;

    return Scaffold(
      appBar: AppBar(title: const Text('Report')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(TCSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Report ${widget.targetDisplayName}',
                style: TCTextStyles.displayMd.copyWith(color: colors.onSurface),
              ),
              const SizedBox(height: TCSpacing.lg),
              // Offline Behavior: "regardless of connectivity, the screen
              // always displays a static, non-gated line of text" — this
              // must never be hidden behind a network check.
              Text(
                "If you're in immediate danger, contact local emergency "
                'services.',
                style: TCTextStyles.bodyMd.copyWith(color: colors.error),
              ),
              const SizedBox(height: TCSpacing.lg),
              RadioGroup<ReportReasonCode>(
                groupValue: _reasonCode,
                onChanged: (value) => _selectReason(value!),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      container: true,
                      label: 'Reasons',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final reason in const [
                            ReportReasonCode.harassment,
                            ReportReasonCode.inappropriateContent,
                            ReportReasonCode.safetyConcern,
                            ReportReasonCode.noShow,
                            ReportReasonCode.fakeProfile,
                          ])
                            RadioListTile<ReportReasonCode>(
                              value: reason,
                              title: Text(reason.label),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: TCSpacing.xl),
                    Semantics(
                      container: true,
                      label: 'Off-platform harassment',
                      child: RadioListTile<ReportReasonCode>(
                        value: ReportReasonCode.offPlatform,
                        title: Text(ReportReasonCode.offPlatform.label),
                        subtitle: const Text(
                          'For harassment or stalking that continued after '
                          'a Table, off the platform — this gets reviewed '
                          'differently and faster.',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: TCSpacing.lg),
              TextField(
                controller: _detailsController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: _detailsRequired
                      ? 'What happened? (required)'
                      : 'What happened? (optional)',
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (widget.targetType == 'user') ...[
                const SizedBox(height: TCSpacing.md),
                CheckboxListTile(
                  value: _alsoBlock,
                  title: const Text('Also block this person'),
                  onChanged: (value) => setState(() {
                    _blockToggleTouched = true;
                    _alsoBlock = value ?? false;
                  }),
                ),
              ],
              if (reportState.status == ReportFlowStatus.failed) ...[
                const SizedBox(height: TCSpacing.md),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    reportState.errorCode == 'already-exists'
                        ? "You've already reported this — our team is on it."
                        : reportState.errorMessage ?? 'Something went wrong.',
                    style: TCTextStyles.bodyMd.copyWith(color: colors.error),
                  ),
                ),
              ],
              const SizedBox(height: TCSpacing.lg),
              ElevatedButton(
                onPressed: _canSubmit && !submitting ? _submit : null,
                child: Text(submitting ? 'Submitting…' : 'Submit Report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportConfirmation extends StatelessWidget {
  const _ReportConfirmation({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(TCSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Thanks, we've got this",
                textAlign: TextAlign.center,
                style: TCTextStyles.displayMd.copyWith(color: colors.onSurface),
              ),
              const SizedBox(height: TCSpacing.sm),
              Text(
                'Our Trust & Safety team will review this report.',
                textAlign: TextAlign.center,
                style: TCTextStyles.bodyMd.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: TCSpacing.lg),
              ElevatedButton(onPressed: onDone, child: const Text('Done')),
            ],
          ),
        ),
      ),
    );
  }
}
