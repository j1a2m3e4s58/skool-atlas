// Retired JHS/SHS app coverage; excluded from the tertiary release suite.
@Tags(['legacy_shs'])
library;

import 'atlas_test_fonts.dart';
import 'page_layout_audit_test.dart' show LayoutAssets;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skoolatlas/main.dart';
import 'package:skoolatlas/school.dart';
import 'package:skoolatlas/planning.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadAtlas();
    await loadPlanningData();
    await loadAtlasTestFonts();
  });

  test(
    'appearance preference survives reload and supports device setting',
    () async {
      final settings = AtlasAppearance();
      await settings.setMode(ThemeMode.dark);
      final reloaded = AtlasAppearance();
      await reloaded.load();
      expect(reloaded.mode, ThemeMode.dark);
      await reloaded.setMode(ThemeMode.system);
      await settings.load();
      expect(settings.mode, ThemeMode.system);
    },
  );

  testWidgets(
    'appearance selector updates pushed routes without resetting navigation',
    (tester) async {
      await atlasAppearance.setMode(ThemeMode.light);
      await tester.pumpWidget(
        AnimatedBuilder(
          animation: atlasAppearance,
          builder: (_, _) => MaterialApp(
            theme: atlasTheme(Brightness.light),
            darkTheme: atlasTheme(Brightness.dark),
            themeMode: atlasAppearance.mode,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => Scaffold(
                        appBar: atlasPageBar(context, 'Preview'),
                        body: const Surface(child: Text('Route retained')),
                      ),
                    ),
                  ),
                  child: const Text('Open preview'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open preview'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Appearance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.text('Route retained'))).brightness,
        Brightness.dark,
      );
      await tester.tapAt(const Offset(10, 80));
      await tester.pumpAndSettle();
      final surface = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(Surface),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (surface.decoration as BoxDecoration).gradient!.colors.first,
        atlasTheme(Brightness.dark).colorScheme.surface,
      );
      expect(find.text('Route retained'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await atlasAppearance.setMode(ThemeMode.system);
    },
  );

  testWidgets('appearance panel clears Android navigation area', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: atlasTheme(Brightness.light),
        home: const Scaffold(body: AppearanceButton()),
      ),
    );
    await tester.tap(find.byTooltip('Appearance'));
    await tester.pumpAndSettle();
    final panel = tester.getRect(
      find.byKey(const ValueKey('appearance-floating-panel')),
    );
    expect(panel.bottom, lessThanOrEqualTo(844 - 34 - 20));
    expect(panel.left, greaterThanOrEqualTo(16));
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Dark'))).brightness,
      Brightness.dark,
    );
    await tester.tap(find.byTooltip('Close appearance'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('appearance-floating-panel')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await atlasAppearance.setMode(ThemeMode.system);
  });

  final pages = <Widget>[
    HomePage(onExploreTap: () {}),
    const ExplorePage(),
    ComparePage(onAddMore: () {}),
    const GuidesPage(),
    const ResourcesPage(),
    const PlacementCheckerPage(),
    const ResultsPlannerPage(),
    const AccountPage(),
    const CareerGuidancePage(),
  ];
  for (final page in pages) {
    testWidgets('dark phone ${page.runtimeType} fits larger text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: atlasTheme(Brightness.dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.25)),
            child: DefaultAssetBundle(bundle: LayoutAssets(), child: child!),
          ),
          home: Scaffold(
            appBar: AppBar(actions: const [AppearanceButton()]),
            body: page,
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: '${page.runtimeType} should fit',
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
}
