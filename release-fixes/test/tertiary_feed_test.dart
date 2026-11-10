import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:skoolatlas/tertiary_data.dart';

Map<String, dynamic> feed() => Map<String, dynamic>.from(
  jsonDecode(File('web/tertiary-feed.json').readAsStringSync()) as Map,
);

void main() {
  test(
    'Published national feed loads and migrates overlapping shortlist IDs',
    () {
      final store = TertiaryStore()..saved = {'nmc:1', 'gtec:881'};
      store.applyFeed(feed());
      expect(store.institutions.length, 618);
      expect(store.institutions.expand((i) => i.regions).toSet().length, 16);
      expect(store.institutions.expand((i) => i.recordIds).toSet().length, 792);
      expect(store.saved, {'gtec:881'});
      expect(
        store.institutions.firstWhere((i) => i.id == 'gtec:922').aliases,
        contains('AAMUSTED'),
      );
    },
  );
  test(
    'Duplicate canonical IDs reject the whole update without partial changes',
    () {
      final store = TertiaryStore()..applyFeed(feed());
      final old = store.institutions;
      final broken = feed();
      final rows = broken['institutions'] as List;
      rows.add(rows.first);
      expect(() => store.applyFeed(broken), throwsFormatException);
      expect(identical(store.institutions, old), isTrue);
    },
  );
  test('Old duplicate-list feed cannot replace the canonical catalogue', () {
    final store = TertiaryStore()..applyFeed(feed());
    final broken = feed()..['schemaVersion'] = 1;
    expect(() => store.applyFeed(broken), throwsFormatException);
    expect(store.institutions.length, 618);
  });
}
