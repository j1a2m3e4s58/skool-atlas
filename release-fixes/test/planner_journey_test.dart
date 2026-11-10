// Retired JHS/SHS app coverage; excluded from the tertiary release suite.
@Tags(['legacy_shs'])
library;

import 'atlas_test_fonts.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skoolatlas/main.dart';
import 'package:skoolatlas/planning.dart';
import 'package:skoolatlas/school.dart';
import 'package:skoolatlas/vacancies.dart';
import 'page_layout_audit_test.dart' show LayoutAssets;

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadAtlas();
    await loadPlanningData();
    await loadAtlasTestFonts();
  });
  setUp(() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    await planningStore.forgetPlan();
    await planningStore.clearInProgressPlan();
  });
  for (final brightness in Brightness.values) {
    testWidgets('grades to eight real schools in ${brightness.name}', (
      tester,
    ) async {
      final previousLoader = officialVacancies.fetchSnapshot;
      officialVacancies.fetchSnapshot = () async => {
        'source': 'https://www.cssps.gov.gh/vacancies',
        'fetchedAt': DateTime.now().toUtc().toIso8601String(),
        'matchedCount': schools.length,
        'schools': {for (final school in schools) school.id: {
          'programmes': [for (final p in school.programs) {'name': p, 'vacancies': 5}],
          'residences': [for (final r in ['Day', 'Boarding']) {'name': r, 'gender': null, 'vacancies': 5}],
        }},
      };
      addTearDown(() {officialVacancies.fetchSnapshot = previousLoader; officialVacancies.data = {}; officialVacancies.error = null;});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: atlasTheme(brightness),
          builder: (_, child) =>
              DefaultAssetBundle(bundle: LayoutAssets(), child: child!),
          home: Scaffold(body: HomePage(onExploreTap: () {})),
        ),
      );
      Future<void> tapText(String label) async {
        final target = find.text(label).last;
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      Future<void> select(Finder field, String value) async {
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        await tester.tap(field);
        await tester.pumpAndSettle();
        await tester.tap(find.text(value).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      await tapText('Enter grades & find schools');
      final englishFieldFinder = find.byKey(
        const ValueKey('grade-English Language-null'),
      );
      final englishDropdown = tester.widget<DropdownButton<int>>(
        find.descendant(
          of: englishFieldFinder,
          matching: find.byType(DropdownButton<int>),
        ),
      );
      final englishField = tester.widget<DropdownButtonFormField<int>>(
        englishFieldFinder,
      );
      expect(englishDropdown.style?.fontSize, 18);
      expect(
        englishDropdown.style?.color,
        atlasTheme(brightness).colorScheme.onSurface,
      );
      final selectedLabels = englishDropdown.selectedItemBuilder!(
        tester.element(find.byType(ResultsPlannerPage)),
      );
      expect(selectedLabels, hasLength(10));
      expect(
        (selectedLabels.first as Text).style?.color,
        atlasTheme(brightness).colorScheme.onSurface,
      );
      expect(
        (selectedLabels[2] as Text).style?.color,
        atlasTheme(brightness).colorScheme.onSurface,
      );
      final gradeTwoItem = englishDropdown.items!.singleWhere(
        (item) => item.value == 2,
      );
      expect(
        (gradeTwoItem.child as Text).style?.color,
        atlasTheme(brightness).colorScheme.onSurface,
      );
      expect(englishField.decoration.labelStyle?.fontSize, 16);
      expect(tester.getSize(englishFieldFinder).width, greaterThan(300));
      await tapText('Analyse my grades');
      expect(find.textContaining('Your six-subject aggregate:'), findsNothing);
      for (final subject in [...coreSubjects, 'Computing', 'French']) {
        await select(find.byKey(ValueKey('grade-$subject-null')), 'Grade 2');
      }
      await tapText('Analyse my grades');
      expect(find.text('Your six-subject aggregate: 12'), findsOneWidget);
      await tapText('Next: where I live');
      final town = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.labelText == 'Your home town or community',
      );
      await tester.ensureVisible(town);
      await tester.enterText(town, 'Cape Coast');
      await select(find.byKey(const ValueKey('home-region-')), 'Central');
      await select(
        find.byKey(const ValueKey('candidate-gender-Not entered')),
        'Male',
      );
      await tapText('Next: explore suitable options');
      await tapText('Suggest my 8 choices');
      expect(find.text('My eight choices (8/8)'), findsOneWidget);
      final dynamic state = tester.state(find.byType(ResultsPlannerPage));
      final draft = List<SchoolChoice>.from(state.choices as List);
      await tapText('3  Find schools');
      final currentSuggestion = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Suggest my 8 choices'),
      );
      expect(currentSuggestion.onPressed, isNull);
      await tapText('4  Review choices');
      final fitHeader = tester.widget<Text>(
        find.text('Why it fits · What to check').first,
      );
      expect(fitHeader.textAlign, TextAlign.center);
      expect(fitHeader.style?.fontSize, 16);
      expect(draft.map((c) => c.schoolId).toSet().length, 8);
      expect(
        draft.where((c) => c.selectionCategory == 'Category A').length,
        lessThanOrEqualTo(2),
      );
      expect(
        draft.where((c) => c.selectionCategory == 'Category B').length,
        lessThanOrEqualTo(3),
      );
      expect(
        draft.where((c) => c.residence == 'Boarding').length,
        lessThanOrEqualTo(5),
      );
      expect(
        draft.where((c) => c.residence == 'Day').length,
        greaterThanOrEqualTo(3),
      );
      expect(
        draft.every(
          (c) => c.school != null && c.school!.programs.contains(c.programme),
        ),
        isTrue,
      );
      expect(draft.every((c) => c.school!.gender != 'Girls'), isTrue);
      expect(
        validateSchoolChoices(
          draft,
          gender: 'Male',
          town: 'Cape Coast',
          region: 'Central',
        ).where((c) => c.error && !['commute', 'catchment'].contains(c.code)),
        isEmpty,
      );
      await tapText(
        'My JHS or the school office confirmed that I can select this Day option.',
      );
      await tapText(
        'My guardian and I checked that I can realistically attend this Day school daily.',
      );
      expect(draft.any((c) => c.catchmentConfirmed), isTrue);
      expect(draft.any((c) => c.commuteConfirmed), isTrue);
      await tapText('2  Where I live');
      await tester.ensureVisible(town);
      await tester.enterText(town, 'Saltpond');
      await tester.pumpAndSettle();
      expect(
        draft
            .where((c) => c.residence == 'Day')
            .every((c) => !c.commuteConfirmed && !c.catchmentConfirmed),
        isTrue,
      );
      await tapText('3  Find schools');
      await tapText('More filters (optional)');
      await select(
        find.byWidgetPredicate(
          (w) =>
              w is DropdownButtonFormField<String> &&
              w.decoration.labelText == 'Study track',
        ),
        'Science / STEM',
      );
      final refreshedSuggestion = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Update my 8 suggestions'),
      );
      expect(refreshedSuggestion.onPressed, isNotNull);
      await tapText('Update my 8 suggestions');
      expect(find.text('Update your school suggestions?'), findsOneWidget);
      await tapText('Update suggestions');
      final refreshedChoices = state.choices as List<SchoolChoice>;
      expect(refreshedChoices, isNotEmpty);
      expect(refreshedChoices.length, lessThanOrEqualTo(8));
      expect(
        refreshedChoices.map((c) => c.schoolId).toSet().length,
        refreshedChoices.length,
      );
      expect(
        find.text('My eight choices (${refreshedChoices.length}/8)'),
        findsOneWidget,
      );
      await tapText('3  Find schools');
      final refreshedButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Suggest my 8 choices'),
      );
      expect(refreshedButton.onPressed, isNull);
      await tester.pumpWidget(const SizedBox());
    }, timeout: const Timeout(Duration(seconds: 60)));
  }
}
