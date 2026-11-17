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
  AdmissionRule rule(String slug) =>
      store.rules.singleWhere((r) => r.id == 'private-20261028-$slug');
  Map<String, int> core([int n = 2]) => {for (final s in coreSubjects) s: n};
  MatchAssessment check(String slug, Map<String, int> g) =>
      assessPathway(rule(slug), g, now: now);
  final science = {
    ...core(),
    'Elective Mathematics': 2,
    'Physics': 2,
    'Chemistry': 2,
  };
  final arts = {...core(), 'Government': 2, 'History': 2, 'French': 2};
  test(
    '20 unique programme records retain evidence, scope and correct institution identity',
    () {
      expect(store.rules, hasLength(600));
    expect(rule('presby-mathematics').data['programme'], 'BSc Mathematics with Statistics');
      expect(
        store.rules.where((r) => r.data['scope'] == 'programme'),
        hasLength(542),
      );
      final added = store.rules
          .where((r) => r.id.startsWith('private-20261028-'))
          .toList();
      expect(added, hasLength(20));
      expect(
        added.where((r) => r.data['status'] == 'needs_source_review'),
        hasLength(1),
      );
      expect(
        {for (final r in added) r.data['institutionId']},
        {'gtec:920', 'gtec:872', 'gtec:935'},
      );
      for (final r in store.rules) {
        expect(() => validateAdmissionRule(r), returnsNormally, reason: r.id);
      }
      for (final r in added) {
        expect(r.data['scope'], 'programme');
        expect(
          r.data['sourceEvidence']['captureSha256'],
          matches(RegExp(r'^[a-f0-9]{64}$')),
        );
        expect(r.data['competitiveCutoff'], isNull);
      }
    },
  );
  test(
    'Central Computer Science accepts Mathematics OR Physics; Civil requires all named subjects',
    () {
      expect(
        check('central-computer-science', {...arts, 'Physics': 2}).academicPass,
        isTrue,
      );
      expect(
        check('central-computer-science', {
          ...arts,
          'Elective Mathematics': 2,
        }).academicPass,
        isTrue,
      );
      expect(check('central-computer-science', arts).academicPass, isFalse);
      expect(check('central-civil', science).academicPass, isTrue);
      expect(
        check('central-civil', {
          ...core(),
          'Physics': 1,
          'Chemistry': 1,
          'Biology': 1,
        }).academicPass,
        isFalse,
      );
    },
  );
  test(
    'Central Pharmacy requires Biology and Chemistry while science nursing has its own list',
    () {
      expect(check('central-pharmacy', science).academicPass, isFalse);
      expect(
        check('central-pharmacy', {...science, 'Biology': 2}).academicPass,
        isTrue,
      );
      expect(
        check('central-pharmacy', {
          ...core(),
          'Biology': 1,
          'Physics': 1,
          'Elective Mathematics': 1,
        }).academicPass,
        isFalse,
      );
      expect(check('central-nursing', science).academicPass, isTrue);
    },
  );
  test(
    'School-specific Science core cannot be replaced for Architecture or IT',
    () {
      for (final id in ['central-architecture', 'central-it']) {
        expect(check(id, arts).academicPass, isTrue);
        expect(
          check(id, {
            ...arts,
            'Integrated Science': 9,
            'Social Studies': 1,
          }).academicPass,
          isFalse,
        );
      }
    },
  );
  test(
    'Central Nursing preserves stream lists and never mixes three incompatible electives',
    () {
      expect(check('central-nursing', arts).academicPass, isTrue);
      expect(
        check('central-nursing', {
          ...core(),
          'Food and Nutrition': 2,
          'Management in Living': 2,
          'French': 2,
        }).academicPass,
        isTrue,
      );
      expect(
        check('central-nursing', {
          ...core(),
          'Biology': 1,
          'Government': 1,
          'Food and Nutrition': 1,
        }).academicPass,
        isFalse,
      );
    },
  );
  test(
    'Pentecost construction requires Mathematics and two published electives',
    () {
      for (final id in [
        'pentecost-construction',
        'pentecost-quantity-surveying',
      ]) {
        expect(
          check(id, {
            ...core(),
            'Elective Mathematics': 2,
            'Economics': 2,
            'Technical Drawing': 2,
          }).academicPass,
          isTrue,
        );
        expect(
          check(id, {
            ...core(),
            'Physics': 1,
            'Chemistry': 1,
            'Geography': 1,
          }).academicPass,
          isFalse,
        );
        expect(
          check(id, {
            ...core(),
            'Elective Mathematics': 1,
            'Government': 1,
            'History': 1,
          }).academicPass,
          isFalse,
        );
      }
    },
  );
  test(
    'Pentecost Nursing cannot use an overlapping non-science list to bypass Biology and Chemistry',
    () {
      expect(
        check('pentecost-nursing', {...science, 'Biology': 2}).academicPass,
        isTrue,
      );
      expect(check('pentecost-nursing', science).academicPass, isFalse);
      expect(check('pentecost-nursing', arts).academicPass, isTrue);
      expect(
        check('pentecost-nursing', {
          ...arts,
          'Integrated Science': 7,
        }).academicPass,
        isFalse,
      );
    },
  );
  test(
    'Presbyterian Mathematics and ICT treat the C4 alternative differently',
    () {
      final withoutMaths = {...arts, 'Core Mathematics': 4};
      expect(check('presby-mathematics', withoutMaths).academicPass, isFalse);
      expect(
        check('presby-mathematics', withoutMaths).status,
        'Additional route information needed',
      );
      expect(check('presby-mathematics', science).academicPass, isTrue);
      expect(check('presby-ict', withoutMaths).academicPass, isTrue);
      expect(
        check('presby-ict', {
          ...withoutMaths,
          'Core Mathematics': 5,
        }).academicPass,
        isFalse,
      );
      expect(
        check('presby-ict', {
          ...withoutMaths,
          'Core Mathematics': 6,
          'Elective Mathematics': 6,
        }).academicPass,
        isTrue,
      );
    },
  );
  test(
    'Programme-specific social-core alternatives and environmental named-elective group are respected',
    () {
      final g = {...arts, 'Integrated Science': 9, 'Social Studies': 2};
      expect(check('presby-business', g).academicPass, isTrue);
      expect(check('presby-environment', g).academicPass, isTrue);
      expect(
        check('presby-environment', {
          ...core(),
          'French': 1,
          'History': 1,
          'Literature in English': 1,
        }).academicPass,
        isFalse,
      );
      expect(rule('presby-nursing').data['programmeRegions'], ['Ashanti']);
      expect(rule('presby-mathematics').data['programmeRegions'], ['Eastern']);
    },
  );
  test(
    'Ambiguous electives and duplicated grading headings cannot approve excellent results',
    () {
      final g = {...science, ...arts, 'Biology': 1};
      for (final id in [
        'central-economics-law',
        'pentecost-actuarial',
        'presby-agribusiness',
        'presby-pa',
      ]) {
        expect(check(id, g).academicPass, isFalse, reason: id);
      }
    },
  );
  test('Aggregate 36 and C6 boundary pass; any compulsory D7 fails', () {
    final g = {...core(6), 'Government': 6, 'History': 6, 'French': 6};
    expect(check('presby-business', g).academicPass, isTrue);
    expect(check('presby-business', g).aggregate, 36);
    expect(
      check('presby-business', {...g, 'English Language': 7}).academicPass,
      isFalse,
    );
    expect(check('presby-business', {...g, 'French': 7}).academicPass, isFalse);
  });
  test(
    '1280 deterministic grade cases preserve arithmetic, mandatory credits and source quarantine',
    () {
      final random = Random(281020);
      var count = 0;
      for (final r in store.rules.where(
        (r) => r.id.startsWith('private-20261028-'),
      )) {
        final allowed = (r.data['electiveRoutes'] as List)
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
          final a = assessPathway(r, g, now: now);
          count++;
          expect(g, original);
          if (a.academicPass) {
            expect(a.countedSubjects, hasLength(6));
            expect(
              a.aggregate,
              a.countedSubjects.values.reduce((a, b) => a + b),
            );
            expect(a.countedSubjects.values.every((n) => n <= 6), isTrue);
            expect(a.aggregate, lessThanOrEqualTo(36));
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
      }
      expect(count, 1280);
    },
  );
}
