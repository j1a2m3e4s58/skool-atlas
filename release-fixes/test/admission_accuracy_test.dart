import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:skoolatlas/tertiary_data.dart';

// Expected cases below are independently transcribed from official source
// sections retained in data/admissions-review-2026-10-27. Numerical current
// cutoffs in tests are fictional fixtures, never production admissions data.
void main() {
  final rules =
      (jsonDecode(
                File('assets/tertiary/admissions.json').readAsStringSync(),
              )['rules']
              as List)
          .map((r) => AdmissionRule(Map<String, dynamic>.from(r)))
          .toList();
  final now = DateTime(2026, 10, 27, 12);
  AdmissionRule rule(String id) => rules.singleWhere((r) => r.id == id);
  Map<String, int> core([int grade = 2]) => {
    for (final s in coreSubjects) s: grade,
  };
  MatchAssessment check(String id, Map<String, int> g) =>
      assessRule(rule(id), g, now: now);
  test('Central IT stays consolidated and pending even with all A1 grades', () {
    expect(rules.where((r) => r.id == 'national-20261027-central-it'), isEmpty);
    final pending = rule('private-20261028-central-it');
    expect(pending.data['status'], 'needs_source_review');
    expect(assessRule(pending, {
      for (final subject in [...coreSubjects, ...electiveSubjects]) subject: 1,
    }, now: DateTime(2026, 11, 17)).academicPass, isFalse);
  });
  test(
    'all published rules pass structural validation; programme and general scopes are distinct',
    () {
      expect(rules.length, 599);
      expect(rules.where((r) => r.data['scope'] == 'programme').length, 541);
      for (final r in rules) {
        expect(() => validateAdmissionRule(r), returnsNormally, reason: r.id);
      }
      expect(rule('ug-wassce-53').data['status'], 'needs_source_review');
    },
  );
  test(
    'older tracked UG programme titles still resolve to their academic rules',
    () {
      expect(
        rule(
          'ug-early-grade',
        ).matchesProgramme('BA Education · Early Grade Specialism'),
        isTrue,
      );
      expect(
        rule(
          'ug-upper-primary-distance',
        ).matchesProgramme('BA Education · Upper Primary · Distance'),
        isTrue,
      );
      expect(
        rule('ug-early-grade').matchesProgramme('BSc Computer Science'),
        isFalse,
      );
    },
  );
  test('UG Consumer Science requires MIL and one of Biology or Chemistry', () {
    for (final science in ['Biology', 'Chemistry']) {
      final g = {
        ...core(),
        'Management in Living': 2,
        science: 2,
        'Food and Nutrition': 2,
      };
      expect(check('ug-wassce-19', g).academicPass, isTrue);
      g.remove('Management in Living');
      g['Government'] = 1;
      expect(check('ug-wassce-19', g).academicPass, isFalse);
    }
  });
  test('C4 subject floors are enforced even with a good aggregate', () {
    final g = {
      ...core(),
      'Core Mathematics': 4,
      'Elective Mathematics': 4,
      'Physics': 2,
      'Chemistry': 2,
    };
    expect(check('ug-wassce-18', g).academicPass, isTrue);
    expect(
      check('ug-wassce-18', {...g, 'Core Mathematics': 5}).academicPass,
      isFalse,
    );
    expect(
      check('ug-wassce-18', {...g, 'Elective Mathematics': 5}).academicPass,
      isFalse,
    );
  });
  test(
    'UG Computer Science needs B3 Elective Maths; a better unrelated elective cannot replace it',
    () {
      final g = {
        ...core(),
        'Elective Mathematics': 3,
        'Physics': 2,
        'Chemistry': 2,
        'Economics': 1,
      };
      expect(check('ug-wassce-23', g).academicPass, isTrue);
      expect(
        check('ug-wassce-23', {...g, 'Elective Mathematics': 4}).academicPass,
        isFalse,
      );
    },
  );
  test(
    'eligibility subject can be required without being counted in the aggregate',
    () {
      final g = {
        ...core(),
        'Biology': 2,
        'Chemistry': 2,
        'Physics': 6,
        'Elective Mathematics': 1,
      };
      final a = check('ug-wassce-44', g);
      expect(a.academicPass, isTrue);
      expect(a.aggregate, 11);
      expect(a.countedSubjects, contains('Elective Mathematics'));
      expect(a.countedSubjects, isNot(contains('Physics')));
      expect(check('ug-wassce-44', {...g, 'Physics': 9}).academicPass, isFalse);
    },
  );
  test('science and non-science aggregates count different cores', () {
    final g = {
      ...core(),
      'Integrated Science': 1,
      'Social Studies': 6,
      'Elective Mathematics': 2,
      'Physics': 2,
      'Chemistry': 2,
    };
    expect(check('ug-early-grade', g).aggregate, 16);
    expect(check('ug-wassce-23', g).aggregate, 11);
    expect(check('ug-early-grade', g).countedSubjects.length, 6);
    expect(
      check('ug-early-grade', {...g, 'Integrated Science': 7}).academicPass,
      isFalse,
    );
  });
  test(
    'programme-specific Distance IT limit 24 overrides general Distance 30',
    () {
      final g = {...core(5), 'Economics': 5, 'Geography': 5, 'Government': 5};
      expect(check('ug-upper-primary-distance', g).academicPass, isTrue);
      expect(check('ug-wassce-03', g).academicPass, isFalse);
    },
  );
  test(
    'UPSA general diploma accepts D7 passes only with at least three counted credits',
    () {
      final g = {
        ...core(7),
        'Integrated Science': 6,
        'Economics': 6,
        'Geography': 6,
        'Government': 7,
      };
      final a = check('upsa-diploma-general', g);
      expect(a.status, 'Meets general entry minimum only');
      expect(a.aggregate, 39);
      expect(
        check('upsa-diploma-general', {...g, 'Geography': 7}).academicPass,
        isFalse,
      );
      expect(check('upsa-real-estate', g).academicPass, isFalse);
    },
  );
  test(
    'best qualifying alternative core is used; a failed alternative is not compulsory',
    () {
      final g = {
        ...core(),
        'Integrated Science': 9,
        'Social Studies': 2,
        'Economics': 2,
        'Geography': 2,
        'Government': 2,
      };
      expect(check('upsa-real-estate', g).academicPass, isTrue);
      expect(
        check('upsa-real-estate', g).countedSubjects,
        contains('Social Studies'),
      );
    },
  );
  test(
    'paired Biology/General Agriculture cannot count as two independent slots',
    () {
      final g = {
        ...core(),
        'Chemistry': 2,
        'Biology': 2,
        'Agricultural Science': 2,
      };
      expect(check('ug-wassce-42', g).academicPass, isFalse);
      expect(
        check('ug-wassce-42', {...g, 'Geography': 3}).academicPass,
        isTrue,
      );
    },
  );
  test(
    'a route needing applicant background confirmation cannot give a positive match',
    () {
      final g = {...core(), 'Chemistry': 2, 'Economics': 2, 'Geography': 2};
      expect(
        check('ug-wassce-41', g).status,
        'Additional route information needed',
      );
      expect(check('ug-wassce-41', g).academicPass, isFalse);
    },
  );
  test(
    'incomplete, failing, out-of-range and unrecognised results cannot match',
    () {
      expect(check('ug-early-grade', {}).status, 'More results needed');
      final g = {...core(), 'Economics': 2, 'Geography': 2, 'Government': 2};
      for (final grade in [7, 8, 9]) {
        expect(
          check('ug-early-grade', {
            ...g,
            'English Language': grade,
          }).academicPass,
          isFalse,
        );
      }
      for (final grade in [0, 10]) {
        expect(
          check('ug-early-grade', {...g, 'English Language': grade}).status,
          'Invalid results',
        );
      }
      expect(
        check('ug-early-grade', {...g, 'Invented subject': 1}).status,
        'Invalid results',
      );
    },
  );
  test(
    'aggregate 24 is accepted and 25 is not for a verified UG regular route',
    () {
      final g = {...core(4), 'Economics': 4, 'Geography': 4, 'Government': 4};
      expect(check('ug-early-grade', g).aggregate, 24);
      expect(check('ug-early-grade', g).academicPass, isTrue);
      expect(
        check('ug-early-grade', {...g, 'Government': 5}).academicPass,
        isFalse,
      );
    },
  );
  test('old, future and changed evidence never produces a match', () {
    final original = rule('ug-early-grade');
    final g = {...core(), 'Economics': 2, 'Geography': 2, 'Government': 2};
    for (final patch in [
      <String, dynamic>{'checkedAt': '2027-01-01'},
      {'checkedAt': '2025-01-01'},
      {'status': 'needs_source_review'},
    ]) {
      expect(
        assessRule(
          AdmissionRule({...original.data, ...patch}),
          g,
          now: now,
        ).status,
        'Needs source review',
      );
    }
  });
  test(
    'official undated and bracketed UG cutoffs never produce a numerical match',
    () {
      for (final r in rules.where((r) => r.data['competitiveCutoff'] != null)) {
        final result = assessCutoff(
          r,
          6,
          academicPass: true,
          targetCycle: '2026/2027',
          now: now,
        );
        expect(result.status, isNot('Within published cutoff'), reason: r.id);
      }
      expect(rule('ug-wassce-23').data['competitiveCutoff']['rawText'], '7(8)');
    },
  );
  AdmissionRule cutoffFixture({
    String cycle = '2026/2027',
    String mode = 'Regular',
    String status = 'source_checked',
  }) => AdmissionRule({
    ...rule('ug-early-grade').data,
    'competitiveCutoff': {
      'sourceUrl': 'https://example.edu.gh/test-only-cutoff',
      'checkedAt': '2026-10-27',
      'cycle': cycle,
      'studyMode': mode,
      'applicantCategory': 'Ghanaian WASSCE first-year applicant',
      'value': 12,
      'rawText': '12',
      'interpretation': 'unambiguous',
      'status': status,
    },
  });
  test(
    'cutoff comparison respects boundary, year, route and academic failure',
    () {
      final r = cutoffFixture();
      expect(
        assessCutoff(
          r,
          12,
          academicPass: true,
          targetCycle: '2026/2027',
          now: now,
        ).status,
        'Within published cutoff',
      );
      expect(
        assessCutoff(
          r,
          13,
          academicPass: true,
          targetCycle: '2026/2027',
          now: now,
        ).status,
        'Above published cutoff',
      );
      for (final year in [null, '2027/2028']) {
        expect(
          assessCutoff(
            r,
            6,
            academicPass: true,
            targetCycle: year,
            now: now,
          ).status,
          'Different or unselected admission year',
        );
      }
      expect(
        assessCutoff(
          cutoffFixture(mode: 'Distance'),
          6,
          academicPass: true,
          targetCycle: '2026/2027',
          now: now,
        ).status,
        'Different admission route',
      );
      expect(
        assessCutoff(
          r,
          6,
          academicPass: false,
          targetCycle: '2026/2027',
          now: now,
        ).status,
        'Academic requirements must be met first',
      );
      expect(
        assessCutoff(
          cutoffFixture(status: 'needs_source_review'),
          6,
          academicPass: true,
          targetCycle: '2026/2027',
          now: now,
        ).status,
        'Cutoff needs verification',
      );
    },
  );
  test(
    'malformed route/cutoff rejects whole feed atomically and old clients cannot consume new rules',
    () {
      Map<String, dynamic> feed() => Map<String, dynamic>.from(
        jsonDecode(File('web/tertiary-feed.json').readAsStringSync()),
      );
      final store = TertiaryStore()..applyFeed(feed());
      final old = store.rules;
      final malformed = feed();
      malformed['rules'] = [
        {
          ...rule('ug-early-grade').data,
          'electiveRoutes': [
            {
              'allowed': ['Economics', 'Geography', 'Government'],
              'groups': [
                {
                  'subjects': ['Economics'],
                  'count': 4,
                },
              ],
            },
          ],
        },
      ];
      expect(() => store.applyFeed(malformed), throwsFormatException);
      expect(identical(store.rules, old), isTrue);
      expect(
        () => store.applyFeed(feed()..['schemaVersion'] = 2),
        throwsFormatException,
      );
      expect(
        () => validateAdmissionRule(
          AdmissionRule({
            ...cutoffFixture().data,
            'competitiveCutoff': {
              ...cutoffFixture().data['competitiveCutoff'],
              'cycle': null,
            },
          }),
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'deterministic matching does not mutate entered grades or published rules',
    () {
      final g = {
        ...core(),
        'Biology': 2,
        'Chemistry': 2,
        'Physics': 6,
        'Elective Mathematics': 1,
      };
      final before = jsonEncode(g);
      final raw = jsonEncode(rule('ug-wassce-44').data);
      final a = check('ug-wassce-44', g);
      final b = check('ug-wassce-44', g);
      expect(a.countedSubjects, b.countedSubjects);
      expect(jsonEncode(g), before);
      expect(jsonEncode(rule('ug-wassce-44').data), raw);
    },
  );
}
