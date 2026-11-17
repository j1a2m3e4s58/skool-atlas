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
  final now = DateTime(2026, 10, 28, 13);
  AdmissionRule rule(String id) =>
      store.rules.singleWhere((r) => r.id == 'ucc-science-20261028-$id');
  MatchAssessment check(String id, Map<String, int> grades) =>
      assessPathway(rule(id), grades, now: now);
  final cores = {for (final c in coreSubjects) c: 6};
  final science = {
    ...cores,
    'Elective Mathematics': 6,
    'Physics': 6,
    'Chemistry': 6,
  };

  test('six unique UCC programme rules validate and retain their evidence', () {
    expect(store.rules, hasLength(599));
    expect(
      store.rules.where((r) => r.data['scope'] == 'programme'),
      hasLength(542),
    );
    final batch = store.rules
        .where((r) => r.id.startsWith('ucc-science-20261028-'))
        .toList();
    expect(batch, hasLength(6));
    for (final r in batch) {
      expect(() => validateAdmissionRule(r), returnsNormally);
      expect(r.data['institutionId'], 'gtec:878');
      expect(
        r.data['sourceUrl'],
        startsWith('https://admissions.ucc.edu.gh/catalogue/programme/'),
      );
      expect(r.data['competitiveCutoff'], isNull);
      expect((r.data['sourceEvidence'] as Map)['captureSha256'], hasLength(64));
    }
  });
  test(
    'all-six C6 passes aggregate 36; failed science cannot be replaced by Social Studies',
    () {
      for (final id in [
        'statistics',
        'mathematics',
        'chemistry',
        'physics',
        'engineering-physics',
      ]) {
        expect(check(id, science).academicPass, isTrue, reason: id);
        expect(check(id, science).aggregate, 36);
        expect(
          check(id, {
            ...science,
            'Integrated Science': 7,
            'Social Studies': 1,
          }).academicPass,
          isFalse,
          reason: id,
        );
        expect(
          check(id, {...science, 'English Language': 7}).academicPass,
          isFalse,
          reason: id,
        );
      }
    },
  );
  test('Geography is allowed for Mathematics but not Statistics', () {
    final g = {
      ...cores,
      'Elective Mathematics': 2,
      'Geography': 2,
      'Economics': 2,
    };
    expect(check('mathematics', g).academicPass, isTrue);
    expect(check('statistics', g).academicPass, isFalse);
    expect(
      check('statistics', {...g, 'Technical Drawing': 3}).academicPass,
      isTrue,
    );
  });
  test(
    'Actuarial Science permits its published business and Social Studies route',
    () {
      final g = {
        ...cores,
        'Integrated Science': 9,
        'Social Studies': 6,
        'Elective Mathematics': 6,
        'Cost Accounting': 6,
        'Accounting': 6,
      };
      expect(check('actuarial-science', g).academicPass, isTrue);
      expect(check('actuarial-science', g).aggregate, 36);
      expect(
        check('actuarial-science', {
          ...g,
          'Elective Mathematics': 7,
        }).academicPass,
        isFalse,
      );
      expect(
        check('actuarial-science', {
          ...g,
          'Accounting': 9,
          'Cost Accounting': 9,
          'French': 1,
          'Government': 1,
        }).academicPass,
        isFalse,
      );
    },
  );
  test(
    'Chemistry accepts Biology alternative; both Physics routes require Elective Mathematics',
    () {
      final g = {...cores, 'Chemistry': 2, 'Physics': 2, 'Biology': 2};
      expect(check('chemistry', g).academicPass, isTrue);
      expect(
        check('chemistry', {
          ...g,
          'Physics': 7,
          'Elective Mathematics': 1,
        }).academicPass,
        isFalse,
      );
      for (final id in ['physics', 'engineering-physics']) {
        expect(check(id, g).academicPass, isFalse);
        final a = check(id, {...science, 'French': 1});
        expect(a.academicPass, isTrue);
        expect(a.countedSubjects.containsKey('French'), isFalse);
        expect(a.aggregate, 36);
      }
    },
  );
  test(
    '1536 independent grade cases match the published subject lists and quarantine changed sources',
    () {
      const allowed = {
        'statistics': [
          'Elective Mathematics',
          'Physics',
          'Chemistry',
          'Economics',
          'Biology',
          'Technical Drawing',
        ],
        'mathematics': [
          'Elective Mathematics',
          'Physics',
          'Chemistry',
          'Economics',
          'Biology',
          'Technical Drawing',
          'Geography',
        ],
        'actuarial-science': [
          'Elective Mathematics',
          'Physics',
          'Chemistry',
          'Economics',
          'Geography',
          'Cost Accounting',
          'Business Management',
          'Accounting',
        ],
        'chemistry': [
          'Chemistry',
          'Physics',
          'Elective Mathematics',
          'Biology',
        ],
        'physics': ['Physics', 'Chemistry', 'Elective Mathematics'],
        'engineering-physics': ['Physics', 'Chemistry', 'Elective Mathematics'],
      };
      final random = Random(281006);
      for (final id in allowed.keys) {
        for (var n = 0; n < 256; n++) {
          final subjects = [...electiveSubjects]..shuffle(random);
          final g = {
            for (final c in coreSubjects) c: 1 + random.nextInt(9),
            for (final e in (n.isEven ? allowed[id]! : subjects.take(4)))
              e: 1 + random.nextInt(9),
          };
          bool credit(String s) => (g[s] ?? 99) <= 6;
          final corePass =
              credit('English Language') &&
              credit('Core Mathematics') &&
              (id == 'actuarial-science'
                  ? (credit('Integrated Science') || credit('Social Studies'))
                  : credit('Integrated Science'));
          final required = id == 'chemistry'
              ? ['Chemistry', 'Physics']
              : id.endsWith('physics')
              ? ['Chemistry', 'Physics', 'Elective Mathematics']
              : ['Elective Mathematics'];
          final expected =
              corePass &&
              required.every(credit) &&
              allowed[id]!.where(credit).length >= 3;
          final a = check(id, g);
          expect(a.academicPass, expected, reason: '$id case $n');
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
