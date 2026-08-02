import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tablecrew/core/theme/color_tokens.dart';
import 'package:tablecrew/core/theme/spacing_tokens.dart';
import 'package:tablecrew/core/theme/type_tokens.dart';
import 'package:tablecrew/data/interest_taxonomy.dart';
import 'package:tablecrew/data/table_mutations_repository.dart';
import 'package:tablecrew/features/tables/application/create_table_controller.dart';
import 'package:tablecrew/features/tables/application/create_table_draft_controller.dart';
import 'package:tablecrew/features/tables/presentation/venue_picker_screen.dart';
import 'package:tablecrew/widgets/skeleton_pulse.dart';

const _monthAbbreviations = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Screen 10 (Create Table), `docs/SCREEN_SPECIFICATIONS.md`.
///
/// **Disclosed F6 scope decisions (each flagged in `TASKS.md` too):**
/// - **Visibility is Crew-only/Closed only.** The Open/Discover options and
///   their Tier-2 Identity Verification interstitial are Milestone F7's
///   scope by explicit plan (`docs/IMPLEMENTATION_PLAN.md` §4 — "the
///   Open-visibility branch of createTable (Screen 10's dormant branch)"
///   is an F7 deliverable, and Screen 8 has no route at all yet). The
///   segmented control shows all three options with Open/Discover disabled
///   and explanatory copy, rather than hiding the choice — the user learns
///   the option exists without a dead-end tap.
/// - **No recurring-Table toggle.** `scheduleRecurringTable` moved out of
///   Foundation entirely (2026-08 re-scope, `docs/IMPLEMENTATION_PLAN.md`
///   §2.4).
/// - **A title field exists here that Screen 10's UI Components list
///   doesn't mention** — `createTable` *requires* `title` (1-100 chars,
///   `docs/API_SPEC.md` §3.1) and every Table Card/Detail renders it, so
///   the spec's omission is treated as a spec gap (flagged for
///   reconciliation), not a reason to invent a derived title server-side.
///
/// Added Milestone F6.
class CreateTableScreen extends ConsumerStatefulWidget {
  /// Creates the Create Table screen. [crewId] pre-fills the Crew when
  /// entered via a Crew Card's "Schedule a Table" quick action.
  const CreateTableScreen({this.crewId, super.key});

  /// The originating Crew, if any.
  final String? crewId;

  @override
  ConsumerState<CreateTableScreen> createState() => _CreateTableScreenState();
}

class _CreateTableScreenState extends ConsumerState<CreateTableScreen> {
  final _titleController = TextEditingController();
  bool _titleSyncedFromDraft = false;

  @override
  void initState() {
    super.initState();
    final crewId = widget.crewId;
    if (crewId != null) {
      unawaited(
        ref.read(createTableDraftControllerProvider.notifier).setCrewId(crewId),
      );
    }
    _titleController.addListener(() {
      unawaited(
        ref
            .read(createTableDraftControllerProvider.notifier)
            .setTitle(_titleController.text),
      );
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickVenue() async {
    final venue = await Navigator.of(context).push(
      MaterialPageRoute<VenueSelection>(
        builder: (context) => const VenuePickerScreen(),
      ),
    );
    if (venue == null || !mounted) return;
    await ref.read(createTableDraftControllerProvider.notifier).setVenue(venue);
  }

  Future<void> _pickStartTime(DateTime? current) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'When is your Table?',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: current == null
          ? const TimeOfDay(hour: 19, minute: 0)
          : TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    await ref.read(createTableDraftControllerProvider.notifier).setStartTime(
          DateTime(date.year, date.month, date.day, time.hour, time.minute),
        );
  }

  Future<void> _submit() async {
    final proceed =
        await ref.read(createTableControllerProvider.notifier).submit();
    if (!mounted || !proceed) return;

    final state = ref.read(createTableControllerProvider);
    if (state.status == CreateTableStatus.succeeded) {
      // Exit Points: Invite & Share Sheet immediately after successful
      // creation (still a stub route this chunk; Screen 12 is next).
      context.goNamed(
        'invite',
        pathParameters: {'tableId': state.createdTableId!},
      );
    } else if (state.status == CreateTableStatus.queuedOffline) {
      // Offline Behavior: the Table exists locally as a Draft; Home is
      // where the user lands while it waits to send.
      context.goNamed('home');
    }
  }

  String _formatStart(DateTime start) {
    final month = _monthAbbreviations[start.month - 1];
    final hour = start.hour % 12 == 0 ? 12 : start.hour % 12;
    final minute = start.minute.toString().padLeft(2, '0');
    final period = start.hour < 12 ? 'AM' : 'PM';
    return '$month ${start.day}, $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final draftAsync = ref.watch(createTableDraftControllerProvider);
    final submitState = ref.watch(createTableControllerProvider);
    final isSubmitting = submitState.status == CreateTableStatus.submitting;

    return Scaffold(
      appBar: AppBar(title: const Text('Plan a Table')),
      body: SafeArea(
        child: draftAsync.when(
          loading: () => const Center(
            child: SkeletonPulse(width: 200, height: 48),
          ),
          error: (error, _) => Center(
            child: Text(
              "Couldn't load your draft.",
              style: TCTextStyles.bodyMd.copyWith(color: colors.error),
            ),
          ),
          data: (draft) {
            if (!_titleSyncedFromDraft) {
              _titleSyncedFromDraft = true;
              _titleController.text = draft.title;
            }
            final recommended = recommendedHeadcountFor(draft.interestTag);
            final headcount = draft.headcount ?? recommended.start;
            final canSubmit = draft.title.trim().isNotEmpty &&
                draft.venue != null &&
                draft.startTime != null &&
                !isSubmitting;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(TCSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Plan a Table',
                    style: TCTextStyles.displayLg.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: TCSpacing.lg),
                  TextField(
                    controller: _titleController,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      labelText: 'What are you planning?',
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: TCSpacing.md),
                  Text(
                    'Activity',
                    style: TCTextStyles.headingMd.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: TCSpacing.sm),
                  Wrap(
                    spacing: TCSpacing.sm,
                    runSpacing: TCSpacing.sm,
                    children: [
                      for (final option in kInterestTaxonomy)
                        ChoiceChip(
                          label: Text(option.label),
                          selected: draft.interestTag == option.tag,
                          selectedColor: TCColors.primary100,
                          onSelected: (_) => unawaited(
                            ref
                                .read(
                                  createTableDraftControllerProvider.notifier,
                                )
                                .setInterestTag(option.tag),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: TCSpacing.lg),
                  _VenueField(venue: draft.venue, onTap: _pickVenue),
                  const SizedBox(height: TCSpacing.md),
                  OutlinedButton(
                    onPressed: isSubmitting
                        ? null
                        : () => _pickStartTime(draft.startTime),
                    child: Text(
                      draft.startTime == null
                          ? 'Pick a date & time'
                          : _formatStart(draft.startTime!),
                    ),
                  ),
                  const SizedBox(height: TCSpacing.lg),
                  _HeadcountStepper(
                    headcount: headcount,
                    recommended: recommended,
                    interestLabel: _labelFor(draft.interestTag),
                    onChanged: (value) => unawaited(
                      ref
                          .read(createTableDraftControllerProvider.notifier)
                          .setHeadcount(value),
                    ),
                  ),
                  const SizedBox(height: TCSpacing.lg),
                  Text(
                    'Visibility',
                    style: TCTextStyles.headingMd.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: TCSpacing.sm),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'closed',
                        label: Text('Crew-only'),
                      ),
                      ButtonSegment(
                        value: 'open',
                        label: Text('Open'),
                        enabled: false,
                      ),
                      ButtonSegment(
                        value: 'discover',
                        label: Text('Discover'),
                        enabled: false,
                      ),
                    ],
                    selected: const {'closed'},
                    onSelectionChanged: (_) {},
                  ),
                  const SizedBox(height: TCSpacing.xs),
                  Text(
                    'Only people you invite can see this Table. Open and '
                    'Discover listings arrive with identity verification.',
                    style: TCTextStyles.caption.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: TCSpacing.md),
                  if (submitState.status == CreateTableStatus.failed &&
                      submitState.errorMessage != null) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        submitState.errorMessage!,
                        style:
                            TCTextStyles.bodyMd.copyWith(color: colors.error),
                      ),
                    ),
                    const SizedBox(height: TCSpacing.md),
                  ],
                  if (isSubmitting)
                    const SkeletonPulse(
                      width: double.infinity,
                      height: TCSpacing.minTouchTarget,
                    )
                  else
                    ElevatedButton(
                      onPressed: canSubmit ? _submit : null,
                      child: const Text('Create Table'),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _labelFor(String? interestTag) {
    for (final option in kInterestTaxonomy) {
      if (option.tag == interestTag) return option.label;
    }
    return 'any activity';
  }
}

/// Empty States: "The venue field's unselected state is a dashed-outline
/// row with a pin icon and Inter microcopy ('Choose a venue')."
class _VenueField extends StatelessWidget {
  const _VenueField({required this.venue, required this.onTap});

  final VenueSelection? venue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = venue == null ? 'Choose a venue' : venue!.name;
    final sublabel = venue?.address;

    return Semantics(
      button: true,
      label: venue == null ? 'Choose a venue' : 'Venue: $label, $sublabel',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(TCSpacing.radiusControl),
          child: Container(
            padding: const EdgeInsets.all(TCSpacing.md),
            decoration: BoxDecoration(
              border: Border.all(color: colors.outline),
              borderRadius: BorderRadius.circular(TCSpacing.radiusControl),
            ),
            child: Row(
              children: [
                Icon(Icons.place_outlined, color: colors.onSurfaceVariant),
                const SizedBox(width: TCSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TCTextStyles.bodyLg.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                      if (sublabel != null)
                        Text(
                          sublabel,
                          style: TCTextStyles.caption.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Screen 10's headcount stepper: hard-clamped 2-8, with the
/// activity-specific recommended band shown as text (and announced on
/// focus per the Accessibility Notes), not enforced as a boundary.
class _HeadcountStepper extends StatelessWidget {
  const _HeadcountStepper({
    required this.headcount,
    required this.recommended,
    required this.interestLabel,
    required this.onChanged,
  });

  static const _hardMin = 2;
  static const _hardMax = 8;

  final int headcount;
  final ({int min, int max, int start}) recommended;
  final String interestLabel;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      label: '$headcount people, recommended ${recommended.min} to '
          '${recommended.max} for $interestLabel',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How many people?',
              style: TCTextStyles.headingMd.copyWith(color: colors.onSurface),
            ),
            const SizedBox(height: TCSpacing.sm),
            Row(
              children: [
                IconButton(
                  onPressed: headcount > _hardMin
                      ? () => onChanged(headcount - 1)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '$headcount',
                  style: TCTextStyles.headingLg.copyWith(
                    color: colors.onSurface,
                  ),
                ),
                IconButton(
                  onPressed: headcount < _hardMax
                      ? () => onChanged(headcount + 1)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
                const SizedBox(width: TCSpacing.sm),
                Text(
                  'Recommended ${recommended.min}-${recommended.max}',
                  style: TCTextStyles.caption.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
