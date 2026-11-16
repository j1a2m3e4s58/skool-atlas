import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skoolatlas/tertiary_app.dart';
import 'package:skoolatlas/tertiary_data.dart';
import 'atlas_test_fonts.dart';

void main() {
  for (final width in [390.0, 1280.0]) {
    testWidgets('glass surface avoids blur on phone at $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: GlassPanel(child: Text('Readable panel'))),
        ),
      );
      expect(
        find.byType(BackdropFilter),
        width < 700 ? findsNothing : findsOneWidget,
      );
      expect(find.text('Readable panel'), findsOneWidget);
    });
  }
  testWidgets(
    'typing does not rank; layout rebuilds reuse ranking; changed evidence invalidates it',
    (tester) async {
      await loadAtlasTestFonts();
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = TertiaryStore()
        ..applyFeed(
          Map<String, dynamic>.from(
            jsonDecode(File('web/tertiary-feed.json').readAsStringSync()),
          ),
        );
      store.sessionGrades.addAll({
        for (final c in coreSubjects) c: 2,
        'Elective Mathematics': 2,
        'Physics': 2,
        'Chemistry': 2,
      });
      Widget shell() => MaterialApp(
        home: Scaffold(
          body: GradePlanner(key: const ValueKey('planner'), store: store),
        ),
      );
      await tester.pumpWidget(shell());
      await tester.pumpAndSettle();
      dynamic state = tester.state(find.byType(LegacyGradePlanner));
      expect(state.recommendations, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('programme-search')),
        'Computer Science',
      );
      await tester.pumpAndSettle();
      expect(state.recommendations, isEmpty);
      await tester.ensureVisible(find.text('Check my pathways'));
      await tester.tap(find.text('Check my pathways'));
      await tester.pumpAndSettle();
      final ranked = state.recommendations as List;
      expect(ranked, isNotEmpty);
      tester.view.physicalSize = const Size(390, 1000);
      await tester.pumpAndSettle();
      expect(identical(state.recommendations, ranked), isTrue);
      const id = 'private-20261028-central-computer-science';
      expect(
        (ranked.singleWhere((r) => r.rule.id == id) as PathwayRecommendation)
            .assessment
            .academicPass,
        isTrue,
      );
      store.rules = [
        for (final rule in store.rules)
          rule.id == id
              ? AdmissionRule({...rule.data, 'status': 'needs_source_review'})
              : rule,
      ];
      await tester.pumpWidget(shell());
      await tester.pumpAndSettle();
      expect(identical(state.recommendations, ranked), isFalse);
      expect(
        (state.recommendations.singleWhere((r) => r.rule.id == id)
                as PathwayRecommendation)
            .assessment
            .academicPass,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
