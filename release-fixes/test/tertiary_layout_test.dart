import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skoolatlas/tertiary_data.dart';
import 'package:skoolatlas/tertiary_app.dart';

void main() {
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
      expect(tester.getTopLeft(explore).dy, tester.getTopLeft(pathway).dy);
      expect(tester.getSize(explore), tester.getSize(pathway));
      expect(tester.getSize(explore).height, greaterThanOrEqualTo(48));
      final heroName = find.byKey(const ValueKey('hero-institution-name'));
      expect(tester.getSize(heroName).width, greaterThan(150));
      expect(tester.getSize(heroName).height, lessThan(55));
      expect(tester.takeException(), isNull);
      final ahafo = find.byKey(const ValueKey('home-region-Ahafo'));
      final ashanti = find.byKey(const ValueKey('home-region-Ashanti'));
      expect(tester.getSize(ahafo), tester.getSize(ashanti));
      expect(tester.getTopLeft(ahafo).dy, tester.getTopLeft(ashanti).dy);
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
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
