import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:skoolatlas/tertiary_data.dart';
import 'package:skoolatlas/student_guidance.dart';

Map<String, dynamic> publication() => Map<String, dynamic>.from(
  jsonDecode(File('web/tertiary-feed.json').readAsStringSync()),
);
void main() {
  final now = DateTime(2026, 10, 27, 12);
  final s = TertiaryStore()..applyFeed(publication());
  AdmissionRule r(String name) =>
      s.rules.singleWhere((r) => r.id == 'expanded-20261027-$name');
  Map<String, int> cores([int grade = 3]) => {
    for (final c in coreSubjects) c: grade,
  };
  MatchAssessment check(String id, Map<String, int> grades) =>
      assessPathway(r(id), grades, now: now, targetCycle: '2026/2027');
  test(
    'all published rules validate and the reviewed batch covers all sixteen regions',
    () {
      expect(s.rules.length, (publication()['rules'] as List).length);
      expect(s.rules.map((r) => r.id).toSet().length, s.rules.length);
      expect(s.rules.length, greaterThanOrEqualTo(508));
      expect(s.rules.where((r) => r.data['scope'] == 'programme').length, greaterThanOrEqualTo(450));
      for (final rule in s.rules) {
        expect(
          () => validateAdmissionRule(rule),
          returnsNormally,
          reason: rule.id,
        );
      }
      final added = s.rules.where((r) => r.id.startsWith('expanded-20261027-'));
      expect(added.length, 112);
      expect(
        added
            .expand(
              (r) => s.institutions
                  .singleWhere((i) => i.id == r.data['institutionId'])
                  .regions,
            )
            .toSet(),
        pathwayRegions.toSet(),
      );
    },
  );
  test(
    'KNUST computing accepts the exact three electives at aggregate 24 and rejects aggregate 30',
    () {
      final g = {
        ...cores(4),
        'Elective Mathematics': 4,
        'Physics': 4,
        'Chemistry': 4,
      };
      expect(check('knust-computer-science', g).academicPass, isTrue);
      expect(check('knust-computer-science', g).aggregate, 24);
      expect(
        check('knust-computer-science', {
          ...cores(5),
          'Elective Mathematics': 5,
          'Physics': 5,
          'Chemistry': 5,
        }).academicPass,
        isFalse,
      );
      expect(
        check('knust-computer-science', {
          ...g,
          'Social Studies': 9,
        }).academicPass,
        isTrue,
      );
      expect(
        check('knust-computer-science', {...g}..remove('Physics')).academicPass,
        isFalse,
      );
      expect(
        check(
          'knust-computer-science',
          {...g}
            ..remove('Chemistry')
            ..['Electronics'] = 4,
        ).academicPass,
        isTrue,
      );
      expect(
        check(
          'knust-computer-science',
          {...g}
            ..remove('Chemistry')
            ..['ICT'] = 4,
        ).academicPass,
        isFalse,
      );
    },
  );
  test(
    'KNUST technical route enforces B3 science only on the published technical option',
    () {
      final g = {
        ...cores(2),
        'Integrated Science': 3,
        'Elective Mathematics': 2,
        'Physics': 2,
        'Technical Drawing': 3,
      };
      final yes = check('knust-industrial-engineering', g);
      expect(yes.academicPass, isTrue);
      expect(yes.route, contains('B3 Integrated Science'));
      expect(yes.aggregate, 14);
      final no = check('knust-industrial-engineering', {
        ...g,
        'Integrated Science': 4,
      });
      expect(no.academicPass, isFalse);
      expect(no.reasons.join(' '), contains('B3'));
      final chemistry = check('knust-industrial-engineering', {
        ...g,
        'Integrated Science': 4,
        'Chemistry': 6,
        'Technical Drawing': 1,
      });
      expect(chemistry.academicPass, isTrue);
      expect(chemistry.countedSubjects.containsKey('Chemistry'), isTrue);
      expect(
        chemistry.countedSubjects.containsKey('Technical Drawing'),
        isFalse,
      );
      expect(chemistry.aggregate, 18);
      final described = describeRequirements(
        r('knust-industrial-engineering'),
      ).join(' ');
      expect(described, contains('Integrated Science must be B3'));
    },
  );
  test(
    'KNUST substitution floors apply while the contradictory ICT option stays conditional',
    () {
      final g = {
        ...cores(2),
        'Elective Mathematics': 2,
        'Physics': 2,
        'ICT': 2,
      };
      final a = check('knust-computer-engineering', g);
      expect(a.academicPass, isTrue);
      final c=check('knust-computer-engineering',{...g,'Integrated Science':4});expect(c.academicPass,isFalse);expect(c.reasons.join(' '),contains('B3'));
      final b = check('knust-industrial-engineering', g);
      expect(b.academicPass, isFalse);
      expect(b.reasons.join(' '), contains('omits it'));
    },
  );
  test(
    'the 2023/2024 KNUST cutoff table is never used as a 2026/2027 threshold',
    () {
      final g = {
        ...cores(1),
        'Elective Mathematics': 2,
        'Physics': 1,
        'Chemistry': 2,
      };
      final a = check('knust-computer-science', g);
      expect(a.aggregate, 8);
      expect(a.academicPass, isTrue);
      expect(a.cutoff.status, 'No verified programme cutoff');
      for (final rule in s.rules.where(
        (r) => r.id.startsWith('expanded-20261027-knust-'),
      )) {
        expect(rule.data['cycle'], '2026/2027');
        expect(rule.data['competitiveCutoff'], isNull);
        expect(
          rule.data['additionalConditions'].join(' '),
          contains('2023/2024'),
        );
      }
    },
  );
  test(
    'GIMPA Mathematics route is supported; the older Physics-only alternative remains held',
    () {
      final g = {
        ...cores(6),
        'Elective Mathematics': 6,
        'Biology': 6,
        'Geography': 6,
      };
      expect(check('gimpa-computer-science', g).academicPass, isTrue);
      expect(check('gimpa-computer-science', g).aggregate, 36);
      expect(
        r('gimpa-computer-science').matchesProgramme('BSc · Computer Science'),
        isTrue,
      );
      expect(
        check(
          'gimpa-computer-science',
          {...g}
            ..remove('Elective Mathematics')
            ..['Physics'] = 1,
        ).academicPass,
        isFalse,
      );
      expect(
        check('gimpa-physics-held', {...g, 'Physics': 1}).status,
        'Needs source review',
      );
      final arts = {
        'English Language': 3,
        'Core Mathematics': 3,
        'Social Studies': 3,
        'Economics': 3,
        'Government': 3,
        'History': 3,
      };
      expect(check('gimpa-ict', arts).academicPass, isTrue);
      expect(
        check(
          'gimpa-ict',
          arts,
        ).countedSubjects.containsKey('Integrated Science'),
        isFalse,
      );
    },
  );
  test(
    'KNUST Home Economics and French requirements are kept programme-specific',
    () {
      final nutrition = {
        ...cores(3),
        'Food and Nutrition': 3,
        'Management in Living': 3,
        'Biology': 3,
      };
      expect(check('knust-nutrition', nutrition).academicPass, isTrue);
      expect(check('knust-computer-science', nutrition).academicPass, isFalse);
      final french = {...cores(3), 'French': 3, 'History': 3, 'Geography': 3};
      expect(check('knust-french', french).academicPass, isTrue);
      expect(
        check('knust-french', {...french, 'French': 4}).academicPass,
        isFalse,
      );
      expect(
        check('knust-english', french).academicPass,
        isTrue,
      ); // Literature is not made mandatory by the published list.
    },
  );
  test(
    'UMaT substitutes Geography only for Geomatic Engineering and respects the Essikado route',
    () {
      final g = {
        ...cores(6),
        'Elective Mathematics': 6,
        'Physics': 6,
        'Geography': 6,
      };
      expect(check('umat-geomatic', g).academicPass, isTrue);
      expect(check('umat-mining', g).academicPass, isFalse);
      final civil = {
        ...cores(3),
        'Elective Mathematics': 3,
        'Physics': 3,
        'Building Construction': 3,
      };
      expect(check('umat-civil-essikado', civil).academicPass, isTrue);
      expect(
        r('umat-civil-essikado').data['campus'],
        contains('Essikado only'),
      );
      expect(
        r('umat-civil-essikado').matchesProgramme('BSc · Civil Engineering'),
        isTrue,
      );
      expect(check('umat-mining', civil).academicPass, isFalse);
    },
  );
  test(
    'UMaT undefined Others electives stay conditional and a defined option takes priority',
    () {
      final unknown = {
        ...cores(3),
        'Elective Mathematics': 3,
        'Biology': 3,
        'French': 3,
      };
      expect(check('umat-math', unknown).academicPass, isFalse);
      expect(
        check('umat-math', unknown).status,
        'Additional route information needed',
      );
      final named = {
        ...cores(3),
        'Elective Mathematics': 3,
        'Physics': 3,
        'Economics': 3,
      };
      expect(check('umat-math', named).academicPass, isTrue);
      expect(check('umat-math', named).route, 'Named published electives');
    },
  );
  test(
    'all 49 national college programme baselines require elective relevance confirmation',
    () {
      final college = s.rules
          .where((r) => r.id.startsWith('expanded-20261027-coe-'))
          .toList();
      expect(college.length, 49);
      expect(college.map((r) => r.data['institutionId']).toSet().length, 49);
      final g = {
        'English Language': 1,
        'Core Mathematics': 1,
        'Social Studies': 1,
        'French': 1,
        'Geography': 1,
        'History': 1,
      };
      for (final rule in college) {
        final a = assessPathway(rule, g, now: now);
        expect(
          a.status,
          'Additional route information needed',
          reason: rule.id,
        );
        expect(a.academicPass, isFalse);
        expect(a.aggregate, 6);
        expect(a.reasons.join(' '), contains('Ghanaian-language'));
        expect(programmeNeedsConfirmation(rule), isTrue);
        expect(
          describeRequirements(rule).join(' '),
          contains('Confirmation required'),
        );
      }
      expect(r('coe-748').programme, contains('Junior High School Education'));
      expect(r('coe-752').programme, contains('Early Grade Education'));
    },
  );
  test(
    'GIMPA Accra course is not ranked as a confirmed Western-campus route',
    () {
      final grades = {
        ...cores(3),
        'Elective Mathematics': 3,
        'Physics': 3,
        'Chemistry': 3,
      };
      final western = rankPathways(
        s,
        grades,
        const PathwayPreferences(regions: {'Western'}),
        now: now,
      ).singleWhere((p) => p.rule.id == r('gimpa-computer-science').id);
      expect(western.preferencePoints, 0);
      expect(western.tradeoffs, contains('Outside your preferred regions.'));
      final accra = rankPathways(
        s,
        grades,
        const PathwayPreferences(regions: {'Greater Accra'}),
        now: now,
      ).singleWhere((p) => p.rule.id == r('gimpa-computer-science').id);
      expect(accra.preferencePoints, 3);
      expect(accra.fitReasons.join(' '), contains('published route'));
      final bad = publication();
      (bad['rules'] as List).singleWhere(
        (r) => r['id'] == 'expanded-20261027-knust-computer-science',
      )['programmeRegions'] = [
        'Western North',
      ];
      expect(() => TertiaryStore().applyFeed(bad), throwsFormatException);
    },
  );
  test(
    'route grade limits cannot weaken a rule or partially mutate a feed',
    () {
      final bad = publication();
      final data = (bad['rules'] as List).singleWhere(
        (r) => r['id'] == 'expanded-20261027-knust-industrial-engineering',
      );
      data['electiveRoutes'][0]['coreMaxGrades']['Integrated Science'] = 9;
      final store = TertiaryStore()..applyFeed(publication());
      final before = store.rules;
      expect(() => store.applyFeed(bad), throwsFormatException);
      expect(identical(store.rules, before), isTrue);
      final clone = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(r('knust-industrial-engineering').data)),
      );
      clone['gradeFloors'] = {'Integrated Science': 2};
      clone['electiveRoutes'][0]['coreMaxGrades']['Integrated Science'] = 6;
      expect(
        assessPathway(AdmissionRule(clone), {
          ...cores(3),
          'Elective Mathematics': 2,
          'Physics': 2,
          'Technical Drawing': 2,
        }, now: now).academicPass,
        isFalse,
      );
    },
  );
  test(
    'deterministic grade cases never approve a failed credit, held source, conditional route or invalid aggregate',
    () {
      final random = Random(271026);
      var cases = 0;
      final added = s.rules.where((r) => r.id.startsWith('expanded-20261027-'));
      for (final rule in added) {
        for (var n = 0; n < 16; n++) {
          final all =
              (rule.data['electiveRoutes'] as List)
                  .expand((r) => r['allowed'] as List)
                  .cast<String>()
                  .toSet()
                  .toList()
                ..shuffle(random);
          final g = {
            for (final c in coreSubjects) c: 1 + random.nextInt(9),
            for (final e in all.take(4)) e: 1 + random.nextInt(9),
          };
          final a = assessPathway(rule, g, now: now);
          cases++;
          if (a.academicPass) {
            expect(a.countedSubjects.length, 6);
            expect(a.countedSubjects.values.every((g) => g <= 6), isTrue);
            expect(
              a.aggregate,
              a.countedSubjects.values.reduce((a, b) => a + b),
            );
            if (rule.data['maxAggregate'] != null) {
              expect(a.aggregate! <= rule.data['maxAggregate'], isTrue);
            }
            expect(rule.data['status'], 'source_checked');
            expect(programmeNeedsConfirmation(rule), isFalse);
          }
        }
      }
      expect(cases, 1792);
    },
  );
}
