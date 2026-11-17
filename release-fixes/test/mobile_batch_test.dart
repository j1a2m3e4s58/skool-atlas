import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:skoolatlas/tertiary_data.dart';

void main() {
  final s = TertiaryStore()
    ..applyFeed(
      Map<String, dynamic>.from(
        jsonDecode(File('web/tertiary-feed.json').readAsStringSync()),
      ),
    );
  final now = DateTime(2026, 10, 28, 12);
  AdmissionRule r(String name) =>
      s.rules.singleWhere((r) => r.id == 'mobile-20261028-csu-$name');
  MatchAssessment check(String name, Map<String, int> g) =>
      assessPathway(r(name), g, now: now);
  final core = {for (final c in coreSubjects) c: 2};
  test(
    'four CSU programme records validate without changing institution identity',
    () {
      expect(s.rules, hasLength(599));
      expect(
        s.rules.where((r) => r.data['scope'] == 'programme'),
        hasLength(542),
      );
      final added = s.rules.where((r) => r.id.startsWith('mobile-20261028-'));
      expect(added, hasLength(4));
      for (final rule in added) {
        expect(rule.data['institutionId'], 'gtec:654');
        expect(() => validateAdmissionRule(rule), returnsNormally);
      }
    },
  );
  test(
    'CSU Computer Science accepts the published Social Studies alternative',
    () {
      final g = {
        ...core,
        'Integrated Science': 9,
        'Social Studies': 6,
        'Government': 6,
        'History': 6,
        'French': 6,
      };
      expect(check('computer-science', g).academicPass, isTrue);
      expect(
        check('computer-science', {...g, 'English Language': 7}).academicPass,
        isFalse,
      );
    },
  );
  test(
    'nursing requires Biology and Chemistry while midwifery publishes any three science electives',
    () {
      final g = {
        ...core,
        'Elective Mathematics': 2,
        'Physics': 2,
        'Chemistry': 2,
      };
      expect(check('nursing', g).academicPass, isFalse);
      expect(check('nursing', {...g, 'Biology': 2}).academicPass, isTrue);
      expect(check('midwifery', g).academicPass, isTrue);
      expect(
        check('midwifery', {
          ...g,
          'Integrated Science': 7,
          'Social Studies': 1,
        }).academicPass,
        isFalse,
      );
    },
  );
  test(
    'undefined IT core and non-science nursing streams require confirmation',
    () {
      final g = {...core, 'Government': 1, 'History': 1, 'French': 1};
      expect(check('information-technology', g).academicPass, isFalse);
      expect(check('nursing', g).academicPass, isFalse);
      expect(check('nursing', g).status, 'Additional route information needed');
    },
  );
  test(
    '256 generated cases preserve credit limits, arithmetic and source quarantine',
    () {
      final random = Random(281004);
      var n = 0;
      for (final rule in s.rules.where(
        (r) => r.id.startsWith('mobile-20261028-'),
      )) {
        final electives = (rule.data['electiveRoutes'] as List)
            .expand((r) => r['allowed'] as List)
            .cast<String>()
            .toSet()
            .toList();
        for (var k = 0; k < 64; k++) {
          electives.shuffle(random);
          final g = {
            for (final c in coreSubjects) c: 1 + random.nextInt(9),
            for (final e in electives.take(4)) e: 1 + random.nextInt(9),
          };
          final a = assessPathway(rule, g, now: now);
          n++;
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
              AdmissionRule({...rule.data, 'status': 'needs_source_review'}),
              g,
              now: now,
            ).academicPass,
            isFalse,
          );
        }
      }
      expect(n, 256);
    },
  );
}
