import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:skoolatlas/tertiary_data.dart';

void main() {
  final store = TertiaryStore()
    ..applyFeed(
      Map<String, dynamic>.from(
        jsonDecode(File('web/tertiary-feed.json').readAsStringSync()),
      ),
    );
  final now = DateTime(2026, 10, 28, 16);
  const agriculture = ['agriculture', 'agribusiness', 'agro-processing'];
  const farm = [
    'Agricultural Science',
    'Crop Husbandry and Horticulture',
    'Animal Husbandry',
    'Fisheries',
    'Forestry',
  ];
  const science = ['Biology', 'Chemistry', 'Physics', 'Elective Mathematics'];
  const tourism = [
    'Geography',
    'Economics',
    'Government',
    'History',
    'French',
    'Business Management',
    'Elective Mathematics',
  ];
  const hospitality = [
    'Geography',
    'Economics',
    'Government',
    'History',
    'Biology',
    'Chemistry',
    'Business Management',
    'Elective Mathematics',
    'Management in Living',
    'Food and Nutrition',
  ];
  const geo = ['Economics', 'Geography', 'Elective Mathematics'];
  const ids = [
    ...agriculture,
    'tourism-management',
    'hospitality-management',
    'geography-and-regional-planning',
  ];
  final core = {for (final c in coreSubjects) c: 6};
  AdmissionRule rule(String id) =>
      store.rules.singleWhere((r) => r.id == 'ucc-applied-20261028-$id');
  MatchAssessment check(String id, Map<String, int> g) =>
      assessPathway(rule(id), g, now: now);

  test(
    'six applied routes validate with retained evidence and unique identity',
    () {
      expect(store.rules, hasLength(599));
      expect(
        store.rules.where((r) => r.data['scope'] == 'programme'),
        hasLength(542),
      );
      for (final id in ids) {
        final r = rule(id);
        expect(() => validateAdmissionRule(r), returnsNormally);
        expect(r.data['institutionId'], 'gtec:878');
        expect(r.data['competitiveCutoff'], isNull);
        expect(
          (r.data['sourceEvidence'] as Map)['captureSha256'],
          hasLength(64),
        );
        expect(
          store.rules.where(
            (other) =>
                other.institution == r.institution &&
                other.programme == r.programme,
          ),
          hasLength(1),
        );
      }
    },
  );
  test(
    'three named agriculture options pass at 36 without forcing Chemistry on every option',
    () {
      for (final id in agriculture) {
        for (final subjects in [
          ['Agricultural Science', 'Chemistry', 'Physics'],
          ['Chemistry', 'Biology', 'Elective Mathematics'],
          ['Crop Husbandry and Horticulture', 'Animal Husbandry', 'Fisheries'],
        ]) {
          final g = {...core, for (final s in subjects) s: 6};
          expect(check(id, g).academicPass, isTrue, reason: '$id $subjects');
          expect(check(id, g).aggregate, 36);
          expect(
            check(id, {
              ...g,
              'Integrated Science': 7,
              'Social Studies': 1,
            }).academicPass,
            isFalse,
          );
          expect(
            check(id, {...g, 'English Language': 7}).academicPass,
            isFalse,
          );
        }
      }
    },
  );
  test(
    'undefined background classifications stay conditional even with excellent grades',
    () {
      final technical = {
        ...core,
        'Technical Drawing': 1,
        'Applied Electricity': 1,
        'Physics': 1,
      };
      for (final id in agriculture) {
        expect(check(id, technical).academicPass, isFalse);
        expect(
          check(id, technical).status,
          'Additional route information needed',
        );
      }
      final arts = {...core, 'Government': 1, 'History': 1, 'French': 1};
      expect(check('agribusiness', arts).academicPass, isFalse);
      expect(
        check('agribusiness', arts).status,
        'Additional route information needed',
      );
    },
  );
  test(
    'Hospitality and Tourism enforce two of their own named subjects plus a third credit',
    () {
      final home = {
        ...core,
        'Integrated Science': 9,
        'Social Studies': 6,
        'Management in Living': 6,
        'Food and Nutrition': 6,
        'Textiles': 6,
      };
      expect(check('hospitality-management', home).academicPass, isTrue);
      expect(check('tourism-management', home).academicPass, isFalse);
      final travel = {
        ...core,
        'Integrated Science': 9,
        'Social Studies': 6,
        'Geography': 6,
        'French': 6,
        'Textiles': 6,
      };
      expect(check('tourism-management', travel).academicPass, isTrue);
      expect(check('hospitality-management', travel).academicPass, isFalse);
      expect(
        check('tourism-management', {...travel, 'French': 7}).academicPass,
        isFalse,
      );
      expect(
        check('tourism-management', {
          ...core,
          'Geography': 1,
          'French': 1,
        }).academicPass,
        isFalse,
      );
    },
  );
  test(
    'Geography retains the six-credit total and confirms an undefined third elective',
    () {
      expect(
        check('geography-and-regional-planning', {
          ...core,
          'Integrated Science': 9,
          'Social Studies': 6,
          for (final s in geo) s: 6,
        }).academicPass,
        isTrue,
      );
      final g = {...core, 'Economics': 6, 'Geography': 6, 'French': 6};
      expect(check('geography-and-regional-planning', g).academicPass, isFalse);
      expect(
        check('geography-and-regional-planning', g).status,
        'Additional route information needed',
      );
      expect(
        check('geography-and-regional-planning', {
          ...core,
          'Economics': 1,
          'Geography': 1,
        }).academicPass,
        isFalse,
      );
    },
  );
  test(
    '1536 independent grade cases preserve routes, group counts and quarantine',
    () {
      final random = Random(281010);
      const pool = [
        ...farm,
        ...science,
        'Geography',
        'Economics',
        'Government',
        'History',
        'French',
        'Business Management',
        'Management in Living',
        'Food and Nutrition',
        'Textiles',
      ];
      for (final id in ids) {
        for (var n = 0; n < 256; n++) {
          final shuffled = [...pool]..shuffle(random);
          final g = {
            for (final c in coreSubjects) c: 1 + random.nextInt(9),
            for (final e in (n.isEven ? pool : shuffled.take(4)))
              e: 1 + random.nextInt(9),
          };
          bool credit(String s) => (g[s] ?? 99) <= 6;
          final corePass =
              credit('English Language') &&
              credit('Core Mathematics') &&
              (agriculture.contains(id)
                  ? credit('Integrated Science')
                  : (credit('Integrated Science') || credit('Social Studies')));
          final agriculturePass =
              (credit('Agricultural Science') &&
                  credit('Chemistry') &&
                  [...science, ...farm]
                      .where(
                        (s) => s != 'Agricultural Science' && s != 'Chemistry',
                      )
                      .any(credit)) ||
              (credit('Chemistry') &&
                  credit('Biology') &&
                  (credit('Physics') || credit('Elective Mathematics'))) ||
              farm.where(credit).length >= 3;
          final enough = electiveSubjects.where(credit).length >= 3;
          final subjectPass = agriculture.contains(id)
              ? agriculturePass
              : id == 'tourism-management'
              ? enough && tourism.where(credit).length >= 2
              : id == 'hospitality-management'
              ? enough && hospitality.where(credit).length >= 2
              : geo.every(credit);
          final a = check(id, g);
          expect(
            a.academicPass,
            corePass && subjectPass,
            reason: '$id case $n',
          );
          if (a.academicPass) {
            expect(a.countedSubjects, hasLength(6));
            expect(
              a.aggregate,
              a.countedSubjects.values.reduce((a, b) => a + b),
            );
            expect(a.countedSubjects.values.every((v) => v <= 6), isTrue);
          }
          expect(
            assessPathway(
              AdmissionRule({
                ...rule(id).data,
                'status': 'needs_source_review',
              }),
              g,
              now: now,
            ).academicPass,
            isFalse,
          );
        }
      }
    },
  );
}
