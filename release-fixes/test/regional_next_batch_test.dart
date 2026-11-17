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
  final now = DateTime(2026, 11, 1, 23);
  final added = store.rules
      .where((r) => r.id.startsWith('regional-next-20261101-'))
      .toList();
  final computing = added
      .where((r) => r.data['institutionId'] == 'gtec:900')
      .toList();
  final management = added.singleWhere(
    (r) => r.data['institutionId'] == 'gtec:899',
  );
  Map<String, int> cores([int n = 6]) => {for (final s in coreSubjects) s: n};
  const named = [
    'Physics',
    'Chemistry',
    'Biology',
    'Agricultural Science',
    'Elective Mathematics',
    'Economics',
    'Geography',
    'Business Management',
    'Accounting',
  ];
  const categoryA = [
    'Geography',
    'Economics',
    'Government',
    'History',
    'Business Management',
  ];
  const categoryB = [
    'Literature in English',
    'French',
    'Accounting',
    'Elective Mathematics',
  ];
  test(
    'eight unique programme rules have evidence, correct regions and no invented competitive cutoffs',
    () {
      expect(added, hasLength(8));
      expect(computing, hasLength(7));
      expect(store.rules, hasLength(599));
      for (final r in added) {
        expect(() => validateAdmissionRule(r), returnsNormally);
        expect(r.data['scope'], 'programme');
        expect(r.data['checkedAt'], '2026-11-01');
        expect(r.data['competitiveCutoff'], isNull);
        expect(
          (r.data['sourceEvidence'] as Map)['captureSha256'],
          hasLength(64),
        );
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
        computing.every(
          (r) => r.data['programmeRegions'].single == 'Upper East',
        ),
        isTrue,
      );
      expect(management.data['programmeRegions'], ['Upper West']);
      expect(
        added.any((r) => r.programme.contains('Network Science')),
        isFalse,
      );
    },
  );
  test(
    'all previous academic semantics, status and dates are preserved exactly',
    () {
      final old =
          jsonDecode(
                File(
                  'data/regional-next-2026-11-01/admissions-before.json',
                ).readAsStringSync(),
              )['rules']
              as List;
      expect(old, hasLength(491));
      for (final r in old) {
        expect(store.rules.singleWhere((v) => v.id == r['id']).data, r);
      }
    },
  );
  test(
    'UTAS named business and science combinations pass without invented prerequisite subjects',
    () {
      for (final r in computing) {
        for (final subjects in [
          ['Accounting', 'Economics', 'Business Management'],
          ['Biology', 'Chemistry', 'Agricultural Science'],
          ['Geography', 'Economics', 'Business Management'],
        ]) {
          final g = {...cores(), for (final s in subjects) s: 6};
          final a = assessPathway(r, g, now: now);
          expect(a.academicPass, isTrue, reason: '${r.id} $subjects');
          expect(a.aggregate, 36);
          expect(a.countedSubjects, hasLength(6));
        }
      }
    },
  );
  test(
    'degree core credit floors, three electives and Science cannot be bypassed',
    () {
      for (final r in added) {
        final g = {
          ...cores(),
          'Geography': 6,
          'Economics': 6,
          'Business Management': 6,
        };
        expect(assessPathway(r, g, now: now).academicPass, isTrue);
        for (final subject in [
          'English Language',
          'Core Mathematics',
          'Integrated Science',
          'Geography',
        ]) {
          for (final bad in [7, 8, 9]) {
            expect(
              assessPathway(r, {...g, subject: bad}, now: now).academicPass,
              isFalse,
              reason: '${r.id} $subject=$bad',
            );
          }
          expect(
            assessPathway(r, {...g}..remove(subject), now: now).academicPass,
            isFalse,
          );
        }
        expect(assessPathway(r, {}, now: now).academicPass, isFalse);
      }
    },
  );
  test(
    'unlisted computing electives and ambiguous UBIDS labels stay conditional even at A1',
    () {
      for (final r in computing) {
        expect(
          assessPathway(r, {
            ...cores(1),
            'Government': 1,
            'History': 1,
            'French': 1,
          }, now: now).academicPass,
          isFalse,
        );
      }
      for (final third in [
        'Christian Religious Studies',
        'Islamic Religious Studies',
        'Cost Accounting',
      ]) {
        expect(
          assessPathway(management, {
            ...cores(1),
            'Geography': 1,
            'Economics': 1,
            third: 1,
          }, now: now).academicPass,
          isFalse,
        );
      }
      expect(
        assessPathway(management, {
          ...cores(),
          'Geography': 6,
          'French': 6,
          'Accounting': 6,
        }, now: now).academicPass,
        isFalse,
      );
      expect(
        assessPathway(management, {
          ...cores(),
          'Geography': 6,
          'Economics': 6,
          'French': 6,
        }, now: now).academicPass,
        isTrue,
      );
    },
  );
  test(
    '4096 independent seeded cases check SCIS best-three grades and UBIDS two-category-A constraint',
    () {
      final random = Random(202611011);
      for (final r in added) {
        for (var n = 0; n < 512; n++) {
          final electives = r == management
              ? [...categoryA, ...categoryB, 'Cost Accounting']
              : [...named, 'Government'];
          final g = {
            for (final s in [...coreSubjects, ...electives])
              s: 1 + random.nextInt(9),
          };
          final accepted = electives
              .where(
                (s) =>
                    g[s]! <= 6 &&
                    (r == management
                        ? s != 'Cost Accounting'
                        : named.contains(s)),
              )
              .toList();
          int? best;
          if ([
            'English Language',
            'Core Mathematics',
            'Integrated Science',
          ].every((s) => g[s]! <= 6)) {
            for (var i = 0; i < accepted.length; i++) {
              for (var j = i + 1; j < accepted.length; j++) {
                for (var k = j + 1; k < accepted.length; k++) {
                  final selected = [accepted[i], accepted[j], accepted[k]];
                  if (r == management &&
                      selected.where(categoryA.contains).length < 2) {
                    continue;
                  }
                  final sum =
                      g['English Language']! +
                      g['Core Mathematics']! +
                      g['Integrated Science']! +
                      selected.map((s) => g[s]!).reduce((a, b) => a + b);
                  best = best == null ? sum : min(best, sum);
                }
              }
            }
          }
          final a = assessPathway(r, g, now: now);
          expect(a.academicPass, best != null, reason: '${r.id} oracle $n');
          if (best != null) {
            expect(a.aggregate, best);
            expect(a.countedSubjects, hasLength(6));
          }
        }
      }
    },
  );
  test(
    'stale, future and held evidence cannot approve regardless of grades',
    () {
      final g = {...cores(1), for (final s in electiveSubjects) s: 1};
      for (final r in added) {
        for (final date in [DateTime(2026, 10, 31), DateTime(2027, 11, 1)]) {
          expect(assessPathway(r, g, now: date).academicPass, isFalse);
        }
        expect(
          assessPathway(
            AdmissionRule({...r.data, 'status': 'needs_source_review'}),
            g,
            now: now,
          ).academicPass,
          isFalse,
        );
      }
    },
  );
  test(
    'UTAS past deadline warning stays visible and no current-cycle UBIDS cutoff is claimed',
    () {
      for (final r in computing) {
        expect(
          r.data['additionalConditions'].join(' '),
          contains('has passed'),
        );
      }
      final deadline = (store.journey.resources['deadlines'] as List)
          .singleWhere(
            (r) => r['id'] == 'regional-20261028-utas-undergraduate',
          );
      expect(deadline['date'], '2026-10-31');
      expect(DateTime.parse(deadline['date']).isBefore(now), isTrue);
      expect(management.data['maxAggregate'], isNull);
      expect(management.data['cycle'], contains('not stated'));
    },
  );
}
