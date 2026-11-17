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
  final now = DateTime(2026, 10, 28, 20);
  const ids = [
    'physician-assistantship',
    'medical-laboratory-science',
    'dental-surgery-assistantship',
    'diagnostic-radiological-technology',
    'health-information-management',
    'disease-control-epidemiology',
    'nutrition',
    'health-promotion',
    'community-mental-health',
  ];
  const science = ['Biology', 'Chemistry', 'Physics', 'Elective Mathematics'];
  final core = {for (final c in coreSubjects) c: 6};
  AdmissionRule rule(String id) =>
      store.rules.singleWhere((r) => r.id == 'kintampo-20261028-$id');
  MatchAssessment check(String id, Map<String, int> g) =>
      assessPathway(rule(id), g, now: now);
  test(
    'nine regular routes validate with unique identity, age warning and no invented annual cutoff',
    () {
      expect(store.rules, hasLength(599));
      expect(
        store.rules.where((r) => r.data['scope'] == 'programme'),
        hasLength(542),
      );
      for (final id in ids) {
        final r = rule(id);
        expect(() => validateAdmissionRule(r), returnsNormally);
        expect(r.data['institutionId'], 'gtec:778');
        expect(r.data['programmeRegions'], ['Bono East']);
        expect(r.data['competitiveCutoff'], isNull);
        expect(r.data['cycle'], contains('not stated'));
        expect(
          (r.data['additionalConditions'] as List).join(' '),
          contains('16–35'),
        );
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
    'Physician Assistantship requires Physics, Chemistry and Biology, not Mathematics instead of Physics',
    () {
      final g = {...core, 'Biology': 6, 'Chemistry': 6, 'Physics': 6};
      expect(check(ids[0], g).academicPass, isTrue);
      expect(check(ids[0], g).aggregate, 36);
      expect(
        check(ids[0], {
          ...g,
          'Physics': 7,
          'Elective Mathematics': 1,
        }).academicPass,
        isFalse,
      );
      expect(
        check(ids[0], {...g, 'Chemistry': 7, 'French': 1}).academicPass,
        isFalse,
      );
    },
  );
  test(
    'laboratory route retains its confirmed combination and flags unresolved alternatives',
    () {
      final g = {
        ...core,
        'Biology': 6,
        'Chemistry': 6,
        'Elective Mathematics': 6,
      };
      expect(check(ids[1], g).academicPass, isTrue);
      final other = {
        ...core,
        'Chemistry': 1,
        'Physics': 1,
        'Elective Mathematics': 1,
      };
      expect(check(ids[1], other).academicPass, isFalse);
      expect(
        check(ids[1], other).status,
        'Additional route information needed',
      );
      expect(check(ids[2], other).academicPass, isTrue);
      expect(check(ids[3], other).academicPass, isTrue);
    },
  );
  test(
    'non-science electives are allowed for five courses but Science core is never replaced by Social Studies',
    () {
      final arts = {...core, 'French': 6, 'History': 6, 'Government': 6};
      for (final id in ids.skip(4)) {
        expect(check(id, arts).academicPass, isTrue);
        expect(check(id, arts).aggregate, 36);
        expect(
          check(id, {
            ...arts,
            'Integrated Science': 7,
            'Social Studies': 1,
          }).academicPass,
          isFalse,
        );
        expect(
          check(id, {...arts, 'English Language': 7}).academicPass,
          isFalse,
        );
        expect(check(id, {...arts, 'French': 7}).academicPass, isFalse);
      }
      expect(
        check(ids[3], {
          ...core,
          'Biology': 6,
          'Chemistry': 6,
          'Physics': 6,
          'Core Mathematics': 7,
        }).academicPass,
        isFalse,
      );
    },
  );
  test(
    'blank and incomplete grades, predicted results and changed evidence cannot become an admission offer',
    () {
      for (final id in ids) {
        expect(check(id, {}).academicPass, isFalse);
        expect(
          check(id, {...core, 'Biology': 1, 'Chemistry': 1}).academicPass,
          isFalse,
        );
        final g = {...core, for (final s in science) s: 1};
        final predicted = assessPathway(
          rule(id),
          g,
          resultBasis: 'Predicted results',
          now: now,
        );
        expect(predicted.status, contains('Provisional'));
        expect(predicted.cutoff.status, contains('Predicted'));
        expect(
          assessPathway(
            AdmissionRule({...rule(id).data, 'status': 'needs_source_review'}),
            g,
            now: now,
          ).academicPass,
          isFalse,
        );
      }
    },
  );
  test(
    '2304 independently derived combinations preserve subjects, credit ceilings, aggregate sums and quarantine',
    () {
      const pool = [
        ...science,
        'French',
        'History',
        'Government',
        'Accounting',
        'Economics',
        'Textiles',
        'Agricultural Science',
      ];
      final random = Random(281031);
      for (final id in ids) {
        for (var n = 0; n < 256; n++) {
          final choices = [...pool]..shuffle(random);
          final g = {
            for (final c in coreSubjects) c: 1 + random.nextInt(9),
            for (final e in n.isEven ? pool : choices.take(4))
              e: 1 + random.nextInt(9),
          };
          bool credit(String s) => (g[s] ?? 99) <= 6;
          final corePass =
              credit('English Language') &&
              credit('Core Mathematics') &&
              credit('Integrated Science');
          final subjects = switch (id) {
            'physician-assistantship' => [
              'Biology',
              'Chemistry',
              'Physics',
            ].every(credit),
            'medical-laboratory-science' =>
              credit('Biology') &&
                  credit('Chemistry') &&
                  (credit('Physics') || credit('Elective Mathematics')),
            'dental-surgery-assistantship' ||
            'diagnostic-radiological-technology' =>
              science.where(credit).length >= 3,
            _ => pool.where(credit).length >= 3,
          };
          final a = check(id, g);
          expect(a.academicPass, corePass && subjects, reason: '$id case $n');
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
        }
      }
    },
  );
}
