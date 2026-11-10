// Retired JHS/SHS app coverage; excluded from the tertiary release suite.
@Tags(['legacy_shs'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skoolatlas/main.dart';
import 'package:skoolatlas/school.dart';
import 'atlas_test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadAtlas();
    await loadAtlasTestFonts();
  });

  test('catalogue covers Ghana with unique IDs and real Bawjiase photos', () {
    expect(schools.length, greaterThan(700));
    expect(schools.map((s) => s.id).toSet().length, schools.length);
    expect(schools.map((s) => s.region).toSet().length, 16);
    final bawjiase = searchSchools(
      query: 'bawjiase',
    ).where((s) => s.id == 'bawjiase-community-senior-high').single;
    expect(bawjiase.images.length, 4);
    expect(bawjiase.region, 'Central');
    expect(bawjiase.mapUri.queryParameters['query'], contains('Bawjiase'));
    expect(schools.any((s) => s.name.contains(r'\/')), isFalse);
  });

  test('filters combine and boarding includes day/boarding schools', () {
    expect(searchSchools(group: 'STEM').length, greaterThanOrEqualTo(5));
    expect(searchSchools(group: 'Private').length, greaterThanOrEqualTo(4));
    final results = searchSchools(
      query: 'bawjiase',
      region: 'Central',
      gender: 'Mixed',
      residency: 'Boarding',
    );
    expect(
      results.map((s) => s.id),
      contains('bawjiase-community-senior-high'),
    );
    expect(searchSchools(query: 'bawjiase', region: 'Ashanti'), isEmpty);
    expect(
      searchSchools(query: 'kumasi').any((s) => s.id == 'prempeh-college'),
      isTrue,
    );
  });

  test('Akuse Methodist has its own attributed campus image and crest', () {
    final school = searchSchools(
      query: 'akuse methodist',
      region: 'Eastern',
    ).single;
    expect(school.images.single, contains('akuse-methodist-senior-high-tech'));
    expect(school.logo, contains('akuse-methodist-senior-high-tech'));
    expect(
      school.sources.any((s) => '${s['label']}'.contains('Graphic Online')),
      isTrue,
    );
    expect(
      searchSchools(query: 'akuse methodist', program: 'Technical').single.id,
      school.id,
    );
  });

  testWidgets('mobile header back and brand return to home', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: MainShell()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore Schools').last);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Go back'), findsOneWidget);
    await tester.tap(find.byTooltip('Go back'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Go back'), findsNothing);
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore Schools').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AtlasBrand));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Go back'), findsNothing);
    expect(find.text('What would you like to do?'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('requested schools and dated achievement evidence are searchable', () {
    expect(
      searchSchools(query: 'obrachire').single.name,
      'Obrachire Senior High Technical School',
    );
    expect(
      searchSchools(query: 'konyako').single.name,
      'Kwanyako Senior High School',
    );
    expect(
      searchSchools(query: 'kwanyarko').single.id,
      'kwanyarko-senior-high',
    );
    final saltpond = searchSchools(query: 'methodist saltpond').single;
    expect(saltpond.achievements.single['year'], 2005);
    expect(saltpond.achievements.single['kind'], 'Academic results');
    for (final school in schools) {
      for (final record in school.achievements) {
        expect(record['year'], inInclusiveRange(1994, 2026));
        expect(Uri.parse(record['url'] as String).scheme, 'https');
        expect(record['result'], isNotEmpty);
      }
    }
    expect(
      searchSchools(query: 'obrachire').single.achievements.single['result'],
      'Reported contest result',
    );
  });

  test(
    'aggregate uses four core and the best two electives and rejects invalid grades',
    () {
      expect(beceAggregate([1, 2, 3, 4], [5, 6, 1, 2]), 13);
      expect(beceAggregate([9, 9, 9, 9], [9, 9]), 54);
      expect(() => beceAggregate([1, 2, 3], [1, 2]), throwsArgumentError);
      expect(() => beceAggregate([0, 1, 2, 3], [1, 2]), throwsArgumentError);
    },
  );

  test(
    'shortlist and comparison persist, reject duplicates and enforce the limit',
    () async {
      final store = AtlasStore();
      await store.load();
      await store.toggleSaved('first');
      store.addComparison('first');
      store.addComparison('first');
      store.addComparison('second');
      store.addComparison('third');
      store.addComparison('fourth');
      expect(store.compared, ['first', 'second', 'third']);
      await store.toggleChecklist('interests');
      final restored = AtlasStore();
      await restored.load();
      expect(restored.saved, contains('first'));
      expect(restored.compared, ['first', 'second', 'third']);
      expect(restored.checklist, contains('interests'));
      await restored.toggleSaved('first');
      expect(restored.saved, isEmpty);
      await restored.removeComparison('second');
      expect(restored.compared, ['first', 'third']);
      await restored.toggleSaved('first');
      await restored.remapSchoolIds({'first': 'merged', 'third': 'merged'});
      final migrated = AtlasStore();
      await migrated.load();
      expect(migrated.saved, {'merged'});
      expect(migrated.compared, ['merged']);
    },
  );

  testWidgets(
    'mobile navigation opens the directory and searches for a school',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: MainShell()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Open menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Explore Schools').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'bawjiase');
      await tester.pumpAndSettle();
      // The coverage note and mobile filters precede the lazy-built results.
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Awutu Bawjiase Community Senior High School'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byTooltip('Save school').first);
      await tester.tap(find.byTooltip('Save school').first);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'bawjiase',
      );
      expect(
        find.text('Awutu Bawjiase Community Senior High School'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('View school'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View school'));
      await tester.pumpAndSettle();
      expect(find.text('Find on map'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'campus spotlight stays still until selected and opens the selected profile',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SchoolCarousel())),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 15));
      expect(find.textContaining('Bawjiase').hitTestable(), findsOneWidget);
      expect(find.byTooltip('Pause slideshow'), findsNothing);
      await tester.tap(find.byTooltip('Next school'));
      await tester.pumpAndSettle();
      expect(
        find.text('Abomosu STEM Senior High').hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.text('Explore this school').hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('Find on map'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'placement page directs students to CSSPS without collecting credentials',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PlacementCheckerPage())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Open official CSSPS portal'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('sample placement'), findsNothing);
    },
  );

  testWidgets(
    'achievement cards keep historical results and missing records clear on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SchoolAchievements(
                school: searchSchools(query: 'methodist saltpond').single,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Historical academic milestone'), findsOneWidget);
      expect(find.textContaining('not current WASSCE'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SchoolAchievements(
                school: searchSchools(query: 'bawjiase').single,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('No reviewed achievement records added yet.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
