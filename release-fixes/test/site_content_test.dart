import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:skoolatlas/tertiary_data.dart';

void main() {
  Map<String, dynamic> feed() => Map<String, dynamic>.from(
    jsonDecode(File('web/tertiary-feed.json').readAsStringSync()) as Map,
  );
  test('published content travels with the offline-cacheable admissions feed', () {
    final source = feed()..['siteContent'] = {'homeTitle': 'Choose your next chapter', 'announcement': 'Applications update'};
    final store = TertiaryStore()..applyFeed(source);
    expect(store.siteContent['homeTitle'], 'Choose your next chapter');
    final restored = TertiaryStore()..applyFeed(Map<String, dynamic>.from(jsonDecode(jsonEncode(source)) as Map));
    expect(restored.siteContent, store.siteContent);
    store.applyFeed(feed());
    expect(store.siteContent, isEmpty);
  });
  test('malformed content cannot partially replace the current publication', () {
    final store = TertiaryStore()..applyFeed(feed()..['siteContent'] = {'homeTitle': 'Keep this'});
    final bad = feed()..['siteContent'] = {'homeTitle': 23};
    expect(() => store.applyFeed(bad), throwsFormatException);
    expect(store.siteContent['homeTitle'], 'Keep this');
  });
}
