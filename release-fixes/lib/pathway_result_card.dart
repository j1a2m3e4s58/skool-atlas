import 'package:flutter/material.dart';
import 'atlas_controls.dart';
import 'tertiary_data.dart';

const _ink = Color(0xFF173F3B);
const _body = Color(0xFF344B47);
const _line = Color(0xFFE0E7E3);

/// Presentation only: every result and alternative comes from the matcher.
class PathwayResultCard extends StatelessWidget {
  final PathwayRecommendation recommendation;
  final bool confirmed;
  final List<String> awaiting, notTaken;
  final List<({String subject, int grade})> nextSteps;
  final List<PathwayRecommendation> alternatives;
  final ValueChanged<String> openSource;
  final ValueChanged<AdmissionRule> openAlternative;
  final VoidCallback? track;
  const PathwayResultCard({
    super.key,
    required this.recommendation,
    required this.confirmed,
    required this.awaiting,
    required this.notTaken,
    required this.nextSteps,
    required this.alternatives,
    required this.openSource,
    required this.openAlternative,
    this.track,
  });

  @override
  Widget build(BuildContext context) {
    final rule = recommendation.rule;
    final result = recommendation.assessment;
    final failed = result.status == 'Requirements not met';
    final accent = confirmed
        ? _ink
        : failed
        ? const Color(0xFF8B3530)
        : const Color(0xFF755620);
    final tint = confirmed
        ? const Color(0xFFEDF5F0)
        : failed
        ? const Color(0xFFFCF1EE)
        : const Color(0xFFFAF5E9);
    return Container(
      key: ValueKey('pathway-result-${rule.id}'),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080D3029),
            blurRadius: 24,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.all(
            MediaQuery.sizeOf(context).width < 500 ? 18 : 28,
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontSize: 15, height: 1.55, color: _body),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.institution,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  rule.programme,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 14),
                if ('${rule.data['campus'] ?? ''}'.trim().isNotEmpty) ...[
                  Text(
                    'Teaching location: ${rule.data['campus']}',
                    style: const TextStyle(fontSize: 13, color: _body),
                  ),
                  const SizedBox(height: 12),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _tag('${rule.data['qualification'] ?? 'WASSCE'}'),
                    _tag('${rule.data['studyMode'] ?? 'Published route'}'),
                    _tag(
                      rule.data['scope'] == 'institution_general'
                          ? 'General entry check'
                          : 'Programme route',
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ACADEMIC CHECK',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(
                              confirmed
                                  ? Icons.check_circle_outline
                                  : Icons.info_outline,
                              color: accent,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              result.status,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: accent,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (result.reasons.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(result.reasons.first),
                      ],
                      if (awaiting.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Awaiting results: ${awaiting.join(', ')}. Missing grades are never assumed to be passes.',
                        ),
                      ],
                      if (notTaken.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Not taken: ${notTaken.join(', ')}. These subjects are excluded from the calculation. Marking a subject as not taken does not waive a compulsory subject requirement.',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Details & next steps',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 8),
                _section('Why this appears', Icons.lightbulb_outline, [
                  ...result.reasons.skip(1).map(_paragraph),
                  ...recommendation.fitReasons.map(_paragraph),
                  ...recommendation.tradeoffs.map(_paragraph),
                  _paragraph(
                    'Ordering reflects academic check status first, then your preferences. It is not an admission probability or a ranking of institutional quality.',
                  ),
                ]),
                if (result.countedSubjects.isNotEmpty)
                  _section(
                    'Your six counted subjects',
                    Icons.format_list_bulleted,
                    [
                      for (final entry in result.countedSubjects.entries)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: _line)),
                          ),
                          child: Text(
                            '${entry.key}: ${gradeNames[entry.value - 1]} (${entry.value})',
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        result.route.isEmpty
                            ? 'Aggregate ${result.aggregate}'
                            : 'Aggregate ${result.aggregate} · ${result.route}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                    ],
                    subtitle:
                        'Aggregate ${result.aggregate} · View the subject breakdown',
                  ),
                _section(
                  'What the published rule checks',
                  Icons.fact_check_outlined,
                  [
                    ...describeRequirements(rule).map(_paragraph),
                    if (rule.data['aggregationNote'] is String)
                      _paragraph(rule.data['aggregationNote']),
                    if ((rule.data['additionalConditions'] as List? ?? [])
                        .isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Additional admission conditions',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      ...(rule.data['additionalConditions'] as List).map(
                        (c) => _paragraph(c as String),
                      ),
                    ],
                  ],
                ),
                if (!result.academicPass &&
                    rule.data['scope'] == 'programme') ...[
                  _section('What could change this result?', Icons.trending_up, [
                    for (final step in nextSteps)
                      _paragraph(
                        'Hypothetically, ${step.subject} at ${gradeNames[step.grade - 1]} would meet this academic check.',
                      ),
                    _paragraph(
                      'Use the simulator to explore a change. Missing subjects, other conditions or multiple shortfalls may still need attention. A hypothetical replacement grade does not establish permission to combine sittings.',
                    ),
                  ]),
                  _section(
                    'Related courses to consider',
                    Icons.alt_route,
                    [
                      if (alternatives.isNotEmpty)
                        _paragraph(
                          'These alternatives meet their checked academic minimum with the entered grades. Additional conditions and competitive selection still apply.',
                        ),
                      if (alternatives.isEmpty)
                        _paragraph(
                          'No verified related alternative was found in this limited dataset. This does not mean that no route exists in Ghana. See the general entry checks for routes that need programme confirmation.',
                        ),
                      for (final alternative in alternatives)
                        Container(
                          margin: const EdgeInsets.only(top: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: _line),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            title: Text(
                              alternative.rule.programme,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '${alternative.rule.institution}\n${alternative.assessment.status}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            trailing: const Icon(Icons.arrow_forward, size: 18),
                            onTap: () => openAlternative(alternative.rule),
                          ),
                        ),
                    ],
                    subtitle: alternatives.isEmpty
                        ? 'Check other available routes'
                        : '${alternatives.length} academically matching alternatives',
                  ),
                ],
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F5EF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Competitive cutoff · separate check',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        result.cutoff.status,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                      _section('Cutoff details & source', Icons.open_in_new, [
                        _paragraph(result.cutoff.detail),
                        if (rule.data['competitiveCutoff'] is Map)
                          TextButton.icon(
                            onPressed: () => openSource(
                              rule.data['competitiveCutoff']['sourceUrl'],
                            ),
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: const Text('Official cutoff table'),
                          ),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _section(
                  'Evidence & admission notes',
                  Icons.verified_outlined,
                  [
                    for (final note in {
                      rule.data['cutoffText'],
                      rule.data['note'],
                    }.whereType<String>().where((s) => s.trim().isNotEmpty))
                      _paragraph(note),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Source checked ${rule.checkedAt}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${rule.data['cycle']}',
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 18),
                AtlasActionRow(
 children: [
FilledButton.tonalIcon(
                      onPressed: track,
                      icon: const Icon(Icons.playlist_add, size: 18),
                      label: const Text('Track this programme'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => openSource(rule.source),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Verify official requirements'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tag(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F5F2),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: _ink,
        height: 1.4,
      ),
    ),
  );

  Widget _paragraph(String text) =>
      Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(text));

  Widget _section(
    String title,
    IconData icon,
    List<Widget> children, {
    String? subtitle,
  }) => AtlasDisclosure(
    tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    childrenPadding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
    expandedCrossAxisAlignment: CrossAxisAlignment.start,
    shape: const Border(bottom: BorderSide(color: _line)),
    collapsedShape: const Border(bottom: BorderSide(color: _line)),
    iconColor: _ink,
    collapsedIconColor: _ink,
    leading: Icon(icon, size: 20, color: _ink),
    title: Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: _ink,
        height: 1.4,
      ),
    ),
    subtitle: subtitle == null
        ? null
        : Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: _body, height: 1.5),
          ),
    children: children,
  );
}
