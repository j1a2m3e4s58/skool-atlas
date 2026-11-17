import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'atlas_controls.dart';
import 'tertiary_data.dart';

bool guidanceCurrent(Map row, DateTime now) {
  final d = DateTime.tryParse('${row['checkedAt']}');
  return row['status'] == 'source_checked' &&
      d != null &&
      !d.isAfter(now) &&
      now.difference(d).inDays <= 180;
}

bool programmeNeedsConfirmation(AdmissionRule rule) =>
    (rule.data['electiveRoutes'] as List? ?? []).isNotEmpty &&
    (rule.data['electiveRoutes'] as List).every(
      (r) => r['confirmation'] != null,
    );

void validateGuidance(Map<String, dynamic> data, Set<String> institutions) {
  if (data['schemaVersion'] != 1) {
    throw const FormatException('Unsupported guidance');
  }
  final ids = <String>{};
  for (final section in ['scholarships', 'campus', 'careers']) {
    if (data[section] is! List) {
      throw const FormatException('Missing guidance section');
    }
    for (final raw in data[section]) {
      final uri = raw is Map ? Uri.tryParse('${raw['sourceUrl']}') : null;
      if (raw is! Map ||
          raw['id'] is! String ||
          (raw['id'] as String).isEmpty ||
          !ids.add(raw['id']) ||
          raw['title'] is! String ||
          raw['text'] is! String ||
          raw['cycle'] is! String ||
          uri?.scheme != 'https' ||
          uri!.userInfo.isNotEmpty ||
          uri.hasPort ||
          !(uri.host.endsWith('.edu.gh') ||
              [
                'nmc.gov.gh',
                'indexing.ntc.gov.gh',
                'engcouncil.gov.gh',
              ].contains(uri.host)) ||
          DateTime.tryParse('${raw['checkedAt']}') == null ||
          !['source_checked', 'needs_source_review'].contains(raw['status']) ||
          (section != 'careers' &&
              !institutions.contains(raw['institutionId'])) ||
          (section == 'scholarships' &&
              (raw['criteria'] is! List ||
                  (raw['criteria'] as List).isEmpty ||
                  (raw['criteria'] as List).toSet().length !=
                      (raw['criteria'] as List).length ||
                  (raw['criteria'] as List).any(
                    (c) => c is! String || c.isEmpty,
                  )))) {
        throw const FormatException('Invalid guidance record');
      }
    }
  }
}

String scholarshipDecision(Map row, Map<String, bool?> answers, DateTime now) {
  if (!guidanceCurrent(row, now)) {
    return 'Paused: official evidence needs review';
  }
  final criteria = List<String>.from(row['criteria']);
  if (criteria.any((c) => answers[c] == false)) {
    return 'Published conditions not met';
  }
  if (criteria.any((c) => answers[c] == null)) return 'More information needed';
  return 'Potential policy fit — confirm an open call and university assessment';
}

class GuidancePanel extends StatefulWidget {
  final TertiaryStore store;
  final int section;
  const GuidancePanel({super.key, required this.store, required this.section});
  @override
  State<GuidancePanel> createState() => _GuidancePanelState();
}

class _GuidancePanelState extends State<GuidancePanel> {
  String school = 'all', query = '', schoolQuery = '';
  final answers = <String, bool?>{};
  bool matchesSearch(Map row) =>
      '${row['title']} ${row['text']} ${(row['tags'] as List? ?? []).join(' ')}'
          .toLowerCase()
          .contains(query);
  Future<void> open(String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Official page could not open. Internet access may be needed.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final section = widget.section;
    final key = section == 5
        ? 'scholarships'
        : section == 6
        ? 'campus'
        : 'careers';
    final rows = List<Map<String, dynamic>>.from(
      (s.guidance[key] as List? ?? []).map((r) => Map<String, dynamic>.from(r)),
    );
    final matchingSchools =
        ([...s.institutions]..sort((a, b) => a.name.compareTo(b.name)))
            .where(
              (i) => '${i.name} ${i.aliases.join(' ')} ${i.regions.join(' ')}'
                  .toLowerCase()
                  .contains(schoolQuery),
            )
            .take(30)
            .toList();
    final chosen = s.institutions.where((i) => i.id == school).firstOrNull;
    if (chosen != null && !matchingSchools.any((i) => i.id == chosen.id)) {
      matchingSchools.insert(0, chosen);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          section == 5
              ? 'Find financial support'
              : section == 6
              ? 'Plan campus life'
              : section == 7
              ? 'Explore careers & licences'
              : 'National evidence coverage',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(
          section == 5
              ? 'Answer the published conditions. Answers stay in this session. No award, open application window or grade-based scholarship entitlement is implied.'
              : section == 6
              ? 'Check the correct teaching campus before booking. Prices, bed availability, accessibility and transport are not verified unless expressly stated.'
              : section == 7
              ? 'Use these official starting points to discuss course content and professional registration. Employment and salary are not guaranteed.'
              : 'The directory covers all 16 regions. Programme-level admissions evidence is incomplete. A regulator listing is separate from programme approval and admission eligibility.',
        ),
        const SizedBox(height: 20),
        if (section != 7) ...[
          TextField(
            decoration: const InputDecoration(
              labelText: 'Find an institution by name or region',
              prefixIcon: Icon(Icons.search),
              helperText:
                  'The selector shows up to 30 search results. Type to find any directory institution.',
            ),
            onChanged: (v) =>
                setState(() => schoolQuery = v.toLowerCase().trim()),
          ),
          const SizedBox(height: 16),
        ],
        if (section != 7)
          AtlasDropdown<String>(
            initialValue: school,
            decoration: const InputDecoration(labelText: 'Institution'),
            items: [
              const DropdownMenuItem(
                value: 'all',
                child: Text('All institutions'),
              ),
              ...matchingSchools.map(
                (i) => DropdownMenuItem(value: i.id, child: Text(i.name)),
              ),
            ],
            onChanged: (v) => setState(() => school = v ?? 'all'),
          ),
        const SizedBox(height: 16),
        if (section == 8)
          ...coverage(s)
        else ...[
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search guidance',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => query = v.toLowerCase().trim()),
          ),
          const SizedBox(height: 16),
          for (final row in rows.where(
            (r) =>
                (school == 'all' ||
                    section == 7 ||
                    r['institutionId'] == school) &&
                matchesSearch(r),
          ))
            Card(
              margin: const EdgeInsets.only(bottom: 18),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row['title'],
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    if (!guidanceCurrent(row, DateTime.now()))
                      const Text(
                        'PAUSED · Source requires review',
                        style: TextStyle(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    Text(row['text']),
                    const SizedBox(height: 12),
                    if (section == 5) ...[
                      for (final c in List<String>.from(row['criteria']))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: AtlasDropdown<String>(
                            initialValue: answers['${row['id']}:$c'] == null
                                ? 'Unknown'
                                : answers['${row['id']}:$c'] == true
                                ? 'Yes'
                                : 'No',
                            decoration: InputDecoration(labelText: c),
                            items: ['Unknown', 'Yes', 'No']
                                .map(
                                  (v) => DropdownMenuItem(
                                    value: v,
                                    child: Text(v),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(
                              () => answers['${row['id']}:$c'] = v == 'Unknown'
                                  ? null
                                  : v == 'Yes',
                            ),
                          ),
                        ),
                      Text(
                        scholarshipDecision(row, {
                          for (final c in List<String>.from(row['criteria']))
                            c: answers['${row['id']}:$c'],
                        }, DateTime.now()),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                    if (section == 6)
                      const Text(
                        'Before paying: confirm the current fee period, utilities, refund terms, accessible facilities, journey to your teaching campus and authorised payment channel.',
                      ),
                    const SizedBox(height: 12),
                    Text(
                      '${row['cycle']}\nHuman-reviewed: ${row['checkedAt']}',
                    ),
                    TextButton.icon(
                      onPressed: () => open(row['sourceUrl']),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Read official evidence'),
                    ),
                  ],
                ),
              ),
            ),
          if (!rows.any(
            (r) =>
                (school == 'all' ||
                    section == 7 ||
                    r['institutionId'] == school) &&
                matchesSearch(r),
          ))
            const Text(
              'No reviewed guidance matches this selection. Ask the institution directly; another campus’s details do not apply.',
            ),
        ],
      ],
    );
  }

  List<Widget> coverage(TertiaryStore s) {
    final regions = s.institutions.expand((i) => i.regions).toSet().toList()
      ..sort();
    final selected = s.institutions.where(
      (i) => school == 'all' || i.id == school,
    );
    return [
      if (school == 'all')
        ...regions.map((region) {
          final ids = s.institutions
              .where((i) => i.regions.contains(region))
              .map((i) => i.id)
              .toSet();
          final programme = s.rules.where(
            (r) =>
                ids.contains(s.ruleInstitutionId(r)) &&
                regionsForProgramme(
                  r,
                  s.institutions
                      .where((i) => i.id == s.ruleInstitutionId(r))
                      .firstOrNull,
                ).contains(region) &&
                r.data['scope'] == 'programme',
          );
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 6),
            title: Text(region),
            subtitle: Text(
              '${ids.length} directory profiles · ${programme.where((r) => guidanceCurrent(r.data, DateTime.now())).length} published programme routes (${programme.where((r) => guidanceCurrent(r.data, DateTime.now()) && programmeNeedsConfirmation(r)).length} require additional confirmation) · ${programme.where((r) => !guidanceCurrent(r.data, DateTime.now())).length} held/stale routes',
            ),
          );
        }),
      if (school != 'all')
        for (final i in selected) ...[
          Text(i.name, style: Theme.of(context).textTheme.titleLarge),
          Text(
            'Regions: ${i.regions.join(', ')} · Regulator listing: ${i.status}',
          ),
          TextButton(
            onPressed: () => open(i.source),
            child: const Text('Check regulator record and programme approval'),
          ),
          if (!s.rules.any(
            (r) =>
                s.ruleInstitutionId(r) == i.id &&
                r.data['scope'] == 'programme',
          ))
            const Text(
              'Programme-specific requirements have not yet been verified for this institution. General entry guidance cannot establish eligibility for every programme.',
            ),
          for (final r in s.rules.where((r) => s.ruleInstitutionId(r) == i.id))
            AtlasDisclosure(
              title: Text(r.programme),
              subtitle: Text(
                '${r.data['scope']} · ${guidanceCurrent(r.data, DateTime.now()) ? 'Reviewed' : 'Held / stale'}${programmeNeedsConfirmation(r) ? ' · programme confirmation required' : ''}',
              ),
              children: [
                ...describeRequirements(r).map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(t),
                  ),
                ),
                Text('${r.data['cycle']} · checked ${r.checkedAt}'),
                TextButton(
                  onPressed: () => open(r.source),
                  child: const Text('Official programme source'),
                ),
              ],
            ),
        ],
    ];
  }
}
