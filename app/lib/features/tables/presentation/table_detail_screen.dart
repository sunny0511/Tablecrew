import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tablecrew/core/auth_state.dart';
import 'package:tablecrew/core/theme/rsvp_status_colors.dart';
import 'package:tablecrew/core/theme/spacing_tokens.dart';
import 'package:tablecrew/core/theme/type_tokens.dart';
import 'package:tablecrew/data/tables_repository.dart';
import 'package:tablecrew/features/tables/application/table_detail_action_controller.dart';
import 'package:tablecrew/features/tables/application/table_detail_controller.dart';
import 'package:tablecrew/widgets/skeleton_pulse.dart';
import 'package:tablecrew/widgets/status_chip.dart';

const _monthAbbreviations = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _cancelWindow = Duration(hours: 2);

/// Screen 13 (Table Detail), `docs/SCREEN_SPECIFICATIONS.md`.
///
/// **Disclosed F6 scope decisions, each also flagged in `TASKS.md`:**
/// - **Full attendee list is host-only.** `firestore.rules`' nested
///   `rsvps` rule (`rsvpUserId == request.auth.uid || isTableHost`) is
///   evaluated per-document even for a `list()` query, so a non-host
///   listing the whole subcollection has every document but their own
///   fail — Firestore denies the entire query rather than filtering.
///   There's no denormalized attendee-preview field on the Table document
///   either (the same gap `HomeScreen`'s doc comment already discloses).
///   A non-host viewer sees only their own RSVP status here; closing this
///   for real needs a schema change, not a client workaround.
/// - **No Table Chat preview, Waitlist link, Rate-this-Table action, or
///   Live-Table-Screen transition** — none of those features exist yet
///   (Chat/Waitlist/Rating are Milestone F8; Live Table Screen is F8 too).
/// - **"Manage Table" collapses into the overflow menu** rather than a
///   separate management surface — there's no dedicated Manage screen to
///   route to this chunk, and Cancel Table / Invite more people cover the
///   host actions this milestone actually builds. "Edit details" is
///   visible but disabled (reusing Create Table's form for editing is
///   deferred, flagged as a follow-up).
/// - **Per-attendee report/block overflow** (`_AttendeeRow`'s trailing
///   menu) was deferred out of this chunk and added in the Trust & Safety
///   client chunk that followed it, per `docs/SECURITY.md`/`CLAUDE.md`'s
///   safety-gating of anything touching reporting/blocking. It routes to
///   Screen 27 (Report Flow) / Screen 28 (Block Confirmation) via plain
///   query parameters, and is hidden on the current user's own row (self-
///   report/self-block is prevented by construction, per both screens'
///   own Validation Rules).
///
/// Added Milestone F6.
class TableDetailScreen extends ConsumerWidget {
  /// Creates the Table Detail screen for [tableId].
  const TableDetailScreen({required this.tableId, super.key});

  /// The Table's document id.
  final String tableId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final dataAsync = ref.watch(tableDetailControllerProvider(tableId));
    final actionState = ref.watch(tableDetailActionControllerProvider(tableId));

    ref.listen(tableDetailActionControllerProvider(tableId), (
      previous,
      next,
    ) {
      if (next.status == TableDetailActionStatus.succeeded) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Done.')));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Table Detail'),
        actions: [
          dataAsync.maybeWhen(
            data: (data) => data.isHost
                ? _HostOverflowMenu(tableId: tableId, table: data.table)
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        child: dataAsync.when(
          loading: _buildSkeleton,
          error: (error, _) => Center(
            child: Text(
              "Couldn't load this Table.",
              style: TCTextStyles.bodyMd.copyWith(color: colors.error),
            ),
          ),
          data: (data) => _TableDetailBody(
            tableId: tableId,
            data: data,
            actionState: actionState,
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(TCSpacing.md),
      children: const [
        SkeletonPulse(width: double.infinity, height: 120),
        SizedBox(height: TCSpacing.md),
        SkeletonPulse(width: double.infinity, height: 64),
        SizedBox(height: TCSpacing.sm),
        SkeletonPulse(width: double.infinity, height: 64),
        SizedBox(height: TCSpacing.sm),
        SkeletonPulse(width: double.infinity, height: 64),
      ],
    );
  }
}

class _TableDetailBody extends ConsumerWidget {
  const _TableDetailBody({
    required this.tableId,
    required this.data,
    required this.actionState,
  });

  final String tableId;
  final TableDetailData data;
  final TableDetailActionState actionState;

  String _formatStart(DateTime start) {
    final month = _monthAbbreviations[start.month - 1];
    final hour = start.hour % 12 == 0 ? 12 : start.hour % 12;
    final minute = start.minute.toString().padLeft(2, '0');
    final period = start.hour < 12 ? 'AM' : 'PM';
    return '$month ${start.day}, $hour:$minute $period';
  }

  Future<void> _confirmAndCancelRsvp(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final withinWindow =
        data.table.startTime.difference(DateTime.now()) < _cancelWindow;
    if (withinWindow) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancel your RSVP?'),
          content: const Text(
            'This Table starts soon — the host will be notified right away.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep my seat'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Cancel RSVP'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    if (!context.mounted) return;
    await ref
        .read(tableDetailActionControllerProvider(tableId).notifier)
        .cancelRsvp();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final table = data.table;
    final isActing = actionState.status == TableDetailActionStatus.acting;

    return ListView(
      padding: const EdgeInsets.all(TCSpacing.md),
      children: [
        Text(
          table.title,
          style: TCTextStyles.displayMd.copyWith(color: colors.onSurface),
        ),
        const SizedBox(height: TCSpacing.xs),
        Text(
          '${table.venueName ?? 'Venue TBD'} · '
          '${_formatStart(table.startTime)}',
          style: TCTextStyles.bodyMd.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: TCSpacing.sm),
        Text(
          '${table.confirmedCount} of ${table.capacityMax} going',
          style: TCTextStyles.caption.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: TCSpacing.lg),
        if (data.isHost)
          _AttendeeList(
            tableId: tableId,
            attendees: data.attendees,
            sharesCrew: data.table.crewId != null,
          )
        else if (data.myRsvpStatus != null)
          StatusChip(
            status: _displayStatusFor(data.myRsvpStatus!),
            label: _labelFor(data.myRsvpStatus!),
          ),
        const SizedBox(height: TCSpacing.lg),
        if (actionState.status == TableDetailActionStatus.failed &&
            actionState.errorCode == 'SEAT_REQUEST_CONTENTION')
          _InlineNotice(
            message: actionState.errorMessage ??
                'Lots of people grabbing a seat right now — try again in a '
                    'second.',
            color: colors.error,
          )
        else if (actionState.status == TableDetailActionStatus.failed &&
            actionState.errorMessage != null)
          _InlineNotice(message: actionState.errorMessage!, color: colors.error)
        else if (actionState.status == TableDetailActionStatus.queuedOffline)
          _InlineNotice(
            message: "You're offline — this will send once you're back "
                'online.',
            color: colors.onSurfaceVariant,
          ),
        const SizedBox(height: TCSpacing.md),
        if (isActing)
          const SkeletonPulse(
            width: double.infinity,
            height: TCSpacing.minTouchTarget,
          )
        else
          _buildPrimaryAction(context, ref, colors),
      ],
    );
  }

  Widget _buildPrimaryAction(
    BuildContext context,
    WidgetRef ref,
    ColorScheme colors,
  ) {
    final table = data.table;
    final isLive =
        !['happened', 'rated', 'cancelled'].contains(_statusWire(table.status));

    if (data.isHost) {
      // Manage Table collapses into the overflow menu this chunk (see
      // this screen's own doc comment) — no separate primary action.
      return const SizedBox.shrink();
    }
    if (data.myRsvpStatus == null) {
      return ElevatedButton(
        onPressed: isLive
            ? () => ref
                .read(tableDetailActionControllerProvider(tableId).notifier)
                .requestSeat()
            : null,
        child: const Text('Request to Join'),
      );
    }
    if (data.myRsvpStatus == RsvpStatus.declined ||
        data.myRsvpStatus == RsvpStatus.noShow) {
      return const SizedBox.shrink();
    }
    return OutlinedButton(
      onPressed: isLive ? () => _confirmAndCancelRsvp(context, ref) : null,
      child: const Text('Cancel RSVP'),
    );
  }

  String _statusWire(TableStatus status) => status.name;
}

class _AttendeeList extends ConsumerWidget {
  const _AttendeeList({
    required this.tableId,
    required this.attendees,
    required this.sharesCrew,
  });

  final String tableId;
  final List<AttendeeSummary> attendees;

  /// Whether this Table is Crew-scoped — passed through to the Block
  /// Confirmation entry point (see `_AttendeeRow`'s overflow menu).
  final bool sharesCrew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;

    if (attendees.isEmpty) {
      // Empty States: "Nobody's joined yet" / "Share this Table to fill
      // it up."
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Nobody's joined yet",
            style: TCTextStyles.headingMd.copyWith(color: colors.onSurface),
          ),
          const SizedBox(height: TCSpacing.xs),
          Text(
            'Share this Table to fill it up',
            style: TCTextStyles.bodyMd.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: TCSpacing.md),
          ElevatedButton(
            onPressed: () => GoRouter.of(context).goNamed(
              'invite',
              pathParameters: {'tableId': tableId},
            ),
            child: const Text('Share this Table'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final attendee in attendees)
          _AttendeeRow(
            tableId: tableId,
            attendee: attendee,
            sharesCrew: sharesCrew,
          ),
      ],
    );
  }
}

class _AttendeeRow extends ConsumerWidget {
  const _AttendeeRow({
    required this.tableId,
    required this.attendee,
    required this.sharesCrew,
  });

  final String tableId;
  final AttendeeSummary attendee;
  final bool sharesCrew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    // Never surfaced on the current user's own row — self-report/self-
    // block is prevented by construction, per Screens 27/28's own
    // Validation Rules, rather than by a validation error message.
    final isSelf = ref.watch(currentUidProvider) == attendee.uid;

    return Semantics(
      label: '${attendee.displayName}, ${_labelFor(attendee.status)}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: TCSpacing.xs),
          child: Row(
            children: [
              CircleAvatar(
                backgroundImage: attendee.photoUrl != null
                    ? NetworkImage(attendee.photoUrl!)
                    : null,
                child: attendee.photoUrl == null
                    ? Text(
                        attendee.displayName.isEmpty
                            ? '?'
                            : attendee.displayName[0].toUpperCase(),
                      )
                    : null,
              ),
              const SizedBox(width: TCSpacing.sm),
              Expanded(
                child: Text(
                  attendee.displayName,
                  style: TCTextStyles.bodyMd.copyWith(color: colors.onSurface),
                ),
              ),
              StatusChip(
                status: _displayStatusFor(attendee.status),
                label: _labelFor(attendee.status),
              ),
              if (attendee.status == RsvpStatus.requested) ...[
                const SizedBox(width: TCSpacing.sm),
                TextButton(
                  onPressed: () => ref
                      .read(
                        tableDetailActionControllerProvider(tableId).notifier,
                      )
                      .confirmAttendee(attendee.uid),
                  child: const Text('Confirm'),
                ),
              ],
              if (!isSelf)
                PopupMenuButton<String>(
                  tooltip: 'More actions for ${attendee.displayName}',
                  onSelected: (value) {
                    switch (value) {
                      case 'report':
                        unawaited(
                          context.pushNamed(
                            'report',
                            queryParameters: {
                              'targetType': 'user',
                              'targetId': attendee.uid,
                              'targetDisplayName': attendee.displayName,
                            },
                          ),
                        );
                      case 'block':
                        unawaited(
                          context.pushNamed(
                            'block',
                            queryParameters: {
                              'targetUserId': attendee.uid,
                              'targetDisplayName': attendee.displayName,
                              'sharesCrew': sharesCrew.toString(),
                            },
                          ),
                        );
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'report', child: Text('Report')),
                    PopupMenuItem(value: 'block', child: Text('Block')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HostOverflowMenu extends ConsumerWidget {
  const _HostOverflowMenu({required this.tableId, required this.table});

  final String tableId;
  final TableSummary table;

  Future<void> _confirmAndCancelTable(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final reasonController = TextEditingController();
    // A plain `showDialog` builder is called once — without a
    // StatefulBuilder wrapping it, nothing rebuilds the dialog as the
    // user types, so a naive `reasonController.text.trim().isEmpty`
    // gate on the confirm button's `onPressed` would evaluate exactly
    // once (against the empty starting text) and stay disabled forever,
    // no matter what's typed. `StatefulBuilder`'s own `setState`, driven
    // by the field's `onChanged`, is what makes the button's enabled
    // state actually track the typed reason.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Cancel this Table?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Attendees will be notified with your reason.'),
              const SizedBox(height: TCSpacing.sm),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'Reason'),
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Never mind'),
            ),
            TextButton(
              onPressed: reasonController.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(true),
              child: const Text('Cancel Table'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref
        .read(tableDetailActionControllerProvider(tableId).notifier)
        .cancelTable(reason: reasonController.text.trim());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'cancel':
            unawaited(_confirmAndCancelTable(context, ref));
          case 'invite':
            GoRouter.of(context)
                .goNamed('invite', pathParameters: {'tableId': tableId});
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'cancel', child: Text('Cancel Table')),
        PopupMenuItem(value: 'invite', child: Text('Invite more people')),
        // "Edit details" is deliberately omitted, not disabled-and-shown:
        // reusing Create Table's form for editing is deferred (this
        // screen's own doc comment), and an item with no handler at all
        // would be a worse affordance than not offering it yet.
      ],
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Text(message, style: TCTextStyles.bodyMd.copyWith(color: color)),
    );
  }
}

/// Maps an rsvp document's status onto the design system's 5-chip
/// vocabulary — same mapping `HomeController.buildHomeTableCard` uses for
/// Home's cards (declined/no_show never reach that mapping there, since
/// Home's own query excludes them; here, a host viewing the full attendee
/// list can see them, so this covers those two cases as well).
RsvpDisplayStatus _displayStatusFor(RsvpStatus status) {
  return switch (status) {
    RsvpStatus.confirmed || RsvpStatus.attended => RsvpDisplayStatus.going,
    RsvpStatus.requested || RsvpStatus.invited => RsvpDisplayStatus.requested,
    RsvpStatus.waitlisted => RsvpDisplayStatus.waitlisted,
    RsvpStatus.declined || RsvpStatus.noShow => RsvpDisplayStatus.notGoing,
    RsvpStatus.unknown => RsvpDisplayStatus.notGoing,
  };
}

String _labelFor(RsvpStatus status) {
  return switch (status) {
    RsvpStatus.confirmed || RsvpStatus.attended => 'Going',
    RsvpStatus.requested || RsvpStatus.invited => 'Requested',
    RsvpStatus.waitlisted => 'Waitlisted',
    RsvpStatus.declined => 'Not Going',
    RsvpStatus.noShow => 'No Show',
    RsvpStatus.unknown => 'Unknown',
  };
}
