import 'atlas_plus_panel.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'atlas_controls.dart';
import 'tertiary_data.dart';
import 'tertiary_app.dart' show GlassPanel, ink, gold;
import 'student_journey.dart';
import 'local_export.dart';
import 'package:url_launcher/url_launcher.dart';
import 'tertiary_gallery.dart';
import 'automatic_reminders.dart';
import 'student_guidance.dart';
import 'parent_report.dart';

class StudentHub extends StatefulWidget {
  final TertiaryStore store;
  final VoidCallback onGrades;
  final void Function(TertiaryInstitution) onProfile;
  const StudentHub({
    super.key,
    required this.store,
    required this.onGrades,
    required this.onProfile,
  });
  @override
  State<StudentHub> createState() => _StudentHubState();
}

class _StudentHubState extends State<StudentHub> {
  int section = 0;
  bool showClosed = false;
  String reminderStatus =
      'Choose a saved future target date and enable its reminder to get started.';
  bool reminderBusy = false;
  @override
  void initState() {
    super.initState();
    automaticReminderStatus()
        .then((value) {
          if (mounted) setState(() => reminderStatus = value);
        })
        .catchError((Object _) {});
  }

  String resourceInstitution = 'all';
  StudentJourney get journey => widget.store.journey;
  TertiaryInstitution? school(String id) =>
      widget.store.institutions.where((i) => i.id == id).firstOrNull;
  String schoolName(String id) =>
      school(id)?.name ?? 'Institution no longer in this snapshot ($id)';
  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> action(Future<void> Function() task) async {
    try {
      await task();
      if (mounted) setState(() {});
    } catch (e) {
      message(e.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> link(String url) async {
    final uri = Uri.tryParse(url);
    if (uri?.scheme != 'https' ||
        !await launchUrl(uri!, mode: LaunchMode.externalApplication)) {
      message(
        'The official link could not open. Internet access may be needed.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'YOUR NEXT CHAPTER',
                style: TextStyle(color: gold, letterSpacing: 2, fontSize: 11),
              ),
              const SizedBox(height: 8),
              const Text(
                'My journey',
                style: TextStyle(
                  fontFamily: 'AtlasSerif',
                  fontSize: 38,
                  color: ink,
                ),
              ),
              const Text(
                'Plan your applications, compare your options and follow the schools that matter to you. Your journey stays on this device unless you choose cloud backup in Atlas Plus.',
              ),
              const SizedBox(height: 18),
              if (journey.storageError != null)
                Text(
                  journey.storageError!,
                  style: const TextStyle(color: Colors.red),
                ),
              AtlasActionRow(
 children: [
FilledButton.icon(
                    onPressed: journey.storageError == null
                        ? addProgramme
                        : null,
                    icon: const Icon(Icons.add),
                    label: const Text('Add programme'),
                  ),
                  OutlinedButton.icon(
                    onPressed: journey.applications.isEmpty
                        ? null
                        : parentReport,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Family PDF report'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onGrades,
                    icon: const Icon(Icons.tune),
                    label: const Text('Check my grades'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => action(() async {
                      final ok = await saveTextFile(
                        'tertiary-journey.json',
                        const JsonEncoder.withIndent('  ').convert({
                          'exportedAt': DateTime.now().toIso8601String(),
                          'applications': journey.applications
                              .map((a) => a.toJson())
                              .toList(),
                          'comparison': journey.comparison,
                          'updates': journey.updates,
                        }),
                        'application/json',
                      );
                      if (!ok) {
                        throw StateError(
                          'Export was not available on this device.',
                        );
                      }
                      message(
                        'Journey export prepared. Keep this personal file private.',
                      );
                    }),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Export journey'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (index, label) in [
                    'Applications',
                    'Compare',
                    'Costs & scholarships',
                    'Galleries',
                    'Updates',
                    'Funding match',
                    'Campus life',
                    'Careers & licences',
                    'Evidence coverage',
                    'Atlas Plus',
                  ].indexed)
                    ChoiceChip(
                      label: Text(label),
                      selected: section == index,
                      onSelected: (_) => setState(() => section = index),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              if (section == 0) ...applications(),
              if (section == 1) ...comparison(),
              if (section == 2) ...resources(),
              if (section == 3) ...galleries(),
              if (section == 4) ...updates(),
              if (section == 9) AtlasPlusPanel(store: widget.store, onReport: parentReport),
              if (section >= 5 && section < 9)
                GuidancePanel(
                  key: ValueKey(section),
                  store: widget.store,
                  section: section,
                ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    ),
  );

  Widget title(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 23,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
    ),
  );
  Widget panel(List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    ),
  );

  Future<void> parentReport() async {
    final selected = journey.applications.take(4).map((a) => a.id).toSet();
    bool includeGrades = false;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Family shortlist report'),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Choose up to six saved applications. This downloads a PDF on this device. Private notes are excluded.',
                  ),
                  for (final a in journey.applications)
                    CheckboxListTile(
                      value: selected.contains(a.id),
                      title: Text(a.programme),
                      subtitle: Text(schoolName(a.institutionId)),
                      onChanged: (v) => update(() {
                        if (v == true && selected.length < 6) {
                          selected.add(a.id);
                        } else if (v != true) {
                          selected.remove(a.id);
                        }
                      }),
                    ),
                  CheckboxListTile(
                    value: includeGrades,
                    title: const Text(
                      'Include entered grades and academic explanations',
                    ),
                    subtitle: const Text(
                      'Optional personal information. Keep the downloaded file private.',
                    ),
                    onChanged: (v) => update(() => includeGrades = v ?? false),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: const Text('Download PDF'),
            ),
          ],
        ),
      ),
    );
    if (proceed != true) return;
    await action(() async {
      final bytes = await buildParentReport(
        widget.store,
        journey.applications.where((a) => selected.contains(a.id)).toList(),
        includeGrades: includeGrades,
      );
      if (!await saveBinaryFile(
        'ghana-tertiary-family-report.pdf',
        bytes,
        'application/pdf',
      )) {
        throw StateError('PDF download is unavailable on this device.');
      }
      message(
        'Family report prepared. Keep any included personal results private.',
      );
    });
  }

  Future<void> addProgramme() async {
    String query = '', courseQuery = '';
    TertiaryInstitution? selected;
    await showDialog<void>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (ctx, update) {
          final schools = widget.store.institutions
              .where(
                (i) =>
                    query.trim().isEmpty ||
                    '${i.name} ${i.aliases.join(' ')} ${i.regions.join(' ')}'
                        .toLowerCase()
                        .contains(query.toLowerCase().trim()),
              )
              .take(25);
          final seenProgrammes = <String>{};
          final courses = selected == null
              ? <String>[]
              : {
                      ...widget.store.rules
                          .where(
                            (r) =>
                                widget.store.ruleInstitutionId(r) ==
                                selected!.id,
                          )
                          .map((r) => r.programme),
                      ...selected!.courses,
                    }
                    .where((c) => seenProgrammes.add(programmeIdentity(c)))
                    .where(
                      (c) => c.toLowerCase().contains(
                        courseQuery.toLowerCase().trim(),
                      ),
                    )
                    .take(40)
                    .toList();
          return AlertDialog(
            title: Text(
              selected == null ? 'Choose an institution' : 'Choose a programme',
            ),
            content: SizedBox(
              width: 650,
              height: 430,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selected == null)
                    TextField(
                      key: const ValueKey('institution-picker-search'),
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Search institution, abbreviation or region',
                      ),
                      onChanged: (v) => update(() => query = v),
                    )
                  else ...[
                    Text(
                      selected!.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () => update(() {
                        selected = null;
                        courseQuery = '';
                      }),
                      child: const Text('Change institution'),
                    ),
                    TextField(
                      key: const ValueKey('programme-picker-search'),
                      decoration: const InputDecoration(
                        labelText: 'Search listed programmes',
                      ),
                      onChanged: (v) => update(() => courseQuery = v),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: selected == null
                          ? [
                              for (final i in schools)
                                ListTile(
                                  title: Text(i.name),
                                  subtitle: Text(i.regions.join(' · ')),
                                  onTap: () => update(() => selected = i),
                                ),
                              if (schools.isEmpty)
                                const Text(
                                  'No institution found. Try another name.',
                                ),
                            ]
                          : [
                              const Text(
                                'A register listing is not a verified entry rule or a current admission offer.',
                                style: TextStyle(fontSize: 12),
                              ),
                              for (final course in courses)
                                ListTile(
                                  title: Text(course),
                                  trailing: const Icon(
                                    Icons.add_circle_outline,
                                  ),
                                  onTap: () async {
                                    try {
                                      await journey.track(selected!.id, course);
                                      if (dialog.mounted) Navigator.pop(dialog);
                                      if (mounted) {
                                        setState(() => section = 0);
                                        message(
                                          'Programme added to your journey.',
                                        );
                                      }
                                    } catch (e) {
                                      message('$e');
                                    }
                                  },
                                ),
                              if (courses.isEmpty)
                                const Text(
                                  'No programme matches this search in the captured register.',
                                ),
                              TextButton(
                                onPressed: () async {
                                  try {
                                    await journey.track(
                                      selected!.id,
                                      'Institution research · programme not selected',
                                    );
                                    if (dialog.mounted) Navigator.pop(dialog);
                                    if (mounted) setState(() => section = 0);
                                  } catch (e) {
                                    message('$e');
                                  }
                                },
                                child: const Text(
                                  'Track institution research instead',
                                ),
                              ),
                            ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> applications() {
    final sorted = [...journey.applications]
      ..sort(
        (a, b) => (a.targetDate ?? '9999').compareTo(b.targetDate ?? '9999'),
      );
    return [
      panel([
        const Text(
          'Automatic device reminders',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        Text(reminderStatus),
        const Text(
          'Opt in on this device. The server stores only random identifiers, reminder dates and a push subscription. Grades, programme names, notes and budgets stay here. Turn reminders off here to remove that server record.',
          style: TextStyle(fontSize: 12),
        ),
        AtlasActionRow(
 children: [
FilledButton.tonalIcon(
              onPressed: reminderBusy || journey.reminderPayload() == '[]'
                  ? null
                  : () async {
                      setState(() => reminderBusy = true);
                      try {
                        final result = await enableAutomaticReminders(
                          journey.reminderPayload(),
                        );
                        if (mounted) setState(() => reminderStatus = result);
                      } finally {
                        if (mounted) setState(() => reminderBusy = false);
                      }
                    },
              icon: const Icon(Icons.notifications_active_outlined),
              label: Text(
                reminderBusy ? 'Setting up…' : 'Enable device reminders',
              ),
            ),
            TextButton(
              onPressed: reminderBusy
                  ? null
                  : () async {
                      final result = await disableAutomaticReminders();
                      if (mounted) setState(() => reminderStatus = result);
                    },
              child: const Text('Turn off device reminders'),
            ),
          ],
        ),
      ]),
      title('Application timeline'),
      const Text(
        'Choose your own target dates and check off the steps you have completed. Official deadlines are listed separately below.',
      ),
      const SizedBox(height: 14),
      if (sorted.isEmpty)
        panel([
          const Text('Your journey starts with a programme.'),
          TextButton(
            onPressed: addProgramme,
            child: const Text('Choose my first programme'),
          ),
        ]),
      for (final a in sorted)
        panel([
          Text(
            schoolName(a.institutionId),
            style: const TextStyle(color: gold, fontSize: 12),
          ),
          Text(
            a.programme,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          Text(
            '${a.stage} · ${a.completed.length}/${applicationTasks.length} checklist steps',
          ),
          if (a.targetDate != null)
            Text(
              'Personal target: ${a.targetDate} · ${deadlineState(a.targetDate)}',
            ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value:
                a.completed.intersection(applicationTasks.toSet()).length /
                applicationTasks.length,
            minHeight: 5,
          ),
          const SizedBox(height: 12),
          if (a.note.isNotEmpty) Text(a.note),
          AtlasActionRow(
 children: [
OutlinedButton(
                onPressed: () => editApplication(a),
                child: const Text('Manage application'),
              ),
              TextButton(
                onPressed: () => action(() => journey.compare(a.id)),
                child: Text(
                  journey.comparison.contains(a.id)
                      ? 'Remove from comparison'
                      : 'Compare programme',
                ),
              ),
              if (school(a.institutionId) != null)
                TextButton(
                  onPressed: () => widget.onProfile(school(a.institutionId)!),
                  child: const Text('View institution'),
                ),
            ],
          ),
        ]),
      title('Official application dates'),
      for (final d in journey.resources['deadlines'] as List)
        if (journey.applications.isEmpty ||
            journey.applications.any(
              (a) => a.institutionId == d['institutionId'],
            ))
          resourceCard(Map<String, dynamic>.from(d), deadline: true),
      title('Saved institutions'),
      if (widget.store.saved.isEmpty)
        const Text('Save institutions from the directory to keep them here.'),
      for (final i in widget.store.institutions.where(
        (i) => widget.store.saved.contains(i.id),
      ))
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(i.name),
          subtitle: Text(i.regions.join(' · ')),
          trailing: IconButton(
            tooltip: 'Remove saved institution',
            icon: const Icon(Icons.bookmark_remove_outlined),
            onPressed: () => action(() => widget.store.toggleSaved(i.id)),
          ),
          onTap: () => widget.onProfile(i),
        ),
    ];
  }

  Future<void> editApplication(ApplicationPlan original) async {
    final draft = ApplicationPlan.fromJson(original.toJson());
    final form = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Manage application'),
          content: SizedBox(
            width: 650,
            child: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      original.programme,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    AtlasDropdown<String>(
                      initialValue: draft.stage,
                      decoration: const InputDecoration(
                        labelText: 'Application progress',
                      ),
                      items: [
                        for (final s in applicationStages)
                          DropdownMenuItem(value: s, child: Text(s)),
                      ],
                      onChanged: (v) => draft.stage = v!,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: ctx,
                              initialDate:
                                  DateTime.tryParse(draft.targetDate ?? '') ??
                                  DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2040),
                            );
                            if (date != null) {
                              update(
                                () => draft.targetDate = date
                                    .toIso8601String()
                                    .substring(0, 10),
                              );
                            }
                          },
                          icon: const Icon(Icons.event_outlined),
                          label: Text(
                            draft.targetDate == null
                                ? 'Choose personal target date'
                                : 'Target: ${draft.targetDate}',
                          ),
                        ),
                        if (draft.targetDate != null)
                          TextButton(
                            onPressed: () => update(() {
                              draft.targetDate = null;
                              draft.reminder = false;
                            }),
                            child: const Text('Clear date'),
                          ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Reminder for this target'),
                      subtitle: const Text(
                        'Save this target, then enable automatic device reminders in My journey. The downloadable calendar file is an alternative for unsupported devices.',
                      ),
                      value: draft.reminder,
                      onChanged: draft.targetDate == null
                          ? null
                          : (v) => update(() => draft.reminder = v),
                    ),
                    if (draft.reminder && draft.targetDate != null)
                      TextButton.icon(
                        onPressed: () => action(() async {
                          if (deadlineState(draft.targetDate) ==
                              'Closed / date passed') {
                            throw StateError(
                              'Choose a future target date for a reminder.',
                            );
                          }
                          final ok = await saveTextFile(
                            'atlas-application-${draft.id}.ics',
                            calendarReminder(
                              draft,
                              schoolName(draft.institutionId),
                            ),
                            'text/calendar',
                          );
                          if (!ok) {
                            throw StateError('Calendar export is unavailable.');
                          }
                          message(
                            'Calendar file prepared. Import it into your calendar to enable the reminder.',
                          );
                        }),
                        icon: const Icon(Icons.calendar_month),
                        label: const Text('Download calendar reminder'),
                      ),
                    const Divider(),
                    const Text(
                      'Personal preparation checklist · confirm exact documents with the institution',
                    ),
                    for (final task in applicationTasks)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(task),
                        value: draft.completed.contains(task),
                        onChanged: (v) => update(() {
                          v == true
                              ? draft.completed.add(task)
                              : draft.completed.remove(task);
                        }),
                      ),
                    TextFormField(
                      initialValue: draft.note,
                      maxLength: 2000,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Personal notes',
                      ),
                      onChanged: (v) => draft.note = v,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Your estimated budget (GHS)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'These are your estimates, separate from the official fee snapshots. Leave unknown amounts blank.',
                    ),
                    const SizedBox(height: 10),
                    AtlasDropdown<String>(
                      initialValue: draft.period,
                      decoration: const InputDecoration(
                        labelText: 'Budget period',
                      ),
                      items: [
                        for (final s in [
                          'One academic year',
                          'One term',
                          'One semester',
                        ])
                          DropdownMenuItem(value: s, child: Text(s)),
                      ],
                      onChanged: (v) => draft.period = v!,
                    ),
                    for (final category in budgetCategories)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: TextFormField(
                          initialValue:
                              draft.budget[category]?.toString() ?? '',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: '$category (GHS)',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return null;
                            }
                            final n = double.tryParse(value.trim());
                            return n == null ||
                                    !n.isFinite ||
                                    n < 0 ||
                                    n > 1000000000
                                ? 'Enter a non-negative amount below 1 billion.'
                                : null;
                          },
                          onSaved: (value) {
                            final n = double.tryParse(value?.trim() ?? '');
                            n == null
                                ? draft.budget.remove(category)
                                : draft.budget[category] = n;
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: ctx,
                  builder: (c) => AlertDialog(
                    title: const Text('Remove this application?'),
                    content: const Text(
                      'Its checklist, notes and budget will also be removed from this device.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Keep'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await action(() async {
                    final before = [...journey.applications];
                    final compared = [...journey.comparison];
                    journey.applications.removeWhere(
                      (a) => a.id == original.id,
                    );
                    journey.comparison.remove(original.id);
                    try {
                      await journey.persist();
                    } catch (_) {
                      journey.applications = before;
                      journey.comparison = compared;
                      rethrow;
                    }
                  });
                  if (dialog.mounted) Navigator.pop(dialog);
                }
              },
              child: const Text('Remove application'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!form.currentState!.validate()) return;
                form.currentState!.save();
                final index = journey.applications.indexWhere(
                  (a) => a.id == original.id,
                );
                journey.applications[index] = draft;
                try {
                  await journey.persist();
                  if (dialog.mounted) Navigator.pop(dialog);
                  if (mounted) setState(() {});
                } catch (e) {
                  journey.applications[index] = original;
                  message('$e');
                }
              },
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }

  AdmissionRule? ruleFor(ApplicationPlan a) => widget.store.rules
      .where(
        (r) =>
            widget.store.ruleInstitutionId(r) == a.institutionId &&
            r.matchesProgramme(a.programme),
      )
      .firstOrNull;
  List<Widget> comparison() {
    final selected = [
      for (final id in journey.comparison)
        ...journey.applications.where((a) => a.id == id),
    ];
    String requirements(ApplicationPlan a) {
      final r = ruleFor(a);
      if (r == null) {
        return 'Exact programme entry rule not verified. Check the institution source.';
      }
      final cores = List<String>.from(r.data['coreCredits']);
      final alternative = List<String>.from(r.data['scienceOrSocial'] ?? []);
      final displayed = cores
          .map(
            (s) => alternative.isNotEmpty && s == alternative.first
                ? alternative.join(' OR ')
                : s,
          )
          .join(', ');
      final floors = Map<String, dynamic>.from(r.data['gradeFloors'] ?? {});
      return '$displayed; ${r.requiredElectives.isEmpty ? 'three allowed electives' : r.requiredElectives.join(', ')}. C6 or better. ${floors.entries.map((e) => '${e.key}: ${gradeNames[(e.value as int) - 1]} or better.').join(' ')}\n${r.data['cutoffText']}\nChecked ${r.checkedAt} · ${r.data['cycle']}';
    }

    return [
      title('Compare programmes'),
      const Text(
        'Select up to four tracked programmes. Unknown requirements, fees and duration stay visible as unknown. Swipe the table sideways on a phone.',
      ),
      const SizedBox(height: 12),
      AtlasPanelGrid(children: [
        for (final a in journey.applications)
          GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.trailing,
              title: Text(a.programme, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(schoolName(a.institutionId), style: const TextStyle(height: 1.5)),
              value: journey.comparison.contains(a.id),
              onChanged: (_) => action(() => journey.compare(a.id)),
            ),
          ),
      ]),
      if (journey.applications.isEmpty)
        TextButton(
          onPressed: addProgramme,
          child: const Text('Add a programme to compare'),
        ),
      const SizedBox(height: 20),
      if (selected.isNotEmpty)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultColumnWidth: const FixedColumnWidth(255),
            columnWidths: const {0: FixedColumnWidth(145)},
            border: TableBorder.all(color: const Color(0xFFD8DFD9)),
            children: [
              comparisonRow(
                'Programme',
                selected
                    .map(
                      (a) => '${schoolName(a.institutionId)}\n${a.programme}',
                    )
                    .toList(),
                bold: true,
              ),
              comparisonRow(
                'Campus / region',
                selected
                    .map(
                      (a) =>
                          school(a.institutionId)?.locations.join(' / ') ??
                          'Not verified',
                    )
                    .toList(),
              ),
              comparisonRow(
                'Qualification / duration',
                selected
                    .map(
                      (a) =>
                          'Programme name as listed above. Duration not verified for this exact route.',
                    )
                    .toList(),
              ),
              comparisonRow(
                'Academic requirements',
                selected.map(requirements).toList(),
              ),
              comparisonRow(
                'Your grade check',
                selected.map((a) {
                  if (widget.store.sessionNewCurriculum) {
                    return 'New curriculum: requirements pending verification';
                  }
                  final r = ruleFor(a);
                  return r == null
                      ? 'No structured rule for this programme'
                      : assessPathway(
                          r,
                          widget.store.sessionGrades,
                          resultBasis: widget.store.sessionResultBasis,
                          sittings: widget.store.sessionSittings,
                        ).status;
                }).toList(),
              ),
              comparisonRow(
                'Official fee snapshots',
                selected.map((a) {
                  final fees = (journey.resources['fees'] as List).where(
                    (f) => f['institutionId'] == a.institutionId,
                  );
                  return fees.isEmpty
                      ? 'Not verified'
                      : fees
                            .map(
                              (f) =>
                                  '${f['title']}: ${f['currency']} ${f['amount']} · ${f['period']}\n${f['cycle']}',
                            )
                            .join('\n\n');
                }).toList(),
              ),
              comparisonRow(
                'Your GHS budget',
                selected
                    .map(
                      (a) =>
                          '${a.budgetComplete ? 'Total estimate' : 'Incomplete subtotal'}: ${a.subtotal.toStringAsFixed(2)}\n${a.period} · personal estimates',
                    )
                    .toList(),
              ),
              comparisonRow(
                'Official deadline',
                selected.map((a) {
                  final d = (journey.resources['deadlines'] as List).where(
                    (r) => r['institutionId'] == a.institutionId,
                  );
                  return d.isEmpty
                      ? 'Not verified for this route'
                      : d
                            .map(
                              (r) =>
                                  '${r['title']}: ${r['date'] ?? 'No fixed date'}\n${deadlineState(r['date'])}',
                            )
                            .join('\n\n');
                }).toList(),
              ),
              comparisonRow(
                'Approval evidence',
                selected
                    .map(
                      (a) =>
                          '${school(a.institutionId)?.status ?? 'Not available'}\nInstitution listing does not establish approval of this exact programme.',
                    )
                    .toList(),
              ),
              TableRow(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Official sources'),
                  ),
                  for (final a in selected)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Wrap(
                        children: [
                          if (ruleFor(a) != null)
                            TextButton(
                              onPressed: () => link(ruleFor(a)!.source),
                              child: const Text('Entry requirements'),
                            ),
                          if (school(a.institutionId) != null)
                            TextButton(
                              onPressed: () =>
                                  widget.onProfile(school(a.institutionId)!),
                              child: const Text('Institution & sources'),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
    ];
  }

  TableRow comparisonRow(
    String label,
    List<String> values, {
    bool bold = false,
  }) => TableRow(
    decoration: BoxDecoration(
      color: bold
          ? ink.withValues(alpha: .07)
          : Colors.white.withValues(alpha: .7),
    ),
    children: [
      for (final text in [label, ...values])
        Padding(
          padding: const EdgeInsets.all(14),
          child: Text(
            text,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
    ],
  );

  Widget resourceCard(
    Map<String, dynamic> row, {
    bool deadline = false,
    bool fee = false,
  }) => panel([
    Text(
      schoolName(row['institutionId']),
      style: const TextStyle(color: gold, fontSize: 12),
    ),
    Text(
      row['title'],
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
    ),
    if (row['status'] == 'needs_source_review')
      const Text(
        'Source changed or could not be reached. Recheck the official source before using this snapshot.',
        style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
      ),
    if (fee)
      Text(
        '${row['currency']} ${row['amount']} · ${row['period']}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    if (deadline)
      Text(
        '${row['date'] ?? 'No fixed calendar date verified'} · ${resourceDeadlineState(row)}',
      ),
    Text(row['note'] ?? ''),
    Text(
      '${row['cycle']} · checked ${row['checkedAt']}',
      style: const TextStyle(fontSize: 12),
    ),
    TextButton.icon(
      onPressed: () => link(row['sourceUrl']),
      icon: const Icon(Icons.open_in_new, size: 16),
      label: const Text('Official source'),
    ),
  ]);
  List<Widget> resources() {
    final ids = {
      for (final section in ['fees', 'scholarships'])
        for (final r in journey.resources[section] as List)
          r['institutionId'] as String,
    };
    bool matches(dynamic r) =>
        resourceInstitution == 'all' ||
        r['institutionId'] == resourceInstitution;
    final fees = (journey.resources['fees'] as List).where(matches).toList();
    final scholarships = (journey.resources['scholarships'] as List)
        .where(matches)
        .where((r) => showClosed || !resourceIsClosed(r))
        .toList();
    return [
      title('Costs & scholarships'),
      const Text(
        'Official snapshots are a starting point. Amounts with different currencies or payment periods are never added together. Confirm the current intake and invoice before paying.',
      ),
      const SizedBox(height: 16),
      AtlasDropdown<String>(
        initialValue: resourceInstitution,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Filter official resources',
        ),
        items: [
          const DropdownMenuItem(
            value: 'all',
            child: Text('All sourced institutions'),
          ),
          for (final id in ids)
            DropdownMenuItem(
              value: id,
              child: Text(schoolName(id), overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (v) => setState(() => resourceInstitution = v!),
      ),
      const SizedBox(height: 16),
      title('Published fees'),
      const Text(
        'This is limited coverage, not a nationwide fee catalogue. For other institutions use their official profile links. Add your own budget through Manage application.',
      ),
      const SizedBox(height: 12),
      for (final fee in fees)
        resourceCard(Map<String, dynamic>.from(fee), fee: true),
      if (fees.isEmpty)
        const Text('No verified numerical fee snapshot for this institution.'),
      title('Funding opportunities'),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Include closed funding calls'),
        value: showClosed,
        onChanged: (v) => setState(() => showClosed = v),
      ),
      for (final s in scholarships)
        resourceCard(Map<String, dynamic>.from(s), deadline: true),
      if (scholarships.isEmpty)
        const Text(
          'No funding call matches this filter. Unknown dates do not mean applications are open.',
        ),
      title('Your budgets'),
      for (final a in journey.applications)
        panel([
          Text(
            '${schoolName(a.institutionId)} · ${a.programme}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            '${a.period} · GHS ${a.subtotal.toStringAsFixed(2)} ${a.budgetComplete ? 'total personal estimate' : 'incomplete subtotal'}',
          ),
          Text(
            '${budgetCategories.where((k) => !a.budget.containsKey(k)).length} cost categories unknown. These amounts are entered by you.',
          ),
          TextButton(
            onPressed: () => editApplication(a),
            child: const Text('Edit budget'),
          ),
        ]),
    ];
  }

  List<Widget> galleries() {
    final ids = {
      ...widget.store.saved,
      ...journey.applications.map((a) => a.institutionId),
    };
    final list = widget.store.institutions
        .where((i) => ids.contains(i.id))
        .toList();
    if (list.isEmpty) {
      list.addAll(
        widget.store.institutions
            .where((i) => galleryPhotos(widget.store, i.id).isNotEmpty)
            .take(12),
      );
    }
    return [
      title('Explore campus life'),
      const Text(
        'Your saved and tracked schools appear here. Each photograph has its own source and caption. Available photographs are included in the offline app pack; external tours need internet.',
      ),
      const SizedBox(height: 16),
      for (final i in list)
        panel([
          Text(
            i.name,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          Text(
            '${galleryPhotos(widget.store, i.id).length} verified photograph(s)',
          ),
          const SizedBox(height: 12),
          InstitutionGallery(store: widget.store, institution: i),
        ]),
    ];
  }

  String get monitoringSummary {
    final count = (widget.store.sourceMonitor['sources'] as List?)?.length;
    final coverage = count == null
        ? 'The full-sweep time depends on the registered sources.'
        : 'The $count-source registry takes up to ${(count / 12).ceil()} hourly runs for a full sweep.';
    return 'The hosted app checks up to 12 official sources each hour in rotating batches. $coverage Changed or unavailable evidence pauses affected admission checks and guidance pending review. New requirements need a reviewed publication. An unchanged snapshot produces no change alerts.';
  }

  List<Widget> updates() => [
    title('Updates for your schools'),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Follow changes to saved and tracked schools'),
      subtitle: const Text(
        'Opt in to an on-device change history. New validated feed data is checked when the app opens, resumes or refreshes. Background push notifications are not enabled.',
      ),
      value: journey.followChanges,
      onChanged: (v) => action(() async {
        await widget.store.observeJourney();
        final before = journey.followChanges;
        journey.followChanges = v;
        try {
          await journey.persist();
        } catch (_) {
          journey.followChanges = before;
          rethrow;
        }
      }),
    ),
    Text(widget.store.syncMessage, style: const TextStyle(fontSize: 12)),
    Text(monitoringSummary),
    const SizedBox(height: 12),
    if (journey.updates.isEmpty)
      panel([
        const Text('No changes recorded yet.'),
        const Text(
          'Save or track a school and enable following. Future changes from the published feed will appear here with before-and-after evidence.',
        ),
      ]),
    for (final u in journey.updates)
      panel([
        Text(
          '${u['read'] == true ? '' : 'NEW · '}${schoolName(u['institutionId'])}',
          style: const TextStyle(color: gold),
        ),
        Text(u['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(
          'Observed ${u['observedAt']} · observation time, not the source publication date',
          style: const TextStyle(fontSize: 12),
        ),
        for (final change in u['changes']) ...[
          Text(
            '${change['field']}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text('Previously: ${change['before'] ?? 'Not recorded'}'),
          Text('Now: ${change['after'] ?? 'Not recorded'}'),
        ],
        AtlasActionRow(
          children: [
            TextButton(
              onPressed: () => link(u['sourceUrl']),
              child: const Text('Verify source'),
            ),
            if (u['read'] != true)
              TextButton(
                onPressed: () => action(() async {
                  u['read'] = true;
                  await journey.persist();
                }),
                child: const Text('Mark read'),
              ),
          ],
        ),
      ]),
  ];
}
