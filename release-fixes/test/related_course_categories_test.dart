import 'package:flutter_test/flutter_test.dart';
import 'package:skoolatlas/tertiary_data.dart';

void main() {
  AdmissionRule rule(String id, String name) => AdmissionRule({
    'id': id,
    'programme': name,
    'institutionId': id,
    'scope': 'programme',
    'studyMode': 'Regular',
  });
  PathwayRecommendation candidate(AdmissionRule r, {bool passes = true}) =>
      PathwayRecommendation(r, MatchAssessment('Test assessment', [], 21,
          academicPass: passes), 0, [], []);

  test('BEd Dagbani alternatives require education relevance and passing grades', () {
    final target = rule('target', 'BEd Dagbani');
    final education = rule('education', 'Bachelor of Education');
    final nursing = rule('nursing', 'Certificate in Nurse Assistant Preventive');
    final failed = rule('failed', 'B.Ed French');
    expect(programmeInterests(target), contains('Education'));
    expect(alternativeProgrammes(target, [
      candidate(nursing), candidate(failed, passes: false), candidate(education),
    ]).map((r) => r.rule.id), ['education']);
  });

  test('Unclassified programmes do not treat every passing course as related', () {
    expect(alternativeProgrammes(rule('unknown', 'Unclassified route'), [
      candidate(rule('nursing', 'BSc Nursing')),
    ]), isEmpty);
  });

  test('Education abbreviation requires word boundaries', () {
    for (final name in ['BEd Dagbani', 'B.Ed. French', 'B.Ed Arabic']) {
      expect(programmeInterests(rule(name, name)), contains('Education'));
    }
    expect(programmeInterests(rule('other', 'Embedded Systems')),
        isNot(contains('Education')));
  });
  test('Hospitality alternatives require related subjects and an academic pass', () {
    final target = rule('atu', 'BTech Hospitality Management');
    final ucc = rule('ucc', 'BSc Hospitality Management');
    final uenr = rule('uenr', 'BSc Hospitality Management');
    final tourism = rule('tourism', 'BSc Tourism Management');
    final pending = rule('pending', 'BSc Hospitality Management');
    expect(programmeInterests(target), contains('Hospitality & tourism'));
    expect(alternativeProgrammes(target, [
      candidate(target), candidate(pending, passes: false),
      candidate(rule('nursing', 'BSc Nursing')),
      candidate(ucc), candidate(uenr), candidate(tourism), candidate(ucc),
    ]).map((r) => r.rule.id), ['ucc', 'uenr', 'tourism']);
    expect(programmeInterests(rule('hospital', 'BSc Hospital Administration')),
        isNot(contains('Hospitality & tourism')));
  });

  test('Communication alternatives exclude technical and nonpassing routes', () {
    final target = rule('ucc-media', 'BA Communication Studies');
    final journalism = rule('acity-media', 'BA in Journalism & Mass Communication');
    final publicRelations = rule('atu-media', 'BTech Public Relations with Digital Communication');
    final pending = rule('knust-media', 'BA Media and Communication Studies');
    expect(alternativeProgrammes(target, [
      candidate(target, passes: false),
      candidate(pending, passes: false),
      candidate(rule('ict', 'BSc Information and Communication Technology')),
      candidate(rule('engineering', 'BSc Electronics & Communication Engineering')),
      candidate(journalism), candidate(publicRelations), candidate(journalism),
    ]).map((r) => r.rule.id), ['acity-media', 'atu-media']);
    expect(programmeInterests(pending), contains('Media & communication'));
    expect(alternativeProgrammes(target, [
      candidate(journalism, passes: false), candidate(publicRelations, passes: false),
    ]), isEmpty);
    for (final name in ['BSc Information and Communication Technology',
      'BSc Electronics & Communication Engineering', 'BSc Telecommunication Engineering']) {
      expect(programmeInterests(rule(name, name)),
          isNot(contains('Media & communication')));
    }
  });

  test('Statistics alternatives require a passing relevant route and stay unique', () {
    final target = rule('ktu-statistics', 'BTech Statistics');
    final applied = rule('atu-statistics', 'BTech Applied Statistics');
    final pending = rule('pending-statistics', 'BSc Mathematics with Statistics');
    expect(alternativeProgrammes(target, [
      candidate(target), candidate(pending, passes: false),
      candidate(rule('computing', 'BSc Computer Science')),
      candidate(applied), candidate(applied),
    ]).map((r) => r.rule.id), ['atu-statistics']);
    expect(programmeInterests(pending), contains('Statistics'));
    expect(alternativeProgrammes(target, [candidate(applied, passes: false)]), isEmpty);
  });

  test('Planning alternatives stay related, passing and unique', () {
    final target = rule('ucc', 'BSc Geography and Regional Planning');
    final degree = rule('uds', 'BSc Planning');
    final diploma = rule('ubids', 'Diploma in Integrated Urban Planning');
    final failed = rule('failed', 'BSc Spatial Planning');
    expect(alternativeProgrammes(target, [
      candidate(target, passes: false), candidate(failed, passes: false),
      candidate(rule('finance', 'BSc Financial Planning')),
      candidate(degree), candidate(diploma), candidate(degree),
    ]).map((r) => r.rule.id), ['uds', 'ubids']);
    for (final name in ['BSc Planning', 'B.Sc. Planning',
      'Bachelor of Science in Planning', 'BSc Planning and Sustainability',
      'BSc Resource and Development Planning', 'BSc Urban Design and Planning']) {
      expect(programmeInterests(rule(name, name)), contains('Planning & development'));
    }
    expect(programmeInterests(rule('other', 'BSc Financial Planning')),
        isNot(contains('Planning & development')));
  });

}
