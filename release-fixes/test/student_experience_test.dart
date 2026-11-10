// Retired JHS/SHS app coverage; excluded from the tertiary release suite.
@Tags(['legacy_shs'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skoolatlas/main.dart';
import 'package:skoolatlas/planning.dart';
import 'package:skoolatlas/school.dart';
import 'atlas_test_fonts.dart';
import 'page_layout_audit_test.dart' show LayoutAssets;

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadAtlas();
    await loadPlanningData();
    await loadAtlasTestFonts();
  });
  Widget app(Widget child) => MaterialApp(
    theme: atlasTheme(Brightness.light),
    builder: (_, child) =>
        DefaultAssetBundle(bundle: LayoutAssets(), child: child!),
    home: child,
  );
  testWidgets(
    'Explore keeps quick school types visible and puts detailed filters away until asked',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove('atlas.explore.filters.v1');
      await tester.pumpWidget(app(const Scaffold(body: ExplorePage())));
      await tester.pumpAndSettle();

      expect(find.text('Government'), findsOneWidget);
      expect(find.text('Private'), findsOneWidget);
      expect(find.text('School type'), findsNothing);
      expect(find.text('Sort by'), findsNothing);
      expect(find.text('More filters'), findsOneWidget);

      await tester.tap(find.text('More filters'));
      await tester.pumpAndSettle();
      expect(find.text('School type'), findsOneWidget);
      expect(find.text('Sort by'), findsOneWidget);
      expect(find.text('About these school listings'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'four primary destinations retain Explore search and restore it after reopening',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(MainShell(key: atlasShellKey)));
      await tester.pumpAndSettle();
      Future<void> tab(String label) async {
        await tester.tap(
          find.descendant(
            of: find.byType(AtlasPrimaryNavigation),
            matching: find.text(label),
          ),
        );
        await tester.pumpAndSettle();
      }

      await tab('Explore');
      Finder search() => find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.labelText == 'Search schools',
      );
      await tester.enterText(search(), 'Bawjiase');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tab('My choices');
      expect(find.text('Your school choices'), findsOneWidget);
      await tab('Results');
      expect(find.text('Enter your BECE grades'), findsOneWidget);
      await tab('Explore');
      expect(tester.widget<TextField>(search()).controller!.text, 'Bawjiase');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app(const Scaffold(body: ExplorePage())));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search()).controller!.text, 'Bawjiase');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'school profile has consistent ordered sections and jump controls',
    (tester) async {
      final school = schools.singleWhere(
        (s) => s.id == 'bawjiase-community-senior-high',
      );
      await tester.pumpWidget(app(SchoolDetailsPage(school: school)));
      await tester.pump();
      final headings = [
        'Overview',
        'Programmes & pathways',
        'Gallery & videos',
        'Achievements & participation',
        'Costs, contacts & residential information',
        'Plan a school visit',
      ];
      double previous = -1;
      for (final heading in headings) {
        final y = tester.getTopLeft(find.text(heading).last).dy;
        expect(y, greaterThan(previous), reason: heading);
        previous = y;
      }
      expect(find.byType(ActionChip), findsNWidgets(6));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test(
    'ordered exports retain unresolved requirements and escape untrusted text',
    () async {
      final school = schools.firstWhere((s) => s.programs.isNotEmpty);
      final html = await offlineSchoolPack(
        [school],
        photos: false,
        choices: [
          SchoolChoice(
            schoolId: school.id,
            programme: school.programs.first,
            residence: 'Day',
          ),
        ],
        requirements: ['Confirm catchment <script>bad</script>'],
      );
      expect(html, contains('Unverified planning draft'));
      expect(
        html,
        contains('Confirm catchment &lt;script&gt;bad&lt;/script&gt;'),
      );
      expect(html, contains('Ordered school-choice draft'));
    },
  );
}
