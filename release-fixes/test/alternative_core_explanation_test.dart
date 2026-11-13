import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:skoolatlas/tertiary_data.dart';

void main() {
  final feed = jsonDecode(File('web/tertiary-feed.json').readAsStringSync()) as Map<String, dynamic>;
  final store = TertiaryStore()..applyFeed(feed);
  final rule = store.rules.singleWhere((r) =>
      r.institution == 'Ho Technical University' &&
      r.programme == 'Bachelor of Technology Fashion Design & Textiles');
  final now = DateTime(2026, 11, 8);
  final grades = {'English Language': 6, 'Core Mathematics': 6,
    'Economics': 6, 'Geography': 6, 'Government': 6};

  test('Missing alternative cores names both permitted subjects', () {
    final result = assessPathway(rule, grades, now: now);
    expect(result.academicPass, isFalse);
    expect(result.reasons.join(' '), contains('Integrated Science OR Social Studies'));
  });
  test('Social Studies satisfies alternative core without Integrated Science', () {
    final result = assessPathway(rule, {...grades, 'Social Studies': 6}, now: now);
    expect(result.academicPass, isTrue);
    expect(result.aggregate, 36);
    expect(result.countedSubjects.containsKey('Integrated Science'), isFalse);
  });
  test('Entered failing core is not described as two missing cores', () {
    final result = assessPathway(rule, {...grades, 'Social Studies': 7}, now: now);
    expect(result.academicPass, isFalse);
    expect(result.reasons.join(' '), isNot(contains('Integrated Science OR Social Studies')));
  });
  test('Both failing alternative cores name both permitted corrections', () {
    final result = assessPathway(rule, {...grades,
      'Integrated Science': 8, 'Social Studies': 7}, now: now);
    expect(result.academicPass, isFalse);
    expect(result.reasons.join(' '),
        contains('Integrated Science OR Social Studies needs C6 or better.'));
  });
  test('Failed core explains the unentered alternative without assuming a pass', () {
    for (final failed in ['Integrated Science', 'Social Studies']) {
      final other = failed == 'Integrated Science'
          ? 'Social Studies' : 'Integrated Science';
      final result = assessPathway(rule, {...grades, failed: 9}, now: now,
          hasAwaitingResults: true);
      expect(result.academicPass, isFalse);
      expect(result.reasons.join(' '), contains('$other at C6'));
      expect(result.reasons.join(' '), contains('not assumed to pass'));
      final resolved = assessPathway(rule,
          {...grades, failed: 9, other: 6}, now: now);
      expect(resolved.academicPass, isTrue);
      expect(resolved.countedSubjects.containsKey(failed), isFalse);
    }
  });
  test('Passing alternative is accepted despite the other failing', () {
    final result = assessPathway(rule, {...grades,
      'Integrated Science': 8, 'Social Studies': 6}, now: now);
    expect(result.academicPass, isTrue);
    expect(result.aggregate, 36);
    expect(result.countedSubjects.containsKey('Integrated Science'), isFalse);
  });
}
