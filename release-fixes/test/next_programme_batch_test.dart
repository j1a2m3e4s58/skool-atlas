import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:skoolatlas/tertiary_data.dart';

Map<String, dynamic> currentFeed() => Map<String, dynamic>.from(
  jsonDecode(File('web/tertiary-feed.json').readAsStringSync()),
);
void main() {
  final now = DateTime(2026, 10, 28, 12);
  final store = TertiaryStore()..applyFeed(currentFeed());
  AdmissionRule r(String slug) =>
      store.rules.singleWhere((x) => x.id == 'expanded-20261028-$slug');
  AdmissionRule old(String id) => store.rules.singleWhere((x) => x.id == id);
  Map<String, int> core([int g = 2]) => {for (final c in coreSubjects) c: g};
  MatchAssessment check(String slug, Map<String, int> g) =>
      assessPathway(r(slug), g, now: now);
  test(
    'second batch is unique, fully validated, versioned and limited to reviewed sources',
    () {
      expect(store.rules, hasLength(599));
      expect(
        store.rules.where((r) => r.data['scope'] == 'programme'),
        hasLength(542),
      );
      final added = store.rules
          .where((r) => r.id.startsWith('expanded-20261028-'))
          .toList();
      expect(added, hasLength(70));
      for (final rule in store.rules) {
        expect(
          () => validateAdmissionRule(rule),
          returnsNormally,
          reason: rule.id,
        );
      }
      expect(
        {for (final rule in added) rule.data['institutionId']},
        {'gtec:880', 'gtec:877', 'gtec:879', 'gtec:882'},
      );
      expect(
        added.where((r) => r.data['finalResultsRequired'] == true),
        hasLength(22),
      );
      expect(added.where((r) => r.data['competitiveCutoff'] != null), isEmpty);
    },
  );
  test(
    'UHAS Social Studies credit is compulsory but never counted in the aggregate',
    () {
      final g = {...core(1), 'Biology': 1, 'Chemistry': 1, 'Physics': 1};
      final pass = check('uhas-pharmacy', {...g, 'Social Studies': 6});
      expect(pass.academicPass, isTrue);
      expect(pass.aggregate, 6);
      expect(pass.countedSubjects.containsKey('Social Studies'), isFalse);
      expect(
        check('uhas-pharmacy', {...g, 'Social Studies': 7}).academicPass,
        isFalse,
      );
      g.remove('Social Studies');
      expect(check('uhas-pharmacy', g).academicPass, isFalse);
      expect(
        check('uhas-pharmacy', {
          ...core(),
          'Physics': 2,
          'Chemistry': 2,
          'Elective Mathematics': 2,
        }).academicPass,
        isFalse,
        reason:
            'Pharmacy specifically requires Biology; medicine has a different published combination.',
      );
      expect(
        check('uhas-medicine', {
          ...core(),
          'Physics': 2,
          'Chemistry': 2,
          'Elective Mathematics': 2,
        }).academicPass,
        isTrue,
      );
    },
  );
  test(
    'UHAS awaiting or predicted results cannot pass even when all entered grades are A1',
    () {
      final grades = {...core(1), 'Biology': 1, 'Chemistry': 1, 'Physics': 1};
      for (final rule in store.rules.where(
        (r) => r.id.startsWith('expanded-20261028-uhas-'),
      )) {
        for (final predicted in [true, false]) {
          final a = assessPathway(
            rule,
            grades,
            now: now,
            resultBasis: predicted ? 'Predicted results' : 'Final results',
            hasAwaitingResults: !predicted,
          );
          expect(a.status, 'Final results required', reason: rule.id);
          expect(a.academicPass, isFalse);
          expect(a.cutoff.status, 'Not compared');
        }
      }
      final ranked = rankPathways(
        store,
        grades,
        PathwayPreferences(),
        now: now,
        hasAwaitingResults: true,
      );
      expect(
        ranked.where(
          (r) =>
              r.rule.id.startsWith('expanded-20261028-uhas-') &&
              r.assessment.academicPass,
        ),
        isEmpty,
      );
    },
  );
  test(
    'UHAS Home Economics and non-science routes retain their own conditions',
    () {
      expect(
        check('uhas-dietetics', {
          ...core(),
          'Chemistry': 2,
          'Food and Nutrition': 2,
          'General Knowledge in Art': 2,
        }).academicPass,
        isTrue,
      );
      expect(
        check('uhas-dietetics', {
          ...core(),
          'Management in Living': 2,
          'Food and Nutrition': 2,
          'General Knowledge in Art': 2,
        }).academicPass,
        isFalse,
      );
      final nonScience = {
        ...core(),
        'Government': 2,
        'Geography': 2,
        'History': 2,
      };
      final a = check('uhas-speech', nonScience);
      expect(a.academicPass, isFalse);
      expect(a.status, 'Additional route information needed');
      final weaker = check('uhas-speech', {
        ...nonScience,
        'Integrated Science': 3,
      });
      expect(weaker.academicPass, isFalse);
      expect(weaker.reasons.join(' '), contains('B2'));
      expect(
        check('uhas-nursing', {
          ...core(),
          'Accounting': 1,
          'Cost Accounting': 1,
          'Business Management': 1,
        }).academicPass,
        isFalse,
      );
    },
  );
  test(
    'UENR engineering combinations do not inherit KNUST route floors or interchange ICT',
    () {
      final grades = {
        ...core(6),
        'Elective Mathematics': 6,
        'Physics': 6,
        'Technical Drawing': 6,
      };
      expect(check('uenr-civil-engineering', grades).academicPass, isTrue);
      expect(
        check('uenr-electrical-engineering', grades).academicPass,
        isFalse,
      );
      final ict = {
        ...core(),
        'Elective Mathematics': 2,
        'Physics': 2,
        'ICT': 2,
      };
      expect(check('uenr-computer-engineering', ict).academicPass, isTrue);
      expect(check('uenr-electrical-engineering', ict).academicPass, isFalse);
      expect(check('uenr-petroleum-engineering', grades).academicPass, isFalse);
    },
  );
  test(
    'UENR agriculture, geoscience and arts routes preserve mandatory combinations',
    () {
      expect(
        check('uenr-agriculture', {
          ...core(),
          'Chemistry': 2,
          'Forestry': 2,
          'Physics': 2,
        }).academicPass,
        isTrue,
      );
      expect(
        check('uenr-agriculture', {
          ...core(),
          'Chemistry': 2,
          'Geography': 2,
          'Physics': 2,
        }).academicPass,
        isFalse,
      );
      expect(
        check('uenr-geoinformation', {
          ...core(),
          'Social Studies': 2,
          'Geography': 2,
          'Government': 2,
          'History': 2,
        }).academicPass,
        isTrue,
      );
      expect(
        check('uenr-geomatics', {
          ...core(),
          'Geography': 2,
          'Government': 2,
          'History': 2,
        }).academicPass,
        isFalse,
      );
      expect(
        check('uenr-geomatics', {
          ...core(),
          'Elective Mathematics': 2,
          'Geography': 2,
          'Government': 2,
        }).academicPass,
        isTrue,
      );
      expect(
        check('uenr-accounting', {
          ...core(),
          'Government': 2,
          'History': 2,
          'French': 2,
        }).academicPass,
        isFalse,
      );
      expect(
        check('uenr-accounting', {
          ...core(),
          'Economics': 2,
          'History': 2,
          'French': 2,
        }).academicPass,
        isTrue,
      );
    },
  );
  test(
    'revised UENR 2026/27 guide updates original programme IDs and their exact combinations',
    () {
      final it = old('national-20261027-uenr-it');
      expect(it.data['cycle'], '2026/2027');
      expect(it.source, contains('REVISED-EDITION-1.pdf'));
      final arts = {...core(), 'Government': 2, 'History': 2, 'French': 2};
      expect(assessPathway(it, arts, now: now).academicPass, isTrue);
      final cs = old('national-20261027-uenr-cs');
      expect(
        assessPathway(cs, {
          ...core(),
          'Elective Mathematics': 2,
          'Biology': 2,
          'Geography': 2,
        }, now: now).academicPass,
        isTrue,
      );
      expect(
        assessPathway(cs, {
          ...core(),
          'Elective Mathematics': 2,
          'Physics': 2,
          'Government': 2,
        }, now: now).academicPass,
        isFalse,
      );
      expect(
        assessPathway(old('national-20261027-uenr-mls'), {
          ...core(),
          'Chemistry': 2,
          'Elective Mathematics': 2,
          'Forestry': 2,
        }, now: now).academicPass,
        isTrue,
      );
      expect(
        assessPathway(old('national-20261027-uenr-chem'), {
          ...core(),
          'Chemistry': 2,
          'Biology': 2,
          'Geography': 2,
        }, now: now).academicPass,
        isFalse,
      );
      expect(
        assessPathway(old('national-20261027-utas-mls'), {
          ...core(),
          'Integrated Science': 7,
          'Biology': 2,
          'Chemistry': 2,
          'Physics': 2,
        }, now: now).academicPass,
        isFalse,
      );
    },
  );
  test(
    'UDS social science, language and land routes require the named subjects',
    () {
      expect(
        check('uds-history', {
          ...core(),
          'History': 6,
          'Government': 6,
          'Economics': 6,
        }).academicPass,
        isTrue,
      );
      expect(
        check('uds-history', {
          ...core(),
          'History': 2,
          'French': 2,
          'Economics': 2,
        }).academicPass,
        isFalse,
      );
      expect(
        check('uds-social-sciences', {
          ...core(),
          'Government': 2,
          'Economics': 2,
          'French': 2,
        }).academicPass,
        isTrue,
      );
      expect(
        check('uds-french', {
          ...core(),
          'French': 2,
          'Literature in English': 2,
          'Economics': 2,
        }).academicPass,
        isTrue,
      );
      expect(
        check('uds-french', {
          ...core(),
          'French': 2,
          'Government': 2,
          'Economics': 2,
        }).academicPass,
        isFalse,
      );
      expect(
        check('uds-planning', {
          ...core(),
          'Economics': 2,
          'Geography': 2,
          'French': 2,
        }).academicPass,
        isTrue,
      );
      expect(
        check('uds-planning', {
          ...core(),
          'Economics': 2,
          'Geography': 2,
          'Biology': 2,
        }).academicPass,
        isFalse,
      );
    },
  );
  test(
    'UEW distance English and Maths stay separate and do not imply regular or top-up eligibility',
    () {
      final g = {
        ...core(),
        'Literature in English': 2,
        'Government': 2,
        'History': 2,
      };
      expect(check('uew-distance-english', g).academicPass, isTrue);
      expect(check('uew-distance-mathematics', g).academicPass, isFalse);
      final maths = {
        ...core(),
        'Elective Mathematics': 2,
        'Government': 2,
        'History': 2,
      };
      expect(check('uew-distance-mathematics', maths).academicPass, isTrue);
      expect(r('uew-distance-english').data['studyMode'], 'Distance');
    },
  );
  test(
    'new policy fields fail closed on older feed versions and malformed rules without partial mutations',
    () {
      final feed = currentFeed();
      final local = TertiaryStore()..applyFeed(feed);
      final before = local.rules;
      final wrong = currentFeed()..['schemaVersion'] = 4;
      expect(() => local.applyFeed(wrong), throwsFormatException);
      expect(identical(local.rules, before), isTrue);
      for (final value in ['true', 0, {}, null]) {
        final malformed = currentFeed();
        final rule = (malformed['rules'] as List).firstWhere(
          (r) => r['ruleVersion'] == 3,
        );
        rule['finalResultsRequired'] = value;
        if (value == null) {
          rule['ruleVersion'] = 2;
          rule['finalResultsRequired'] = true;
        }
        expect(() => local.applyFeed(malformed), throwsFormatException);
        expect(identical(local.rules, before), isTrue);
      }
    },
  );
  test(
    'slash-separated alternatives cannot supply multiple counted subject slots without confirmation',
    () {
      for (final slug in [
        'uenr-meteorology',
        'uenr-climate',
        'uenr-geoinformation',
        'uenr-natural-resources',
        'uenr-aquaculture',
      ]) {
        final a = check(slug, {
          ...core(),
          'Biology': 1,
          'Agricultural Science': 1,
          'Forestry': 1,
        });
        expect(a.academicPass, isFalse, reason: slug);
        expect(a.status, 'Additional route information needed', reason: slug);
      }
      expect(
        check('uenr-meteorology', {
          ...core(),
          'Physics': 2,
          'Elective Mathematics': 2,
          'Forestry': 2,
        }).academicPass,
        isTrue,
      );
      final cs = assessPathway(old('national-20261027-uenr-cs'), {
        ...core(),
        'Elective Mathematics': 2,
        'Physics': 2,
        'Applied Electricity': 2,
      }, now: now);
      expect(cs.academicPass, isFalse);
      expect(cs.status, 'Additional route information needed');
      expect(
        check('uenr-food-technology', {
          ...core(),
          'Elective Mathematics': 2,
          'Physics': 2,
          'Chemistry': 2,
        }).academicPass,
        isFalse,
      );
      expect(
        check('uenr-food-technology', {
          ...core(),
          'Elective Mathematics': 2,
          'Biology': 2,
          'Chemistry': 2,
        }).academicPass,
        isTrue,
      );
      expect(
        check('uenr-nursing', {
          ...core(),
          'French': 2,
          'Arabic': 2,
          'Geography': 2,
        }).academicPass,
        isFalse,
      );
      expect(
        check('uenr-nursing', {
          ...core(),
          'French': 2,
          'Government': 2,
          'Geography': 2,
        }).academicPass,
        isTrue,
      );
    },
  );
  test(
    '2240 deterministic cases preserve six-subject arithmetic, mandatory credits and source gating',
    () {
      final random = Random(281026);
      var count = 0;
      for (final rule in store.rules.where(
        (r) => r.id.startsWith('expanded-20261028-'),
      )) {
        final allowed = (rule.data['electiveRoutes'] as List)
            .expand((r) => r['allowed'] as List)
            .cast<String>()
            .toSet()
            .toList();
        for (var n = 0; n < 32; n++) {
          allowed.shuffle(random);
          final g = {
            for (final c in coreSubjects) c: 1 + random.nextInt(9),
            for (final e in allowed.take(4)) e: 1 + random.nextInt(9),
          };
          final a = assessPathway(rule, g, now: now);
          count++;
          if (a.academicPass) {
            expect(a.countedSubjects, hasLength(6));
            expect(
              a.aggregate,
              a.countedSubjects.values.reduce((a, b) => a + b),
            );
            expect(a.countedSubjects.values.every((v) => v <= 6), isTrue);
            for (final c in rule.data['coreCredits']) {
              if (!(rule.data['scienceOrSocial'] as List? ?? []).contains(c)) {
                expect(g[c], lessThanOrEqualTo(6), reason: '${rule.id}: $c');
              }
            }
          }
          final held = AdmissionRule({
            ...rule.data,
            'status': 'needs_source_review',
          });
          expect(assessPathway(held, g, now: now).academicPass, isFalse);
        }
      }
      expect(count, 2240);
    },
  );
}
