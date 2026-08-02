import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tablecrew/data/crews_repository.dart';
import 'package:tablecrew/data/tables_repository.dart';

part 'invite_share_data.g.dart';

/// Everything Invite & Share Sheet (Screen 12) needs for a Table — the
/// Table itself plus, if it was created on behalf of a Crew, that Crew's
/// member roster for the multi-select.
class InviteShareData {
  /// Creates the loaded state.
  const InviteShareData({required this.table, required this.crewMembers});

  /// The Table being shared.
  final TableSummary table;

  /// The originating Crew's members, or `null` if the Table has no
  /// `crewId` — Screen 12's "No Crew yet" empty state then applies,
  /// per its own Empty States note that link-sharing is the primary path
  /// either way.
  final List<CrewMember>? crewMembers;
}

/// Loads [InviteShareData] for [tableId]. A plain `FutureProvider.family`
/// (no notifier needed — this screen has no client-persisted mutation of
/// its own to drive; see `invite_share_screen.dart`'s doc comment for why
/// "Send invites" isn't wired to anything yet).
///
/// Added Milestone F6.
@riverpod
Future<InviteShareData> inviteShareData(Ref ref, String tableId) async {
  final table = await ref.read(tablesRepositoryProvider).fetchTable(tableId);
  if (table == null) {
    throw StateError('Table $tableId not found or not readable.');
  }
  final crewId = table.crewId;
  final crewMembers = crewId == null
      ? null
      : await ref.read(crewsRepositoryProvider).fetchCrewMembers(crewId);
  return InviteShareData(table: table, crewMembers: crewMembers);
}
