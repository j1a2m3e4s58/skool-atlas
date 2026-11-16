import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skoolatlas/tertiary_app.dart';
import 'package:skoolatlas/tertiary_data.dart';

void main() {
  for (final width in [320.0, 390.0, 1280.0]) {
    testWidgets(
      'Grade explanations, uncertain cutoffs and edit invalidation at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final rows =
            jsonDecode(
                  File('assets/tertiary/admissions.json').readAsStringSync(),
                )['rules']
                as List;
        final store = TertiaryStore()
          ..rules = [
            AdmissionRule(
              Map<String, dynamic>.from(
                rows.singleWhere((r) => r['id'] == 'ug-wassce-23'),
              ),
            ),
          ];
        store.sessionGrades.addAll({
          'English Language': 2,
          'Core Mathematics': 2,
          'Integrated Science': 2,
          'Social Studies': 2,
          'Elective Mathematics': 3,
          'Physics': 2,
          'Chemistry': 2,
        });
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(width == 320 ? 1.25 : 1),
              ),
              child: child!,
            ),
            home: Scaffold(body: GradePlanner(store: store)),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Check my pathways'));
        await tester.tap(find.text('Check my pathways'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Your six counted subjects'));
        await tester.tap(find.text('Your six counted subjects'));
        await tester.pumpAndSettle();
        expect(find.text('Meets checked academic minimum'), findsOneWidget);
        expect(find.text('Elective Mathematics: B3 (3)'), findsOneWidget);
        expect(find.text('Cutoff needs verification'), findsOneWidget);
        expect(find.text('Within published cutoff'), findsNothing);
        expect(tester.takeException(), isNull);
        final mathematics = find.byKey(
          const ValueKey('grade-Core Mathematics-2'),
        );
        await Scrollable.ensureVisible(tester.element(mathematics), alignment: 0.5);
        await tester.pumpAndSettle();
        await tester.tap(mathematics);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('D7'), 100, scrollable: find.byType(Scrollable).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('D7').last);
        await tester.pumpAndSettle();
        expect(find.text('Meets checked academic minimum'), findsNothing);
        expect(store.sessionGrades['Core Mathematics'], 7);
        await tester.ensureVisible(find.text('Check my pathways'));
        await tester.tap(find.text('Check my pathways'));
        await tester.pumpAndSettle();
        expect(find.text('Requirements not met'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
