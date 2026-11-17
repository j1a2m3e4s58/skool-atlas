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
  final now = DateTime(2026, 10, 30, 22);
  AdmissionRule rule(String id) => store.rules.singleWhere((r) => r.id == id);
  MatchAssessment check(String id, Map<String, int> g) =>
      assessPathway(rule(id), g, now: now);
  const ids = [
    'four-region-20261030-applied-biology',
    'four-region-20261030-environmental-science',
  ];
  const science = [
    'Biology',
    'Physics',
    'Chemistry',
    'Agricultural Science',
    'Elective Mathematics',
  ];
  final cores = {for (final c in coreSubjects) c: 6};
  test(
    'two distinct Upper East programmes validate with current intake and exact evidence',
    () {
      expect(store.rules, hasLength(599));
      expect(
        store.rules.where((r) => r.data['scope'] == 'programme'),
        hasLength(542),
      );
      for (final id in ids) {
        final r = rule(id);
        expect(() => validateAdmissionRule(r), returnsNormally);
        expect(r.data['programmeRegions'], ['Upper East']);
        expect(r.data['campus'], 'Navrongo');
        expect(r.data['cycle'], '2026/2027');
        expect(r.data['checkedAt'], '2026-10-30');
        expect(
          (r.data['sourceEvidence'] as Map)['captureSha256'],
          hasLength(64),
        );
        expect(r.data['competitiveCutoff'], isNull);
        expect(
          store.rules.where(
            (o) => o.institution == r.institution && o.programme == r.programme,
          ),
          hasLength(1),
        );
      }
    },
  );
  test(
    'all ten three-of-five combinations pass at 36, without invented compulsory Biology',
    () {
      for (final id in ids) {
        for (var a = 0; a < 5; a++) {
          for (var b = a + 1; b < 5; b++) {
            for (var c = b + 1; c < 5; c++) {
              final result = check(id, {
                ...cores,
                science[a]: 6,
                science[b]: 6,
                science[c]: 6,
              });
              expect(result.academicPass, isTrue);
              expect(result.aggregate, 36);
            }
          }
        }
      }
    },
  );
  test(
    'regular entries cannot borrow Mature D7 allowance, Arts credits or disputed Social core',
    () {
      for (final id in ids) {
        final g = {
          ...cores,
          'Physics': 6,
          'Chemistry': 6,
          'Agricultural Science': 6,
        };
        for (final subject in [
          'English Language',
          'Core Mathematics',
          'Integrated Science',
          'Physics',
        ]) {
          for (final bad in [7, 8, 9]) {
            expect(
              check(id, {
                ...g,
                subject: bad,
                'Government': 1,
                'History': 1,
                'Social Studies': 1,
              }).academicPass,
              isFalse,
            );
          }
        }
        expect(
          check(id, {
            ...cores,
            'Government': 1,
            'History': 1,
            'Economics': 1,
          }).academicPass,
          isFalse,
        );
        expect(check(id, {}).academicPass, isFalse);
      }
      expect(rule(ids.first).data['note'], contains('Social Studies'));
    },
  );
  test(
    'Upper West category boundaries and diploma core allowance remain distinct from degree checks',
    () {
      const planning = 'regional-20261028-ubids-planning';
      const urban = 'regional-20261028-ubids-urban-design';
      const diploma = 'regional-20261028-ubids-urban-diploma';
      final g = {...cores, 'Geography': 6, 'Economics': 6, 'Accounting': 6};
      expect(check(planning, g).academicPass, isTrue);
      expect(
        check(planning, {
          ...cores,
          'Geography': 1,
          'Accounting': 1,
          'Business Management': 1,
        }).academicPass,
        isFalse,
      );
      expect(
        check(urban, {
          ...cores,
          'Technical Drawing': 6,
          'Building Construction': 6,
          'ICT': 6,
        }).academicPass,
        isTrue,
      );
      final d = {
        ...g,
        'English Language': 7,
        'Core Mathematics': 7,
        'Integrated Science': 7,
        'Social Studies': 7,
      };
      expect(check(diploma, d).academicPass, isTrue);
      expect(check(diploma, d).aggregate, 39);
      expect(check(planning, d).academicPass, isFalse);
      expect(
        check(diploma, {...d, 'English Language': 8}).academicPass,
        isFalse,
      );
      expect(
        check(diploma, {
          ...cores,
          'Geography': 1,
          'Accounting': 1,
          'ICT': 1,
        }).academicPass,
        isFalse,
      );
    },
  );
  test(
    'North East and Savannah catalogue profiles do not create invented grade approvals',
    () {
      final g = {
        for (final c in coreSubjects) c: 1,
        for (final e in electiveSubjects) e: 1,
      };
      for (final id in ['nmc:110', 'gtec:805', 'gtec:905', 'gtec:979']) {
        final candidates = store.rules.where(
          (r) =>
              r.data['institutionId'] == id && r.data['scope'] == 'programme',
        );
        expect(
          candidates.where((r) => assessPathway(r, g, now: now).academicPass),
          isEmpty,
        );
      }
    },
  );
  test(
    '2304 independent region-specific grade cases preserve published categories, grades and quarantine',
    () {
      final random = Random(301026);
      for (final id in ids) {
        for (var n = 0; n < 768; n++) {
          final g = {
            for (final c in coreSubjects) c: 1 + random.nextInt(9),
            for (final s in [...science, 'Government', 'History', 'Accounting'])
              s: 1 + random.nextInt(9),
          };
          final expected =
              [
                'English Language',
                'Core Mathematics',
                'Integrated Science',
              ].every((s) => g[s]! <= 6) &&
              science.where((s) => g[s]! <= 6).length >= 3;
          final result = check(id, g);
          expect(result.academicPass, expected, reason: '$id case $n');
          if (result.academicPass) {
            expect(result.countedSubjects, hasLength(6));
            expect(result.countedSubjects.values.every((v) => v <= 6), isTrue);
            expect(
              result.aggregate,
              result.countedSubjects.values.reduce((a, b) => a + b),
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
              now: DateTime(2027, 10, 30),
            ).academicPass,
            isFalse,
          );
        }
      }
      const a = [
        'Geography',
        'Economics',
        'Government',
        'History',
        'Elective Mathematics',
        'Literature in English',
        'French',
        'Physics',
        'Chemistry',
        'Biology',
      ];
      const b = ['Accounting', 'Business Management'];
      const arts = [
        'Geography',
        'Economics',
        'Government',
        'History',
        'Elective Mathematics',
        'ICT',
      ];
      const technical = [
        'Technical Drawing',
        'Building Construction',
        'Elective Mathematics',
        'ICT',
      ];
      const da = [
        'Geography',
        'Economics',
        'Elective Mathematics',
        'Government',
        'History',
        'Graphic Design',
        'Technical Drawing',
        'Building Construction',
        'Business Management',
        'General Knowledge in Art',
      ];
      const db = [
        'Accounting',
        'Picture Making',
        'Ceramics',
        'Sculpture',
        'Literature in English',
        'ICT',
      ];
      for (final id in [
        'regional-20261028-ubids-planning',
        'regional-20261028-ubids-urban-design',
        'regional-20261028-ubids-urban-diploma',
      ]) {
        for (var n = 0; n < 256; n++) {
          final g = {
            for (final c in coreSubjects) c: 1 + random.nextInt(9),
            for (final s in {...a, ...b, ...arts, ...technical, ...da, ...db})
              s: 1 + random.nextInt(9),
          };
          bool credit(String s) => g[s]! <= 6;
          final bool expected;
          if (id.endsWith('planning')) {
            expected =
                [
                  'English Language',
                  'Core Mathematics',
                  'Integrated Science',
                ].every(credit) &&
                a.where(credit).length >= 2 &&
                [...a, ...b].where(credit).length >= 3;
          } else if (id.endsWith('urban-design')) {
            expected =
                [
                  'English Language',
                  'Core Mathematics',
                  'Integrated Science',
                ].every(credit) &&
                (arts.where(credit).length >= 3 ||
                    technical.where(credit).length >= 3);
          } else {
            expected =
                g['English Language']! <= 7 &&
                g['Core Mathematics']! <= 7 &&
                (g['Integrated Science']! <= 7 || g['Social Studies']! <= 7) &&
                da.where(credit).length >= 2 &&
                [...da, ...db].where(credit).length >= 3;
          }
          final result = check(id, g);
          expect(result.academicPass, expected, reason: '$id case $n');
        }
      }
    },
  );
}
