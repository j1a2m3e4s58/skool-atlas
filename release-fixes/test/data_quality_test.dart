// Retired JHS/SHS app coverage; excluded from the tertiary release suite.
@Tags(['legacy_shs'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skoolatlas/main.dart';
import 'package:skoolatlas/school.dart';
import 'package:skoolatlas/planning.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadAtlas();
    await loadPlanningData();
  });
  test(
    'reviewed identities retain media, current programmes and saved aliases',
    () {
      for (final pair in [
        [
          'presbyterian-boys-senior-high-legon',
          'presby-boys-senior-high-legon',
        ],
        ['krobo-girls-senior-high', 'krobo-girls-presby-senior-high'],
        [
          'wesley-girls-senior-high-cape-coast',
          'wesley-girls-high-school-cape-coast',
        ],
      ]) {
        final school = schools.singleWhere((s) => s.id == pair[0]);
        expect(schools.any((s) => s.id == pair[1]), isFalse);
        expect(school.images, isNotEmpty);
        expect(school.data['registerYear'], 2026);
        expect(school.data['legacyIds'], contains(pair[1]));
        expect(
          SchoolChoice(
            schoolId: pair[1],
            programme: school.programs.first,
            residence: 'Day',
          ).school,
          same(school),
        );
      }
      expect(reconciliation['missing'], isEmpty);
      expect(reconciliation['possibleDuplicates'], isEmpty);
      expect(reconciliation['conflictingCodes'], ['0060208', '0060612', '0060715']);
      final hemang = schools.singleWhere((s) => s.id == 'hemang-buoho-technical-institute');
      expect(hemang.data['code'], '9052000');
      expect(hemang.data['registerOriginalCode'], '9051305');
      expect(hemang.data['registerCodeConflict'], isFalse);
      expect(
        searchSchools(query: 'lawra').any((s) => s.id == 'lawra-senior-high'),
        isTrue,
      );
      expect(
        schools.singleWhere((s) => s.id == 'wa-senior-high').id,
        isNot('lawra-senior-high'),
      );
    },
  );
  test(
    'changed details invalidate reviewed choices even when code was confirmed',
    () {
      final school = schools.singleWhere(
        (s) => s.id == 'presbyterian-boys-senior-high-legon',
      );
      final old = school.data['code'];
      final choice = SchoolChoice(
        schoolId: school.id,
        programme: school.programs.first,
        residence: 'Day',
        codeConfirmed: true,
        commuteConfirmed: true,
        catchmentConfirmed: true,
        reviewedSignature: school.selectionSignature,
      );
      final loaded = SchoolChoice.fromJson(choice.toJson());
      school.data['code'] = 'changed-code';
      try {
        expect(
          validateSchoolChoices(
            [loaded],
            gender: 'Male',
            town: 'Legon',
            region: 'Greater Accra',
          ).any((c) => c.code == 'school-changed' && c.error),
          isTrue,
        );
      } finally {
        school.data['code'] = old;
      }
      expect(
        validateSchoolChoices(
          [loaded],
          gender: 'Male',
          town: 'Legon',
          region: 'Greater Accra',
        ).any((c) => c.code == 'school-changed'),
        isFalse,
      );
    },
  );
  test(
    'cloud and offline saved choices preserve merged school identities',
    () async {
      final local = AtlasStore();
      await local.load();
      await local.applyCloudState(
        {'presby-boys-senior-high-legon'},
        ['presby-boys-senior-high-legon'],
        {},
        merge: false,
      );
      expect(local.saved, {'presbyterian-boys-senior-high-legon'});
      expect(local.compared, ['presbyterian-boys-senior-high-legon']);
      final reopened = AtlasStore();
      await reopened.load();
      expect(reopened.saved, local.saved);
      expect(reopened.compared, local.compared);
    },
  );
  test(
    'programme removal and merged aliases cannot make a valid duplicate draft',
    () {
      final school = schools.singleWhere(
        (s) => s.id == 'krobo-girls-senior-high',
      );
      final checks = validateSchoolChoices(
        [
          SchoolChoice(
            schoolId: school.id,
            programme: 'Removed programme',
            residence: 'Day',
          ),
          SchoolChoice(
            schoolId: 'krobo-girls-presby-senior-high',
            programme: school.programs.first,
            residence: 'Day',
          ),
        ],
        gender: 'Female',
        town: 'Odumase',
        region: 'Eastern',
      );
      expect(checks.any((c) => c.code == 'programme'), isTrue);
      expect(checks.any((c) => c.code == 'duplicate'), isTrue);
    },
  );
  for (final width in [320.0, 430.0]) {
    testWidgets('results form fits $width wide with larger text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const Scaffold(body: ResultsPlannerPage()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('missing profile facts are explicit on a small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final school = schools.firstWhere(
      (s) =>
          s.images.isEmpty &&
          !s.hasCrest &&
          s.data['registerCodeConflict'] == true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SchoolInformationStatus(school: school),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('View source and missing details'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('conflicts with another register entry'),
      findsOneWidget,
    );
    expect(find.text('Not yet verified'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
