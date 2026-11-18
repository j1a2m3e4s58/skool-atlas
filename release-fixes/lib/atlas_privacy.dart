import 'package:flutter/material.dart';

const atlasSupportEmail = 'jamest4n4@gmail.com';
const atlasPrivacyText = '''Tertiary Atlas privacy notice
Updated 18 November 2026

Tertiary Atlas helps you explore institutions and plan applications. Contact: jamest4n4@gmail.com.

Grades and suggestions
Grades are assessed on your device and kept in the current session. They are not sent to our admissions update service. Clear results removes entered grades. A report you choose to export may contain grades; you control where you save or share it.

Saved information
Saved institutions, preferences, comparisons, application plans and reminders are stored on your device. Remove individual saved items in the app, or clear the app storage in Android Settings to remove all locally saved information. Android backup or device-transfer features may retain copies according to your device settings.

Optional Atlas Plus cloud workspace
With your explicit consent, a cloud workspace stores application plans, private notes, budgets and comparisons on Cloudflare. Grades are not uploaded. This is access-controlled storage, not end-to-end encryption. Your private access code opens the workspace on another device; it is held only in the current app session. Keep a separate secure copy: a lost code cannot be recovered. Saving and restoring are manual and replace the selected copy; they do not merge. Delete cloud workspace removes the active cloud backup and sharing link. Cloudflare may retain operational backups under its retention policies. Local copies remain on your devices.

Family sharing
Only applications you select are shared after separate consent. A read-only family snapshot contains programme, institution, stage and target date; it excludes grades, private notes and budgets. Anyone holding the family link can read it for seven days unless you revoke it earlier. A new link replaces the old one. Downloaded or printed copies cannot be revoked.

Internet and external services
The app downloads published admissions updates over HTTPS. Our Cloudflare hosting provider receives normal network request information, including IP address and request metadata, when you connect. Grades are not included in those update requests. Opening an institution website, map, email or other external link uses that service and its privacy practices. No advertising or analytics SDK is included in this release.

Support and sharing
If you email support, we receive your email address and the information you send. Do not send passwords, examination login details or identity documents. Support correspondence is used to handle your request; ask the support address for deletion when it is no longer needed, subject to necessary legal or security retention. Exported files and copies shared with others must be deleted separately.

Your choices
You can use bundled information offline. Online updates and external links require a connection. This release does not require an account. For privacy questions or requests, email jamest4n4@gmail.com. Changes to this notice will carry a revised date.
''';

class AtlasPrivacyButton extends StatelessWidget {
  final String email;
  const AtlasPrivacyButton({super.key, this.email = atlasSupportEmail});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    icon: const Icon(Icons.privacy_tip_outlined),
    label: const Text('Privacy & support'),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy & support'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(child: SelectableText(atlasPrivacyText.replaceAll(atlasSupportEmail, email))),
        ),
        actions: [TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        )],
      ),
    ),
  );
}
