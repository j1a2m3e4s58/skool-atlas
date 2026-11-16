import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'tertiary_data.dart';
import 'student_journey.dart';

/// Local-only export. Private notes and grades are excluded unless requested.
Future<Uint8List> buildParentReport(
  TertiaryStore store,
  List<ApplicationPlan> plans, {
  bool includeGrades = false,
}) async {
  if (plans.isEmpty || plans.length > 6) {
    throw ArgumentError('Select between one and six applications.');
  }
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/roboto-regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/roboto-bold.ttf'),
  );
  final doc = pw.Document();
  final ink = PdfColor.fromHex('#173F3B');
  pw.Widget text(String value) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 7),
    child: pw.Text(value),
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(38),
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      footer: (c) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Ghana Tertiary Atlas | ${c.pageNumber} / ${c.pagesCount}',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ),
      build: (context) => [
        pw.Text(
          'Your tertiary shortlist',
          style: pw.TextStyle(
            fontSize: 25,
            fontWeight: pw.FontWeight.bold,
            color: ink,
          ),
        ),
        pw.SizedBox(height: 10),
        text(
          'Family planning report • ${DateTime.now().toIso8601String().substring(0, 10)}',
        ),
        text(
          'Official academic requirements are not an admission offer. Programme approval, current intake, selection, fees and deadlines must be confirmed with the institution. Unknown values remain unknown.',
        ),
        text(
          includeGrades
              ? 'Includes the results entered in this session. Keep this report private.'
              : 'Grades and private application notes are excluded.',
        ),
        if (includeGrades && store.sessionNewCurriculum)
          text('New curriculum. Admission requirements pending verification. ' '${store.newCurriculumGrades.entries.map((e) => "${e.key}: ${e.value == 0 ? 'Not entered / awaiting result' : gradeNames[e.value - 1]}").join('; ')}'),
        if (includeGrades && !store.sessionNewCurriculum)
          text(
            'Old curriculum. Results basis: ${store.sessionResultBasis}; sittings: ${store.sessionSittings}. ${store.sessionGrades.entries.map((e) => '${e.key}: ${gradeNames[e.value - 1]}').join('; ')}',
          ),
        for (final a in plans) ...[
          if (a != plans.first) pw.NewPage(),
          pw.SizedBox(height: 18),
          pw.Divider(color: ink),
          pw.Text(
            a.programme,
            style: pw.TextStyle(
              fontSize: 17,
              fontWeight: pw.FontWeight.bold,
              color: ink,
            ),
          ),
          text(
            store.institutions
                    .where((i) => i.id == a.institutionId)
                    .firstOrNull
                    ?.name ??
                a.institutionId,
          ),
          text('Application stage: ${a.stage}'),
          text(
            'Regulator record: ${store.institutions.where((i) => i.id == a.institutionId).firstOrNull?.source ?? 'Not available in this snapshot'}. Confirm programme approval separately.',
          ),
          ..._academic(store, a, includeGrades).map(text),
          text(
            'Personal budget (${a.period}, GHS): ${a.budget.isEmpty ? 'not entered' : a.subtotal.toStringAsFixed(2)}${a.budgetComplete ? '' : ' • incomplete; not a full cost estimate'}. Personal estimates are separate from official fees.',
          ),
          for (final e in a.budget.entries)
            text('${e.key}: GHS ${e.value.toStringAsFixed(2)}'),
          text(
            'Personal target: ${a.targetDate ?? 'not set'} (not an official deadline).',
          ),
          ..._resources(store, a).map(text),
        ],
        pw.SizedBox(height: 18),
        text(
          'Next steps: confirm the exact programme and teaching campus, regulator approval, applicable intake and selection process. Request an itemised fee schedule and accommodation terms. Apply only through official channels.',
        ),
      ],
    ),
  );
  return doc.save();
}

List<String> _academic(TertiaryStore s, ApplicationPlan a, bool include) {
  if (s.sessionNewCurriculum) {
    return ['New-curriculum programme requirements and subject acceptance remain pending verification. Older academic rules are not applied to these results.'];
  }
  final r = s.rules
      .where(
        (r) =>
            s.ruleInstitutionId(r) == a.institutionId &&
            r.matchesProgramme(a.programme),
      )
      .firstOrNull;
  if (r == null) {
    return [
      'Exact programme requirements are not verified. Contact admissions before relying on a grade suggestion.',
    ];
  }
  return [
    'Evidence: ${r.data['status']} | checked ${r.checkedAt} | ${r.data['cycle']}',
    ...describeRequirements(r),
    'Count three permitted electives alongside the three published aggregate core subjects. Additional required credits are checked separately. Each route uses its published subject grade floors.',
    for (final route in r.data['electiveRoutes'] as List? ?? [])
      '${route['label']}: three electives at ${gradeNames[(route['maxGrade'] ?? 6) - 1]} or better, subject to any stricter individual grades above. Permitted electives: ${(route['allowed'] as List).length >= electiveSubjects.length ? 'any elective, subject to the mandatory subjects and groups above' : (route['allowed'] as List).join(', ')}.',
    ...List<String>.from(r.data['additionalConditions'] ?? []),
    if (include) ...[
      assessPathway(
        r,
        s.sessionGrades,
        resultBasis: s.sessionResultBasis,
        sittings: s.sessionSittings,
      ).status,
      ...assessPathway(
        r,
        s.sessionGrades,
        resultBasis: s.sessionResultBasis,
        sittings: s.sessionSittings,
      ).reasons,
    ],
    'Official requirements: ${r.source}',
    if (r.data['generalSourceUrl'] != null)
      'General policy: ${r.data['generalSourceUrl']}',
    'Competitive cutoff: ${r.data['competitiveCutoff'] == null ? 'No current verified numerical competitive cutoff. Confirm with admissions.' : '${r.data['competitiveCutoff']['rawText']} | intake: ${r.data['competitiveCutoff']['cycle'] ?? 'unconfirmed'} | evidence: ${r.data['competitiveCutoff']['status']}. A confirmed intake and unambiguous interpretation are required for comparison. Source: ${r.data['competitiveCutoff']['sourceUrl']}'}',
  ];
}

List<String> _resources(TertiaryStore s, ApplicationPlan a) {
  final result = <String>[];
  for (final key in ['fees', 'deadlines']) {
    final rows = (s.journey.resources[key] as List? ?? []).where(
      (r) => r['institutionId'] == a.institutionId,
    );
    if (rows.isEmpty) {
      result.add(
        'Official $key: no current programme-specific record verified.',
      );
    }
    for (final r in rows) {
      result.add(
        'Institution $key reference (programme applicability must be confirmed): ${r['title'] ?? r['label'] ?? key}; evidence ${r['status'] ?? 'dated published snapshot'}; checked ${r['checkedAt']}; ${r['sourceUrl']}. ${key == 'fees' ? 'Published amount: ${r['currency']} ${r['amount']} (${r['period']}).' : 'Published date: ${r['date'] ?? 'no fixed calendar date supplied'}.'} Intake: ${r['cycle']}. ${r['note'] ?? ''} Confirm current applicability; no extension or availability is inferred.',
      );
    }
  }
  return result;
}
