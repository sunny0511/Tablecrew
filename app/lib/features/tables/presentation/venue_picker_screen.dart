import 'package:flutter/material.dart';
import 'package:tablecrew/core/theme/spacing_tokens.dart';
import 'package:tablecrew/core/theme/type_tokens.dart';
import 'package:tablecrew/data/table_mutations_repository.dart';

/// Screen 11 (Venue Picker), `docs/SCREEN_SPECIFICATIONS.md` — **manual-
/// entry v1** (Milestone F6).
///
/// **Disclosed scope cut, not silent:** the spec's live venue *search*
/// (provider-backed results list, map preview, use-current-location bias)
/// is not built in this chunk, because no maps/places provider has ever
/// been chosen or provisioned anywhere in this project — the spec's own
/// API Calls section defers to "the underlying maps/places provider per
/// `docs/ARCHITECTURE.md`," and `ARCHITECTURE.md` names none. That is a
/// real founder decision (provider choice, API key, billing) tracked in
/// `TASKS.md`, not something to guess at. What ships now is the spec's own
/// "Can't find it? Add manually" fallback — name + address producing
/// structured data — as the primary path, which the spec already requires
/// to be fully functional standalone (its Offline Behavior leads with
/// exactly this form whenever search is unavailable). The search UI lands
/// with the provider integration, not as a dead search box that returns
/// nothing.
///
/// Pushed as a plain [Navigator] route returning a [VenueSelection] (or
/// null on cancel) rather than a GoRouter route: the route table's
/// `venue-picker` path nests under `/tables/:tableId` (venue *editing* on
/// an existing Table), but at create time no tableId exists yet — a
/// transient, result-returning selection flow is exactly what a nested
/// Navigator push is for.
///
/// Added Milestone F6.
class VenuePickerScreen extends StatefulWidget {
  /// Creates the Venue Picker.
  const VenuePickerScreen({super.key});

  @override
  State<VenuePickerScreen> createState() => _VenuePickerScreenState();
}

class _VenuePickerScreenState extends State<VenuePickerScreen> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  bool get _canUse =>
      _nameController.text.trim().isNotEmpty &&
      _addressController.text.trim().isNotEmpty;

  void _use() {
    if (!_canUse) return;
    Navigator.of(context).pop(
      VenueSelection(
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Choose a venue')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(TCSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add the venue',
                style: TCTextStyles.displayMd.copyWith(
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: TCSpacing.sm),
              Text(
                'Enter the place name and address so everyone knows where '
                'to meet. Venue search is coming soon — for now, add it '
                'yourself.',
                style: TCTextStyles.bodyMd.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: TCSpacing.lg),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Venue name'),
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: TCSpacing.md),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address'),
                maxLines: 2,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: TCSpacing.lg),
              ElevatedButton(
                onPressed: _canUse ? _use : null,
                child: const Text('Use this venue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
