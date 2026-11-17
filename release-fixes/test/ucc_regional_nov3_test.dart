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
  final now = DateTime(2026, 11, 3, 12);
  final added = store.rules
      .where((r) => r.id.startsWith('ucc-regional-20261103-'))
      .toList();
  AdmissionRule rule(String slug) =>
      added.singleWhere((r) => r.id == 'ucc-regional-20261103-$slug');
  Map<String, int> cores([int n = 6]) => {for (final s in coreSubjects) s: n};
  const arts = [
    'Geography',
    'Economics',
    'Government',
    'History',
    'French',
    'Elective Mathematics',
    'ICT',
  ];
  const business = [
    'Accounting',
    'Business Management',
    'Economics',
    'Elective Mathematics',
    'ICT',
    'French',
    'Cost Accounting',
  ];
  const science = [
    'Biology',
    'Chemistry',
    'Physics',
    'Elective Mathematics',
    'French',
    'Geography',
    'Agricultural Science',
    'ICT',
  ];
  const agriculture = [
    'Agricultural Science',
    'Animal Husbandry',
    'Crop Husbandry and Horticulture',
    'Fisheries',
    'Forestry',
    'Physics',
    'Chemistry',
    'Elective Mathematics',
  ];
  const him = [
    'Biology',
    'Chemistry',
    'Physics',
    'Elective Mathematics',
    'Economics',
    'Geography',
    'Government',
    'Animal Husbandry',
    'Agricultural Science',
    'ICT',
    'Management in Living',
    'Food and Nutrition',
  ];
  test(
    'six unique source-backed programmes validate across Upper West and Northern',
    () {
      expect(store.rules, hasLength(599));
      expect(added, hasLength(6));
      expect(
        store.rules.where((r) => r.data['scope'] == 'programme'),
        hasLength(542),
      );
      for (final r in added) {
        expect(() => validateAdmissionRule(r), returnsNormally);
        expect(r.data['checkedAt'], '2026-11-03');
        expect(
          (r.data['sourceEvidence'] as Map)['captureSha256'],
          hasLength(64),
        );
        expect(r.data['competitiveCutoff'], isNull);
        expect(
          store.rules.where(
            (o) =>
                o.data['institutionId'] == r.data['institutionId'] &&
                o.programme == r.programme,
          ),
          hasLength(1),
        );
      }
      expect(
        added.where((r) => r.data['programmeRegions'].single == 'Upper West'),
        hasLength(5),
      );
      expect(rule('uds-health-information').data['programmeRegions'], [
        'Northern',
      ]);
    },
  );
  test(
    'all 499 earlier academic records retain exactly the same requirements and evidence dates',
    () {
      final before =
          jsonDecode(
                File(
                  'data/ucc-regional-2026-11-03/admissions-before.json',
                ).readAsStringSync(),
              )['rules']
              as List;
      expect(before, hasLength(499));
      for (final r in before) {
        expect(store.rules.singleWhere((o) => o.id == r['id']).data, r);
      }
    },
  );
  test(
    'degree and diploma credit floors are distinct and diploma aggregate 36 is enforced',
    () {
      for (final slug in ['social-policy', 'organisational']) {
        final degree = rule(slug), diploma = rule('$slug-diploma');
        final g = {
          ...cores(),
          'English Language': 7,
          'Core Mathematics': 7,
          'Integrated Science': 4,
          'Government': 6,
          'History': 6,
          'Geography': 6,
        };
        expect(assessPathway(degree, g, now: now).academicPass, isFalse);
        final a = assessPathway(diploma, g, now: now);
        expect(a.academicPass, isTrue);
        expect(a.aggregate, 36);
        expect(
          assessPathway(diploma, {
            ...g,
            'Integrated Science': 5,
            'Social Studies': 9,
          }, now: now).academicPass,
          isFalse,
        );
        for (final bad in [7, 8, 9]) {
          expect(
            assessPathway(diploma, {
              ...g,
              'Geography': bad,
            }, now: now).academicPass,
            isFalse,
          );
        }
        expect(
          assessPathway(diploma, {
            ...g,
            'Integrated Science': 9,
            'Social Studies': 4,
          }, now: now).academicPass,
          isTrue,
        );
        expect(
          assessPathway(degree, {
            ...cores(),
            'Integrated Science': 9,
            'Social Studies': 1,
            'Government': 1,
            'History': 1,
            'Geography': 1,
          }, now: now).academicPass,
          isFalse,
        );
      }
    },
  );
  test(
    'published background areas stay separate and Urban Governance accepts its additional areas',
    () {
      final sci = {...cores(), 'Biology': 6, 'Chemistry': 6, 'Physics': 6};
      expect(
        assessPathway(rule('urban-governance'), sci, now: now).academicPass,
        isTrue,
      );
      expect(
        assessPathway(rule('social-policy'), sci, now: now).academicPass,
        isFalse,
      );
      expect(
        assessPathway(rule('organisational'), sci, now: now).academicPass,
        isFalse,
      );
      for (final r in added.where(
        (r) => r.data['institutionId'] == 'gtec:899',
      )) {
        expect(
          assessPathway(r, {
            ...cores(),
            'Accounting': 6,
            'Business Management': 6,
            'Economics': 6,
          }, now: now).academicPass,
          isTrue,
        );
        expect(
          assessPathway(r, {
            ...cores(1),
            'Accounting': 1,
            'Government': 1,
            'Biology': 1,
          }, now: now).academicPass,
          isFalse,
        );
        expect(
          assessPathway(r, {
            ...cores(1),
            'Graphic Design': 1,
            'Ceramics': 1,
            'Technical Drawing': 1,
          }, now: now).academicPass,
          isFalse,
        );
      }
    },
  );
  test(
    'UDS uses WASSCE electives rather than SSSCE or post-basic restrictions',
    () {
      final r = rule('uds-health-information');
      for (final subjects in [
        ['Geography', 'Government', 'Food and Nutrition'],
        ['Animal Husbandry', 'Agricultural Science', 'ICT'],
        ['Management in Living', 'Food and Nutrition', 'Biology'],
      ]) {
        final a = assessPathway(r, {
          ...cores(),
          for (final s in subjects) s: 6,
        }, now: now);
        expect(a.academicPass, isTrue);
        expect(a.aggregate, 36);
      }
      expect(
        assessPathway(r, {
          ...cores(1),
          'Accounting': 1,
          'Business Management': 1,
          'Cost Accounting': 1,
        }, now: now).academicPass,
        isFalse,
      );
      expect(
        assessPathway(r, {
          ...cores(),
          'Integrated Science': 9,
          'Social Studies': 1,
          'Government': 6,
          'Geography': 6,
          'Food and Nutrition': 6,
        }, now: now).academicPass,
        isFalse,
      );
    },
  );
  test(
    'missing subjects and D7/E8/F9 degree grades cannot be hidden by strong surplus results',
    () {
      for (final r in added) {
        final g = {...cores(), 'Government': 6, 'History': 6, 'Geography': 6};
        if (r.id.endsWith('uds-health-information')) {
          g.remove('History');
          g['Food and Nutrition'] = 6;
        }
        expect(assessPathway(r, g, now: now).academicPass, isTrue);
        expect(assessPathway(r, {}, now: now).academicPass, isFalse);
        expect(
          assessPathway(
            r,
            {...g}..remove('Core Mathematics'),
            now: now,
          ).academicPass,
          isFalse,
        );
        expect(
          assessPathway(r, {
            ...g,
            'English Language': 8,
          }, now: now).academicPass,
          isFalse,
        );
      }
    },
  );
  test(
    '3072 independent seeded cases preserve area membership, core alternatives and best-six arithmetic',
    () {
      final random = Random(20261103);
      for (final r in added) {
        for (var n = 0; n < 512; n++) {
          final diploma = r.programme.startsWith('Diploma'),
              isHim = r.id.endsWith('uds-health-information'),
              urban = r.id.endsWith('urban-governance');
          final subjects = <String>{
            ...arts,
            ...business,
            ...science,
            ...agriculture,
            ...him,
            'Graphic Design',
            'Technical Drawing',
          };
          final g = {
            for (final s in [...coreSubjects, ...subjects])
              s: 1 + random.nextInt(9),
          };
          final third = diploma
              ? min(g['Integrated Science']!, g['Social Studies']!)
              : g['Integrated Science']!;
          final coreSum =
              g['English Language']! + g['Core Mathematics']! + third;
          int? expected;
          if (g['English Language']! <= (diploma ? 7 : 6) &&
              g['Core Mathematics']! <= (diploma ? 7 : 6) &&
              third <= (diploma ? 7 : 6)) {
            final areas = isHim
                ? [him]
                : [arts, business, if (urban) science, if (urban) agriculture];
            for (final area in areas) {
              final grades =
                  area.where((s) => g[s]! <= 6).map((s) => g[s]!).toList()
                    ..sort();
              if (grades.length < 3) {
                continue;
              }
              final aggregate =
                  coreSum + grades.take(3).reduce((a, b) => a + b);
              if (aggregate <= 36 &&
                  (expected == null || aggregate < expected)) {
                expected = aggregate;
              }
            }
          }
          final result = assessPathway(r, g, now: now);
          expect(
            result.academicPass,
            expected != null,
            reason: '${r.id}: case $n',
          );
          if (expected != null) {
            expect(result.aggregate, expected);
            expect(result.countedSubjects, hasLength(6));
          }
        }
      }
    },
  );
  test(
    'new routes and restored UCC rules remain held for changed, unavailable or stale evidence',
    () {
      final review = jsonDecode(
        File('reports/ucc-regional-review.json').readAsStringSync(),
      );
      final urls = {for (final row in review['uccReview']) row['url']};
      final ucc = store.rules
          .where((r) => urls.contains(r.data['sourceUrl']))
          .toList();
      expect(ucc, hasLength(8));
      final g = {...cores(1), for (final s in electiveSubjects) s: 1};
      for (final r in [...added, ...ucc]) {
        expect(
          assessPathway(
            AdmissionRule({...r.data, 'status': 'needs_source_review'}),
            g,
            now: now,
          ).academicPass,
          isFalse,
        );
        expect(
          assessPathway(r, g, now: DateTime(2027, 11, 3)).academicPass,
          isFalse,
        );
      }
    },
  );
  test(
    'past UDS deadline, unknown UBIDS intake and no invented competitive cutoff remain explicit',
    () {
      expect(
        rule('uds-health-information').data['additionalConditions'].join(' '),
        contains('has passed'),
      );
      for (final r in added.where(
        (r) => r.data['institutionId'] == 'gtec:899',
      )) {
        expect(r.data['cycle'], contains('not stated'));
      }
      expect(rule('urban-governance').data['maxAggregate'], isNull);
    },
  );
}
