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
  final now = DateTime(2026, 10, 28, 17);
  const ids = [
    'accounting',
    'finance',
    'management',
    'marketing',
    'human-resource-management',
    'procurement-and-supply-chain-management',
  ];
  AdmissionRule rule(String id) =>
      store.rules.singleWhere((r) => r.id == 'ucc-business-20261028-$id');
  MatchAssessment check(String id, Map<String, int> grades) =>
      assessPathway(rule(id), grades, now: now);
  final core = {for (final c in coreSubjects) c: 6};
  final arts = {...core, 'French': 6, 'History': 6, 'Literature in English': 6};

  test(
    'six business routes have unique identity, frozen evidence and no invented cutoff',
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
        expect(r.data['cycle'], contains('not stated'));
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
    'Accounting requires Financial Accounting and counts it even when lower graded',
    () {
      expect(
        subjectMatchesSearch('Accounting', 'Financial Accounting'),
        isTrue,
      );
      final cost = {...arts, 'Cost Accounting': 1, 'Business Management': 1};
      expect(check('accounting', cost).academicPass, isFalse);
      final g = {
        for (final c in coreSubjects) c: 1,
        'Accounting': 6,
        'Economics': 1,
        'Government': 1,
        'History': 1,
      };
      final a = check('accounting', g);
      expect(a.academicPass, isTrue);
      expect(a.countedSubjects['Accounting'], 6);
      expect(a.aggregate, 11);
      expect(
        check('accounting', {...g, 'Accounting': 7}).academicPass,
        isFalse,
      );
    },
  );
  test(
    'Finance requires Mathematics OR Economics as one of three counted electives',
    () {
      expect(check('finance', arts).academicPass, isFalse);
      for (final subject in ['Economics', 'Elective Mathematics']) {
        final g = {...core, subject: 6, 'French': 6, 'History': 6};
        expect(check('finance', g).academicPass, isTrue);
        expect(check('finance', g).aggregate, 36);
        expect(check('finance', {...g, subject: 7}).academicPass, isFalse);
      }
      expect(
        check('finance', {
          ...core,
          'Economics': 1,
          'Elective Mathematics': 1,
        }).academicPass,
        isFalse,
      );
      final g = {
        for (final c in coreSubjects) c: 1,
        'Economics': 6,
        'French': 1,
        'History': 1,
        'Government': 1,
      };
      expect(check('finance', g).countedSubjects['Economics'], 6);
      expect(check('finance', g).aggregate, 11);
    },
  );
  test(
    'four programmes accept any three elective credits without a business prerequisite',
    () {
      for (final id in ids.skip(2)) {
        expect(check(id, arts).academicPass, isTrue);
        expect(check(id, arts).aggregate, 36);
        expect(
          check(id, {...core, 'French': 1, 'History': 1}).academicPass,
          isFalse,
        );
        expect(check(id, {...arts, 'French': 7}).academicPass, isFalse);
      }
    },
  );
  test(
    'Social Studies can replace Science but no elective can replace a failed core',
    () {
      final g = {
        ...arts,
        'Accounting': 6,
        'Economics': 6,
        'Integrated Science': 9,
        'Social Studies': 6,
      };
      for (final id in ids) {
        expect(check(id, g).academicPass, isTrue);
        expect(check(id, {...g, 'English Language': 7}).academicPass, isFalse);
        expect(
          check(id, {
            ...g,
            'Core Mathematics': 7,
            'Elective Mathematics': 1,
          }).academicPass,
          isFalse,
        );
        expect(check(id, {...g, 'Social Studies': 7}).academicPass, isFalse);
        final missing = {...g}..remove('English Language');
        expect(check(id, missing).academicPass, isFalse);
      }
    },
  );
  test(
    '1536 independently derived combinations enforce programme subjects and quarantine',
    () {
      const pool = [
        'Accounting',
        'Cost Accounting',
        'Business Management',
        'Economics',
        'Elective Mathematics',
        'Physics',
        'Chemistry',
        'Biology',
        'French',
        'History',
        'Government',
        'Literature in English',
        'Textiles',
        'Geography',
        'Music',
        'Food and Nutrition',
        'Technical Drawing',
      ];
      final random = Random(281029);
      for (final id in ids) {
        for (var n = 0; n < 256; n++) {
          final choices = [...pool]..shuffle(random);
          final g = {
            for (final c in coreSubjects) c: 1 + random.nextInt(9),
            for (final e in n.isEven ? pool : choices.take(4))
              e: 1 + random.nextInt(9),
          };
          bool credit(String s) => (g[s] ?? 99) <= 6;
          final corePass =
              credit('English Language') &&
              credit('Core Mathematics') &&
              (credit('Integrated Science') || credit('Social Studies'));
          final subjectPass =
              pool.where(credit).length >= 3 &&
              switch (id) {
                'accounting' => credit('Accounting'),
                'finance' =>
                  credit('Economics') || credit('Elective Mathematics'),
                _ => true,
              };
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
