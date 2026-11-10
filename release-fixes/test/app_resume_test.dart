// Retired JHS/SHS app coverage; excluded from the tertiary release suite.
@Tags(['legacy_shs'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skoolatlas/main.dart';
import 'package:skoolatlas/planning.dart';
import 'package:skoolatlas/school.dart';
import 'package:skoolatlas/vacancies.dart';

import 'atlas_test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadAtlas();
    await loadPlanningData();
    await loadAtlasTestFonts();
  });

  test('last app section and back path survive an app restart', () async {
    final firstRun = AtlasSession();
    await firstRun.load();
    await firstRun.save(
      selectedPage: 8,
      pageHistory: [0, 1],
      visitedPages: {0, 1, 8},
    );

    final resumedRun = AtlasSession();
    await resumedRun.load();

    expect(resumedRun.selectedPage, 8);
    expect(resumedRun.pageHistory, [0, 1]);
    expect(resumedRun.visitedPages, {0, 1, 8});
  });

  testWidgets(
    'planner recovers current step, grades and town, then autosaves edits',
    (tester) async {
      await planningStore.clearInProgressPlan();
      final oldVacancyLoader = officialVacancies.fetchSnapshot;
      officialVacancies.fetchSnapshot = () async => {
        'source': 'https://www.cssps.gov.gh/vacancies',
        'fetchedAt': DateTime.now().toUtc().toIso8601String(),
        'matchedCount': 0,
        'schools': <String, Object>{},
      };
      addTearDown(() {
        officialVacancies.fetchSnapshot = oldVacancyLoader;
        officialVacancies.data = {};
        officialVacancies.error = null;
      });

      await planningStore.saveInProgressPlan({
        'schema': 'choice-recovery-v1',
        'grades': {
          for (final subject in coreSubjects) subject: 2,
          'Computing': 2,
          'French': 2,
        },
        'town': 'Cape Coast',
        'jhsTown': 'Cape Coast',
        'region': 'Central',
        'district': '',
        'gender': 'Male',
        'programme': 'General Science',
        'track': 'General',
        'scope': 'Region & boarding',
        'draftStyle': 'Balanced categories',
        'resultType': 'Actual results',
        'search': '',
        'step': 1,
        'limit': 8,
        'aggregate': 12,
        'vacanciesOnly': true,
        'choices': [],
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: atlasTheme(Brightness.light),
          home: const Scaffold(body: ResultsPlannerPage()),
        ),
      );
      await tester.pump();

      expect(find.text('Step 2 of 4'), findsOneWidget);
      final dynamic state = tester.state(find.byType(ResultsPlannerPage));
      expect(state.town.text, 'Cape Coast');
      expect(state.region, 'Central');
      expect(state.grades['English Language'], 2);
      expect(state.aggregate, 12);

      state.grades['English Language'] = 3;
      state.setState(() {});
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(planningStore.inProgressPlan!['grades']['English Language'], 3);
      await tester.pumpWidget(const SizedBox.shrink());
      await planningStore.saveInProgressPlan(planningStore.inProgressPlan!);

      final nextLaunch = PlanningStore();
      await nextLaunch.load();
      expect(nextLaunch.inProgressPlan!['step'], 1);
      expect(nextLaunch.inProgressPlan!['town'], 'Cape Coast');
      expect(nextLaunch.inProgressPlan!['grades']['English Language'], 3);
    },
  );
}
