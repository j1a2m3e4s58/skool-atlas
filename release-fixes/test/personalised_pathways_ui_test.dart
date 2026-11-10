import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skoolatlas/tertiary_app.dart';
import 'package:skoolatlas/tertiary_data.dart';
import 'package:skoolatlas/pathway_widgets.dart';

void main() {
  final width = double.parse(
    Platform.environment['ATLAS_PATHWAY_UI_WIDTH'] ?? '390',
  );
  testWidgets('preference chips wrap with larger text on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(1.25)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: PreferenceControls(
                    store: TertiaryStore(),
                    onChanged: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Personalise your suggestions'));
    await tester.pumpAndSettle();
    expect(find.text('Agriculture & environment'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'personalised pathway journey at $width: preferences, alternatives, simulation, prediction and awaiting results',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
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
          for (final id in ['ug-wassce-23', 'ug-wassce-18'])
            AdmissionRule(
              Map<String, dynamic>.from(rows.singleWhere((r) => r['id'] == id)),
            ),
        ];
      store.institutions =
          (jsonDecode(
                    File('assets/tertiary/catalogue.json').readAsStringSync(),
                  )['institutions']
                  as List)
              .map(
                (r) =>
                    TertiaryInstitution.fromJson(Map<String, dynamic>.from(r)),
              )
              .toList();
      store.sessionGrades.addAll({
        'English Language': 2,
        'Core Mathematics': 2,
        'Integrated Science': 2,
        'Social Studies': 2,
        'Elective Mathematics': 4,
        'Physics': 2,
        'Chemistry': 2,
      });
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(width == 320 ? 1.25 : 1)),
            child: child!,
          ),
          home: Scaffold(body: GradePlanner(store: store)),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> tapText(String text) async {
        debugPrint('Journey: $text');
        await tester.ensureVisible(find.text(text).first);
        await tester.tap(find.text(text).first);
        await tester.pumpAndSettle();
      }

      Finder dropdown(String label) => find.byWidgetPredicate(
        (w) => w is DropdownButtonFormField && w.decoration.labelText == label,
      );
      Future<void> choose(String label, String value) async {
        debugPrint('Journey: $label -> $value');
        final field = dropdown(label);
        await tester.ensureVisible(field);
        await tester.tap(field);
        await tester.pumpAndSettle();
        if (find.text(value).evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            find.text(value), -120,
            scrollable: find.byType(Scrollable).last,
          );
        }
        await tester.tap(find.text(value).last);
        await tester.pumpAndSettle();
      }

      await tapText('Personalise your suggestions');
      await tapText('Computing & data');
      await tapText('Greater Accra');
      await tapText('Save preferences on this device');
      expect(store.preferences.interests, {'Computing & data'});
      expect(
        (await SharedPreferences.getInstance()).getString(
          'tertiary.preferences.v1',
        ),
        isNot(contains('English Language')),
      );
      await tapText('Personalise your suggestions');
      await tapText('Check my pathways');
      expect(find.text('Meets checked academic minimum'), findsOneWidget);
      expect(find.text('Requirements not met'), findsOneWidget);
      await tapText('Related courses to consider');
      expect(find.text('B.Ed. in Computer Science'), findsNWidgets(2));
      final alternative = find.text('B.Ed. in Computer Science').last;
      await tester.ensureVisible(alternative);
      await tester.tap(alternative);
      await tester.pumpAndSettle();
      expect(find.text('Requirements not met'), findsNothing);
      final query = find.byKey(const ValueKey('programme-search'));
      await tester.ensureVisible(query);
      await tester.enterText(query, 'Computer Science');
      await tester.pumpAndSettle();
      await tapText('Check my pathways');
      await tapText('What if I improve a grade?');
      await choose('Subject to simulate', 'Elective Mathematics');
      await choose('Hypothetical grade', 'B3');
      await tapText('Try this grade');
      expect(store.sessionGrades['Elective Mathematics'], 4);
      expect(
        find.textContaining('1 additional programme routes'),
        findsOneWidget,
      );
      await choose('Results basis', 'Predicted results');
      expect(find.text('Meets checked academic minimum'), findsNothing);
      await tapText('Check my pathways');
      expect(find.text('Provisional academic minimum met'), findsOneWidget);
      await choose('English Language', 'Awaiting result');
      expect(store.sessionGrades.containsKey('English Language'), isFalse);
      expect(store.sessionAwaiting, contains('English Language'));
      await tapText('Check my pathways');
      expect(find.text('Provisional academic minimum met'), findsNothing);
      await choose('English Language', 'B2');
      await choose('Results basis', 'Final results');
      await choose('Examination sittings', 'Two sittings · combined results');
      await tapText('Check my pathways');
      expect(
        find.text('Combined-sitting policy needs verification'),
        findsNWidgets(2),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'elective search accepts WAEC aliases and avoids a duplicate selected subject at $width',
    (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = TertiaryStore();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GradePlanner(store: store)),
        ),
      );
      await tester.pumpAndSettle();
      final elective = find.text('Elective 1: Choose subject');
      await tester.ensureVisible(elective);
      await tester.tap(elective);
      await tester.pumpAndSettle();
      final search = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.labelText == 'Search subject or WAEC name',
      );
      await tester.enterText(search, 'Financial Accounting');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accounting / Financial Accounting'));
      await tester.pumpAndSettle();
      expect(
        find.text('Elective 1: Accounting / Financial Accounting'),
        findsOneWidget,
      );
      expect(store.sessionGrades.containsKey('Accounting'), isFalse);
      final second = find.text('Elective 2: Choose subject');
      await tester.ensureVisible(second);
      await tester.tap(second);
      await tester.pumpAndSettle();
      await tester.enterText(search, 'Financial Accounting');
      await tester.pumpAndSettle();
      expect(
        find.text('No matching subject. Try another spelling.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
