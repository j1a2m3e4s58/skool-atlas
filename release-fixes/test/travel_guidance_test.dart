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
  });
  test('school name alone cannot establish a town match', () {
    final school = School({
      'id': 'sample',
      'name': 'Cape Coast Example School',
      'location': 'Accra, Ghana',
    });
    expect(townMatches(school, 'Cape Coast'), isFalse);
    expect(
      townMatches(School({'location': 'Cape   Coast, Ghana'}), ' Cape Coast '),
      isTrue,
    );
    expect(
      townMatches(School({'location': 'Cape Coast, Ghana'}), 'Coastal'),
      isFalse,
    );
  });
  test('travel confirmation does not silently confirm catchment', () {
    final school = schools.firstWhere(
      (s) =>
          s.data['registerYear'] == 2026 &&
          s.residency.contains('Day') &&
          s.programs.isNotEmpty,
    );
    final choice = SchoolChoice(
      schoolId: school.id,
      programme: school.programs.first,
      residence: 'Day',
      commuteConfirmed: true,
    );
    List<ChoiceCheck> checks() => validateSchoolChoices(
      [choice],
      gender: 'Male',
      town: 'Cape Coast',
      region: 'Central',
    );
    expect(checks().any((c) => c.code == 'catchment' && c.error), isTrue);
    choice.catchmentConfirmed = true;
    expect(checks().any((c) => c.code == 'catchment'), isFalse);
    expect(SchoolChoice.fromJson(choice.toJson()).catchmentConfirmed, isTrue);
    final oldDraft = choice.toJson()..remove('catchmentConfirmed');
    expect(SchoolChoice.fromJson(oldDraft).catchmentConfirmed, isFalse);
  });
  test('district and region words in an address do not count as a campus town', () {
    final school = School({
      'location': 'Ankaful, Cape Coast Metro, Central, Ghana',
      'region': 'Central',
      'district': 'Cape Coast Metro',
      'residency': 'Day/Boarding',
    });
    expect(townMatches(school, 'Cape Coast'), isFalse);
    expect(townMatches(school, 'Central'), isFalse);
    expect(localDayCandidate(school, 'Central', 'Cape Coast', ''), isFalse);
    expect(localDayCandidate(school, 'Central', 'Cape Coast', 'Cape Coast Metro'), isTrue);
    expect(localDayCandidate(school, 'Western', 'Ankaful', ''), isFalse);
  });
  test(
    'official vacancy evidence preserves codes and complete catalogue programmes',
    () {
      final reviewed = schools
          .where((s) => s.data['publicProgrammeReview'] is Map)
          .toList();
      expect(reviewed.length, greaterThan(600));
      for (final school in reviewed) {
        final review = school.data['publicProgrammeReview'] as Map;
        expect(review['expectedCode'], school.data['code'] ?? '');
        expect(review['source'], 'https://www.cssps.gov.gh/vacancies');
        expect(review['codeStatus'], contains('does not publish'));
      }
      final bawjiase = schools.singleWhere(
        (s) => s.id == 'bawjiase-community-senior-high',
      );
      expect(bawjiase.programs, contains('Home Economics'));
      expect(
        (bawjiase.data['publicProgrammeReview'] as Map)['catalogueOnly'],
        contains('Home Economics'),
      );
      expect(
        schools
            .singleWhere((s) => s.id == 'methodist-saltpond')
            .data['publicProgrammeReview'],
        isNull,
      );
    },
  );
}
