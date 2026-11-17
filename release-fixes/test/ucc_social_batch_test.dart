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
  final now = DateTime(2026, 10, 28, 16);
  const science = ['Elective Mathematics', 'Physics', 'Chemistry', 'Biology'];
  const humanities = ['Literature in English', 'History', 'French'];
  const social = ['Elective Mathematics', 'Geography', 'Economics'];
  const arts = [
    'French',
    'Literature in English',
    'Music',
    'Government',
    'History',
    'Economics',
    'Geography',
  ];
  const anthropology = [
    'Economics',
    'Geography',
    'Elective Mathematics',
    'Government',
    'History',
  ];
  const population = [
    'Geography',
    'Economics',
    'Government',
    'History',
    'Business Management',
    'Food and Nutrition',
    'Management in Living',
    'Elective Mathematics',
  ];
  const ids = [
    'psychology',
    'arts',
    'anthropology',
    'population-and-health',
    'social-sciences',
    'communication-studies',
  ];
  final core = {for (final c in coreSubjects) c: 6};
  AdmissionRule rule(String id) =>
      store.rules.singleWhere((r) => r.id == 'ucc-social-20261028-$id');
  MatchAssessment check(String id, Map<String, int> g) =>
      assessPathway(rule(id), g, now: now);
  test(
    'six social and humanities records validate with unique identity and evidence',
    () {
      expect(store.rules, hasLength(600));
      expect(
        store.rules.where((r) => r.data['scope'] == 'programme'),
        hasLength(542),
      );
      for (final id in ids) {
        final r = rule(id);
        expect(() => validateAdmissionRule(r), returnsNormally);
        expect(r.data['institutionId'], 'gtec:878');
        expect(r.data['competitiveCutoff'], isNull);
        expect(
          (r.data['sourceEvidence'] as Map)['captureSha256'],
          hasLength(64),
        );
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
    'Psychology accepts each defined category but does not pool mixed categories',
    () {
      for (final subjects in [
        humanities,
        social,
        ['Biology', 'Chemistry', 'Physics'],
      ]) {
        final g = {
          ...core,
          'Integrated Science': 9,
          'Social Studies': 6,
          for (final s in subjects) s: 6,
        };
        expect(check('psychology', g).academicPass, isTrue);
        expect(check('psychology', g).aggregate, 36);
        expect(
          check('psychology', {...g, 'English Language': 7}).academicPass,
          isFalse,
        );
      }
      expect(
        check('psychology', {
          ...core,
          'Literature in English': 1,
          'Elective Mathematics': 1,
          'Physics': 1,
        }).academicPass,
        isFalse,
      );
      expect(
        check('psychology', {
          ...core,
          'Literature in English': 1,
          'History': 1,
          'Twi (Akuapem)': 1,
        }).status,
        'Additional route information needed',
      );
    },
  );
  test('Arts, Anthropology and Population lists are not interchangeable', () {
    final music = {...core, 'Music': 6, 'French': 6, 'Textiles': 6};
    expect(check('arts', music).academicPass, isTrue);
    expect(check('anthropology', music).academicPass, isFalse);
    final home = {
      ...core,
      'Integrated Science': 9,
      'Social Studies': 6,
      'Food and Nutrition': 6,
      'Management in Living': 6,
      'Textiles': 6,
    };
    expect(check('population-and-health', home).academicPass, isTrue);
    expect(check('arts', home).academicPass, isFalse);
    final gov = {...core, 'Government': 6, 'History': 6, 'Textiles': 6};
    expect(check('anthropology', gov).academicPass, isTrue);
    expect(
      check('anthropology', {...gov, 'Government': 7}).academicPass,
      isFalse,
    );
  });
  test(
    'Social Sciences requires six credits; unnamed third-elective relevance stays conditional',
    () {
      expect(
        check('social-sciences', {
          ...core,
          for (final s in social) s: 6,
        }).academicPass,
        isTrue,
      );
      expect(
        check('social-sciences', {
          ...core,
          'Economics': 6,
          'Geography': 6,
          'French': 6,
        }).status,
        'Additional route information needed',
      );
      expect(
        check('social-sciences', {
          ...core,
          'Economics': 1,
          'Geography': 1,
        }).academicPass,
        isFalse,
      );
    },
  );
  test(
    'Communication and ambiguous Religious Studies mappings cannot give confident approval',
    () {
      final g = {
        ...core,
        'Literature in English': 1,
        'French': 1,
        'Government': 1,
      };
      expect(check('communication-studies', g).academicPass, isFalse);
      expect(
        check('communication-studies', g).status,
        'Additional route information needed',
      );
      final religion = {
        ...core,
        'Christian Religious Studies': 1,
        'Ga': 1,
        'Textiles': 1,
      };
      expect(check('arts', religion).academicPass, isFalse);
      expect(
        check('arts', religion).status,
        'Additional route information needed',
      );
      expect(check('anthropology', religion).academicPass, isFalse);
    },
  );
  test(
    '1536 independent cases preserve categories, group counts and source quarantine',
    () {
      const pool = [
        ...science,
        'Literature in English',
        'History',
        'French',
        'Music',
        'Government',
        'Economics',
        'Geography',
        'Business Management',
        'Food and Nutrition',
        'Management in Living',
        'Textiles',
        'Christian Religious Studies',
        'Ga',
        'Accounting',
      ];
      final random = Random(281011);
      for (final id in ids) {
        for (var n = 0; n < 256; n++) {
          final choices = [...pool]..shuffle(random);
          final g = {
            for (final c in coreSubjects) c: 1 + random.nextInt(9),
            for (final e in (n.isEven ? pool : choices.take(4)))
              e: 1 + random.nextInt(9),
          };
          bool credit(String s) => (g[s] ?? 99) <= 6;
          final corePass =
              credit('English Language') &&
              credit('Core Mathematics') &&
              (credit('Integrated Science') || credit('Social Studies'));
          final enough = pool.where(credit).length >= 3;
          final subjectPass = switch (id) {
            'psychology' =>
              humanities.every(credit) ||
                  social.every(credit) ||
                  science.where(credit).length >= 3,
            'arts' => enough && arts.where(credit).length >= 2,
            'anthropology' => enough && anthropology.where(credit).length >= 2,
            'population-and-health' =>
              enough && population.where(credit).length >= 2,
            'social-sciences' => social.every(credit),
            _ => false,
          };
          final a = check(id, g);
          expect(
            a.academicPass,
            corePass && subjectPass,
            reason: '$id case $n',
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
