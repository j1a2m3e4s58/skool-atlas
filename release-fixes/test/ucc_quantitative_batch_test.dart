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
  AdmissionRule rule(String id) =>
      store.rules.singleWhere((r) => r.id == 'ucc-quant-20261028-$id');
  MatchAssessment check(String id, Map<String, int> grades) =>
      assessPathway(rule(id), grades, now: now);
  const m = 'Elective Mathematics';
  final core = {for (final c in coreSubjects) c: 6};
  const examples = {
    'mathematics-with-economics': [m, 'Economics', 'Geography'],
    'mathematics-with-business': [m, 'Cost Accounting', 'Accounting'],
    'mathematics-and-statistics': [m, 'Physics', 'Technical Drawing'],
    'meteorology-and-atmospheric-physics': [m, 'Physics', 'Chemistry'],
    'industrial-chemistry': ['Biology', 'Physics', 'Chemistry'],
    'economics': ['Economics', 'Government', 'History'],
  };
  test(
    'six quantitative records validate, are unique and retain official evidence',
    () {
      expect(store.rules, hasLength(599));
      expect(
        store.rules.where((r) => r.data['scope'] == 'programme'),
        hasLength(542),
      );
      for (final id in examples.keys) {
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
    'Economics does not inherit Mathematics with Economics requirements',
    () {
      final arts = {
        ...core,
        'Integrated Science': 9,
        'Social Studies': 6,
        'Economics': 6,
        'Government': 6,
        'History': 6,
      };
      expect(check('economics', arts).academicPass, isTrue);
      expect(check('economics', arts).aggregate, 36);
      expect(check('mathematics-with-economics', arts).academicPass, isFalse);
      final g = {...core, m: 6, 'Economics': 6, 'Geography': 6};
      expect(check('mathematics-with-economics', g).academicPass, isTrue);
      expect(
        check('mathematics-with-economics', {
          ...g,
          'Economics': 7,
          'Chemistry': 1,
        }).academicPass,
        isFalse,
      );
      expect(
        check('mathematics-with-economics', {
          ...core,
          m: 1,
          'Economics': 1,
          'French': 1,
        }).academicPass,
        isFalse,
      );
    },
  );
  test(
    'Mathematics business and statistics elective lists remain distinct',
    () {
      final business = {...core, m: 6, 'Cost Accounting': 6, 'Accounting': 6};
      expect(check('mathematics-with-business', business).academicPass, isTrue);
      expect(
        check('mathematics-and-statistics', business).academicPass,
        isFalse,
      );
      final drawing = {...core, m: 6, 'Physics': 6, 'Technical Drawing': 6};
      expect(check('mathematics-and-statistics', drawing).academicPass, isTrue);
      expect(check('mathematics-with-business', drawing).academicPass, isFalse);
      expect(
        check('mathematics-with-business', {
          ...core,
          m: 6,
          'Biology': 6,
          'Physics': 6,
        }).academicPass,
        isTrue,
      );
    },
  );
  test(
    'Industrial Chemistry permits Biology but Meteorology requires Mathematics',
    () {
      final bio = {...core, 'Biology': 6, 'Chemistry': 6, 'Physics': 6};
      expect(check('industrial-chemistry', bio).academicPass, isTrue);
      expect(
        check('meteorology-and-atmospheric-physics', bio).academicPass,
        isFalse,
      );
      expect(
        check('meteorology-and-atmospheric-physics', {
          ...core,
          m: 6,
          'Physics': 6,
          'Chemistry': 6,
        }).academicPass,
        isTrue,
      );
      expect(
        check('industrial-chemistry', {
          ...bio,
          'Physics': 7,
          m: 1,
        }).academicPass,
        isFalse,
      );
    },
  );
  test(
    'C6 boundary passes; compulsory failures and changed evidence cannot pass',
    () {
      for (final id in examples.keys) {
        final g = {...core, for (final e in examples[id]!) e: 6};
        expect(check(id, g).academicPass, isTrue);
        expect(check(id, g).aggregate, 36);
        expect(check(id, {...g, 'English Language': 7}).academicPass, isFalse);
        if (id != 'economics') {
          expect(
            check(id, {
              ...g,
              'Integrated Science': 7,
              'Social Studies': 1,
            }).academicPass,
            isFalse,
          );
        }
        expect(
          assessPathway(
            AdmissionRule({...rule(id).data, 'status': 'needs_source_review'}),
            g,
            now: now,
          ).academicPass,
          isFalse,
        );
      }
    },
  );
  test(
    '1536 independent grade cases verify compulsory electives and six-subject arithmetic',
    () {
      const optional = {
        'mathematics-with-economics': [
          m,
          'Economics',
          'Chemistry',
          'Physics',
          'Biology',
          'Geography',
          'Business Management',
          'Cost Accounting',
          'Accounting',
        ],
        'mathematics-with-business': [
          m,
          'Economics',
          'Chemistry',
          'Physics',
          'Biology',
          'Geography',
          'Business Management',
          'Cost Accounting',
          'Accounting',
        ],
        'mathematics-and-statistics': [
          m,
          'Chemistry',
          'Physics',
          'Biology',
          'Economics',
          'Geography',
          'Technical Drawing',
        ],
        'meteorology-and-atmospheric-physics': [m, 'Physics', 'Chemistry'],
        'industrial-chemistry': ['Chemistry', 'Physics', m, 'Biology'],
        'economics': [
          'Economics',
          m,
          'Chemistry',
          'Physics',
          'Biology',
          'Geography',
          'Business Management',
          'Cost Accounting',
          'Accounting',
          'Government',
          'History',
          'French',
          'Technical Drawing',
        ],
      };
      const required = {
        'mathematics-with-economics': [m, 'Economics'],
        'mathematics-with-business': [m],
        'mathematics-and-statistics': [m],
        'meteorology-and-atmospheric-physics': [m, 'Physics', 'Chemistry'],
        'industrial-chemistry': ['Chemistry', 'Physics'],
        'economics': ['Economics'],
      };
      final random = Random(281009);
      for (final id in examples.keys) {
        for (var n = 0; n < 256; n++) {
          final pool = [...optional['economics']!]..shuffle(random);
          final subjects = n.isEven ? optional[id]! : pool.take(4);
          final g = {
            for (final c in coreSubjects) c: 1 + random.nextInt(9),
            for (final e in subjects) e: 1 + random.nextInt(9),
          };
          bool credit(String s) => (g[s] ?? 99) <= 6;
          final expected =
              credit('English Language') &&
              credit('Core Mathematics') &&
              (id == 'economics'
                  ? (credit('Integrated Science') || credit('Social Studies'))
                  : credit('Integrated Science')) &&
              required[id]!.every(credit) &&
              optional[id]!.where(credit).length >= 3;
          final a = check(id, g);
          expect(a.academicPass, expected, reason: '$id case $n');
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
