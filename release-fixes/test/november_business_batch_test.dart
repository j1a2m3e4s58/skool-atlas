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
  final now = DateTime(2026, 11, 1, 12);
  final rules = store.rules
      .where((r) => r.id.startsWith('november-20261101-'))
      .toList();
  Map<String, int> cores([int n = 6]) => {for (final s in coreSubjects) s: n};
  test(
    'six unique City Campus programmes validate with frozen evidence and dated closed-intake warning',
    () {
      expect(store.rules, hasLength(600));
      expect(rules, hasLength(6));
      expect(
        store.rules.where((r) => r.data['scope'] == 'programme'),
        hasLength(542),
      );
      for (final r in rules) {
        expect(() => validateAdmissionRule(r), returnsNormally);
        expect(r.data['campus'], 'City Campus, Tamale');
        expect(r.data['programmeRegions'], ['Northern']);
        expect(r.data['checkedAt'], '2026-11-01');
        expect(r.data['cycle'], '2026/2027');
        expect(
          (r.data['sourceEvidence'] as Map)['captureSha256'],
          hasLength(64),
        );
        expect(
          r.data['additionalConditions'].join(' '),
          contains('has passed'),
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
    'Arts, Business, Visual Arts, Science, Home Economics and Agriculture combinations pass without invented prerequisites',
    () {
      const areas = [
        ['Government', 'History', 'French'],
        ['Accounting', 'Business Management', 'Economics'],
        ['General Knowledge in Art', 'Graphic Design', 'Ceramics'],
        ['Physics', 'Chemistry', 'Biology'],
        ['Food and Nutrition', 'Management in Living', 'Clothing and Textiles'],
        [
          'Agricultural Science',
          'Animal Husbandry',
          'Crop Husbandry and Horticulture',
        ],
      ];
      for (final r in rules) {
        for (final group in areas) {
          final g = {...cores(), for (final s in group) s: 6};
          final a = assessPathway(r, g, now: now);
          expect(a.academicPass, isTrue, reason: '${r.id} $group');
          expect(a.aggregate, 36);
          expect(a.countedSubjects, hasLength(6));
          expect(
            assessPathway(r, {
              ...g,
              'Integrated Science': 9,
            }, now: now).academicPass,
            isTrue,
          );
          expect(
            assessPathway(r, {
              ...g,
              'Social Studies': 9,
            }, now: now).academicPass,
            isTrue,
          );
        }
      }
    },
  );
  test(
    'D7/E8/F9 credits, missing electives and unverified technical combinations cannot approve',
    () {
      for (final r in rules) {
        final g = {...cores(), 'Government': 6, 'History': 6, 'French': 6};
        for (final bad in [7, 8, 9]) {
          for (final subject in [
            'English Language',
            'Core Mathematics',
            'French',
          ]) {
            expect(
              assessPathway(r, {...g, subject: bad}, now: now).academicPass,
              isFalse,
            );
          }
          expect(
            assessPathway(r, {
              ...g,
              'Integrated Science': bad,
              'Social Studies': bad,
            }, now: now).academicPass,
            isFalse,
          );
        }
        expect(
          assessPathway(r, {...g}..remove('French'), now: now).academicPass,
          isFalse,
        );
        expect(assessPathway(r, {}, now: now).academicPass, isFalse);
        expect(
          assessPathway(r, {
            ...cores(1),
            'Auto Mechanics': 1,
            'Metalwork': 1,
            'Building Construction': 1,
          }, now: now).academicPass,
          isFalse,
        );
      }
    },
  );
  test(
    'changed, unavailable, future and stale evidence never approves even all A1 results',
    () {
      final g = {...cores(1), 'Government': 1, 'History': 1, 'French': 1};
      for (final r in rules) {
        expect(
          assessPathway(
            AdmissionRule({...r.data, 'status': 'needs_source_review'}),
            g,
            now: now,
          ).academicPass,
          isFalse,
        );
        expect(
          assessPathway(r, g, now: DateTime(2026, 10, 31)).academicPass,
          isFalse,
        );
        expect(
          assessPathway(r, g, now: DateTime(2027, 11, 1)).academicPass,
          isFalse,
        );
      }
    },
  );
  test(
    'published June 2026 deadline is past and cannot look like an open application',
    () {
      final row = Map<String, dynamic>.from(
      (store.journey.resources['deadlines'] as List).singleWhere(
          (r) => r['id'] == 'uds-undergraduate-2026',
        ),
      );
      expect(row['date'], '2026-06-30');
      expect(DateTime.parse(row['date']).isBefore(now), isTrue);
      expect(row['note'], contains('does not mean applications are open'));
    },
  );
  test(
    '3072 seeded independent grade cases preserve best core alternative, three electives, six distinct grades and source holds',
    () {
      final random = Random(20261101);
      const electives = [
        'Government',
        'History',
        'French',
        'Physics',
        'Chemistry',
        'Accounting',
        'Graphic Design',
        'Food and Nutrition',
        'Auto Mechanics',
      ];
      for (final r in rules) {
        for (var n = 0; n < 512; n++) {
          final g = {
            for (final s in [...coreSubjects, ...electives])
              s: 1 + random.nextInt(9),
          };
          final accepted =
              electives
                  .where((s) => s != 'Auto Mechanics' && g[s]! <= 6)
                  .map((s) => g[s]!)
                  .toList()
                ..sort();
          final alternative = min(
            g['Integrated Science']!,
            g['Social Studies']!,
          );
          final expected =
              g['English Language']! <= 6 &&
              g['Core Mathematics']! <= 6 &&
              alternative <= 6 &&
              accepted.length >= 3;
          final a = assessPathway(r, g, now: now);
          expect(a.academicPass, expected, reason: '${r.id} case $n');
          if (expected) {
            expect(
              a.aggregate,
              g['English Language']! +
                  g['Core Mathematics']! +
                  alternative +
                  accepted.take(3).reduce((a, b) => a + b),
            );
            expect(a.countedSubjects, hasLength(6));
            expect(a.countedSubjects.values.every((v) => v <= 6), isTrue);
          }
        }
      }
    },
  );
}
