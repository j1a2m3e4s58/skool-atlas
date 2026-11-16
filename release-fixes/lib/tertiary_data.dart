import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'student_journey.dart';
import 'student_guidance.dart' show validateGuidance;

part 'admission_matching.dart';
part 'personalised_pathways.dart';

const coreSubjects = [
  'English Language',
  'Core Mathematics',
  'Integrated Science',
  'Social Studies',
];
const electiveSubjects = [
  'Elective Mathematics',
  'Physics',
  'Chemistry',
  'Biology',
  'Economics',
  'Geography',
  'Government',
  'History',
  'Literature in English',
  'French',
  'Accounting',
  'Business Management',
  'Cost Accounting',
  'General Knowledge in Art',
  'Graphic Design',
  'Textiles',
  'Clothing and Textiles',
  'Management in Living',
  'Food and Nutrition',
  'Agricultural Science',
  'ICT',
  'Applied Electricity',
  'Electronics',
  'Technical Drawing',
  'Ghanaian Language',
  'Christian Religious Studies',
  'Islamic Religious Studies',
  'Music',
  'Picture Making',
  'Basketry',
  'Ceramics',
  'Jewellery',
  'Leatherwork',
  'Sculpture',
  'Auto Mechanics',
  'Building Construction',
  'Metalwork',
  'Woodwork',
  'Animal Husbandry',
  'Crop Husbandry and Horticulture',
  'Fisheries',
  'Forestry',
  'Typewriting',
  'Clerical Office Duties',
  'Arabic',
  'West Africa Traditional Religion',
  'Dagaare',
  'Dagbani',
  'Dangme',
  'Ewe',
  'Ga',
  'Gonja',
  'Kasem',
  'Nzema',
  'Twi (Akuapem)',
  'Twi (Asante)',
];
const gradeNames = ['A1', 'B2', 'B3', 'C4', 'C5', 'C6', 'D7', 'E8', 'F9'];

class TertiaryInstitution {
  final String id, name, category, location, source, checkedAt, status;
  final List<String> courses;
  final String? nameSource;
  final bool listedActive;
  final List<String> regions, aliases, recordIds, locations;
  final List<Map<String, dynamic>> records;
  const TertiaryInstitution({
    this.nameSource,
    required this.id,
    required this.name,
    required this.category,
    required this.location,
    required this.source,
    required this.checkedAt,
    required this.status,
    required this.courses,
    required this.listedActive,
    this.regions = const [],
    this.aliases = const [],
    this.recordIds = const [],
    this.locations = const [],
    this.records = const [],
  });
  String get group {
    final c = category.toLowerCase();
    if (c.contains('skills')) return 'Skills & fashion';
    if (c.contains('nurs') || c.contains('health')) return 'Nursing & health';
    if (c.contains('education')) return 'Colleges of education';
    if (c.contains('technical') || c.contains('polytechnic')) {
      return 'Technical universities';
    }
    return 'Universities & colleges';
  }

  String get mediaKey => id;
  factory TertiaryInstitution.fromJson(Map<String, dynamic> r) =>
      TertiaryInstitution(
        nameSource: r['nameSource'],
        id: r['id'],
        name: r['name'],
        category: r['category'],
        location: r['location'],
        source: r['source'],
        checkedAt: r['checkedAt'],
        status: r['status'],
        courses: List<String>.from(r['courses']),
        listedActive: r['listedActive'],
        regions: List<String>.from(r['regions'] ?? []),
        aliases: List<String>.from(r['aliases'] ?? []),
        recordIds: List<String>.from(r['recordIds'] ?? []),
        locations: List<String>.from(r['locations'] ?? []),
        records: [
          for (final row in r['records'] ?? []) Map<String, dynamic>.from(row),
        ],
      );
}

class AdmissionRule {
  final Map<String, dynamic> data;
  AdmissionRule(this.data);
  String get id => data['id'] as String;
  String get institution => data['institution'] as String;
  String get programme => data['programme'] as String;
  String get source => data['sourceUrl'] as String;
  String get checkedAt => data['checkedAt'] as String;
  bool matchesProgramme(String value) => [
    programme,
    ...List<String>.from(data['programmeAliases'] as List? ?? []),
  ].any((name) => programmeIdentity(name) == programmeIdentity(value));
  List<String> get requiredElectives =>
      List<String>.from(data['requiredElectives'] as List? ?? []);
}

class TertiaryStore {
  final journey = StudentJourney();
  Map<String, dynamic> guidance = {};
  bool sessionNewCurriculum = false;
  final newCurriculumGrades = <String, int>{};
  final sessionGrades = <String, int>{};
  final sessionAwaiting = <String>{};
  final sessionNotTaken = <String>{};
  String sessionResultBasis = 'Final results';
  int sessionSittings = 1;
  PathwayPreferences preferences = const PathwayPreferences();
  String? preferencesStorageError;
  Map<String, dynamic> sourceMonitor = {};
  List<TertiaryInstitution> institutions = [];
  List<AdmissionRule> rules = [];
  Map<String, dynamic> media = {};
  Map<String, dynamic> cutoffs = {};
  Set<String> saved = {};
  String syncMessage = 'Offline snapshot available';
  String? feedUrl;
  Future<Map<String, dynamic>> _asset(String name) async =>
      Map<String, dynamic>.from(
        jsonDecode(await rootBundle.loadString('assets/tertiary/$name.json'))
            as Map,
      );
  Future<void> load() async {
    final bundled = await Future.wait([
      for (final name in [
        'catalogue',
        'admissions',
        'media',
        'ug_cutoffs',
        'student_resources',
        'student_guidance',
      ])
        _asset(name),
    ]);
    final catalogue = bundled[0];
    final a = bundled[1];
    media = bundled[2];
    cutoffs = bundled[3];
    await journey.load(bundled[4]);
    institutions = [
      for (final row in catalogue['institutions'])
        TertiaryInstitution.fromJson(Map<String, dynamic>.from(row)),
    ];
    guidance = bundled[5];
    validateGuidance(guidance, institutions.map((i) => i.id).toSet());
    rules = (a['rules'] as List)
        .map((r) => AdmissionRule(Map<String, dynamic>.from(r as Map)))
        .toList();
    const configuredFeed = String.fromEnvironment('TERTIARY_FEED_URL');
    feedUrl = configuredFeed.isNotEmpty
        ? configuredFeed
        : kIsWeb
        ? Uri.base.resolve('tertiary-feed.json').toString()
        : '';
    final prefs = await SharedPreferences.getInstance();
    await loadPathwayPreferences();
    saved = (prefs.getStringList('tertiary.saved.v1') ?? []).toSet();
    saved = {
      for (final id in saved)
        institutions
                .where((i) => i.id == id || i.recordIds.contains(id))
                .map((i) => i.id)
                .firstOrNull ??
            id,
    };
    await prefs.setStringList('tertiary.saved.v1', saved.toList());
    final cached = prefs.getString('tertiary.feed.v10');
    if (cached != null) {
      try {
        applyFeed(Map<String, dynamic>.from(jsonDecode(cached) as Map));
      } catch (_) {
        /* Keep bundled data. */
      }
    }
  }

  void applyFeed(Map<String, dynamic> feed) {
    if (![2, 3, 4, 5].contains(feed['schemaVersion']) ||
        feed['rules'] is! List) {
      throw const FormatException('Unsupported feed');
    }
    final updated = (feed['rules'] as List)
        .map((r) => AdmissionRule(Map<String, dynamic>.from(r as Map)))
        .toList();
    if (updated.isEmpty ||
        updated.map((r) => r.id).toSet().length != updated.length) {
      throw const FormatException('Empty or duplicate rules');
    }
    for (final r in updated) {
      validateAdmissionRule(r);
      if (r.data['ruleVersion'] == 2 &&
          ![3, 4, 5].contains(feed['schemaVersion'])) {
        throw const FormatException(
          'New admission rules require the current feed',
        );
      }
      if (r.data['ruleVersion'] == 3 && feed['schemaVersion'] != 5) {
        throw const FormatException(
          'Result-policy rules require feed version five',
        );
      }
    }
    List<TertiaryInstitution>? catalog;
    if (feed['institutions'] != null) {
      final rows = feed['institutions'] as List;
      catalog = rows.map((raw) {
        final r = Map<String, dynamic>.from(raw as Map);
        final source = Uri.parse(r['source'] as String);
        if (source.scheme != 'https' ||
            ![
              'gtec.edu.gh',
              'ctvet.gov.gh',
              'nmc.gov.gh',
            ].contains(source.host) ||
            DateTime.tryParse(r['checkedAt'] as String) == null) {
          throw const FormatException('Invalid institution source');
        }
        return TertiaryInstitution.fromJson(r);
      }).toList();
      if (catalog.length < 500 ||
          catalog.map((i) => i.id).toSet().length != catalog.length ||
          catalog.any(
            (i) =>
                i.id.isEmpty ||
                i.name.isEmpty ||
                i.regions.isEmpty ||
                i.recordIds.isEmpty ||
                RegExp(
                  r'senior high|senior secondary|\bSHS\b',
                  caseSensitive: false,
                ).hasMatch(i.name),
          )) {
        throw const FormatException('Incomplete institution feed');
      }
    }
    for (final r in updated.where((r) => r.data['programmeRegions'] != null)) {
      final school = (catalog ?? institutions)
          .where((i) => i.id == r.data['institutionId'])
          .firstOrNull;
      if (school == null ||
          !(r.data['programmeRegions'] as List).every(
            school.regions.contains,
          )) {
        throw const FormatException(
          'Programme teaching regions do not match the institution record',
        );
      }
    }
    Map<String, dynamic>? cutoffUpdate;
    if (feed['cutoffs'] is Map) {
      final latest = Map<String, dynamic>.from(feed['cutoffs'] as Map);
      if (latest['rows'] is! List ||
          latest['columns'] is! List ||
          (latest['columns'] as List).length != 5 ||
          (latest['columns'] as List).any((c) => c is! String) ||
          (latest['rows'] as List).any(
            (r) => r is! List || r.length < 5 || r.any((c) => c is! String),
          ) ||
          latest['sourceUrl'] != 'https://admissions.ug.edu.gh/node/36' ||
          DateTime.tryParse('${latest['checkedAt']}') == null) {
        throw const FormatException('Invalid cutoff table');
      }
      cutoffUpdate = latest;
    }
    Map<String, dynamic>? resourceUpdate;
    if (feed['studentResources'] != null) {
      resourceUpdate = Map<String, dynamic>.from(
        feed['studentResources'] as Map,
      );
      StudentJourney.validateResources(resourceUpdate);
      final validIds = (catalog ?? institutions).map((i) => i.id).toSet();
      for (final section in ['fees', 'deadlines', 'scholarships']) {
        if ((resourceUpdate[section] as List).any(
          (r) => !validIds.contains(r['institutionId']),
        )) {
          throw const FormatException('Unknown resource institution');
        }
      }
    }
    Map<String, dynamic>? guidanceUpdate;
    if (feed['studentGuidance'] != null) {
      guidanceUpdate = Map<String, dynamic>.from(
        feed['studentGuidance'] as Map,
      );
      validateGuidance(
        guidanceUpdate,
        (catalog ?? institutions).map((i) => i.id).toSet(),
      );
    }
    final monitor = feed['sourceMonitor'] == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(feed['sourceMonitor'] as Map);
    if (monitor.isNotEmpty &&
        (monitor['sources'] is! List ||
            (monitor['sources'] as List).any(
              (s) =>
                  s is! Map ||
                  Uri.tryParse('${s['url']}')?.scheme != 'https' ||
                  ![
                    'unchanged',
                    'changed',
                    'unavailable',
                    'not_yet_checked',
                    'unavailable_at_release',
                  ].contains(s['state']),
            ))) {
      throw const FormatException('Invalid source monitor');
    }
    if (guidanceUpdate != null) guidance = guidanceUpdate;
    rules = updated;
    sourceMonitor = monitor;
    if (catalog != null) {
      institutions = catalog;
      saved = {
        for (final id in saved)
          institutions
                  .where((i) => i.id == id || i.recordIds.contains(id))
                  .map((i) => i.id)
                  .firstOrNull ??
              id,
      };
    }
    if (cutoffUpdate != null) cutoffs = cutoffUpdate;
    if (resourceUpdate != null) journey.resources = resourceUpdate;
  }

  String? ruleInstitutionId(AdmissionRule rule) {
    final explicit = rule.data['institutionId'];
    if (explicit is String && institutions.any((i) => i.id == explicit)) {
      return explicit;
    }
    String norm(String s) =>
        s.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
    final name = norm(rule.institution);
    return institutions
        .where((i) => [i.name, ...i.aliases].any((n) => norm(n) == name))
        .firstOrNull
        ?.id;
  }

  Future<void> observeJourney() async {
    final snapshot = <String, Map<String, dynamic>>{};
    for (final i in institutions) {
      snapshot['institution:${i.id}'] = {
        'institutionId': i.id,
        'title': i.name,
        'name': i.name,
        'sourceUrl': i.source,
        'approval': i.status,
        'programmes': i.courses,
        'regions': i.regions,
      };
    }
    for (final r in rules) {
      final id = ruleInstitutionId(r);
      if (id == null) continue;
      snapshot['rule:${r.id}'] = {
        'institutionId': id,
        'title': r.programme,
        'sourceUrl': r.source,
        for (final e in r.data.entries)
          if (![
            'checkedAt',
            'institutionId',
            'sourceUrl',
            'programme',
            'institution',
          ].contains(e.key))
            e.key: e.value,
      };
    }
    for (final section in ['fees', 'deadlines', 'scholarships']) {
      for (final raw in journey.resources[section] as List) {
        final row = Map<String, dynamic>.from(raw);
        snapshot['resource:${row['id']}'] = {
          for (final e in row.entries)
            if (!['checkedAt', 'id'].contains(e.key)) e.key: e.value,
        };
      }
    }
    for (final section in ['scholarships', 'campus']) {
      for (final raw in guidance[section] as List? ?? []) {
        final row = Map<String, dynamic>.from(raw);
        snapshot['guidance:${row['id']}'] = {
          for (final e in row.entries)
            if (!['checkedAt', 'id'].contains(e.key)) e.key: e.value,
        };
      }
    }
    await journey.observe(snapshot, {
      ...saved,
      ...journey.applications.map((a) => a.institutionId),
    });
  }

  Future<void> refresh() async {
    if (feedUrl == null || feedUrl!.isEmpty) {
      syncMessage =
          'Live feed is not configured. Showing dated offline sources.';
      return;
    }
    final feedUri = Uri.tryParse(feedUrl!);
    if (feedUri?.scheme != 'https' &&
        !(feedUri?.scheme == 'http' &&
            ['localhost', '127.0.0.1'].contains(feedUri?.host))) {
      syncMessage = 'Update feed requires HTTPS.';
      return;
    }
    try {
      final response = await http
          .get(Uri.parse(feedUrl!))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200 || response.bodyBytes.length > 8000000) {
        throw const FormatException('Feed unavailable');
      }
      applyFeed(Map<String, dynamic>.from(jsonDecode(response.body) as Map));
      var cached = false;
      try {
        final prefs = await SharedPreferences.getInstance();
        // Only obsolete, reproducible feed caches are retired. Saved choices,
        // applications, preferences and reminders retain their own keys.
        for (final key
            in prefs
                .getKeys()
                .where(
                  (key) => RegExp(r'^tertiary\.feed\.v[1-9]$').hasMatch(key),
                )
                .toList()) {
          await prefs.remove(key);
        }
        cached = await prefs.setString('tertiary.feed.v10', response.body);
      } catch (_) {
        // A browser storage limit cannot undo an accepted online publication.
      }
      var journeyUpdated = true;
      try {
        await observeJourney();
      } catch (_) {
        journeyUpdated = false;
      }
      syncMessage =
          'Admissions feed updated · ${DateTime.now().toIso8601String().substring(0, 16)}'
          '${cached ? '' : ' · Offline update could not be saved on this device.'}'
          '${journeyUpdated ? '' : ' · Journey change tracking could not be saved.'}';
    } catch (_) {
      syncMessage =
          'Could not update. Your last saved sources remain available.';
    }
  }

  Future<void> toggleSaved(String id) async {
    saved.contains(id) ? saved.remove(id) : saved.add(id);
    await (await SharedPreferences.getInstance()).setStringList(
      'tertiary.saved.v1',
      saved.toList(),
    );
  }

  Future<void> loadPathwayPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final preferenceText = prefs.getString('tertiary.preferences.v1');
    if (preferenceText != null) {
      try {
        preferences = PathwayPreferences.fromJson(
          Map<String, dynamic>.from(jsonDecode(preferenceText)),
        );
      } catch (_) {
        preferencesStorageError =
            'Saved preferences could not be read. The original device value has been preserved.';
      }
    }
  }

  Future<void> savePathwayPreferences() async {
    if (preferencesStorageError != null) {
      throw StateError(preferencesStorageError!);
    }
    final ok = await (await SharedPreferences.getInstance()).setString(
      'tertiary.preferences.v1',
      jsonEncode(preferences.toJson()),
    );
    if (!ok) {
      throw StateError(
        'Preferences could not be saved. They remain available in this session.',
      );
    }
  }
}
