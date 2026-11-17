import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:skoolatlas/tertiary_data.dart';
import 'package:skoolatlas/student_journey.dart';

void main() {
  final store = TertiaryStore()
    ..applyFeed(
      Map<String, dynamic>.from(
        jsonDecode(File('web/tertiary-feed.json').readAsStringSync()),
      ),
    );
  final now = DateTime(2026, 10, 28, 18);
  AdmissionRule rule(String id) =>
      store.rules.singleWhere((r) => r.id == 'regional-20261028-$id');
  MatchAssessment check(String id, Map<String, int> g) =>
      assessPathway(rule(id), g, now: now);
  final core = {for (final c in coreSubjects) c: 6};
  const pa = [
    'Geography',
    'Economics',
    'Government',
    'History',
    'Elective Mathematics',
    'Literature in English',
    'French',
    'Physics',
    'Chemistry',
    'Biology',
  ];
  const pb = ['Accounting', 'Business Management'];
  const arts = [
    'Geography',
    'Economics',
    'Government',
    'History',
    'Elective Mathematics',
    'ICT',
  ];
  const tech = [
    'Technical Drawing',
    'Building Construction',
    'Elective Mathematics',
    'ICT',
  ];
  const da = [
    'Geography',
    'Economics',
    'Elective Mathematics',
    'Government',
    'History',
    'Graphic Design',
    'Technical Drawing',
    'Building Construction',
    'Business Management',
    'General Knowledge in Art',
  ];
  const db = [
    'Accounting',
    'Business Management',
    'Picture Making',
    'Ceramics',
    'Sculpture',
    'Literature in English',
    'ICT',
  ];
  test(
    'regional publication validates and keeps programme and general scopes separate',
    () {
      expect(store.rules, hasLength(599));
      expect(
        store.rules.where((r) => r.data['scope'] == 'programme'),
        hasLength(542),
      );
      for (final id in [
        'ubids-planning',
        'ubids-urban-design',
        'ubids-urban-diploma',
        'utas-nursing',
        'utas-midwifery',
        'utas-general-2026',
      ]) {
        final r = rule(id);
        expect(() => validateAdmissionRule(r), returnsNormally);
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
      expect(rule('utas-general-2026').data['scope'], 'institution_general');
      expect(rule('ubids-planning').data['programmeRegions'], ['Upper West']);
      expect(rule('utas-nursing').data['programmeRegions'], ['Upper East']);
    },
  );
  test(
    'Planning permits three A or two A and one B; Science remains required',
    () {
      final g = {...core, 'Geography': 6, 'Economics': 6, 'Accounting': 6};
      expect(check('ubids-planning', g).academicPass, isTrue);
      expect(check('ubids-planning', g).aggregate, 36);
      expect(
        check('ubids-planning', {
          ...core,
          'Geography': 1,
          'Accounting': 1,
          'Business Management': 1,
        }).academicPass,
        isFalse,
      );
      expect(
        check('ubids-planning', {
          ...g,
          'Integrated Science': 7,
          'Social Studies': 1,
        }).academicPass,
        isFalse,
      );
      expect(
        check('ubids-planning', {...g, 'English Language': 7}).academicPass,
        isFalse,
      );
      expect(
        check('ubids-planning', {
          ...core,
          'Geography': 1,
          'Economics': 1,
          'Christian Religious Studies': 1,
        }).academicPass,
        isFalse,
      );
    },
  );
  test(
    'degree and diploma grades stay distinct and diploma does not inherit an invented aggregate cap',
    () {
      final g = {
        for (final c in coreSubjects) c: 7,
        'Geography': 6,
        'Economics': 6,
        'Accounting': 6,
      };
      final a = check('ubids-urban-diploma', g);
      expect(a.academicPass, isTrue);
      expect(a.aggregate, 39);
      expect(rule('ubids-urban-diploma').data['maxAggregate'], isNull);
      expect(check('ubids-planning', g).academicPass, isFalse);
      expect(
        check('ubids-urban-diploma', {
          ...g,
          'English Language': 8,
        }).academicPass,
        isFalse,
      );
      expect(
        check('ubids-urban-diploma', {...g, 'Accounting': 7}).academicPass,
        isFalse,
      );
      expect(
        check('ubids-urban-diploma', {
          ...g,
          'Integrated Science': 9,
        }).academicPass,
        isTrue,
      );
      expect(
        check('ubids-urban-diploma', {
          ...g,
          'Integrated Science': 9,
          'Social Studies': 8,
        }).academicPass,
        isFalse,
      );
    },
  );
  test(
    'Urban Design separates General Arts and Technical lists and holds ambiguous mappings',
    () {
      expect(
        check('ubids-urban-design', {
          ...core,
          'Geography': 6,
          'Economics': 6,
          'History': 6,
        }).academicPass,
        isTrue,
      );
      expect(
        check('ubids-urban-design', {
          ...core,
          'Technical Drawing': 6,
          'Building Construction': 6,
          'ICT': 6,
        }).academicPass,
        isTrue,
      );
      expect(
        check('ubids-urban-design', {
          ...core,
          'Government': 1,
          'Technical Drawing': 1,
          'Elective Mathematics': 1,
        }).academicPass,
        isFalse,
      );
      expect(
        check('ubids-urban-design', {
          ...core,
          'Graphic Design': 1,
          'Picture Making': 1,
          'Ceramics': 1,
        }).academicPass,
        isFalse,
      );
    },
  );
  test(
    'UTAS health routes and their undated 14 cutoff cannot produce current-year approval',
    () {
      final g = {
        for (final c in coreSubjects) c: 1,
        'Biology': 1,
        'Chemistry': 1,
        'Physics': 1,
        'Elective Mathematics': 1,
      };
      for (final id in ['utas-nursing', 'utas-midwifery']) {
        expect(check(id, g).academicPass, isFalse);
        expect(check(id, g).status, 'Additional route information needed');
        expect(
          assessCutoff(
            rule(id),
            6,
            academicPass: true,
            targetCycle: '2026/2027',
            now: now,
          ).status,
          'Cutoff needs verification',
        );
        expect(check(id, {...g, 'Accounting': 1}).academicPass, isFalse);
      }
      expect(
        check('utas-general-2026', {
          ...g,
          'Integrated Science': 9,
          'Social Studies': 1,
        }).academicPass,
        isFalse,
      );
    },
  );
  test(
    'dated resources preserve fee columns, deadline and closed scholarship status',
    () {
      final resources = store.journey.resources;
      final fees = (resources['fees'] as List)
          .where((r) => r['id'].startsWith('regional-20261028-'))
          .toList();
      expect(fees, hasLength(4));
      expect(
        fees.singleWhere(
          (r) => r['id'] == 'regional-20261028-utas-application',
        )['amount'],
        200,
      );
      final planning = fees.singleWhere(
        (r) => r['id'] == 'regional-20261028-ubids-planning',
      );
      expect(planning['amount'], 2840.93);
      expect(planning['amount'], isNot(2798.93));
      expect(fees.every((r) => r['costType'] != 'tuition'), isTrue);
      expect(
        fees.any((r) => r['institutionId'] == 'gtec:899' && r['amount'] == 0),
        isFalse,
      );
      final deadlines = (resources['deadlines'] as List).where(
        (r) => r['id'].startsWith('regional-20261028-'),
      );
      expect(deadlines, hasLength(2));
      expect(
        deadlines.every(
          (r) => r['date'] == '2026-10-31' && r['cycle'] == '2026/2027',
        ),
        isTrue,
      );
      final scholarship = (resources['scholarships'] as List).singleWhere(
        (r) => r['id'] == 'regional-20261028-utas-eazi-closed',
      );
      expect(scholarship['title'], contains('applications closed'));
      expect(scholarship['date'], isNull);
    },
  );
  test(
    'closed calls without dates are hidden by default and retain an honest label',
    () {
      final closed = {'date': null, 'availability': 'closed'};
      expect(resourceIsClosed(closed, now: now), isTrue);
      expect(
        resourceDeadlineState(closed, now: now),
        'Closed by official source',
      );
      expect(resourceIsClosed({'date': null}, now: now), isFalse);
      expect(
        resourceDeadlineState({'date': null}, now: now),
        'Date not confirmed',
      );
      expect(resourceIsClosed({'date': '2026-10-27'}, now: now), isTrue);
      expect(resourceIsClosed({'date': '2026-10-31'}, now: now), isFalse);
      final row = (store.journey.resources['scholarships'] as List).singleWhere(
        (r) => r['id'] == 'regional-20261028-utas-eazi-closed',
      );
      expect(resourceIsClosed(row, now: now), isTrue);
    },
  );
  test(
    '1536 independent combinations preserve categories, core ceilings, sums and source quarantine',
    () {
      const ids = [
        'ubids-planning',
        'ubids-urban-design',
        'ubids-urban-diploma',
        'utas-nursing',
        'utas-midwifery',
        'utas-general-2026',
      ];
      final pool = {
        ...pa,
        ...pb,
        ...da,
        ...db,
        'Cost Accounting',
        'Christian Religious Studies',
      }.toList();
      final random = Random(281030);
      for (final id in ids) {
        for (var n = 0; n < 256; n++) {
          final choices = [...pool]..shuffle(random);
          final g = {
            for (final c in coreSubjects) c: 1 + random.nextInt(9),
            for (final e in n.isEven ? pool : choices.take(4))
              e: 1 + random.nextInt(9),
          };
          bool credit(String s) => (g[s] ?? 99) <= 6;
          bool triple(
            List<String> allowed,
            List<String> counted,
            int required,
          ) =>
              allowed.where(credit).length >= 3 &&
              counted.where(credit).length >= required;
          final corePass = id == 'ubids-urban-diploma'
              ? (g['English Language']! <= 7 &&
                    g['Core Mathematics']! <= 7 &&
                    (g['Integrated Science']! <= 7 ||
                        g['Social Studies']! <= 7))
              : (credit('English Language') &&
                    credit('Core Mathematics') &&
                    credit('Integrated Science'));
          final subjectPass = switch (id) {
            'ubids-planning' => triple([...pa, ...pb], pa, 2),
            'ubids-urban-design' =>
              arts.where(credit).length >= 3 || tech.where(credit).length >= 3,
            'ubids-urban-diploma' => triple({...da, ...db}.toList(), da, 2),
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
