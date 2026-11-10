// Retired JHS/SHS app coverage; excluded from the tertiary release suite.
@Tags(['legacy_shs'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skoolatlas/main.dart';
import 'package:skoolatlas/school.dart';
import 'package:skoolatlas/planning.dart';
import 'package:skoolatlas/website_content.dart';
import 'atlas_test_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadAtlas();
    await loadPlanningData();
    await websiteContent.load();
    await loadAtlasTestFonts();
  });
  testWidgets(
    'Saltpond Methodist profile renders its historic photo and source tabs',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final school = schools.singleWhere((s) => s.id == 'methodist-saltpond');
      await tester.pumpWidget(
        MaterialApp(
          theme: atlasTheme(Brightness.light),
          home: SchoolDetailsPage(school: school),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      expect(find.text('About these photographs'), findsOneWidget);
      expect(find.text('School sources & media'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
