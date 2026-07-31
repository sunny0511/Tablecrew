import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tablecrew/app.dart';

void main() {
  testWidgets('TableCrewApp builds and shows the Milestone F0 placeholder',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: TableCrewApp()),
    );

    expect(
      find.text('TableCrew — Foundation scaffold (Milestone F0)'),
      findsOneWidget,
    );
  });

  testWidgets('TableCrewApp uses Material 3', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: TableCrewApp()),
    );

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.useMaterial3, isTrue);
  });
}
