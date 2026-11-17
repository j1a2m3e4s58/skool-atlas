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
  const ids = [
    'geological',
    'environmental-engineering',
    'economics',
    'medical-imaging',
    'accounting',
    'business-information',
  ];
  AdmissionRule rule(String id) =>
      store.rules.singleWhere((r) => r.id == 'uds-prof-20261028-$id');
  MatchAssessment check(String id, Map<String, int> g) =>
      assessPathway(rule(id), g, now: now);
  final cores = {for (final c in coreSubjects) c: 6};
  test(
    'six source-backed unique records preserve intake and route distinctions',
    () {
      expect(store.rules, hasLength(599));
      for (final id in ids) {
        final r = rule(id);
        expect(() => validateAdmissionRule(r), returnsNormally);
        expect(r.data['competitiveCutoff'], isNull);
        expect(r.data['cycle'], contains('not stated'));
        expect(
          store.rules.where(
            (o) => o.institution == r.institution && o.programme == r.programme,
          ),
          hasLength(1),
        );
        expect(
          (r.data['sourceEvidence'] as Map)['captureSha256'],
          hasLength(64),
        );
      }
      for (final id in [
        'geological',
        'environmental-engineering',
        'medical-imaging',
      ]) {
        expect(rule(id).data['maxAggregate'], isNull);
      }
      expect(
        rule('medical-imaging').data['additionalConditions'].join(' '),
        contains('interview'),
      );
    },
  );
  test(
    'Geological requires and counts Maths even with stronger alternate electives',
    () {
      final g = {
        ...cores,
        'Elective Mathematics': 6,
        'Geography': 1,
        'Physics': 1,
        'Chemistry': 1,
      };
      final a = check('geological', g);
      expect(a.academicPass, isTrue);
      expect(a.countedSubjects['Elective Mathematics'], 6);
      expect(
        check('geological', {...g, 'Elective Mathematics': 7}).academicPass,
        isFalse,
      );
      expect(
        check('geological', {
          ...cores,
          'Elective Mathematics': 6,
          'Applied Electricity': 6,
          'Geography': 6,
        }).academicPass,
        isTrue,
      );
      expect(
        check('geological', {
          ...cores,
          'Elective Mathematics': 1,
          'Government': 1,
          'History': 1,
        }).academicPass,
        isFalse,
      );
    },
  );
  test(
    'Environmental permits named Agriculture science route and rejects arts substitution',
    () {
      expect(
        check('environmental-engineering', {
          ...cores,
          'Agricultural Science': 6,
          'Biology': 6,
          'Chemistry': 6,
        }).academicPass,
        isTrue,
      );
      expect(
        check('environmental-engineering', {
          ...cores,
          'Geography': 1,
          'Economics': 1,
          'Government': 1,
        }).academicPass,
        isFalse,
      );
    },
  );
  test(
    'Medical Imaging requires Biology and Physics and excludes Social core replacement',
    () {
      final g = {
        ...cores,
        'Biology': 6,
        'Physics': 6,
        'Elective Mathematics': 6,
      };
      expect(check('medical-imaging', g).academicPass, isTrue);
      for (final missing in ['Biology', 'Physics', 'Integrated Science']) {
        expect(
          check('medical-imaging', {
            ...g,
            missing: 7,
            'Chemistry': 1,
            'Social Studies': 1,
          }).academicPass,
          isFalse,
        );
      }
    },
  );
  test(
    'Economics and business accept published Social core and three Arts credits at 36',
    () {
      for (final id in ['economics', 'accounting', 'business-information']) {
        final g = {
          ...cores,
          'Integrated Science': 9,
          'Social Studies': 6,
          'Government': 6,
          'History': 6,
          'Geography': 6,
        };
        expect(check(id, g).academicPass, isTrue);
        expect(check(id, g).aggregate, 36);
        expect(check(id, {...g, 'English Language': 7}).academicPass, isFalse);
        expect(check(id, {...g, 'Geography': 7}).academicPass, isFalse);
      }
    },
  );
  test(
    '3072 seeded independent subject-credit oracles and evidence quarantine checks',
    () {
      final random = Random(281026);
      const subjects = [
        'Biology',
        'Physics',
        'Chemistry',
        'Elective Mathematics',
        'Agricultural Science',
        'Geography',
        'Applied Electricity',
        'Economics',
        'Government',
        'History',
      ];
      for (final id in ids) {
        for (var n = 0; n < 512; n++) {
          final g = {
            for (final c in coreSubjects) c: 1 + random.nextInt(9),
            for (final s in subjects) s: 1 + random.nextInt(9),
          };
          bool credit(String s) => (g[s] ?? 9) <= 6;
          final social = [
            'economics',
            'accounting',
            'business-information',
          ].contains(id);
          final corePass =
              credit('English Language') &&
              credit('Core Mathematics') &&
              (credit('Integrated Science') ||
                  (social && credit('Social Studies')));
          final electivePass = switch (id) {
            'geological' =>
              credit('Elective Mathematics') &&
                  [
                        'Physics',
                        'Chemistry',
                        'Geography',
                        'Applied Electricity',
                      ].where(credit).length >=
                      2,
            'environmental-engineering' =>
              [
                    'Biology',
                    'Physics',
                    'Chemistry',
                    'Elective Mathematics',
                    'Agricultural Science',
                  ].where(credit).length >=
                  3,
            'medical-imaging' =>
              credit('Biology') &&
                  credit('Physics') &&
                  (credit('Chemistry') || credit('Elective Mathematics')),
            _ => subjects.where(credit).length >= 3,
          };
          final a = check(id, g);
          expect(
            a.academicPass,
            corePass && electivePass,
            reason: '$id case $n',
          );
          if (a.academicPass) {
            expect(a.countedSubjects, hasLength(6));
            expect(a.countedSubjects.values.every((v) => v <= 6), isTrue);
            expect(
              a.aggregate,
              a.countedSubjects.values.reduce((a, b) => a + b),
            );
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
          expect(
            assessPathway(
              rule(id),
              g,
              now: DateTime(2027, 10, 28),
            ).academicPass,
            isFalse,
          );
        }
      }
    },
  );
}
