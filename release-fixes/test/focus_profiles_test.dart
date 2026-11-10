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
    'requested schools have one identity, sourced contacts and explicit remaining gaps',
    () {
      for (final id in [
        'bawjiase-community-senior-high',
        'obrachire-senior-high-tech',
        'kwanyarko-senior-high',
        'methodist-saltpond',
      ]) {
        final school = schools.singleWhere((s) => s.id == id);
        expect(school.data['profileReviewed'], '2026-10-17');
        expect(school.data['profileRemaining'], isNotEmpty);
        expect(
          (supportData['schools'][id] as List).any(
            (r) => r['kind'] == 'Contact',
          ),
          isTrue,
        );
      }
      expect(
        searchSchools(query: 'kwastech').single.id,
        'kwanyarko-senior-high',
      );
      expect(searchSchools(query: 'mehiss').single.id, 'methodist-saltpond');
    },
  );
  testWidgets(
    'provider crest and historic contact limits remain visible on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final school = schools.singleWhere(
        (s) => s.id == 'kwanyarko-senior-high',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SchoolInformationStatus(school: school),
                  SchoolPracticalInfo(school: school),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('View source and missing details'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('School endorsement and redistribution permission'),
        findsOneWidget,
      );
      expect(find.text('Historical contact'), findsOneWidget);
      expect(find.text('Copy contact details'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
