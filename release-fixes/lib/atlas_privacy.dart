import 'package:flutter/material.dart';

const atlasSupportEmail = 'jamest4n4@gmail.com';
const atlasPrivacyText = '''Tertiary Atlas privacy notice
Updated 16 November 2026

Tertiary Atlas helps you explore institutions and plan applications. Contact: jamest4n4@gmail.com.

Grades and suggestions
Grades are assessed on your device and kept in the current session. They are not sent to our admissions update service. Clear results removes entered grades. A report you choose to export may contain grades; you control where you save or share it.

Saved information
Saved institutions, preferences, comparisons, application plans and reminders are stored on your device. Remove individual saved items in the app, or clear the app storage in Android Settings to remove all locally saved information. Android backup or device-transfer features may retain copies according to your device settings.

Internet and external services
The app downloads published admissions updates over HTTPS. Our Cloudflare hosting provider receives normal network request information, including IP address and request metadata, when you connect. Grades are not included in those update requests. Opening an institution website, map, email or other external link uses that service and its privacy practices. No advertising or analytics SDK is included in this release.

Support and sharing
If you email support, we receive your email address and the information you send. Do not send passwords, examination login details or identity documents. Support correspondence is used to handle your request; ask the support address for deletion when it is no longer needed, subject to necessary legal or security retention. Exported files and copies shared with others must be deleted separately.

Your choices
You can use bundled information offline. Online updates and external links require a connection. This release does not require an account. For privacy questions or requests, email jamest4n4@gmail.com. Changes to this notice will carry a revised date.
''';

class AtlasPrivacyButton extends StatelessWidget {
  const AtlasPrivacyButton({super.key});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    icon: const Icon(Icons.privacy_tip_outlined),
    label: const Text('Privacy & support'),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy & support'),
        content: const SizedBox(
          width: 620,
          child: SingleChildScrollView(child: SelectableText(atlasPrivacyText)),
        ),
        actions: [TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        )],
      ),
    ),
  );
}
