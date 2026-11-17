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
  final now = DateTime(2026, 10, 28, 15);
  const sci = ['Biology', 'Chemistry', 'Physics', 'Elective Mathematics'];
  const definite = [
    'biochemistry',
    'environmental-science',
    'forensic-science',
    'conservation-biology-and-entomology',
    'laboratory-technology',
  ];
  AdmissionRule rule(String id) =>
      store.rules.singleWhere((r) => r.id == 'ucc-bio-20261028-$id');
  MatchAssessment check(String id, Map<String, int> g) =>
      assessPathway(rule(id), g, now: now);
  final core = {for (final c in coreSubjects) c: 6};
  test(
    'six UCC bioscience records validate with exact identity and retained sources',
    () {
      expect(store.rules, hasLength(599));
      expect(
        store.rules.where((r) => r.data['scope'] == 'programme'),
        hasLength(542),
      );
      final batch = store.rules
          .where((r) => r.id.startsWith('ucc-bio-20261028-'))
          .toList();
      expect(batch, hasLength(6));
      for (final r in batch) {
        expect(() => validateAdmissionRule(r), returnsNormally);
        expect(r.data['institutionId'], 'gtec:878');
        expect(r.data['competitiveCutoff'], isNull);
        expect(
          (r.data['sourceEvidence'] as Map)['captureSha256'],
          hasLength(64),
        );
      }
    },
  );
  test('all four three-of-four science combinations pass at aggregate 36', () {
    for (final id in definite) {
      for (final omitted in sci) {
        final g = {
          ...core,
          for (final s in sci.where((s) => s != omitted)) s: 6,
        };
        expect(
          check(id, g).academicPass,
          isTrue,
          reason: '$id without $omitted',
        );
        expect(check(id, g).aggregate, 36);
        expect(
          check(id, {
            ...g,
            'Integrated Science': 7,
            'Social Studies': 1,
          }).academicPass,
          isFalse,
        );
        expect(check(id, {...g, 'Core Mathematics': 7}).academicPass, isFalse);
      }
    }
  });
  test(
    'unrelated excellent electives cannot replace required science credits',
    () {
      final g = {
        ...core,
        'Biology': 6,
        'Chemistry': 6,
        'Government': 1,
        'History': 1,
      };
      for (final id in definite.where((id) => id != 'laboratory-technology')) {
        expect(check(id, g).academicPass, isFalse, reason: id);
      }
      expect(check('laboratory-technology', g).academicPass, isFalse);
      expect(
        check('laboratory-technology', g).status,
        'Additional route information needed',
      );
    },
  );
  test(
    'undefined molecular core combination stays conditional even with all A1 results',
    () {
      final g = {for (final c in coreSubjects) c: 1, for (final s in sci) s: 1};
      expect(
        check('molecular-biology-and-biotechnology', g).academicPass,
        isFalse,
      );
      expect(
        check('molecular-biology-and-biotechnology', g).status,
        'Additional route information needed',
      );
      expect(
        check('molecular-biology-and-biotechnology', {
          ...g,
          'Integrated Science': 9,
          'Social Studies': 1,
        }).status,
        'Additional route information needed',
      );
    },
  );
  test(
    'a new year or repeated source polling does not silently renew old evidence',
    () {
      final g = {...core, 'Biology': 1, 'Chemistry': 1, 'Physics': 1};
      final r = rule('forensic-science');
      expect(
        assessPathway(r, g, now: DateTime(2027, 10, 28)).academicPass,
        isFalse,
      );
      expect(r.data['checkedAt'], '2026-10-28');
      expect(
        assessPathway(
          AdmissionRule({...r.data, 'status': 'needs_source_review'}),
          g,
          now: now,
        ).academicPass,
        isFalse,
      );
    },
  );
  test(
    '1536 independent grade cases preserve science combinations and source quarantine',
    () {
      final random = Random(281008);
      for (final id in [...definite, 'molecular-biology-and-biotechnology']) {
        for (var n = 0; n < 256; n++) {
          final g = {
            for (final c in coreSubjects) c: 1 + random.nextInt(9),
            for (final e in sci) e: 1 + random.nextInt(9),
            'Government': 1,
            'History': 1,
          };
          bool credit(String s) => (g[s] ?? 99) <= 6;
          final expected =
              id != 'molecular-biology-and-biotechnology' &&
              [
                'English Language',
                'Core Mathematics',
                'Integrated Science',
              ].every(credit) &&
              sci.where(credit).length >= 3;
          final a = check(id, g);
          expect(a.academicPass, expected, reason: '$id case $n');
          if (a.academicPass) {
            expect(a.countedSubjects, hasLength(6));
            expect(
              a.aggregate,
              a.countedSubjects.values.reduce((a, b) => a + b),
            );
            expect(
              a.countedSubjects.keys.where(
                (s) => s == 'Government' || s == 'History',
              ),
              isEmpty,
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
        }
      }
    },
  );
}
