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
  final now = DateTime(2026, 10, 28, 12);
  AdmissionRule rule(String slug) =>
      store.rules.singleWhere((r) => r.id == 'technical-20261028-$slug');
  Map<String, int> core([int n = 2]) => {for (final c in coreSubjects) c: n};
  MatchAssessment check(String slug, Map<String, int> g) =>
      assessPathway(rule(slug), g, now: now);
  final science = {
    ...core(),
    'Elective Mathematics': 2,
    'Physics': 2,
    'Chemistry': 2,
  };
  final arts = {...core(), 'Government': 2, 'History': 2, 'French': 2};
  test(
    '35 distinct reviewed records validate without inventing programme coverage',
    () {
      expect(store.rules, hasLength(600));
      final added = store.rules
          .where((r) => r.id.startsWith('technical-20261028-'))
          .toList();
      expect(added, hasLength(35));
      expect(added.where((r) => r.data['scope'] == 'programme'), hasLength(29));
      expect(
        added.where((r) => r.data['scope'] == 'institution_general'),
        hasLength(6),
      );
      expect(
        added.where((r) => r.data['status'] == 'needs_source_review'),
        hasLength(3),
      );
      expect({for (final r in store.rules) r.id}, hasLength(600));
      for (final r in store.rules) {
        expect(() => validateAdmissionRule(r), returnsNormally, reason: r.id);
      }
    },
  );
  test(
    'Civil requires mathematics and physics; electrical accepts published alternatives',
    () {
      expect(check('atu-civil', science).academicPass, isTrue);
      final g = {...core(), 'Biology': 2, 'Chemistry': 2, 'ICT': 2};
      expect(check('atu-civil', g).academicPass, isFalse);
      expect(check('atu-electrical', g).academicPass, isTrue);
      expect(
        check('atu-mechanical', {
          ...core(),
          'Metalwork': 2,
          'Auto Mechanics': 2,
          'Technical Drawing': 2,
        }).academicPass,
        isTrue,
      );
    },
  );
  test('Statistics and procurement require at least one named elective', () {
    for (final id in ['atu-statistics', 'atu-procurement']) {
      expect(check(id, arts).academicPass, isFalse);
      expect(check(id, {...arts, 'Economics': 2}).academicPass, isTrue);
    }
  });
  test(
    'Secretaryship published aggregate 24 boundary and compulsory science',
    () {
      final g = {...core(4), 'Government': 4, 'History': 4, 'French': 4};
      expect(check('atu-secretaryship', g).aggregate, 24);
      expect(check('atu-secretaryship', g).academicPass, isTrue);
      expect(
        check('atu-secretaryship', {...g, 'French': 5}).academicPass,
        isFalse,
      );
      expect(
        check('atu-secretaryship', {
          ...g,
          'Integrated Science': 7,
          'Social Studies': 1,
        }).academicPass,
        isFalse,
      );
    },
  );
  test(
    'Fashion and interior permit published social-studies core alternative',
    () {
      for (final id in ['atu-fashion', 'atu-interior']) {
        expect(
          check(id, {
            ...arts,
            'Integrated Science': 9,
            'Social Studies': 6,
          }).academicPass,
          isTrue,
        );
      }
    },
  );
  test(
    'Science computing route passes; undefined non-science route requires confirmation',
    () {
      for (final id in [
        'atu-cyber',
        'atu-computer-science',
        'atu-informatics',
      ]) {
        expect(check(id, science).academicPass, isTrue);
        expect(
          check(id, {...arts, 'Elective Mathematics': 2}).academicPass,
          isFalse,
        );
      }
    },
  );
  test(
    'Undefined relevant subjects remain conditional even with excellent grades',
    () {
      for (final id in ['atu-water', 'atu-data-science', 'ktu-ict']) {
        final complete = {...science, 'Biology': 1};
        expect(check(id, complete).academicPass, isFalse);
        expect(
          check(id, complete).status,
          'Additional route information needed',
        );
      }
    },
  );
  test(
    'Conflicting official grade statements never approve even all A1 results',
    () {
      for (final id in [
        'atu-renewable',
        'atu-food-manufacturing',
        'ktu-computer-science',
      ]) {
        expect(
          check(id, {for (final s in science.keys) s: 1}).academicPass,
          isFalse,
        );
      }
    },
  );
  test('HND D7 core passes are separate from degree credit requirements', () {
    final g = {...core(7), 'Government': 6, 'History': 6, 'French': 6};
    for (final prefix in ['ktu', 'btu']) {
      expect(check('$prefix-hnd-general', g).academicPass, isTrue);
      expect(rule('$prefix-hnd-general').data['scope'], 'institution_general');
      expect(check('$prefix-degree-general', g).academicPass, isFalse);
      expect(
        check('$prefix-hnd-general', {...g, 'French': 7}).academicPass,
        isFalse,
      );
      expect(
        check('$prefix-hnd-general', {
          ...g,
          'English Language': 8,
        }).academicPass,
        isFalse,
      );
    }
  });
  test(
    'Sunyani science core differs from institutions accepting social studies',
    () {
      final g = {...arts, 'Integrated Science': 9, 'Social Studies': 2};
      for (final id in [
        'ktu-degree-general',
        'btu-degree-general',
        'tatu-degree-general',
      ]) {
        expect(check(id, g).academicPass, isTrue);
      }
      expect(check('stu-degree-general', g).academicPass, isFalse);
    },
  );
  test(
    '2240 generated cases preserve arithmetic, grade ceilings and source quarantine',
    () {
      final random = Random(281035);
      var count = 0;
      for (final r in store.rules.where(
        (r) => r.id.startsWith('technical-20261028-'),
      )) {
        final electives = (r.data['electiveRoutes'] as List)
            .expand((x) => x['allowed'] as List)
            .cast<String>()
            .toSet()
            .toList();
        for (var n = 0; n < 64; n++) {
          electives.shuffle(random);
          final g = {
            for (final c in coreSubjects) c: 1 + random.nextInt(9),
            for (final e in electives.take(5)) e: 1 + random.nextInt(9),
          };
          final original = Map<String, int>.from(g);
          final a = assessPathway(r, g, now: now);
          count++;
          expect(g, original);
          if (a.academicPass) {
            expect(a.countedSubjects, hasLength(6));
            expect(
              a.aggregate,
              a.countedSubjects.values.reduce((a, b) => a + b),
            );
            for (final entry in a.countedSubjects.entries) {
              final limit = (r.data['coreMaxGrades'] as Map?)?[entry.key] ?? 6;
              expect(
                entry.value,
                lessThanOrEqualTo(limit as int),
                reason: r.id,
              );
            }
            if (r.data['maxAggregate'] != null) {
              expect(a.aggregate, lessThanOrEqualTo(r.data['maxAggregate']));
            }
          }
          expect(
            assessPathway(
              AdmissionRule({...r.data, 'status': 'needs_source_review'}),
              g,
              now: now,
            ).academicPass,
            isFalse,
          );
        }
      }
      expect(count, 2240);
    },
  );
}
