import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skoolatlas/tertiary_app.dart';
import 'package:skoolatlas/tertiary_data.dart';
import 'package:skoolatlas/pathway_widgets.dart';

void main() {
  for (final width in [320.0, 1280.0]) {
    testWidgets('held evidence stays explanatory and read-only at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = TertiaryStore()
        ..applyFeed(
          Map<String, dynamic>.from(
            jsonDecode(File('web/tertiary-feed.json').readAsStringSync()),
          ),
        );
      String? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: GlassPanel(
                  child: EvidenceReviewPanel(
                    store: store,
                    openSource: (url) => opened = url,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Admissions evidence under review'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('A new admission year is not guessed'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Admission cycle is not explicitly confirmed'),
        findsWidgets,
      );
      expect(
        find.textContaining('No numerical match is inferred'),
        findsNWidgets(3),
      );
      expect(find.text('Approve'), findsNothing);
      final first = find
          .textContaining('Academic requirements need a reviewed source check.')
          .first;
      await tester.ensureVisible(first);
      await tester.tap(first);
      await tester.pumpAndSettle();
      expect(opened, startsWith('https://'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
