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
  final now = DateTime(2026, 11, 1, 23);
  AdmissionRule rule(String id) => store.rules.singleWhere((r) => r.id == id);
  Map<String, int> core([int grade = 6]) => {
    for (final s in coreSubjects) s: grade,
  };
  test(
    'reviewed URL migrations preserve every academic field and original evidence date',
    () {
      final before =
          (jsonDecode(
                File(
                  'data/remaining-nine-2026-11-01/admissions-before.json',
                ).readAsStringSync(),
              )['rules']
              as List);
      expect(store.rules, hasLength(599));
      for (final r in store.rules.where(
        (r) => before.any((o) => o['id'] == r.id),
      )) {
        final a = Map<String, dynamic>.from(
          before.singleWhere((o) => o['id'] == r.id),
        );
        final b = Map<String, dynamic>.from(r.data);
        for (final key in ['sourceUrl', 'generalSourceUrl']) {
          a.remove(key);
          b.remove(key);
        }
        expect(b, a, reason: r.id);
        expect(() => validateAdmissionRule(r), returnsNormally);
      }
    },
  );
  test(
    'conflicting KTU and Presbyterian requirements never approve even all A1 grades',
    () {
      final g = {...core(1), for (final s in electiveSubjects) s: 1};
      for (final id in [
        'technical-20261028-ktu-computer-science',
        'private-20261028-presby-pa',
      ]) {
        expect(assessPathway(rule(id), g, now: now).academicPass, isFalse);
      }
    },
  );
  test(
    'UMaT geography substitution remains restricted to Geomatic Engineering and Civil retains Building Construction',
    () {
      final g = {
        ...core(),
        'Elective Mathematics': 6,
        'Physics': 6,
        'Geography': 6,
      };
      expect(
        assessPathway(
          rule('expanded-20261027-umat-geomatic'),
          g,
          now: now,
        ).academicPass,
        isTrue,
      );
      expect(
        assessPathway(
          rule('expanded-20261027-umat-mining'),
          g,
          now: now,
        ).academicPass,
        isFalse,
      );
      expect(
        assessPathway(rule('expanded-20261027-umat-civil-essikado'), {
          ...core(),
          'Elective Mathematics': 6,
          'Physics': 6,
          'Building Construction': 6,
        }, now: now).academicPass,
        isTrue,
      );
      expect(
        assessPathway(rule('expanded-20261027-umat-mining'), {
          ...core(),
          'Elective Mathematics': 6,
          'Physics': 6,
          'Building Construction': 6,
        }, now: now).academicPass,
        isFalse,
      );
    },
  );
  test(
    '768 independent UMaT combinations retain mandatory subjects, C6 boundaries and arithmetic',
    () {
      final random = Random(202611019);
      for (final slug in ['mining', 'geomatic', 'civil-essikado']) {
        final r = rule('expanded-20261027-umat-$slug');
        for (var n = 0; n < 256; n++) {
          final g = {
            for (final s in [
              ...coreSubjects,
              'Elective Mathematics',
              'Physics',
              'Chemistry',
              'Geography',
              'Building Construction',
              'Government',
            ])
              s: 1 + random.nextInt(9),
          };
          final third = slug == 'geomatic'
              ? min(g['Chemistry']!, g['Geography']!)
              : slug == 'civil-essikado'
              ? min(g['Chemistry']!, g['Building Construction']!)
              : g['Chemistry']!;
          final required = [
            g['English Language']!,
            g['Core Mathematics']!,
            g['Integrated Science']!,
            g['Elective Mathematics']!,
            g['Physics']!,
            third,
          ];
          final expected = required.every((v) => v <= 6);
          final a = assessPathway(r, g, now: now);
          expect(a.academicPass, expected, reason: '$slug case $n');
          if (expected) {
            expect(a.aggregate, required.reduce((a, b) => a + b));
            expect(a.countedSubjects, hasLength(6));
          }
        }
      }
    },
  );
  test(
    'every affected academic check remains disabled when its source changes, is unavailable or is stale',
    () {
      final review = jsonDecode(
        File('reports/remaining-nine-review.json').readAsStringSync(),
      );
      final ids = <String>{
        for (final source in review['confirmations'])
          for (final id in source['academicRuleIds']) id as String,
      };
      final g = {...core(1), for (final s in electiveSubjects) s: 1};
      for (final id in ids) {
        final r = rule(id);
        expect(
          assessPathway(
            AdmissionRule({...r.data, 'status': 'needs_source_review'}),
            g,
            now: now,
          ).academicPass,
          isFalse,
        );
        expect(
          assessPathway(r, g, now: DateTime(2027, 11, 1)).academicPass,
          isFalse,
        );
      }
    },
  );
}
