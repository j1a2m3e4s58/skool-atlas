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
  final now = DateTime(2026, 10, 28, 23);
  const ids = [
    'biotechnology',
    'microbiology',
    'biochemistry',
    'biological-science',
    'forensic-science',
  ];
  AdmissionRule rule(String id) =>
      store.rules.singleWhere((r) => r.id == 'northern-science-20261028-$id');
  MatchAssessment check(String id, Map<String, int> g) =>
      assessPathway(rule(id), g, now: now);
  final cores = {for (final c in coreSubjects) c: 6};
  test(
    'five unique programme records validate and preserve source and Northern campus',
    () {
      expect(store.rules, hasLength(600));
      expect(
        store.rules.where((r) => r.data['scope'] == 'programme'),
        hasLength(542),
      );
      for (final id in ids) {
        final r = rule(id);
        expect(() => validateAdmissionRule(r), returnsNormally);
        expect(r.data['campus'], 'Nyankpala Campus');
        expect(r.data['programmeRegions'], ['Northern']);
        expect(
          (r.data['sourceEvidence'] as Map)['captureSha256'],
          hasLength(64),
        );
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
    'Biotechnology requires Physics and does not borrow Mathematics substitution from Microbiology',
    () {
      final g = {
        ...cores,
        'Biology': 6,
        'Chemistry': 6,
        'Physics': 6,
        'Elective Mathematics': 1,
      };
      expect(check('biotechnology', g).academicPass, isTrue);
      expect(check('biotechnology', g).countedSubjects['Physics'], 6);
      expect(
        check('biotechnology', {...g, 'Physics': 7}).academicPass,
        isFalse,
      );
      expect(check('microbiology', {...g, 'Physics': 7}).academicPass, isTrue);
      for (final subject in ['Biology', 'Chemistry']) {
        expect(check('microbiology', {...g, subject: 7}).academicPass, isFalse);
      }
    },
  );
  test(
    'Biochemistry follows its named electives rather than inventing compulsory Biology or Chemistry',
    () {
      expect(
        check('biochemistry', {
          ...cores,
          'Geography': 6,
          'Agricultural Science': 6,
          'Elective Mathematics': 6,
        }).academicPass,
        isTrue,
      );
      expect(
        check('biochemistry', {
          ...cores,
          'Government': 1,
          'History': 1,
          'Economics': 1,
        }).academicPass,
        isFalse,
      );
      for (final id in ids.take(4)) {
        expect(
          check(id, {
            ...cores,
            'Integrated Science': 7,
            'Social Studies': 1,
            'Biology': 1,
            'Chemistry': 1,
            'Physics': 1,
          }).academicPass,
          isFalse,
        );
      }
    },
  );
  test(
    'Biological Science retains Biology and aggregate 18 boundary; Microbiology undated 15 is not current',
    () {
      final g = {
        for (final c in coreSubjects) c: 3,
        'Biology': 3,
        'Chemistry': 3,
        'Physics': 3,
      };
      final a = check('biological-science', g);
      expect(a.academicPass, isTrue);
      expect(a.aggregate, 18);
      expect(
        check('biological-science', {...g, 'Physics': 4}).academicPass,
        isFalse,
      );
      expect(
        check('biological-science', {
          ...g,
          'Biology': 7,
          'Elective Mathematics': 1,
        }).academicPass,
        isFalse,
      );
      final m = check('microbiology', {
        ...cores,
        'Biology': 6,
        'Chemistry': 6,
        'Physics': 6,
      });
      expect(m.academicPass, isTrue);
      expect(m.aggregate, 36);
      expect(
        assessCutoff(
          rule('microbiology'),
          6,
          academicPass: true,
          targetCycle: '2026/2027',
          now: now,
        ).status,
        'Cutoff needs verification',
      );
      expect(
        (rule('microbiology').data['competitiveCutoff'] as Map)['status'],
        'cycle_unconfirmed',
      );
    },
  );
  test(
    'Forensic ambiguous three-of-five wording never becomes a confirmed academic pass',
    () {
      final g = {
        for (final c in coreSubjects) c: 1,
        'Physics': 1,
        'Chemistry': 1,
        'Biology': 1,
        'Agricultural Science': 1,
        'Elective Mathematics': 1,
      };
      expect(check('forensic-science', g).academicPass, isFalse);
      expect(
        check('forensic-science', g).status,
        'Additional route information needed',
      );
      expect(
        check('forensic-science', {...g, 'Integrated Science': 9}).academicPass,
        isFalse,
      );
      expect(rule('forensic-science').data['scienceOrSocial'], [
        'Integrated Science',
        'Social Studies',
      ]);
    },
  );
  test(
    '2560 independent scenarios preserve mandatory subjects, best permitted aggregate and evidence quarantine',
    () {
      final random = Random(28261);
      const subjects = [
        'Biology',
        'Chemistry',
        'Physics',
        'Elective Mathematics',
        'Agricultural Science',
        'Geography',
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
          final corePass = [
            'English Language',
            'Core Mathematics',
            'Integrated Science',
          ].every(credit);
          final bool pass;
          switch (id) {
            case 'biotechnology':
              pass =
                  corePass && ['Biology', 'Chemistry', 'Physics'].every(credit);
            case 'microbiology':
              pass =
                  corePass &&
                  credit('Biology') &&
                  credit('Chemistry') &&
                  (credit('Physics') || credit('Elective Mathematics'));
            case 'biochemistry':
              pass = corePass && subjects.take(6).where(credit).length >= 3;
            case 'biological-science':
              final others = [
                'Chemistry',
                'Physics',
                'Elective Mathematics',
              ].where(credit).map((s) => g[s]!).toList()..sort();
              pass =
                  corePass &&
                  credit('Biology') &&
                  others.length >= 2 &&
                  g['English Language']! +
                          g['Core Mathematics']! +
                          g['Integrated Science']! +
                          g['Biology']! +
                          others[0] +
                          others[1] <=
                      18;
            default:
              pass = false;
          }
          final a = check(id, g);
          expect(a.academicPass, pass, reason: '$id case $n');
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
