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
  final added = store.rules
      .where((r) => r.id.startsWith('northern-health-20261103-'))
      .toList();
  final now = DateTime(2026, 11, 3, 12);
  Map<String, int> science([int n = 6]) => {
    for (final s in [
      ...coreSubjects,
      'Biology',
      'Chemistry',
      'Physics',
      'Elective Mathematics',
    ])
      s: n,
  };
  test(
    'three unique Northern health programmes validate with frozen evidence',
    () {
      expect(store.rules, hasLength(599));
      expect(added, hasLength(3));
      expect(
        store.rules.where((r) => r.data['scope'] == 'programme'),
        hasLength(542),
      );
      for (final r in added) {
        expect(() => validateAdmissionRule(r), returnsNormally);
        expect(r.data['programmeRegions'], ['Northern']);
        expect(r.data['campus'], 'Tamale Campus');
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
    },
  );
  test(
    'all 505 previous requirements and dates stay byte-equivalent as JSON objects',
    () {
      final before =
          jsonDecode(
                File(
                  'data/northern-health-2026-11-03/admissions-before.json',
                ).readAsStringSync(),
              )['rules']
              as List;
      expect(before, hasLength(505));
      for (final r in before) {
        expect(store.rules.singleWhere((o) => o.id == r['id']).data, r);
      }
    },
  );
  test(
    'both Biology and Chemistry are mandatory counted electives with either third science',
    () {
      for (final r in added) {
        for (final third in ['Physics', 'Elective Mathematics']) {
          final g = {
            for (final s in coreSubjects) s: 6,
            'Biology': 6,
            'Chemistry': 6,
            third: 6,
          };
          final a = assessPathway(r, g, now: now);
          expect(a.academicPass, isTrue);
          expect(a.aggregate, 36);
          expect(a.countedSubjects, hasLength(6));
        }
        for (final required in ['Biology', 'Chemistry']) {
          final g = science(1)..remove(required);
          expect(assessPathway(r, g, now: now).academicPass, isFalse);
          for (final bad in [7, 8, 9]) {
            expect(
              assessPathway(r, {
                ...science(1),
                required: bad,
              }, now: now).academicPass,
              isFalse,
            );
          }
        }
      }
    },
  );
  test(
    'missing core results and Social Studies cannot conceal failing Integrated Science',
    () {
      for (final r in added) {
        expect(assessPathway(r, {}, now: now).academicPass, isFalse);
        for (final core in [
          'English Language',
          'Core Mathematics',
          'Integrated Science',
        ]) {
          expect(
            assessPathway(r, science(1)..remove(core), now: now).academicPass,
            isFalse,
          );
          expect(
            assessPathway(r, {...science(1), core: 7}, now: now).academicPass,
            isFalse,
          );
        }
        expect(
          assessPathway(r, {
            ...science(1),
            'Integrated Science': 9,
            'Social Studies': 1,
          }, now: now).academicPass,
          isFalse,
        );
      }
    },
  );
  test(
    'published competitive figures stay separate from academic minima and an admission offer',
    () {
      for (final r in added) {
        final cutoff = r.data['competitiveCutoff'] as Map;
        expect(cutoff['cycle'], isNull);
        expect(cutoff['status'], 'cycle_unconfirmed');
        expect(cutoff['value'], r.id.endsWith('medical-laboratory') ? 12 : 14);
        expect(assessPathway(r, science(), now: now).academicPass, isTrue);
        final conditions = (r.data['additionalConditions'] as List).join(' ');
        expect(conditions, contains('entrance examination and interview'));
        expect(conditions, contains('has passed'));
      }
    },
  );
  test(
    'Home Economics consideration cannot become an automatic science-route approval',
    () {
      for (final r in added) {
        final g = {
          for (final s in coreSubjects) s: 1,
          'Food and Nutrition': 1,
          'Management in Living': 1,
          'Biology': 1,
          'Economics': 1,
        };
        expect(assessPathway(r, g, now: now).academicPass, isFalse);
        if (!r.id.endsWith('medical-laboratory')) {
          expect(
            (r.data['electiveRoutes'] as List).last['confirmation'],
            contains('not approved automatically'),
          );
        }
      }
    },
  );
  test(
    '6144 seeded independent grade cases preserve required subjects and best-six arithmetic',
    () {
      final random = Random(3112026);
      for (final r in added) {
        for (var n = 0; n < 2048; n++) {
          final g = {
            for (final s in [
              ...coreSubjects,
              'Biology',
              'Chemistry',
              'Physics',
              'Elective Mathematics',
              'Food and Nutrition',
              'Government',
            ])
              s: 1 + random.nextInt(9),
          };
          final third = min(g['Physics']!, g['Elective Mathematics']!);
          final valid =
              [
                'English Language',
                'Core Mathematics',
                'Integrated Science',
                'Biology',
                'Chemistry',
              ].every((s) => g[s]! <= 6) &&
              third <= 6;
          final a = assessPathway(r, g, now: now);
          expect(a.academicPass, valid, reason: '${r.id} case $n');
          if (valid) {
            expect(
              a.aggregate,
              g['English Language']! +
                  g['Core Mathematics']! +
                  g['Integrated Science']! +
                  g['Biology']! +
                  g['Chemistry']! +
                  third,
            );
            expect(a.countedSubjects, hasLength(6));
          }
        }
      }
    },
  );
  test(
    'source holds, stale evidence and canonical disputes cannot approve even all A1s',
    () {
      for (final r in added) {
        expect(
          assessPathway(
            AdmissionRule({...r.data, 'status': 'needs_source_review'}),
            science(1),
            now: now,
          ).academicPass,
          isFalse,
        );
        expect(
          assessPathway(r, science(1), now: DateTime(2027, 11, 3)).academicPass,
          isFalse,
        );
      }
      final all = {
        for (final s in [...coreSubjects, ...electiveSubjects]) s: 1,
      };
      for (final id in [
        'technical-20261028-ktu-computer-science',
        'private-20261028-presby-pa',
      ]) {
        expect(
          assessPathway(
            store.rules.singleWhere((r) => r.id == id),
            all,
            now: now,
          ).academicPass,
          isFalse,
        );
      }
    },
  );
}
