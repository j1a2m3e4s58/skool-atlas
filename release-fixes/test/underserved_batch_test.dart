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
  final now = DateTime(2026, 10, 28, 22);
  const detailed = ['physiotherapy', 'trauma'];
  const education = [
    'gambaga',
    'dambai',
    'savannah',
    'tumu',
    'enchi',
    'bia',
    'wiawso',
    'bosco',
  ];
  AdmissionRule rule(String slug) =>
      store.rules.singleWhere((r) => r.id == 'underserved-20261028-$slug');
  MatchAssessment check(String slug, Map<String, int> g) =>
      assessPathway(rule(slug), g, now: now);
  final core = {for (final c in coreSubjects) c: 6};
  test(
    'ten unique records retain seven regions, source evidence and distinct confidence levels',
    () {
      expect(store.rules, hasLength(600));
      expect(
        store.rules.where((r) => r.data['scope'] == 'programme'),
        hasLength(542),
      );
      final newRules = store.rules
          .where((r) => r.id.startsWith('underserved-20261028-'))
          .toList();
      expect(newRules, hasLength(10));
      final regions = <String>{};
      for (final r in newRules) {
        expect(() => validateAdmissionRule(r), returnsNormally);
        expect(
          (r.data['sourceEvidence'] as Map)['captureSha256'],
          hasLength(64),
        );
        expect(
          store.rules.where(
            (o) => o.institution == r.institution && o.programme == r.programme,
          ),
          hasLength(1),
        );
        regions.addAll(List<String>.from(r.data['programmeRegions']));
        expect(r.data['competitiveCutoff'], isNull);
      }
      expect(regions, {
        'Ahafo',
        'North East',
        'Oti',
        'Savannah',
        'Upper East',
        'Upper West',
        'Western North',
      });
    },
  );
  test(
    'Ahafo diplomas accept the four published areas at aggregate 36 with no invented science prerequisite',
    () {
      for (final id in detailed) {
        for (final electives in [
          ['Biology', 'Physics', 'Chemistry'],
          [
            'Agricultural Science',
            'Animal Husbandry',
            'Crop Husbandry and Horticulture',
          ],
          ['Food and Nutrition', 'Management in Living', 'Economics'],
          ['History', 'Government', 'Ghanaian Language'],
        ]) {
          final a = check(id, {...core, for (final s in electives) s: 6});
          expect(a.academicPass, isTrue);
          expect(a.aggregate, 36);
        }
        final g = {...core, 'History': 6, 'Government': 6, 'Geography': 6};
        for (final c in [
          'English Language',
          'Core Mathematics',
          'Integrated Science',
          'History',
        ]) {
          for (final fail in [7, 8, 9]) {
            expect(
              check(id, {...g, c: fail, 'Social Studies': 1}).academicPass,
              isFalse,
            );
          }
        }
        expect(
          rule(id).data['additionalConditions'].join(' '),
          contains('written examination and oral interview'),
        );
      }
    },
  );
  test(
    'Area lists stay separate and business subjects do not replace accepted electives',
    () {
      for (final id in detailed) {
        expect(
          check(id, {
            ...core,
            'Animal Husbandry': 1,
            'Food and Nutrition': 1,
            'History': 1,
          }).academicPass,
          isFalse,
        );
        expect(
          check(id, {
            ...core,
            'Accounting': 1,
            'Business Management': 1,
            'Cost Accounting': 1,
          }).academicPass,
          isFalse,
        );
        expect(
          check(id, {
            ...core,
            'Dagaare': 6,
            'History': 6,
            'Government': 6,
          }).academicPass,
          isTrue,
        );
        expect(
          check(id, {
            ...core,
            'Christian Religious Studies': 6,
            'French': 6,
            'General Knowledge in Art': 6,
          }).academicPass,
          isTrue,
        );
      }
    },
  );
  test(
    'Every education baseline remains conditional even with A1s and retains the expired-intake warning',
    () {
      for (final id in education) {
        final r = rule('early-$id');
        expect(r.data['cycle'], '2026/2027');
        expect(r.data['evidenceBasis'], 'national_programme_baseline');
        expect(
          r.data['additionalConditions'].join(' '),
          contains('31 August 2026'),
        );
        final a = check('early-$id', {
          for (final c in coreSubjects) c: 1,
          'History': 1,
          'Government': 1,
          'Geography': 1,
        });
        expect(a.academicPass, isFalse);
        expect(a.status, 'Additional route information needed');
        expect(r.data['scienceOrSocial'], [
          'Integrated Science',
          'Social Studies',
        ]);
        expect(
          (r.data['electiveRoutes'] as List).single['confirmation'],
          contains('Early Grade Education'),
        );
      }
    },
  );
  test(
    '2048 independent detailed grade oracles preserve area and aggregate correctness',
    () {
      final random = Random(2810267);
      const areas = [
        ['Biology', 'Physics', 'Elective Mathematics', 'Chemistry'],
        [
          'Agricultural Science',
          'Animal Husbandry',
          'Crop Husbandry and Horticulture',
          'Physics',
          'Elective Mathematics',
          'Chemistry',
        ],
        [
          'Biology',
          'Elective Mathematics',
          'Chemistry',
          'Economics',
          'Food and Nutrition',
          'Management in Living',
        ],
        [
          'Literature in English',
          'French',
          'Ghanaian Language',
          'Christian Religious Studies',
          'Islamic Religious Studies',
          'Economics',
          'Geography',
          'History',
          'Government',
          'Elective Mathematics',
          'General Knowledge in Art',
        ],
      ];
      final subjects = areas.expand((a) => a).toSet().toList();
      for (final id in detailed) {
        for (var n = 0; n < 1024; n++) {
          final g = {
            for (final c in coreSubjects) c: 1 + random.nextInt(9),
            for (final s in subjects) s: 1 + random.nextInt(9),
          };
          bool credit(String s) => (g[s] ?? 9) <= 6;
          final expected =
              [
                'English Language',
                'Core Mathematics',
                'Integrated Science',
              ].every(credit) &&
              areas.any((area) => area.where(credit).length >= 3);
          final a = check(id, g);
          expect(a.academicPass, expected, reason: '$id case $n');
          if (a.academicPass) {
            expect(a.countedSubjects, hasLength(6));
            expect(a.countedSubjects.values.every((v) => v <= 6), isTrue);
            expect(
              a.aggregate,
              a.countedSubjects.values.reduce((a, b) => a + b),
            );
            expect(a.aggregate, lessThanOrEqualTo(36));
          }
        }
      }
    },
  );
  test(
    '512 education scenarios never become confident and all new rules fail closed for stale or changed evidence',
    () {
      final random = Random(73928);
      for (final id in education) {
        for (var n = 0; n < 64; n++) {
          final g = {
            for (final c in coreSubjects) c: 1 + random.nextInt(9),
            'History': 1 + random.nextInt(9),
            'Government': 1 + random.nextInt(9),
            'Geography': 1 + random.nextInt(9),
          };
          expect(check('early-$id', g).academicPass, isFalse);
        }
      }
      for (final r in store.rules.where(
        (r) => r.id.startsWith('underserved-20261028-'),
      )) {
        final g = {
          for (final c in coreSubjects) c: 1,
          'History': 1,
          'Government': 1,
          'Geography': 1,
        };
        expect(
          assessPathway(
            AdmissionRule({...r.data, 'status': 'needs_source_review'}),
            g,
            now: now,
          ).academicPass,
          isFalse,
        );
        expect(
          assessPathway(r, g, now: DateTime(2027, 10, 28)).academicPass,
          isFalse,
        );
      }
    },
  );
}
