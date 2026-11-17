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
  final now = DateTime(2026, 10, 28, 21);
  const ids = [
    'food-science',
    'agricultural-education',
    'agricultural-food-economics',
    'biodiversity',
    'natural-resources',
    'environmental-management',
    'forest-conservation',
    'veterinary-nursing',
  ];
  const science = ['Biology', 'Chemistry', 'Physics', 'Elective Mathematics'];
  const arts = [
    'Geography',
    'Economics',
    'Government',
    'History',
    'Elective Mathematics',
  ];
  final core = {for (final c in coreSubjects) c: 6};
  AdmissionRule rule(String id) =>
      store.rules.singleWhere((r) => r.id == 'uds-agri-20261028-$id');
  MatchAssessment check(String id, Map<String, int> g) =>
      assessPathway(rule(id), g, now: now);
  test(
    'eight Nyankpala records validate, remain unique and retain evidence and campus',
    () {
      expect(store.rules, hasLength(599));
      expect(
        store.rules.where((r) => r.data['scope'] == 'programme'),
        hasLength(542),
      );
      for (final id in ids) {
        final r = rule(id);
        expect(() => validateAdmissionRule(r), returnsNormally);
        expect(r.data['campus'], 'Nyankpala Campus');
        expect(r.data['programmeRegions'], ['Northern']);
        expect(r.data['competitiveCutoff'], isNull);
        expect(r.data['cycle'], contains('not stated'));
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
    'science and agriculture courses cannot borrow an Arts combination or a Social core',
    () {
      for (final id in ids.take(3)) {
        final g = {
          ...core,
          'Agricultural Science': 6,
          'Chemistry': 6,
          'Physics': 6,
        };
        expect(check(id, g).academicPass, isTrue);
        expect(check(id, g).aggregate, 36);
        expect(
          check(id, {
            ...core,
            'Geography': 1,
            'Economics': 1,
            'Government': 1,
          }).academicPass,
          isFalse,
        );
        expect(
          check(id, {
            ...g,
            'Integrated Science': 7,
            'Social Studies': 1,
          }).academicPass,
          isFalse,
        );
      }
    },
  );
  test(
    'Biodiversity preserves separate categories and both alternative groups in category B',
    () {
      final g = {
        ...core,
        'Agricultural Science': 6,
        'Animal Husbandry': 6,
        'Elective Mathematics': 6,
      };
      expect(check('biodiversity', g).academicPass, isTrue);
      expect(
        check('biodiversity', {
          ...g,
          'Animal Husbandry': 7,
          'Chemistry': 1,
        }).academicPass,
        isFalse,
      );
      expect(
        check('biodiversity', {
          ...core,
          'Agricultural Science': 1,
          'Animal Husbandry': 1,
          'Crop Husbandry and Horticulture': 1,
        }).academicPass,
        isFalse,
      );
      expect(
        check('biodiversity', {
          ...core,
          'Geography': 6,
          'Economics': 6,
          'Elective Mathematics': 6,
        }).academicPass,
        isTrue,
      );
      expect(
        check('biodiversity', {
          ...core,
          'Biology': 1,
          'Chemistry': 1,
          'Geography': 1,
        }).academicPass,
        isFalse,
      );
    },
  );
  test(
    'Natural Resources retains C4 Science and whole-results confirmation even with excellent grades',
    () {
      final g = {
        ...core,
        'Integrated Science': 4,
        'Biology': 1,
        'Chemistry': 1,
        'Physics': 1,
      };
      expect(rule('natural-resources').data['gradeFloors'], {
        'Integrated Science': 4,
      });
      expect(check('natural-resources', g).academicPass, isFalse);
      expect(
        check('natural-resources', g).status,
        'Additional route information needed',
      );
      expect(
        check('natural-resources', {
          ...g,
          'Integrated Science': 5,
          'Social Studies': 1,
        }).academicPass,
        isFalse,
      );
      expect(
        check('natural-resources', {...g, 'French': 7}).academicPass,
        isFalse,
      );
    },
  );
  test(
    'Environmental Management enforces the Arts prerequisite while allowing its published alternative core',
    () {
      final g = {
        ...core,
        'Integrated Science': 9,
        'Social Studies': 6,
        'Geography': 6,
        'Government': 6,
        'History': 6,
      };
      expect(check('environmental-management', g).academicPass, isTrue);
      expect(
        check('environmental-management', {
          ...g,
          'Geography': 7,
          'Elective Mathematics': 1,
        }).academicPass,
        isFalse,
      );
      expect(
        check('environmental-management', {
          ...core,
          'Biology': 6,
          'Chemistry': 6,
          'Physics': 6,
        }).academicPass,
        isTrue,
      );
      expect(
        check('forest-conservation', {
          ...core,
          'Geography': 1,
          'Economics': 1,
          'Elective Mathematics': 1,
        }).academicPass,
        isFalse,
      );
    },
  );
  test(
    'Veterinary Nursing keeps its science and agriculture combinations distinct',
    () {
      final g = {
        ...core,
        'Integrated Science': 9,
        'Social Studies': 6,
        'Agricultural Science': 6,
        'Chemistry': 6,
        'Physics': 6,
      };
      expect(check('veterinary-nursing', g).academicPass, isTrue);
      expect(
        check('veterinary-nursing', {
          ...core,
          'Chemistry': 6,
          'Physics': 6,
          'Elective Mathematics': 6,
        }).academicPass,
        isTrue,
      );
      expect(
        check('veterinary-nursing', {
          ...core,
          'Biology': 1,
          'Chemistry': 1,
          'Elective Mathematics': 1,
        }).academicPass,
        isFalse,
      );
      expect(
        check('veterinary-nursing', {...g, 'English Language': 7}).academicPass,
        isFalse,
      );
    },
  );
  test(
    '2048 independent combinations preserve category requirements, grade limits and source quarantine',
    () {
      const pool = [
        ...science,
        'Agricultural Science',
        'Animal Husbandry',
        'Crop Husbandry and Horticulture',
        'Geography',
        'Economics',
        'Government',
        'History',
        'French',
        'Accounting',
      ];
      final random = Random(281032);
      for (final id in ids) {
        for (var n = 0; n < 256; n++) {
          final choices = [...pool]..shuffle(random);
          final g = {
            for (final c in coreSubjects) c: 1 + random.nextInt(9),
            for (final e in n.isEven ? pool : choices.take(4))
              e: 1 + random.nextInt(9),
          };
          bool credit(String s) => (g[s] ?? 99) <= 6;
          final optionCore = [
            'environmental-management',
            'veterinary-nursing',
          ].contains(id);
          final corePass =
              credit('English Language') &&
              credit('Core Mathematics') &&
              (credit('Integrated Science') ||
                  (optionCore && credit('Social Studies')));
          final agScience =
              [...science, 'Agricultural Science'].where(credit).length >= 3;
          final catA =
              credit('Biology') &&
              credit('Chemistry') &&
              (credit('Physics') || credit('Elective Mathematics'));
          final catB =
              credit('Agricultural Science') &&
              (credit('Animal Husbandry') ||
                  credit('Crop Husbandry and Horticulture')) &&
              ['Chemistry', 'Physics', 'Elective Mathematics'].any(credit);
          final catC = [
            'Geography',
            'Economics',
            'Elective Mathematics',
          ].every(credit);
          final subjects = switch (id) {
            'food-science' ||
            'agricultural-education' ||
            'agricultural-food-economics' => agScience,
            'biodiversity' => catA || catB || catC,
            'forest-conservation' => catA || catB,
            'environmental-management' =>
              agScience ||
                  (arts.where(credit).length >= 3 &&
                      (credit('Economics') || credit('Geography'))),
            'veterinary-nursing' =>
              credit('Chemistry') &&
                  credit('Physics') &&
                  (credit('Biology') ||
                      credit('Elective Mathematics') ||
                      credit('Agricultural Science')),
            _ => false,
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
