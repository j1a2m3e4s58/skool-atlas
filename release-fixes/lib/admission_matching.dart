part of 'tertiary_data.dart';

class CutoffAssessment {
  final String status, detail;
  const CutoffAssessment(this.status, this.detail);
}

class MatchAssessment {
  final String status;
  final List<String> reasons;
  final int? aggregate;
  final Map<String, int> countedSubjects;
  final bool academicPass;
  final String route;
  final CutoffAssessment cutoff;
  const MatchAssessment(
    this.status,
    this.reasons,
    this.aggregate, {
    this.countedSubjects = const {},
    this.academicPass = false,
    this.route = '',
    this.cutoff = const CutoffAssessment(
      'Not checked',
      'Academic requirements must be checked first.',
    ),
  });
}

bool _freshEvidence(Map data, DateTime now) {
  final checked = DateTime.tryParse('${data['checkedAt']}');
  return data['status'] == 'source_checked' &&
      checked != null &&
      !checked.isAfter(now) &&
      now.difference(checked).inDays <= 180;
}

CutoffAssessment assessCutoff(
  AdmissionRule rule,
  int? aggregate, {
  required bool academicPass,
  String? targetCycle,
  DateTime? now,
}) {
  final raw = rule.data['competitiveCutoff'];
  if (raw is! Map) {
    return const CutoffAssessment(
      'No verified programme cutoff',
      'A general academic minimum is not a competitive admission cutoff.',
    );
  }
  final printed = '${raw['rawText'] ?? raw['value'] ?? 'Not stated'}';
  if (!_freshEvidence(raw, now ?? DateTime.now())) {
    return CutoffAssessment(
      'Cutoff needs verification',
      'Official table prints $printed. Its year, interpretation or source needs confirmation; no cutoff match is inferred.',
    );
  }
  if (raw['cycle'] == null ||
      raw['value'] is! int ||
      raw['interpretation'] != 'unambiguous') {
    return CutoffAssessment(
      'Cutoff interpretation unconfirmed',
      'Official table prints $printed. No current numerical comparison is available.',
    );
  }
  if (targetCycle == null || targetCycle != raw['cycle']) {
    return CutoffAssessment(
      'Different or unselected admission year',
      'Published cutoff: $printed for ${raw['cycle']}. It is not applied to another or unspecified year.',
    );
  }
  if (raw['studyMode'] != rule.data['studyMode'] ||
      raw['applicantCategory'] != rule.data['applicantCategory']) {
    return const CutoffAssessment(
      'Different admission route',
      'The published cutoff belongs to another study mode or applicant category.',
    );
  }
  if (!academicPass || aggregate == null) {
    return const CutoffAssessment(
      'Academic requirements must be met first',
      'An aggregate alone cannot satisfy subject and grade requirements.',
    );
  }
  return aggregate <= (raw['value'] as int)
      ? CutoffAssessment(
          'Within published cutoff',
          'Aggregate $aggregate is within $printed for ${raw['cycle']}. This is not an admission offer; selection conditions still apply.',
        )
      : CutoffAssessment(
          'Above published cutoff',
          'Aggregate $aggregate exceeds $printed for ${raw['cycle']}. Academic minimum and competitive cutoff are separate checks.',
        );
}

List<List<String>> _triples(List<String> values) => [
  for (var a = 0; a < values.length; a++)
    for (var b = a + 1; b < values.length; b++)
      for (var c = b + 1; c < values.length; c++)
        [values[a], values[b], values[c]],
];

MatchAssessment assessRule(
  AdmissionRule rule,
  Map<String, int> grades, {
  DateTime? now,
  String? targetCycle,
}) {
  final clock = now ?? DateTime.now();
  MatchAssessment result(
    String status,
    List<String> reasons,
    int? sum, {
    Map<String, int> counted = const {},
    bool passed = false,
    String route = '',
  }) => MatchAssessment(
    status,
    reasons,
    sum,
    countedSubjects: counted,
    academicPass: passed,
    route: route,
    cutoff: assessCutoff(
      rule,
      sum,
      academicPass: passed,
      targetCycle: targetCycle,
      now: clock,
    ),
  );
  try {
    validateAdmissionRule(rule);
  } catch (_) {
    return result('Needs source review', [
      'This rule is incomplete or unsupported. No match is inferred.',
    ], null);
  }
  if (!_freshEvidence(rule.data, clock)) {
    return result('Needs source review', [
      'This rule needs a fresh source check before matching.',
    ], null);
  }
  if (grades.containsKey('Ghanaian Language') &&
      namedGhanaianLanguages.any(grades.containsKey)) {
    return result('Invalid results', [
      'Choose the exact language only; a generic Ghanaian Language entry cannot count again alongside a named language.',
    ], null);
  }
  if (grades.entries.any(
    (e) =>
        ![...coreSubjects, ...electiveSubjects].contains(e.key) ||
        e.value < 1 ||
        e.value > 9,
  )) {
    return result('Invalid results', [
      'Use a supported subject and a WASSCE grade from A1 to F9.',
    ], null);
  }
  final data = rule.data;
  final coreLimits = Map<String, dynamic>.from(
    data['coreMaxGrades'] as Map? ?? {},
  );
  final floors = Map<String, dynamic>.from(data['gradeFloors'] as Map? ?? {});
  final baseCores = List<String>.from(data['coreCredits']);
  final alternatives = List<String>.from(
    data['scienceOrSocial'] as List? ?? [],
  );
  final coreOptions = <List<String>>[List<String>.from(data['aggregateCores'])];
  if (alternatives.isNotEmpty) {
    coreOptions.clear();
    for (final alternative in alternatives) {
      final cores = List<String>.from(data['aggregateCores']);
      cores[cores.indexOf(alternatives.first)] = alternative;
      coreOptions.add(cores);
    }
  }
  final routes = data['electiveRoutes'] is List
      ? List<Map<String, dynamic>>.from(
          (data['electiveRoutes'] as List).map(
            (r) => Map<String, dynamic>.from(r),
          ),
        )
      : <Map<String, dynamic>>[
          {
            'label': 'Published elective combination',
            'required': rule.requiredElectives,
            'countedRequired': rule.requiredElectives,
            'allowed': data['allowedElectives'] ?? electiveSubjects,
          },
        ];
  Map<String, int>? best;
  String bestRoute = '';
  String? bestConfirmation;
  List<String>? bestErrors, bestMissing;
  int? bestFailedAggregate;
  Map<String, int> bestFailedCounted = {};
  var bestFailedEnteredElectives = -1;
  for (final countedCores in coreOptions) {
    final creditCores = List<String>.from(baseCores);
    if (alternatives.isNotEmpty) {
      creditCores[creditCores.indexOf(alternatives.first)] = countedCores
          .firstWhere(alternatives.contains);
    }
    for (final route in routes) {
      final errors = <String>[], missing = <String>[];
      final routeCoreLimits = Map<String, dynamic>.from(
        route['coreMaxGrades'] as Map? ?? {},
      );
      for (final s in creditCores) {
        final base = (floors[s] ?? coreLimits[s] ?? 6) as int;
        final local = (routeCoreLimits[s] ?? base) as int;
        final limit = base < local ? base : local;
        if (grades[s] == null) {
          missing.add(
            alternatives.contains(s) &&
                    alternatives.every((subject) => grades[subject] == null)
                ? alternatives.join(' OR ')
                : s,
          );
        } else if (grades[s]! > limit) {
          final alternativesFailSameLimit = alternatives.contains(s) &&
              alternatives.every((subject) {
                final alternativeBase =
                    (floors[subject] ?? coreLimits[subject] ?? 6) as int;
                final alternativeLocal =
                    (routeCoreLimits[subject] ?? alternativeBase) as int;
                final alternativeLimit = alternativeBase < alternativeLocal
                    ? alternativeBase : alternativeLocal;
                return grades[subject] != null &&
                    grades[subject]! > alternativeLimit &&
                    alternativeLimit == limit;
              });
          final subjectLabel = alternativesFailSameLimit
              ? alternatives.join(' OR ') : s;
          final unenteredAlternatives = alternatives.contains(s)
              ? alternatives.where((subject) => grades[subject] == null)
              : const <String>[];
          final alternativeAdvice = unenteredAlternatives.map((subject) {
            final alternativeBase =
                (floors[subject] ?? coreLimits[subject] ?? 6) as int;
            final alternativeLocal =
                (routeCoreLimits[subject] ?? alternativeBase) as int;
            final alternativeLimit = alternativeBase < alternativeLocal
                ? alternativeBase : alternativeLocal;
            return ' Alternatively, add or confirm $subject at '
                '${gradeNames[alternativeLimit - 1]} or better; '
                'an unentered or awaiting result is not assumed to pass.';
          }).join();
          errors.add(
            (local < base
                ? '$subjectLabel needs ${gradeNames[limit - 1]} or better for ${route['label'] ?? 'this route'}.'
                : '$subjectLabel needs ${gradeNames[limit - 1]} or better.') +
                alternativeAdvice,
          );
        }
      }
      final maxGrade = (route['maxGrade'] ?? 6) as int;
      final required = List<String>.from(route['required'] as List? ?? []);
      final countedRequired = List<String>.from(
        route['countedRequired'] as List? ?? required,
      );
      for (final s in required) {
        final limit = (floors[s] ?? maxGrade) as int;
        if (grades[s] == null) {
          missing.add(s);
        } else if (grades[s]! > limit) {
          errors.add('$s needs ${gradeNames[limit - 1]} or better.');
        }
      }
      final allowed = List<String>.from(
        route['allowed'] as List? ?? electiveSubjects,
      );
      final entered = allowed.where(grades.containsKey).toList();
      final groups = List<Map<String, dynamic>>.from(
        (route['groups'] as List? ?? []).map(
          (g) => Map<String, dynamic>.from(g),
        ),
      );
      final triples = _triples(
        entered,
      ).where((t) => t.toSet().containsAll(countedRequired)).toList();
      Map<String, int>? routeBest;
      for (final triple in triples) {
        if (countedCores.any((s) => !grades.containsKey(s))) continue;
        if (triple.any((s) => grades[s]! > ((floors[s] ?? maxGrade) as int))) {
          continue;
        }
        if (groups.any(
          (g) =>
              triple
                  .where(
                    (s) =>
                        (g['subjects'] as List).contains(s) &&
                        grades[s]! <= ((g['maxGrade'] ?? maxGrade) as int),
                  )
                  .length <
              (g['count'] as int),
        )) {
          continue;
        }
        final counted = {
          for (final s in [...countedCores, ...triple]) s: grades[s]!,
        };
        if (counted.length != 6) continue;
        final credits = counted.values.where((g) => g <= 6).length;
        if (credits < ((data['minCredits'] ?? 6) as int)) continue;
        final total = counted.values.fold(0, (a, b) => a + b);
        if (data['maxAggregate'] is int &&
            total > (data['maxAggregate'] as int)) {
          continue;
        }
        if (routeBest == null ||
            total < routeBest.values.fold(0, (a, b) => a + b)) {
          routeBest = counted;
        }
      }
      if (routeBest != null && errors.isEmpty && missing.isEmpty) {
        final confirmation = route['confirmation'] as String?;
        if (best == null ||
            bestConfirmation != null && confirmation == null ||
            (bestConfirmation == null) == (confirmation == null) &&
                routeBest.values.fold(0, (a, b) => a + b) <
                    best.values.fold(0, (a, b) => a + b)) {
          best = routeBest;
          bestRoute = '${route['label'] ?? 'Published route'}';
          bestConfirmation = confirmation;
        }
        continue;
      }
      if (entered.length < 3) {
        missing.add('three entered electives accepted by this route');
      }
      for (final g in groups) {
        final subjects = List<String>.from(g['subjects']);
        final limit = (g['maxGrade'] ?? maxGrade) as int;
        final known = subjects.where(grades.containsKey).toList();
        final qualified = known.where((s) => grades[s]! <= limit).length;
        if (qualified < (g['count'] as int)) {
          final message =
              '${g['count']} of ${subjects.join(', ')} at ${gradeNames[limit - 1]} or better';
          if (known.length < (g['count'] as int)) {
            missing.add(message);
          } else {
            errors.add('This route needs $message.');
          }
        }
      }
      // Explain the best available combination even if its aggregate is too high.
      final possible = triples
          .where(
            (t) =>
                !t.any((s) => grades[s]! > ((floors[s] ?? maxGrade) as int)) &&
                !groups.any(
                  (g) =>
                      t
                          .where(
                            (s) =>
                                (g['subjects'] as List).contains(s) &&
                                grades[s]! <=
                                    ((g['maxGrade'] ?? maxGrade) as int),
                          )
                          .length <
                      (g['count'] as int),
                ),
          )
          .toList();
      int? sum;
      Map<String, int> failedCounted = {};
      if (possible.isNotEmpty && countedCores.every(grades.containsKey)) {
        possible.sort(
          (a, b) => a
              .fold(0, (n, s) => n + grades[s]!)
              .compareTo(b.fold(0, (n, s) => n + grades[s]!)),
        );
        failedCounted = {
          for (final s in [...countedCores, ...possible.first]) s: grades[s]!,
        };
        final sums =
            possible
                .map(
                  (t) =>
                      [...countedCores, ...t].fold(0, (a, s) => a + grades[s]!),
                )
                .toList()
              ..sort();
        sum = sums.first;
        if (data['maxAggregate'] is int &&
            sum > (data['maxAggregate'] as int)) {
          errors.add(
            'Aggregate $sum exceeds the published academic limit of ${data['maxAggregate']}.',
          );
        }
      }
      if (entered.length >= 3 &&
          routeBest == null &&
          errors.isEmpty &&
          missing.isEmpty) {
        errors.add(
          'The entered electives do not meet the required combination, grades or credit count.',
        );
      }
      final score = errors.length + missing.length;
      if (bestErrors == null ||
          score < bestErrors.length + bestMissing!.length ||
          score == bestErrors.length + bestMissing.length &&
              entered.length > bestFailedEnteredElectives) {
        bestErrors = errors;
        bestMissing = missing;
        bestFailedAggregate = sum;
        bestFailedCounted = failedCounted;
        bestFailedEnteredElectives = entered.length;
      }
    }
  }
  if (best != null) {
    final total = best.values.fold(0, (a, b) => a + b);
    final general = data['scope'] == 'institution_general';
    return result(
      bestConfirmation != null
          ? 'Additional route information needed'
          : general
          ? 'Meets general entry minimum only'
          : 'Meets checked academic minimum',
      [
        'Aggregate $total from the six subjects shown below.',
        if (general)
          'This is a general institutional check; exact programme requirements remain unverified.',
        ?bestConfirmation,
        'Academic minimum and competitive selection are assessed separately. Additional admission conditions still apply.',
      ],
      total,
      counted: best,
      passed: bestConfirmation == null,
      route: bestRoute,
    );
  }
  final errors = bestErrors ?? <String>[], missing = bestMissing ?? <String>[];
  return result(
    errors.isNotEmpty ? 'Requirements not met' : 'More results needed',
    [
      ...errors,
      if (missing.isNotEmpty) 'Add or confirm: ${missing.toSet().join('; ')}.',
    ],
    bestFailedAggregate,
    counted: bestFailedCounted,
  );
}

void validateAdmissionRule(AdmissionRule rule) {
  try {
    _validateAdmissionRule(rule);
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('Invalid admission rule structure');
  }
}

void _validateAdmissionRule(AdmissionRule rule) {
  final d = rule.data;
  bool validSubjects(dynamic raw, List<String> allowed, {int? length}) =>
      raw is List &&
      (length == null || raw.length == length) &&
      raw.toSet().length == raw.length &&
      raw.every((s) => s is String && allowed.contains(s));
  void need(bool value) {
    if (!value) throw const FormatException('Invalid admission rule');
  }

  final url = Uri.tryParse('${d['sourceUrl']}');
  if (d['sittingPolicy'] != null) {
    final p = d['sittingPolicy'];
    need(
      p is Map &&
          p['maxSittings'] is int &&
          p['maxSittings'] >= 1 &&
          p['maxSittings'] <= 2 &&
          Uri.tryParse('${p['sourceUrl']}')?.scheme == 'https' &&
          DateTime.tryParse('${p['checkedAt']}') != null &&
          ['source_checked', 'needs_source_review'].contains(p['status']),
    );
  }
  need(
    d['programmeAliases'] == null ||
        d['programmeAliases'] is List &&
            (d['programmeAliases'] as List).every(
              (name) => name is String && name.trim().isNotEmpty,
            ),
  );
  need(
    d['id'] is String &&
        rule.id.isNotEmpty &&
        d['institution'] is String &&
        rule.institution.isNotEmpty &&
        d['programme'] is String &&
        rule.programme.isNotEmpty,
  );
  need(
    url?.scheme == 'https' &&
        url!.host.isNotEmpty &&
        DateTime.tryParse('${d['checkedAt']}') != null,
  );
  need(['source_checked', 'needs_source_review'].contains(d['status']));
  need(
    d['programmeRegions'] == null ||
        d['programmeRegions'] is List &&
            (d['programmeRegions'] as List).isNotEmpty &&
            (d['programmeRegions'] as List).toSet().length ==
                (d['programmeRegions'] as List).length &&
            (d['programmeRegions'] as List).every(pathwayRegions.contains),
  );
  need(d['ruleVersion'] == null || [2, 3].contains(d['ruleVersion']));
  need(
    d['ruleVersion'] == 3
        ? d['finalResultsRequired'] is bool
        : d['finalResultsRequired'] == null,
  );
  need(
    validSubjects(d['coreCredits'], coreSubjects) &&
        (d['coreCredits'] as List).isNotEmpty &&
        validSubjects(d['aggregateCores'], coreSubjects, length: 3),
  );
  need(
    (d['coreCredits'] as List).toSet().containsAll(d['aggregateCores'] as List),
  );
  need(
    d['maxAggregate'] is int &&
            d['maxAggregate'] >= 6 &&
            d['maxAggregate'] <= 54 ||
        [2, 3].contains(d['ruleVersion']) && d['maxAggregate'] == null,
  );
  need(
    validSubjects(d['requiredElectives'] ?? [], electiveSubjects) &&
        (d['requiredElectives'] as List? ?? []).length <= 3,
  );
  need(
    validSubjects(d['allowedElectives'] ?? electiveSubjects, electiveSubjects),
  );
  need(
    (d['allowedElectives'] as List? ?? electiveSubjects).toSet().containsAll(
      d['requiredElectives'] as List? ?? [],
    ),
  );
  final alternatives = d['scienceOrSocial'] as List? ?? [];
  need(
    alternatives.isEmpty ||
        validSubjects(alternatives, [
              'Integrated Science',
              'Social Studies',
            ], length: 2) &&
            (d['coreCredits'] as List).contains(alternatives.first) &&
            (d['aggregateCores'] as List).contains(alternatives.first),
  );
  for (final name in ['gradeFloors', 'coreMaxGrades']) {
    need(d[name] == null || d[name] is Map);
    for (final e in (d[name] as Map? ?? {}).entries) {
      need(
        [...coreSubjects, ...electiveSubjects].contains(e.key) &&
            e.value is int &&
            e.value >= 1 &&
            e.value <= (name == 'coreMaxGrades' ? 8 : 6),
      );
    }
  }
  if ([2, 3].contains(d['ruleVersion'])) {
    need(
      d['qualification'] == 'WASSCE' &&
          ['programme', 'institution_general'].contains(d['scope']),
    );
    need(
      d['studyMode'] is String &&
          d['applicantCategory'] is String &&
          d['cycle'] is String,
    );
    need(
      d['minCredits'] == null ||
          d['minCredits'] is int &&
              d['minCredits'] >= 0 &&
              d['minCredits'] <= 6,
    );
    need(
      d['additionalConditions'] == null ||
          d['additionalConditions'] is List &&
              (d['additionalConditions'] as List).every((v) => v is String),
    );
    need(
      d['electiveRoutes'] is List &&
          (d['electiveRoutes'] as List).isNotEmpty &&
          (d['electiveRoutes'] as List).length <= 12,
    );
    for (final raw in d['electiveRoutes']) {
      need(raw is Map);
      final r = raw as Map;
      need(
        r.keys.every(
          (k) => [
            'label',
            'required',
            'countedRequired',
            'allowed',
            'groups',
            'maxGrade',
            'confirmation',
            'coreMaxGrades',
          ].contains(k),
        ),
      );
      need(r['confirmation'] == null || r['confirmation'] is String);
      need(r['coreMaxGrades'] == null || r['coreMaxGrades'] is Map);
      for (final e in (r['coreMaxGrades'] as Map? ?? {}).entries) {
        need(
          [
                ...(d['coreCredits'] as List),
                ...(d['scienceOrSocial'] as List? ?? []),
              ].contains(e.key) &&
              e.value is int &&
              e.value >= 1 &&
              e.value <= 6,
        );
      }
      final allowed = r['allowed'] ?? electiveSubjects;
      need(
        validSubjects(allowed, electiveSubjects) &&
            (allowed as List).length >= 3,
      );
      need(
        validSubjects(r['required'] ?? [], electiveSubjects) &&
            (r['required'] as List? ?? []).length <= 4,
      );
      need(
        validSubjects(
              r['countedRequired'] ?? r['required'] ?? [],
              electiveSubjects,
            ) &&
            (r['countedRequired'] as List? ?? r['required'] as List? ?? [])
                    .length <=
                3,
      );
      need(
        (allowed as List).toSet().containsAll(
          r['countedRequired'] as List? ?? r['required'] as List? ?? [],
        ),
      );
      need(
        r['maxGrade'] == null ||
            r['maxGrade'] is int && r['maxGrade'] >= 1 && r['maxGrade'] <= 8,
      );
      need(r['groups'] == null || r['groups'] is List);
      for (final g in r['groups'] as List? ?? []) {
        need(
          g is Map &&
              g.keys.every(
                (k) => ['subjects', 'count', 'maxGrade'].contains(k),
              ),
        );
        need(
          g is Map &&
              validSubjects(g['subjects'], electiveSubjects) &&
              g['count'] is int &&
              g['count'] >= 1 &&
              g['count'] <= 3 &&
              (g['subjects'] as List).length >= g['count'],
        );
        need((allowed).toSet().containsAll(g['subjects'] as List));
        need(
          g['maxGrade'] == null ||
              g['maxGrade'] is int && g['maxGrade'] >= 1 && g['maxGrade'] <= 7,
        );
      }
    }
  }
  if (d['competitiveCutoff'] != null) {
    need(d['competitiveCutoff'] is Map);
    final c = d['competitiveCutoff'] as Map;
    need(
      Uri.tryParse('${c['sourceUrl']}')?.scheme == 'https' &&
          DateTime.tryParse('${c['checkedAt']}') != null,
    );
    need(c['rawText'] is String && c['rawText'].isNotEmpty);
    need(
      [
        'source_checked',
        'needs_source_review',
        'cycle_unconfirmed',
        'ambiguous',
      ].contains(c['status']),
    );
    need(
      c['value'] == null ||
          c['value'] is int && c['value'] >= 6 && c['value'] <= 54,
    );
    if (c['status'] == 'source_checked') {
      need(
        RegExp(r'^\d+$').hasMatch(c['rawText'].trim()) &&
            int.tryParse(c['rawText'].trim()) == c['value'],
      );
      final yearParts = '${c['cycle']}'.split('/');
      need(
        yearParts.length == 2 &&
            int.tryParse(yearParts[0]) != null &&
            int.tryParse(yearParts[1]) == int.parse(yearParts[0]) + 1,
      );
      need(
        c['interpretation'] == 'unambiguous' &&
            c['value'] is int &&
            RegExp(r'^\d{4}/\d{4}$').hasMatch('${c['cycle']}') &&
            c['studyMode'] is String &&
            c['applicantCategory'] is String,
      );
    }
  }
}
