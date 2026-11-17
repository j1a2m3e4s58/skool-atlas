import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'atlas_controls.dart';
import 'tertiary_data.dart';

// Ministry of Education Year 3 resource catalogue, checked 16 November 2026.
// These are curriculum names, not admissions equivalence mappings.
const curriculumSource = 'https://curriculumresources.edu.gh/trs_year3/';
const newCurriculumSubjects = <String>[
  'Additional Mathematics',
  'Agricultural Science',
  'Agriculture',
  'Automotive and Metal Technology',
  'Building Construction and Wood Technology',
  'Electrical and Electronic Technology',
  'Arabic',
  'Art and Design Foundation',
  'Arts and Design Studio',
  'Aviation and Aerospace Engineering',
  'Biology',
  'Biomedical Science',
  'Accounting',
  'Business Management',
  'Chemistry',
  'Religious Studies (Christian)',
  'Religious Studies (Islamic)',
  'Computing',
  'Core Physical Education and Health (PEH)',
  'Design and Communication Technology',
  'Economics',
  'Elective Physical Education and Health (PEH)',
  'Engineering',
  'English Language',
  'French',
  'General Science',
  'Geography',
  'Ghanaian Language',
  'Government',
  'History',
  'Clothing and Textiles',
  'Food and Nutrition',
  'Management in Living',
  'Information Communication Technology (ICT)',
  'Intervention English',
  'Intervention Mathematics',
  'Literature-in-English',
  'Manufacturing Engineering',
  'Mathematics',
  'Music',
  'Performing Arts',
  'Physics',
  'Religious and Moral Education',
  'Robotics',
  'Social Studies',
  'Spanish',
];

String curriculumSubjectLabel(String subject) => switch (subject) {
  'Art and Design Foundation' => '$subject (ADF)',
  'Arts and Design Studio' => '$subject (ADS)',
  _ => subject,
};

const newCurriculumPending =
    'Admission requirements pending verification';

class NewCurriculumPlanner extends StatefulWidget {
  final TertiaryStore store;
  const NewCurriculumPlanner({super.key, required this.store});
  @override
  State<NewCurriculumPlanner> createState() => _NewCurriculumPlannerState();
}

class _NewCurriculumPlannerState extends State<NewCurriculumPlanner> {
  bool checked = false;
  String query = '';
  Map<String, int> get grades => widget.store.newCurriculumGrades;

  @override
  Widget build(BuildContext context) {
    final available = newCurriculumSubjects.where((subject) =>
        !grades.containsKey(subject) &&
        curriculumSubjectLabel(subject).toLowerCase().contains(query.toLowerCase().trim()));
    return SingleChildScrollView(
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Your new-curriculum subjects',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            const Text('Choose the exact subjects on your results or school transcript. '
                'Your old-curriculum entries are kept separately while you switch.'),
            const SizedBox(height: 12),
            const Text('The catalogue includes support and internally assessed subjects. '
                'Listing a subject here does not make it a WASSCE elective or a university entry requirement. '
                'Enter A1–F9 only where your results use that scale; otherwise leave the grade unentered.'),
            TextButton.icon(
              onPressed: () => launchUrl(Uri.parse(curriculumSource),
                  mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Official subject list · checked 16 Nov 2026'),
            ),
            const SizedBox(height: 16),
            for (final subject in grades.keys.toList())
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(curriculumSubjectLabel(subject),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: AtlasDropdown<int>(
                      key: ValueKey('new-grade-$subject'),
                      initialValue: grades[subject],
                      decoration: const InputDecoration(labelText: 'Grade or result status'),
                      items: [
                        const DropdownMenuItem(value: 0, child: Text('Not entered / awaiting result')),
                        for (var i = 0; i < gradeNames.length; i++)
                          DropdownMenuItem(value: i + 1, child: Text(gradeNames[i])),
                      ],
                      onChanged: (value) => setState(() {
                        grades[subject] = value!;
                        checked = false;
                      }),
                    )),
                    IconButton(
                      tooltip: 'Remove $subject',
                      onPressed: () => setState(() { grades.remove(subject); checked = false; }),
                      icon: const Icon(Icons.close),
                    ),
                  ]),
                ]),
              ),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Find a new-curriculum subject',
                hintText: 'For example ADF, ADS or Robotics',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => query = value),
            ),
            const SizedBox(height: 8),
            Text('${available.length} subjects available · ${grades.length} selected'),
            const SizedBox(height: 8),
            if (available.isEmpty) const Text('No matching subjects. Try another name.'),
            SizedBox(
              height: 240,
              child: ListView(children: [
                for (final subject in available)
                  ListTile(
                    title: Text(curriculumSubjectLabel(subject)),
                    trailing: const Icon(Icons.add_circle_outline),
                    onTap: () => setState(() { grades[subject] = 0; checked = false; }),
                  ),
              ]),
            ),
            const SizedBox(height: 20),
            Wrap(spacing: 12, runSpacing: 12, children: [
              FilledButton.icon(
                onPressed: grades.isEmpty ? null : () => setState(() => checked = true),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Check new-curriculum guidance'),
              ),
              TextButton(
                onPressed: () => setState(() { grades.clear(); checked = false; }),
                child: const Text('Clear new-curriculum results'),
              ),
            ]),
            if (checked) ...[
              const SizedBox(height: 20),
              const Card(child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(newCurriculumPending, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  SizedBox(height: 10),
                  Text('Your subjects have been recorded for this session. Atlas has not yet verified '
                      'programme-specific acceptance of this curriculum. No eligibility, aggregate or '
                      'grade-qualified alternatives are calculated from older rules. This is not a rejection.'),
                  SizedBox(height: 10),
                  Text('You can browse institutions and official programme links in Explore. '
                      'Ask admissions to confirm your exact subject combination and intake before applying.'),
                ]),
              )),
            ],
            const SizedBox(height: 24),
          ]),
        ),
      )),
    );
  }
}
