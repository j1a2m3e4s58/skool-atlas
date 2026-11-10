// Retired JHS/SHS app coverage; excluded from the tertiary release suite.
@Tags(['legacy_shs'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skoolatlas/planning.dart';
import 'package:skoolatlas/school.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadAtlas();
    await loadPlanningData();
  });

  test('aggregate uses four core subjects and the best two other subjects', () {
    final grades = {
      for (final s in coreSubjects) s: 2,
      'Computing': 1,
      'French': 3,
      'Career Technology': 9,
    };
    expect(resultsAggregate(grades), 12);
    grades.remove('Mathematics');
    expect(() => resultsAggregate(grades), throwsArgumentError);
  });
  test('unresolved codes and MIST vacancy identity never enter auto suggestions', () {
    final heldIds = <String>{
      'bechem-business-college',
      'yamfo-anglican-senior-high-school',
      'new-longoro-comm-school-dega',
      'siraaj-deen-senior-high-school',
      'abrafi-senior-high',
      'morning-star-senior-high-school',
      'mist-senior-high-school',
      'mist-senior-high-school-yeji',
    };
    final held = schools.where((school) => heldIds.contains(school.id)).toList();
    expect(held.map((school) => school.id).toSet(), heldIds);
    expect(held.every((school) => school.heldFromAutomaticSuggestions), isTrue);
    final grades = {for (final subject in coreSubjects) subject: 2};
    final options = resultsSchoolOptions(
      programme: 'General Science',
      region: 'Central',
      district: '',
      town: 'Cape Coast',
      gender: 'Male',
      grades: grades,
    );
    expect(options.any((match) => heldIds.contains(match.school.id)), isFalse);
    final draft = buildSuggestedChoices(
      options: held,
      programme: 'General Science',
      region: 'Central',
      town: 'Cape Coast',
      gender: 'Male',
    );
    expect(draft, isEmpty);

    final dambai = held.singleWhere((school) => school.id == 'mist-senior-high-school');
    expect(dambai.data['publicProgrammeReview'], isNull);
    expect(dambai.plannerSourceLabel, contains('2026-10-16'));
    expect(dambai.plannerSourceLabel, isNot(contains('2026-10-20')));
  });
  for (final grade in [2, 4, 7]) {
    test('real Cape Coast catalogue produces reviewed ordered choices for grade $grade', () {
      final grades = {
        for (final subject in coreSubjects) subject: grade,
        'Computing': grade, 'French': grade,
      };
      final options = resultsSchoolOptions(
        programme: 'General Science', region: 'Central', district: '',
        town: 'Cape Coast', gender: 'Male', grades: grades,
      );
      final draft = buildSuggestedChoices(
        options: options.map((m) => m.school).toList(),
        programme: 'General Science', region: 'Central',
        town: 'Cape Coast', gender: 'Male',
      );
      expect(resultsAggregate(grades), grade * 6);
      expect(draft.length, 8);
      expect(draft.map((c) => c.schoolId).toSet().length, 8);
      final ranks = draft.map((c) => ['Category A', 'Category B', 'Category C']
        .indexOf(c.selectionCategory)).toList();
      expect(ranks, orderedEquals([...ranks]..sort()));
      for (final choice in draft) {
        final school = choice.school!;
        expect(school.identityNeedsReview, isFalse);
        expect(school.data['registerCodeConflict'], isNot(true));
        expect(school.gender, isNot('Girls'));
        expect(school.programs, contains('General Science'));
        if (choice.residence == 'Day') {
          expect(localDayCandidate(school, 'Central', 'Cape Coast', ''), isTrue);
        }
        expect(choiceFitReasons(choice, grades: grades, region: 'Central',
          town: 'Cape Coast').join(' '), contains('not establish admission eligibility'));
      }
      final blocking = validateSchoolChoices(draft, gender: 'Male',
        town: 'Cape Coast', region: 'Central').where((c) => c.error &&
          !['commute', 'catchment'].contains(c.code));
      expect(blocking.map((c) => '${c.code}: ${c.message}'), isEmpty);
    });
  }

  test('eight category C day choices are allowed, with commute checks', () {
    final candidates = schools
        .where(
          (s) =>
              s.category == 'Category C' &&
              s.data['registerYear'] == 2026 &&
              s.residency.contains('Day') &&
              s.programs.isNotEmpty,
        )
        .take(8)
        .toList();
    expect(candidates.length, 8);
    final choices = candidates
        .map(
          (s) => SchoolChoice(
            schoolId: s.id,
            programme: s.programs.first,
            residence: 'Day',
            commuteConfirmed: true,
            catchmentConfirmed: true,
            codeConfirmed: true,
          ),
        )
        .toList();
    final checks = validateSchoolChoices(
      choices,
      gender: '',
      town: 'Accra',
      region: 'Greater Accra',
      now: DateTime(2026, 10, 16),
    );
    expect(checks.where((c) => c.error).map((c) => c.code), isEmpty);
    choices.first.commuteConfirmed = false;
    expect(
      validateSchoolChoices(
        choices,
        gender: '',
        town: 'Accra',
        region: 'Greater Accra',
      ).any((c) => c.error),
      isTrue,
    );
  });

  test('a duplicate school cannot satisfy the eight-school rule', () {
    final s = schools.firstWhere((s) => s.programs.isNotEmpty);
    final choices = List.generate(
      8,
      (_) => SchoolChoice(
        schoolId: s.id,
        programme: s.programs.first,
        residence: 'Day',
      ),
    );
    expect(
      validateSchoolChoices(
        choices,
        gender: '',
        town: 'Accra',
        region: 'Greater Accra',
      ).any((c) => c.code == 'duplicate'),
      isTrue,
    );
  });
}
