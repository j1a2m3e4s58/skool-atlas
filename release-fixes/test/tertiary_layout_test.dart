import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skoolatlas/tertiary_data.dart';
import 'package:skoolatlas/tertiary_app.dart';
import 'package:skoolatlas/atlas_controls.dart';

void main() {
  testWidgets('Mobile actions stack without squeezing larger phone text', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2)),
      child: Scaffold(body: Padding(padding: const EdgeInsets.all(24), child: AtlasActionRow(children: [
        FilledButton.icon(key: const ValueKey('pair-first'), onPressed: () {}, icon: const Icon(Icons.search), label: const Text('Explore institutions')),
        OutlinedButton.icon(key: const ValueKey('pair-second'), onPressed: () {}, icon: const Icon(Icons.tune), label: const Text('Find my pathway')),
      ]))),
    )));
    await tester.pumpAndSettle();
    final first = find.byKey(const ValueKey('pair-first'));
    final second = find.byKey(const ValueKey('pair-second'));
    expect(tester.getTopLeft(second).dy, greaterThan(tester.getBottomLeft(first).dy));
    expect(tester.getSize(first).width, tester.getSize(second).width);
    expect(tester.takeException(), isNull);
  });

  final data =
      jsonDecode(File('assets/tertiary/admissions.json').readAsStringSync())
          as Map;
  final rules = (data['rules'] as List)
      .map((r) => AdmissionRule(Map<String, dynamic>.from(r as Map)))
      .toList();
  for (final width in [
    320.0,
    1280.0,
    double.parse(Platform.environment['ATLAS_TERTIARY_LAYOUT_WIDTH'] ?? '390'),
  ]) {
    testWidgets('Tertiary discovery and grade form fit width $width', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = TertiaryStore()
        ..rules = rules
        ..institutions = [
          const TertiaryInstitution(
            id: 'gtec:fixture',
            name: 'University of Ghana',
            category: 'Traditional University',
            location: 'Legon',
            regions: ['Ahafo', 'Ashanti', 'Bono', 'Bono East', 'Central', 'Eastern', 'Greater Accra', 'North East', 'Northern', 'Oti', 'Savannah', 'Upper East', 'Upper West', 'Volta', 'Western', 'Western North'],
            source: 'https://gtec.edu.gh/explore-institutions/',
            checkedAt: '2026-10-25',
            status: 'Active',
            courses: ['BSc · Computer Science'],
            listedActive: true,
          ),
          const TertiaryInstitution(
            id: 'gtec:long-fixture',
            name: 'Kwame Nkrumah University of Science and Technology',
            category: 'Traditional University',
            location: 'Kumasi',
            source: 'https://gtec.edu.gh/explore-institutions/',
            checkedAt: '2026-10-25',
            status: 'Active',
            courses: ['BSc · Civil Engineering'],
            listedActive: true,
          ),
        ];
      await tester.pumpWidget(TertiaryAtlasApp(store: store));
      await tester.pumpAndSettle();
      expect(find.text('TERTIARY ATLAS'), findsOneWidget);
      final explore = find.byKey(const ValueKey('home-explore-action'));
      final pathway = find.byKey(const ValueKey('home-pathway-action'));
      expect(tester.getTopLeft(pathway).dy, greaterThan(tester.getBottomLeft(explore).dy));
      expect(tester.getSize(explore).width, tester.getSize(pathway).width);
      expect(tester.getSize(explore).height, greaterThanOrEqualTo(48));
      final heroName = find.byKey(const ValueKey('hero-institution-name'));
      expect(tester.getSize(heroName).width, greaterThan(150));
      expect(tester.getSize(heroName).height, lessThan(55));
      expect(tester.takeException(), isNull);
      final ahafo = find.byKey(const ValueKey('home-region-Ahafo'));
      final ashanti = find.byKey(const ValueKey('home-region-Ashanti'));
      expect(tester.getSize(ahafo), tester.getSize(ashanti));
      if (width < 600) {
        expect(tester.getTopLeft(ashanti).dy, greaterThan(tester.getBottomLeft(ahafo).dy));
        expect(tester.getSize(ahafo).width, greaterThan(width * .65));
      } else {
        expect(tester.getTopLeft(ahafo).dy, tester.getTopLeft(ashanti).dy);
      }
      final westernNorth = find.byKey(const ValueKey('home-region-Western North'));
      expect(westernNorth, findsOneWidget);
      await tester.ensureVisible(westernNorth);
      await tester.tap(westernNorth);
      await tester.pumpAndSettle();
      expect(find.text('Find your place.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(width >= 850 ? 'Grade planner' : 'My grades'));
      await tester.pumpAndSettle();
      expect(find.text('A clearer path forward.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Sources').last);
      await tester.pumpAndSettle();
      final sourceAhafo = find.byKey(const ValueKey('source-region-Ahafo'));
      final sourceAshanti = find.byKey(const ValueKey('source-region-Ashanti'));
      expect(sourceAhafo, findsOneWidget);
      expect(tester.getSize(sourceAhafo).width, tester.getSize(sourceAshanti).width);
      if (width < 600) {
        expect(tester.getSize(sourceAhafo).width, closeTo(width - 48, 1));
        expect(tester.getTopLeft(sourceAshanti).dy, greaterThan(tester.getBottomLeft(sourceAhafo).dy));
      }
      expect(find.byKey(const ValueKey('source-region-Western North')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('My journey').last);
      await tester.pumpAndSettle();
      for (final section in ['Compare', 'Costs & scholarships', 'Galleries', 'Updates']) {
        final chip = find.text(section).first;
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$section at $width');
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
