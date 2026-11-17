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
  final now = DateTime(2026, 10, 28, 12);
  AdmissionRule r(String slug) =>
      store.rules.singleWhere((r) => r.id == 'applied-20261028-$slug');
  MatchAssessment check(String slug, Map<String, int> g) =>
      assessPathway(r(slug), g, now: now);
  Map<String, int> core([int n = 2]) => {for (final c in coreSubjects) c: n};
  final sci = {
    ...core(),
    'Elective Mathematics': 2,
    'Physics': 2,
    'Chemistry': 2,
  };
  final arts = {...core(), 'Economics': 2, 'Government': 2, 'History': 2};
  test(
    '26 distinct programme records validate with retained source evidence',
    () {
      expect(store.rules, hasLength(599));
      expect(
        store.rules.where((r) => r.data['scope'] == 'programme'),
        hasLength(542),
      );
      final batch = store.rules
          .where((r) => r.id.startsWith('applied-20261028-'))
          .toList();
      expect(batch, hasLength(26));
      expect(
        batch.where((r) => r.data['institutionId'] == 'gtec:837'),
        hasLength(22),
      );
      expect(
        batch.where((r) => r.data['institutionId'] == 'gtec:827'),
        hasLength(3),
      );
      expect(
        batch.where((r) => r.data['institutionId'] == 'gtec:828'),
        hasLength(1),
      );
      for (final rule in store.rules) {
        expect(
          () => validateAdmissionRule(rule),
          returnsNormally,
          reason: rule.id,
        );
      }
      for (final rule in batch) {
        expect(rule.data['scope'], 'programme');
        expect(
          rule.data['sourceEvidence']['captureSha256'],
          matches(RegExp(r'^[a-f0-9]{64}$')),
        );
        expect(rule.data['competitiveCutoff'], isNull);
      }
    },
  );
  test(
    'KsTU Medical Laboratory requires Physics, not a Mathematics substitution',
    () {
      expect(
        check('kstu-medical-laboratory', {...sci, 'Biology': 2}).academicPass,
        isTrue,
      );
      expect(
        check('kstu-medical-laboratory', {
          ...core(),
          'Elective Mathematics': 1,
          'Biology': 1,
          'Chemistry': 1,
        }).academicPass,
        isFalse,
      );
      expect(
        check('kstu-medical-laboratory', {
          ...sci,
          'Biology': 2,
          'Integrated Science': 7,
          'Social Studies': 1,
        }).academicPass,
        isFalse,
      );
    },
  );
  test(
    'KTU Statistics and Actuarial require elective Mathematics credit without importing SSSCE floors',
    () {
      for (final slug in ['ktu-statistics', 'ktu-actuarial']) {
        expect(check(slug, arts).academicPass, isFalse);
        expect(
          check(slug, {...arts, 'Elective Mathematics': 6}).academicPass,
          isTrue,
        );
        expect(
          check(slug, {...arts, 'Elective Mathematics': 7}).academicPass,
          isFalse,
        );
      }
    },
  );
  test(
    'KTU Food distinguishes the named pure science route from ambiguous backgrounds',
    () {
      expect(check('ktu-food', sci).academicPass, isTrue);
      expect(
        check('ktu-food', {
          ...core(),
          'Food and Nutrition': 2,
          'Management in Living': 2,
          'Economics': 2,
        }).academicPass,
        isFalse,
      );
      expect(
        check('ktu-food', {
          ...sci,
          'Integrated Science': 7,
          'Social Studies': 1,
        }).academicPass,
        isFalse,
      );
    },
  );
  test(
    'Electric Vehicle, Robotics and UAS require Mathematics Physics and named Chemistry route',
    () {
      for (final slug in [
        'bachelor-of-science-in-electric-vehicle-engineering',
        'bsc-robotics-engineering',
        'bsc-unmanned-aerial-systems-uas-engineering',
      ]) {
        expect(check('acity-$slug', sci).academicPass, isTrue);
        expect(
          check('acity-$slug', {
            ...core(),
            'Elective Mathematics': 2,
            'Physics': 2,
            'Government': 2,
          }).academicPass,
          isFalse,
        );
        expect(
          check('acity-$slug', {
            ...core(),
            'Biology': 1,
            'Physics': 1,
            'Chemistry': 1,
          }).academicPass,
          isFalse,
        );
      }
    },
  );
  test(
    'Undefined engineering third subjects remain confirmation-only even with Chemistry',
    () {
      for (final slug in [
        'bsc-computer-engineering',
        'bsc-electrical-electronics-engineering',
        'bsc-electronics-communication-engineering',
        'bsc-mechanical-engineering',
        'bsc-artificial-intelligence',
      ]) {
        expect(check('acity-$slug', sci).academicPass, isFalse);
        expect(
          check('acity-$slug', sci).status,
          'Additional route information needed',
        );
      }
    },
  );
  test(
    'Data Science WASSCE examples do not inherit the SSSCE Mathematics prerequisite',
    () {
      final g = {...arts, 'Integrated Science': 9, 'Social Studies': 2};
      expect(
        check('acity-bsc-data-science-artificial-intelligence', g).academicPass,
        isTrue,
      );
      expect(
        check('acity-bsc-artificial-intelligence', g).academicPass,
        isFalse,
      );
      expect(check('acity-bsc-computer-science', arts).academicPass, isFalse);
    },
  );
  test(
    'Named business programmes require Integrated Science, while Entrepreneurship keeps relevance conditional',
    () {
      for (final slug in [
        'bba-marketing',
        'bba-human-resource-management',
        'bachelor-of-business-administration-banking-finance',
        'bachelor-of-business-administration-accounting',
      ]) {
        expect(check('acity-$slug', arts).academicPass, isTrue);
        expect(
          check('acity-$slug', {
            ...arts,
            'Integrated Science': 9,
            'Social Studies': 1,
          }).academicPass,
          isFalse,
        );
      }
      expect(
        check(
          'acity-bachelor-of-business-administration-entrepreneurship',
          arts,
        ).academicPass,
        isFalse,
      );
    },
  );
  test(
    'Communications and Film accept named examples and their Social Studies core alternative',
    () {
      final g = {...arts, 'Integrated Science': 9, 'Social Studies': 2};
      for (final slug in [
        'ba-advertising-and-public-relations',
        'ba-in-journalism-mass-communication',
        'bachelor-of-arts-in-film-and-digital-technologies',
      ]) {
        expect(check('acity-$slug', g).academicPass, isTrue);
      }
    },
  );
  test('C6 aggregate 36 boundary passes but compulsory D7 does not', () {
    final g = {...core(6), 'Government': 6, 'History': 6, 'French': 6};
    expect(check('acity-bba-marketing', g).academicPass, isTrue);
    expect(check('acity-bba-marketing', g).aggregate, 36);
    expect(
      check('acity-bba-marketing', {...g, 'English Language': 7}).academicPass,
      isFalse,
    );
    expect(
      check('acity-bba-marketing', {...g, 'French': 7}).academicPass,
      isFalse,
    );
  });
  test(
    'Course-specific Science alternatives and actual regions remain separate',
    () {
      final g = {...sci, 'Integrated Science': 9, 'Social Studies': 2};
      expect(check('acity-bsc-nuclear-engineering', g).academicPass, isTrue);
      expect(check('acity-bsc-robotics-engineering', g).academicPass, isFalse);
      expect(r('kstu-medical-laboratory').data['programmeRegions'], [
        'Ashanti',
      ]);
      expect(r('ktu-statistics').data['programmeRegions'], ['Eastern']);
      expect(r('acity-bsc-nuclear-engineering').data['programmeRegions'], [
        'Greater Accra',
      ]);
    },
  );
  test(
    '1664 generated grade cases preserve six-credit arithmetic and source quarantine',
    () {
      final random = Random(28102626);
      var count = 0;
      for (final rule in store.rules.where(
        (r) => r.id.startsWith('applied-20261028-'),
      )) {
        final allowed = (rule.data['electiveRoutes'] as List)
            .expand((x) => x['allowed'] as List)
            .cast<String>()
            .toSet()
            .toList();
        for (var n = 0; n < 64; n++) {
          allowed.shuffle(random);
          final g = {
            for (final c in coreSubjects) c: 1 + random.nextInt(9),
            for (final e in allowed.take(5)) e: 1 + random.nextInt(9),
          };
          final original = Map<String, int>.from(g);
          final a = assessPathway(rule, g, now: now);
          count++;
          expect(g, original);
          if (a.academicPass) {
            expect(a.countedSubjects, hasLength(6));
            expect(
              a.aggregate,
              a.countedSubjects.values.reduce((a, b) => a + b),
            );
            expect(a.countedSubjects.values.every((n) => n <= 6), isTrue);
            if (rule.data['maxAggregate'] != null) {
              expect(a.aggregate, lessThanOrEqualTo(rule.data['maxAggregate']));
            }
          }
          expect(
            assessPathway(
              AdmissionRule({...rule.data, 'status': 'needs_source_review'}),
              g,
              now: now,
            ).academicPass,
            isFalse,
          );
        }
      }
      expect(count, 1664);
    },
  );
}
