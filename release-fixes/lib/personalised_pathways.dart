part of 'tertiary_data.dart';

const pathwayInterests = <String, List<String>>{
  'Statistics': ['statistics', 'statistical'],
  'Computing & data': [
    'computer',
    'computing',
    'information technology',
    'communication technology',
    'data science',
    'actuarial',
    'mathematical',
  ],
  'Health': [
    'medicine',
    'dental',
    'nursing',
    'midwif',
    'pharmacy',
    'health',
    'dietet',
    'physiotherap',
    'radiograph',
    'respiratory',
    'occupational therapy',
  ],
  'Planning & development': [
    'spatial planning',
    'regional planning',
    'urban planning',
    'urban design',
    'development planning',
    'planning and sustainability',
  ],
  'Hospitality & tourism': ['hospitality', 'tourism', 'hotel management'],
  'Media & communication': [
    'journalism',
    'mass communication',
    'communication studies',
    'public relations',
  ],
  'Engineering': ['engineering'],
  'Education': ['education', 'b.ed', 'b.ed.'],
  'Business & law': [
    'business',
    'administration',
    'account',
    'economics',
    'finance',
    'estate',
    'law',
  ],
  'Arts & languages': [
    'arts',
    'french',
    'english',
    'spanish',
    'arabic',
    'language',
    'sport',
  ],
  'Agriculture & environment': [
    'agricultur',
    'earth',
    'environment',
    'veterinary',
    'biological',
    'food science',
  ],
  'Creative & design': [
    'design',
    'fine arts',
    'music',
    'dance',
    'theatre',
    'consumer',
    'clothing',
    'textile',
  ],
};
const pathwayRegions = [
  'Ahafo',
  'Ashanti',
  'Bono',
  'Bono East',
  'Central',
  'Eastern',
  'Greater Accra',
  'North East',
  'Northern',
  'Oti',
  'Savannah',
  'Upper East',
  'Upper West',
  'Volta',
  'Western',
  'Western North',
];
const subjectAliases = <String, String>{
  'General Agriculture': 'Agricultural Science',
  'Financial Accounting': 'Accounting',
  'Principles of Cost Accounting': 'Cost Accounting',
  'Foods and Nutrition': 'Food and Nutrition',
  'Mathematics (Elective)': 'Elective Mathematics',
  'ICT (Elective)': 'ICT',
  'General Knowledge-In-Art': 'General Knowledge in Art',
};
const namedGhanaianLanguages = [
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
String subjectDisplayName(String subject) => switch (subject) {
  'Accounting' => 'Accounting / Financial Accounting',
  'Agricultural Science' => 'Agricultural Science / General Agriculture',
  'Cost Accounting' => 'Cost Accounting / Principles of Cost Accounting',
  _ => subject,
};
bool subjectMatchesSearch(String subject, String query) {
  final q = query.trim().toLowerCase();
  return subject.toLowerCase().contains(q) ||
      subjectDisplayName(subject).toLowerCase().contains(q) ||
      subjectAliases.entries.any(
        (e) => e.value == subject && e.key.toLowerCase().contains(q),
      );
}

class PathwayPreferences {
  final Set<String> interests, regions;
  final String level, mode;
  final double? annualTuitionGhs;
  const PathwayPreferences({
    this.interests = const {},
    this.regions = const {},
    this.level = 'Any',
    this.mode = 'Any',
    this.annualTuitionGhs,
  });
  PathwayPreferences copyWith({
    Set<String>? interests,
    Set<String>? regions,
    String? level,
    String? mode,
    double? annualTuitionGhs,
    bool clearBudget = false,
  }) => PathwayPreferences(
    interests: interests ?? this.interests,
    regions: regions ?? this.regions,
    level: level ?? this.level,
    mode: mode ?? this.mode,
    annualTuitionGhs: clearBudget
        ? null
        : annualTuitionGhs ?? this.annualTuitionGhs,
  );
  Map<String, dynamic> toJson() => {
    'interests': interests.toList()..sort(),
    'regions': regions.toList()..sort(),
    'level': level,
    'mode': mode,
    'annualTuitionGhs': annualTuitionGhs,
  };
  factory PathwayPreferences.fromJson(Map<String, dynamic> r) {
    if (r['interests'] is! List ||
        r['regions'] is! List ||
        !(r['interests'] as List).every(pathwayInterests.containsKey) ||
        !(r['regions'] as List).every(pathwayRegions.contains) ||
        !['Any', 'Degree', 'Diploma'].contains(r['level']) ||
        !['Any', 'Regular', 'Distance'].contains(r['mode']) ||
        r['annualTuitionGhs'] != null &&
            (r['annualTuitionGhs'] is! num ||
                !(r['annualTuitionGhs'] as num).isFinite ||
                r['annualTuitionGhs'] < 0)) {
      throw const FormatException('Invalid preferences');
    }
    return PathwayPreferences(
      interests: Set<String>.from(r['interests']),
      regions: Set<String>.from(r['regions']),
      level: r['level'],
      mode: r['mode'],
      annualTuitionGhs: (r['annualTuitionGhs'] as num?)?.toDouble(),
    );
  }
}

Set<String> programmeInterests(AdmissionRule rule) => {
  if (RegExp(r'\b(?:b\.?sc\.?|bachelor of science(?: in)?)\s+planning\b',
          caseSensitive: false).hasMatch(rule.programme))
    'Planning & development',
  if (RegExp(r'\bb\.?ed\b', caseSensitive: false).hasMatch(rule.programme))
    'Education',
  for (final entry in pathwayInterests.entries)
    if (entry.value.any((word) => word == 'sport'
        ? RegExp(r'\bsport', caseSensitive: false).hasMatch(rule.programme)
        : rule.programme.toLowerCase().contains(word)))
      entry.key,
};
String programmeLevel(AdmissionRule rule) {
  final name = rule.programme.toLowerCase();
  if (name.contains('diploma')) return 'Diploma';
  if (RegExp(
    r'bachelor|b\.sc|bsc|b\.ed|b.ed|ba education|doctor|llb|undergraduate',
  ).hasMatch(name)) {
    return 'Degree';
  }
  return 'Unconfirmed';
}

class PathwayRecommendation {
  final AdmissionRule rule;
  final MatchAssessment assessment;
  final int preferencePoints;
  final List<String> fitReasons, tradeoffs;
  const PathwayRecommendation(
    this.rule,
    this.assessment,
    this.preferencePoints,
    this.fitReasons,
    this.tradeoffs,
  );
  bool get programmeMatch =>
      rule.data['scope'] == 'programme' && assessment.academicPass;
  int get academicTier => rule.data['scope'] == 'institution_general'
      ? 4
      : assessment.academicPass
      ? 0
      : assessment.status == 'More results needed'
      ? 1
      : assessment.status == 'Requirements not met'
      ? 2
      : 3;
}

MatchAssessment assessPathway(
  AdmissionRule rule,
  Map<String, int> grades, {
  String? targetCycle,
  DateTime? now,
  String resultBasis = 'Final results',
  int sittings = 1,
  bool hasAwaitingResults = false,
}) {
  if (!['Final results', 'Predicted results'].contains(resultBasis)) {
    return const MatchAssessment('Invalid results basis', [
      'Choose final or predicted results.',
    ], null);
  }
  final base = assessRule(rule, grades, targetCycle: targetCycle, now: now);
  if ((resultBasis == 'Predicted results' || hasAwaitingResults) &&
      rule.data['finalResultsRequired'] == true) {
    return MatchAssessment(
      'Final results required',
      [
        'The official programme policy does not accept awaiting results. Predicted grades cannot establish an eligible application.',
        ...base.reasons,
      ],
      base.aggregate,
      countedSubjects: base.countedSubjects,
      route: base.route,
      cutoff: const CutoffAssessment(
        'Not compared',
        'Final examination results are required before eligibility or cutoff comparison.',
      ),
    );
  }
  if (sittings < 1 || sittings > 2) {
    return const MatchAssessment('Invalid sitting count', [
      'Only one or two sittings can be entered.',
    ], null);
  }
  if (sittings > 1) {
    final policy = rule.data['sittingPolicy'];
    if (policy is! Map ||
        policy['maxSittings'] is! int ||
        policy['maxSittings'] < sittings ||
        !_freshEvidence(policy, now ?? DateTime.now())) {
      return MatchAssessment(
        'Combined-sitting policy needs verification',
        [
          'Results from two sittings are not accepted automatically. This programme has no current, verified policy permitting this combination.',
          ...base.reasons,
        ],
        base.aggregate,
        countedSubjects: base.countedSubjects,
        cutoff: const CutoffAssessment(
          'Not compared',
          'Sitting-policy confirmation is required before eligibility or cutoff comparison.',
        ),
      );
    }
  }
  if (resultBasis == 'Predicted results' && base.academicPass) {
    return MatchAssessment(
      rule.data['scope'] == 'institution_general'
          ? 'Provisional general minimum only'
          : 'Provisional academic minimum met',
      [
        'Based on predicted grades, not confirmed examination results.',
        ...base.reasons,
      ],
      base.aggregate,
      countedSubjects: base.countedSubjects,
      academicPass: true,
      route: base.route,
      cutoff: const CutoffAssessment(
        'Predicted results · no confirmed cutoff match',
        'Use final examination results for an actual cutoff comparison.',
      ),
    );
  }
  return base;
}

List<({String subject, int grade})> singleSubjectNextSteps(
  AdmissionRule rule,
  Map<String, int> original, {
  DateTime? now,
  String? targetCycle,
  int sittings = 1,
}) {
  if (assessPathway(
    rule,
    original,
    now: now,
    targetCycle: targetCycle,
    sittings: sittings,
  ).academicPass) {
    return [];
  }
  final steps = <({String subject, int grade})>[];
  for (final subject in original.keys) {
    for (var grade = original[subject]! - 1; grade >= 1; grade--) {
      if (assessPathway(
        rule,
        {...original, subject: grade},
        now: now,
        targetCycle: targetCycle,
        sittings: sittings,
        resultBasis: 'Predicted results',
      ).academicPass) {
        steps.add((subject: subject, grade: grade));
        break;
      }
    }
    if (steps.length == 3) break;
  }
  return steps;
}

List<String> regionsForProgramme(
  AdmissionRule rule,
  TertiaryInstitution? institution,
) => List<String>.from(
  rule.data['programmeRegions'] as List? ?? institution?.regions ?? [],
);

List<PathwayRecommendation> rankPathways(
  TertiaryStore store,
  Map<String, int> grades,
  PathwayPreferences preferences, {
  String? targetCycle,
  DateTime? now,
  String resultBasis = 'Final results',
  int sittings = 1,
  bool hasAwaitingResults = false,
}) {
  final clock = now ?? DateTime.now();
  final ranked = <PathwayRecommendation>[];
  for (final rule in store.rules) {
    final assessment = assessPathway(
      rule,
      grades,
      targetCycle: targetCycle,
      now: clock,
      resultBasis: resultBasis,
      sittings: sittings,
      hasAwaitingResults: hasAwaitingResults,
    );
    final reasons = <String>[], tradeoffs = <String>[];
    var points = 0;
    final areas = programmeInterests(rule).intersection(preferences.interests);
    if (areas.isNotEmpty) {
      points += areas.length * 4;
      reasons.add('Matches your interests: ${areas.join(', ')}.');
    } else if (preferences.interests.isNotEmpty) {
      tradeoffs.add('Outside your selected subject interests.');
    }
    final institution = store.institutions
        .where((i) => i.id == store.ruleInstitutionId(rule))
        .firstOrNull;
    if (preferences.regions.isNotEmpty) {
      final overlap = regionsForProgramme(
        rule,
        institution,
      ).toSet().intersection(preferences.regions);
      if (overlap.isNotEmpty) {
        points += 3;
        reasons.add(
          rule.data['programmeRegions'] == null
              ? 'Institution has a listed location in ${overlap.join(', ')}. Confirm this programme’s teaching campus.'
              : 'This published route has a teaching location in ${overlap.join(', ')}. Confirm the stated campus.',
        );
      } else {
        tradeoffs.add(
          institution == null
              ? 'Institution location is not verified here.'
              : 'Outside your preferred regions.',
        );
      }
    }
    if (preferences.mode != 'Any') {
      if (rule.data['studyMode'] == preferences.mode) {
        points += 2;
        reasons.add(
          'Matches your ${preferences.mode.toLowerCase()} study preference.',
        );
      } else {
        tradeoffs.add('Different study mode from your preference.');
      }
    }
    if (preferences.level != 'Any') {
      if (programmeLevel(rule) == preferences.level) {
        points += 2;
        reasons.add(
          'Matches your ${preferences.level.toLowerCase()} preference.',
        );
      } else {
        tradeoffs.add('Different or unconfirmed qualification level.');
      }
    }
    if (preferences.annualTuitionGhs != null) {
      final fees = (store.journey.resources['fees'] as List)
          .where(
            (f) =>
                f['institutionId'] == store.ruleInstitutionId(rule) &&
                f['costType'] == 'tuition' &&
                f['currency'] == 'GHS' &&
                f['period'] == 'Per academic year' &&
                targetCycle != null &&
                f['cycle'] == targetCycle &&
                _freshEvidence({
                  ...Map<String, dynamic>.from(f),
                  'status': f['status'] ?? 'source_checked',
                }, clock),
          )
          .toList();
      if (fees.length == 1 && fees.first['amount'] is num) {
        if (fees.first['amount'] <= preferences.annualTuitionGhs) {
          points++;
          reasons.add(
            'Verified annual tuition is within your GHS tuition limit; living costs are excluded.',
          );
        } else {
          tradeoffs.add(
            'Verified annual tuition exceeds your GHS tuition limit.',
          );
        }
      } else {
        tradeoffs.add(
          'Comparable annual GHS tuition is not verified; budget fit is unknown.',
        );
      }
    }
    if (reasons.isEmpty) {
      reasons.add(
        'Listed because an academic rule is available, not because admission is guaranteed.',
      );
    }
    ranked.add(
      PathwayRecommendation(
        rule,
        assessment,
        points,
        List.unmodifiable(reasons),
        List.unmodifiable(tradeoffs),
      ),
    );
  }
  ranked.sort((a, b) {
    var c = a.academicTier.compareTo(b.academicTier);
    if (c != 0) return c;
    c = b.preferencePoints.compareTo(a.preferencePoints);
    if (c != 0) return c;
    c = a.rule.institution.compareTo(b.rule.institution);
    return c != 0 ? c : a.rule.id.compareTo(b.rule.id);
  });
  return ranked;
}

List<PathwayRecommendation> alternativeProgrammes(
  AdmissionRule target,
  List<PathwayRecommendation> ranked, {
  int limit = 4,
}) {
  final interests = programmeInterests(target);
  // Unknown subject areas cannot establish that a course is related.
  if (interests.isEmpty) return [];
  final seen = <String>{};
  final output = <PathwayRecommendation>[];
  for (final recommendation in ranked) {
    final r = recommendation.rule;
    if (!recommendation.programmeMatch ||
        r.id == target.id ||
        r.matchesProgramme(target.programme) &&
            r.data['institutionId'] == target.data['institutionId']) {
      continue;
    }
    if (interests.isNotEmpty &&
        programmeInterests(r).intersection(interests).isEmpty) {
      continue;
    }
    final key =
        '${r.data['institutionId']}|${programmeIdentity(r.programme)}|${r.data['studyMode']}';
    if (seen.add(key)) output.add(recommendation);
    if (output.length >= limit) break;
  }
  return output;
}

class GradeSimulation {
  final String subject;
  final int? previous;
  final int proposed;
  final List<PathwayRecommendation> newlyMatched;
  const GradeSimulation(
    this.subject,
    this.previous,
    this.proposed,
    this.newlyMatched,
  );
}

GradeSimulation simulateGrade(
  TertiaryStore store,
  Map<String, int> original,
  PathwayPreferences preferences,
  String subject,
  int grade, {
  DateTime? now,
  String? targetCycle,
  int sittings = 1,
}) {
  if (![...coreSubjects, ...electiveSubjects].contains(subject) ||
      grade < 1 ||
      grade > 9 ||
      original[subject] != null && grade >= original[subject]!) {
    throw const FormatException(
      'Choose a better grade for a supported subject.',
    );
  }
  final before = rankPathways(
    store,
    original,
    preferences,
    now: now,
    targetCycle: targetCycle,
    sittings: sittings,
  );
  final after = rankPathways(
    store,
    {...original, subject: grade},
    preferences,
    now: now,
    targetCycle: targetCycle,
    sittings: sittings,
    resultBasis: 'Predicted results',
  );
  final previouslyMatched = before
      .where((r) => r.programmeMatch)
      .map((r) => r.rule.id)
      .toSet();
  return GradeSimulation(
    subject,
    original[subject],
    grade,
    after
        .where(
          (r) => r.programmeMatch && !previouslyMatched.contains(r.rule.id),
        )
        .toList(),
  );
}

List<String> describeRequirements(AdmissionRule rule) {
  final d = rule.data;
  final alternatives = List<String>.from(d['scienceOrSocial'] as List? ?? []);
  final lines = <String>[];
  for (final s in List<String>.from(d['coreCredits'])) {
    if (alternatives.contains(s)) continue;
    final grade = (d['gradeFloors']?[s] ?? d['coreMaxGrades']?[s] ?? 6) as int;
    lines.add('$s: ${gradeNames[grade - 1]} or better.');
  }
  if (alternatives.isNotEmpty) {
    lines.add(
      '${alternatives.join(' OR ')}: one permitted alternative core is counted.',
    );
  }
  for (final route in d['electiveRoutes'] as List? ?? []) {
    final required = List<String>.from(route['required'] as List? ?? []);
    lines.add(
      '${route['label']}: ${required.isEmpty ? 'choose three permitted electives' : 'requires ${required.join(', ')}'}.',
    );
    for (final e in (route['coreMaxGrades'] as Map? ?? {}).entries) {
      lines.add(
        '${route['label']}: ${e.key} must be ${gradeNames[(e.value as int) - 1]} or better.',
      );
    }
    if (route['confirmation'] != null) {
      lines.add('Confirmation required: ${route['confirmation']}');
    }
    for (final g in route['groups'] as List? ?? []) {
      lines.add(
        'Choose at least ${g['count']} of ${(g['subjects'] as List).join(', ')} within that route.',
      );
    }
    for (final subject in required) {
      final floor = d['gradeFloors']?[subject];
      if (floor is int) {
        lines.add('$subject: ${gradeNames[floor - 1]} or better.');
      }
    }
    if (required
        .toSet()
        .difference(
          Set<String>.from(route['countedRequired'] as List? ?? required),
        )
        .isNotEmpty) {
      lines.add(
        'Some entry credits remain compulsory even when excluded from the aggregate.',
      );
    }
  }
  if (d['maxAggregate'] is int) {
    lines.add(
      'Academic aggregate limit: ${d['maxAggregate']}; this is separate from a competitive cutoff.',
    );
  }
  if (d['minCredits'] != null) {
    lines.add(
      'At least ${d['minCredits']} of the six counted subjects must be credit passes.',
    );
  }
  if (d['finalResultsRequired'] == true) {
    lines.add(
      'Final examination results required; awaiting or predicted results are not accepted for the published application.',
    );
  }
  return lines;
}

List<Map<String, dynamic>> admissionReviewQueue(TertiaryStore store) {
  final queue = <String, Map<String, dynamic>>{};
  void add(String url, String kind, String title, String reason) {
    final key = '$kind|$url';
    final row = queue.putIfAbsent(
      key,
      () => {
        'sourceUrl': url,
        'kind': kind,
        'titles': <String>[],
        'reason': reason,
      },
    );
    if (!(row['titles'] as List).contains(title)) {
      (row['titles'] as List).add(title);
    }
  }

  for (final r in store.rules) {
    if (!_freshEvidence(r.data, DateTime.now())) {
      add(
        r.source,
        'academic',
        r.programme,
        'Academic requirements need a reviewed source check.',
      );
    }
    if (RegExp(
      r'not stated|not specified|unconfirmed',
      caseSensitive: false,
    ).hasMatch('${r.data['cycle']}')) {
      add(
        r.source,
        'cycle',
        r.programme,
        'Admission cycle is not explicitly confirmed. Verify the intended intake with the institution.',
      );
    }
    final c = r.data['competitiveCutoff'];
    if (c is Map && !_freshEvidence(c, DateTime.now())) {
      add(
        c['sourceUrl'],
        'cutoff',
        r.programme,
        'Cutoff year, interpretation or source is unconfirmed. No numerical match is inferred.',
      );
    }
  }
  for (final s in store.sourceMonitor['sources'] as List? ?? []) {
    if ([
      'changed',
      'unavailable',
      'unavailable_at_release',
    ].contains(s['state'])) {
      add(
        s['url'],
        'source',
        'Official evidence page',
        'Official source ${s['state']}; affected checks stay paused until reviewed.',
      );
    }
  }
  for (final section in ['scholarships', 'campus', 'careers']) {
    for (final row in store.guidance[section] as List? ?? []) {
      if (!_freshEvidence(row, DateTime.now())) {
        add(
          row['sourceUrl'],
          'guidance',
          row['title'],
          'Guidance needs a reviewed source check before it can support a current recommendation.',
        );
      }
    }
  }
  return queue.values.toList();
}
