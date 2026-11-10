import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skoolatlas/tertiary_data.dart';
import 'package:skoolatlas/pathway_result_card.dart';

void main() {
  final rows =
      jsonDecode(
            File('assets/tertiary/admissions.json').readAsStringSync(),
          )['rules']
          as List;
  final rule = AdmissionRule(
    Map<String, dynamic>.from(
      rows.singleWhere((r) => r['id'] == 'ug-wassce-23'),
    ),
  );
  final alternate = AdmissionRule(
    Map<String, dynamic>.from(
      rows.singleWhere((r) => r['id'] == 'ug-wassce-18'),
    ),
  );
  final grades = {
    'English Language': 2,
    'Core Mathematics': 2,
    'Integrated Science': 2,
    'Social Studies': 2,
    'Elective Mathematics': 3,
    'Physics': 2,
    'Chemistry': 2,
  };
  for (final width in [320.0, 390.0, 1280.0]) {
    testWidgets('readable details and actions at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var tracked = false;
      String? source;
      final result = assessRule(rule, grades);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(width == 320 ? 1.25 : 1),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: PathwayResultCard(
                      recommendation: PathwayRecommendation(rule, result, 4, [
                        'Matches your interests: Computing & data.',
                      ], []),
                      confirmed: true,
                      awaiting: [],
                      notTaken: [],
                      nextSteps: [],
                      alternatives: [],
                      openSource: (url) => source = url,
                      openAlternative: (_) {},
                      track: () => tracked = true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Meets checked academic minimum'), findsOneWidget);
      expect(find.text('Cutoff needs verification'), findsOneWidget);
      expect(find.text('Elective Mathematics: B3 (3)'), findsNothing);
      Future<void> tap(String label) async {
        final target = find.text(label).first;
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      await tap('Why this appears');
      expect(
        find.text('Matches your interests: Computing & data.'),
        findsOneWidget,
      );
      await tap('Your six counted subjects');
      expect(find.text('Elective Mathematics: B3 (3)'), findsOneWidget);
      await tap('What the published rule checks');
      expect(find.textContaining('Academic aggregate limit:'), findsOneWidget);
      await tap('Cutoff details & source');
      expect(
        find.textContaining('no cutoff match is inferred'),
        findsOneWidget,
      );
      await tap('Official cutoff table');
      expect(source, startsWith('https://'));
      await tap('Track this programme');
      expect(tracked, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('failed card retains alternatives and next steps', (
    tester,
  ) async {
    final result = assessRule(rule, {...grades, 'Elective Mathematics': 4});
    AdmissionRule? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PathwayResultCard(
              recommendation: PathwayRecommendation(rule, result, 0, [], []),
              confirmed: false,
              awaiting: [],
              notTaken: [],
              nextSteps: [(subject: 'Elective Mathematics', grade: 3)],
              alternatives: [
                PathwayRecommendation(
                  alternate,
                  assessRule(alternate, grades),
                  0,
                  [],
                  [],
                ),
              ],
              openSource: (_) {},
              openAlternative: (rule) => opened = rule,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final label in [
      'What could change this result?',
      'Related courses to consider',
      alternate.programme,
    ]) {
      final target = find.text(label).first;
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
    }
    expect(opened?.id, alternate.id);
    expect(
      find.textContaining('Hypothetically, Elective Mathematics at B3'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('empty alternatives and not-taken cores never imply eligibility', (tester) async {
    final incomplete = {...grades}..remove('English Language');
    final result = assessRule(rule, incomplete);
    expect(result.academicPass, isFalse);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: PathwayResultCard(
        recommendation: PathwayRecommendation(rule, result, 0, [], []),
        confirmed: false, awaiting: [], notTaken: ['English Language'],
        nextSteps: [], alternatives: [], openSource: (_) {}, openAlternative: (_) {},
      ),
    ))));
    await tester.pumpAndSettle();
    expect(find.textContaining('does not waive a compulsory subject requirement'), findsOneWidget);
    final section = find.text('Related courses to consider');
    await tester.ensureVisible(section);
    await tester.tap(section);
    await tester.pumpAndSettle();
    expect(find.textContaining('No verified related alternative was found'), findsOneWidget);
    expect(find.textContaining('These alternatives meet their checked academic minimum'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
