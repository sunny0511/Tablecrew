import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tablecrew/core/theme/spacing_tokens.dart';
import 'package:tablecrew/core/theme/type_tokens.dart';
import 'package:tablecrew/data/crews_repository.dart';
import 'package:tablecrew/features/tables/application/invite_share_data.dart';
import 'package:tablecrew/widgets/skeleton_pulse.dart';

/// Screen 12 (Invite & Share Sheet), `docs/SCREEN_SPECIFICATIONS.md` —
/// **Crew-only branch only, link-copy only, Milestone F6.**
///
/// **Disclosed scope cuts, each also in `TASKS.md`:**
/// - **Open/Discover branches don't exist.** F6-scope Tables are always
///   Crew-only/Closed (Create Table's own disclosed cut) — this screen
///   only ever renders the Crew-only headline/UI, never the Open/Discover
///   ones the spec also describes.
/// - **"Send invites" is visible but disabled, with an inline reason.**
///   The spec says Table invites are "recorded against the Table
///   document," but no request/invite schema or endpoint for that exists
///   anywhere in `docs/DATABASE.md`/`docs/API_SPEC.md` — the exact same
///   disclosed gap `functions/src/crews/index.ts`'s `addMember`
///   `inviteToken` path already has (no backing data model, `not-found`
///   unconditionally). Building a real one needs its own design pass
///   (a pending-invite schema, an issuance/notification endpoint), not a
///   guess made inside this chunk. The multi-select itself is real —
///   backed by the Crew's actual member roster — so the UI is honest
///   about who *would* be invited, just not yet able to dispatch it.
/// - **"Share via..." (native OS share sheet) isn't wired up** — no share
///   package (e.g. `share_plus`) has been added to this codebase yet;
///   adding a new production dependency is treated as its own decision,
///   not folded into this chunk. "Copy link" is fully real (clipboard-
///   only, no new dependency needed).
/// - **The copied/shared link doesn't actually deep-link into the app on
///   another device.** `docs/ARCHITECTURE.md` §Routing names "Firebase
///   Dynamic Links successors" as the intended mechanism for invite
///   links, but names no specific vendor — Dynamic Links itself is
///   discontinued, and no successor (Branch, AppsFlyer OneLink, a
///   self-hosted Universal/App Links domain association) has been chosen
///   or provisioned. The link below is a real, stable, copyable URL
///   (`https://tablecrew.app/tables/{tableId}`) — sufficient for FR-T6's
///   "share a link with a specific contact" requirement in substance —
///   but opening it outside the app today would 404, not launch
///   TableCrew. Tracked in `TASKS.md` alongside the maps/places provider
///   gap as a real vendor decision, not guessed at here.
///
/// Added Milestone F6.
class InviteShareScreen extends ConsumerWidget {
  /// Creates the Invite & Share Sheet for [tableId].
  const InviteShareScreen({required this.tableId, super.key});

  /// The Table's document id.
  final String tableId;

  String _linkFor(String tableId) => 'https://tablecrew.app/tables/$tableId';

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _linkFor(tableId)));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Copied!')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final dataAsync = ref.watch(inviteShareDataProvider(tableId));

    return Scaffold(
      appBar: AppBar(title: const Text('Invite your Crew')),
      body: SafeArea(
        child: dataAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(TCSpacing.xl),
            child: SkeletonPulse(width: double.infinity, height: 200),
          ),
          error: (error, _) => Center(
            child: Text(
              "Couldn't load this Table.",
              style: TCTextStyles.bodyMd.copyWith(color: colors.error),
            ),
          ),
          data: (data) => SingleChildScrollView(
            padding: const EdgeInsets.all(TCSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Invite your Crew',
                  style:
                      TCTextStyles.displayMd.copyWith(color: colors.onSurface),
                ),
                const SizedBox(height: TCSpacing.lg),
                if (data.crewMembers == null || data.crewMembers!.isEmpty)
                  _NoCrewEmptyState(colors: colors)
                else
                  _CrewMultiSelect(members: data.crewMembers!),
                const SizedBox(height: TCSpacing.xl),
                Text(
                  'Or share a link',
                  style:
                      TCTextStyles.headingMd.copyWith(color: colors.onSurface),
                ),
                const SizedBox(height: TCSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () => _copyLink(context),
                  icon: const Icon(Icons.link),
                  label: const Text('Copy link'),
                ),
                const SizedBox(height: TCSpacing.lg),
                ElevatedButton(
                  onPressed: () => GoRouter.of(context).goNamed(
                    'table-detail',
                    pathParameters: {'tableId': tableId},
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoCrewEmptyState extends StatelessWidget {
  const _NoCrewEmptyState({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'No Crew yet',
          style: TCTextStyles.headingMd.copyWith(color: colors.onSurface),
        ),
        const SizedBox(height: TCSpacing.xs),
        Text(
          'Share a link instead, or build a Crew from Tables you attend.',
          style: TCTextStyles.bodyMd.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _CrewMultiSelect extends StatefulWidget {
  const _CrewMultiSelect({required this.members});

  final List<CrewMember> members;

  @override
  State<_CrewMultiSelect> createState() => _CrewMultiSelectState();
}

class _CrewMultiSelectState extends State<_CrewMultiSelect> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final member in widget.members)
          CheckboxListTile(
            value: _selected.contains(member.uid),
            onChanged: (checked) {
              setState(() {
                if (checked ?? false) {
                  _selected.add(member.uid);
                } else {
                  _selected.remove(member.uid);
                }
              });
            },
            title: Text(member.displayName),
          ),
        const SizedBox(height: TCSpacing.sm),
        // Disabled unconditionally — see this screen's own doc comment
        // for why: no invite-dispatch endpoint exists yet, so there is
        // nothing this button could call even with a valid selection.
        const ElevatedButton(
          onPressed: null,
          child: Text('Send invites'),
        ),
        const SizedBox(height: TCSpacing.xs),
        Semantics(
          liveRegion: true,
          child: Text(
            "Sending Crew invites isn't wired up yet — share the link "
            'below instead.',
            style:
                TCTextStyles.caption.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
