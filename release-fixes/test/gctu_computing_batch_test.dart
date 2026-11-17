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
  final now = DateTime(2026, 10, 28, 14);
  AdmissionRule rule(String id) =>
      store.rules.singleWhere((r) => r.id == 'gctu-computing-20261028-$id');
  MatchAssessment check(String id, Map<String, int> g) =>
      assessPathway(rule(id), g, now: now);
  final cores = {for (final c in coreSubjects) c: 6};
  final mathsArts = {
    ...cores,
    'Elective Mathematics': 6,
    'Government': 6,
    'History': 6,
  };
  const ids = [
    'computer-science',
    'software-engineering',
    'cyber-security',
    'information-systems',
    'web-development',
    'data-science',
  ];

  test(
    'six GCTU routes validate with their own faculty sources and dated intake',
    () {
      expect(store.rules, hasLength(600));
      expect(
        store.rules.where((r) => r.data['scope'] == 'programme'),
        hasLength(542),
      );
      for (final id in ids) {
        final r = rule(id);
        expect(() => validateAdmissionRule(r), returnsNormally);
        expect(r.data['institutionId'], 'gtec:672');
        expect(r.data['cycle'], '2026/2027');
        expect(r.data['sourceUrl'], startsWith('https://focis.gctu.edu.gh/'));
        expect(
          r.data['generalSourceUrl'],
          'https://site.gctu.edu.gh/2026-2027-admissions',
        );
        expect(r.data['competitiveCutoff'], isNull);
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
    'CS and Software require Elective Mathematics without inventing Physics',
    () {
      for (final id in ['computer-science', 'software-engineering']) {
        expect(check(id, mathsArts).academicPass, isTrue);
        expect(check(id, mathsArts).aggregate, 36);
        expect(
          check(id, {
            ...mathsArts,
            'Elective Mathematics': 7,
            'French': 1,
          }).academicPass,
          isFalse,
        );
        expect(
          check(id, {
            ...mathsArts,
            'Integrated Science': 7,
            'Social Studies': 1,
          }).academicPass,
          isFalse,
        );
      }
      expect(check('cyber-security', mathsArts).academicPass, isFalse);
      expect(
        check('cyber-security', {...mathsArts, 'Physics': 6}).academicPass,
        isTrue,
      );
      expect(
        check('cyber-security', {
          ...mathsArts,
          'Physics': 7,
          'Chemistry': 1,
        }).academicPass,
        isFalse,
      );
    },
  );
  test(
    'Information Systems permits Social Studies; Web requires Science without Elective Mathematics',
    () {
      final arts = {
        ...cores,
        'Integrated Science': 9,
        'Social Studies': 6,
        'Government': 6,
        'History': 6,
        'French': 6,
      };
      expect(check('information-systems', arts).academicPass, isTrue);
      expect(check('web-development', arts).academicPass, isFalse);
      expect(
        check('web-development', {
          ...arts,
          'Integrated Science': 6,
        }).academicPass,
        isTrue,
      );
      expect(
        check('web-development', {
          ...arts,
          'Integrated Science': 6,
          'English Language': 7,
        }).academicPass,
        isFalse,
      );
    },
  );
  test(
    'undefined Data Science combination cannot pass even with high science grades',
    () {
      final g = {
        ...cores,
        'Elective Mathematics': 1,
        'Physics': 1,
        'Chemistry': 1,
      };
      expect(check('data-science', g).academicPass, isFalse);
      expect(
        check('data-science', g).status,
        'Additional route information needed',
      );
    },
  );
  test(
    'awaiting results, combined sittings and changed sources do not become admission approval',
    () {
      final cs = rule('computer-science');
      final predicted = assessPathway(
        cs,
        mathsArts,
        now: now,
        resultBasis: 'Predicted results',
      );
      expect(predicted.status, 'Provisional academic minimum met');
      expect(
        predicted.cutoff.status,
        'Predicted results · no confirmed cutoff match',
      );
      expect(
        assessPathway(cs, mathsArts, now: now, sittings: 2).academicPass,
        isFalse,
      );
      expect(
        assessPathway(
          AdmissionRule({...cs.data, 'status': 'needs_source_review'}),
          mathsArts,
          now: now,
        ).academicPass,
        isFalse,
      );
    },
  );
  test(
    '1536 independent grade cases preserve exact compulsory subjects, arithmetic and quarantine',
    () {
      final random = Random(281007);
      for (final id in ids) {
        for (var n = 0; n < 256; n++) {
          final electives = [...electiveSubjects]..shuffle(random);
          final choices = n.isEven
              ? ['Elective Mathematics', 'Physics', 'Government', 'History']
              : electives.take(4);
          final g = {
            for (final c in coreSubjects) c: 1 + random.nextInt(9),
            for (final e in choices) e: 1 + random.nextInt(9),
          };
          bool credit(String s) => (g[s] ?? 99) <= 6;
          final corePass =
              credit('English Language') &&
              credit('Core Mathematics') &&
              (id == 'information-systems'
                  ? (credit('Integrated Science') || credit('Social Studies'))
                  : credit('Integrated Science'));
          final enough = electiveSubjects.where(credit).length >= 3;
          final mathRequired = [
            'computer-science',
            'software-engineering',
            'cyber-security',
          ].contains(id);
          final languageConflict =
              g.containsKey('Ghanaian Language') &&
              const [
                'Dagaare',
                'Dagbani',
                'Dangme',
                'Ewe',
                'Ga',
                'Gonja',
                'Kasem',
                'Nzema',
                'Twi (Akuapem)',
                'Twi (Asante)',
              ].any(g.containsKey);
          final expected =
              !languageConflict &&
              id != 'data-science' &&
              corePass &&
              enough &&
              (!mathRequired || credit('Elective Mathematics')) &&
              (id != 'cyber-security' || credit('Physics'));
          final a = check(id, g);
          expect(
            a.academicPass,
            expected,
            reason: '$id case $n grades $g: ${a.status} ${a.reasons}',
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
