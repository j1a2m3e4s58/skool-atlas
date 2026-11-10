import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:skoolatlas/tertiary_data.dart';

void main() {
  final feed = jsonDecode(File('web/tertiary-feed.json').readAsStringSync()) as Map<String, dynamic>;
  final store = TertiaryStore()..applyFeed(feed);
  final now = DateTime(2026, 11, 4);
  final grades = {'English Language': 1, 'Core Mathematics': 1,
    'Integrated Science': 1, 'Biology': 1, 'Chemistry': 1, 'Physics': 1};
  test('Reviewed diploma routes use Ministry admission evidence; held copies cannot match', () {
    // These five routes superseded the original indexing-only records.
    // Grade boundaries are exercised in savannah_northeast_moh_test.dart.
    final ids = ['kpembe-rgn', 'kpembe-rm', 'damongo-rgn', 'nalerigu-rgn', 'nalerigu-rm']
        .map((id) => 'nmc-indexing-20261104-$id').toSet();
    final rules = store.rules.where((r) => ids.contains(r.id)).toList();
    expect(rules, hasLength(5));
    expect(rules.map((r) => r.data['campus']).toSet(), {'Kpembe', 'Damongo', 'Nalerigu'});
    for (final rule in rules) {
      validateAdmissionRule(rule);
      expect(Uri.parse(rule.data['sourceUrl'] as String).host, 'register.healthtraining.gov.gh');
      expect(rule.data['maxAggregate'], 36);
      final held = AdmissionRule({...rule.data, 'status': 'needs_source_review'});
      expect(assessPathway(held, grades, now: now).academicPass, isFalse);
    }
  });
  test('Kpembe NAP remains pending without numeric college admission requirements', () {
    final rule = store.rules.singleWhere((r) => r.id == 'nmc-indexing-20261104-kpembe-nap');
    expect(rule.data['status'], 'needs_source_review');
    expect(rule.data['maxAggregate'], isNull);
    for (final grade in [1, 6, 8, 9]) {
      final result = assessPathway(rule, grades.map((k, v) => MapEntry(k, grade)), now: now);
      expect(result.academicPass, isFalse);
      expect(result.aggregate, isNull);
    }
  });
}
