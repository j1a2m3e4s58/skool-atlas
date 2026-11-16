import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skoolatlas/curriculum_planner.dart';
import 'package:skoolatlas/tertiary_app.dart';
import 'package:skoolatlas/tertiary_data.dart';

void main() {
  test('Ministry catalogue contains all 46 entries without legacy aliases', () {
    expect(newCurriculumSubjects.length, 46);
    expect(newCurriculumSubjects.toSet().length, 46);
    expect(newCurriculumSubjects, containsAll([
      'Art and Design Foundation', 'Arts and Design Studio',
      'Intervention Mathematics', 'Intervention English',
      'Robotics', 'Spanish', 'General Science', 'Additional Mathematics',
      'Core Physical Education and Health (PEH)',
      'Elective Physical Education and Health (PEH)',
    ]));
    expect(electiveSubjects, isNot(contains('Arts and Design Studio')));
    expect(electiveSubjects, contains('General Knowledge in Art'));
    expect(curriculumSubjectLabel('Arts and Design Studio'), contains('ADS'));
  });

  for (final width in [320.0, 390.0, 1280.0]) {
    testWidgets('Separate curricula preserve grades and pending guidance at $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = TertiaryStore()
        ..sessionGrades['Core Mathematics'] = 6
        ..newCurriculumGrades['Art and Design Foundation'] = 8;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: GradePlanner(store: store)),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New curriculum'));
      await tester.pumpAndSettle();
      expect(find.text('Art and Design Foundation (ADF)'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'ADS');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Arts and Design Studio (ADS)'));
      await tester.tap(find.text('Arts and Design Studio (ADS)'));
      await tester.pumpAndSettle();
      expect(store.newCurriculumGrades['Arts and Design Studio'], 0);
      final grade = find.byKey(const ValueKey('new-grade-Art and Design Foundation'));
      await Scrollable.ensureVisible(tester.element(grade), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(grade);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('F9').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('F9').last);
      await tester.pumpAndSettle();
      expect(store.newCurriculumGrades['Art and Design Foundation'], 9);
      await tester.ensureVisible(find.text('Check new-curriculum guidance'));
      await tester.tap(find.text('Check new-curriculum guidance'));
      await tester.pumpAndSettle();
      expect(find.text(newCurriculumPending), findsOneWidget);
      expect(find.text('Meets checked academic minimum'), findsNothing);
      await tester.tap(find.text('Old curriculum'));
      await tester.pumpAndSettle();
      expect(store.sessionGrades, {'Core Mathematics': 6});
      await tester.tap(find.text('New curriculum'));
      await tester.pumpAndSettle();
      expect(store.newCurriculumGrades['Art and Design Foundation'], 9);
      await tester.ensureVisible(find.text('Clear new-curriculum results'));
      await tester.tap(find.text('Clear new-curriculum results'));
      await tester.pumpAndSettle();
      expect(store.newCurriculumGrades, isEmpty);
      expect(store.sessionGrades['Core Mathematics'], 6);
      expect(tester.takeException(), isNull);
    });
  }
}
