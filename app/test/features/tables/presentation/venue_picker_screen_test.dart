import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablecrew/data/table_mutations_repository.dart';
import 'package:tablecrew/features/tables/presentation/venue_picker_screen.dart';

/// Widget tests for Screen 11 (Venue Picker)'s manual-entry v1, Milestone
/// F6.
void main() {
  // Returns the push's own Future wrapped in a record — a bare
  // `Future<VenueSelection?>` return type here would trigger Dart's async
  // "flattening" (an async function returning a Future<T> chains onto it),
  // which would make this whole helper not resolve until the *pushed*
  // screen pops, defeating the point of getting a handle to await later,
  // after this test has interacted with that still-open screen.
  Future<({Future<VenueSelection?> pushed})> openPicker(
    WidgetTester tester,
  ) async {
    late Future<VenueSelection?> pushFuture;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              pushFuture = Navigator.of(context).push(
                MaterialPageRoute<VenueSelection>(
                  builder: (context) => const VenuePickerScreen(),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return (pushed: pushFuture);
  }

  testWidgets('Use this venue is disabled until both fields are filled', (
    tester,
  ) async {
    await openPicker(tester);

    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Use this venue'),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Venue name'),
      'Cafe Coffee Day',
    );
    await tester.pump();
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Use this venue'),
          )
          .onPressed,
      isNull,
      reason: 'address is still empty',
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Address'),
      '123 Main St',
    );
    await tester.pump();
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Use this venue'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
      'Use this venue pops a VenueSelection with no coordinates '
      '(manual entry has none)', (tester) async {
    final opened = await openPicker(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Venue name'),
      'Cafe Coffee Day',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Address'),
      '123 Main St',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Use this venue'));
    await tester.pumpAndSettle();

    final popped = await opened.pushed;
    expect(popped?.name, 'Cafe Coffee Day');
    expect(popped?.address, '123 Main St');
    expect(popped?.latitude, isNull);
    expect(popped?.longitude, isNull);
    expect(popped?.venueId, isNull);
  });
}
