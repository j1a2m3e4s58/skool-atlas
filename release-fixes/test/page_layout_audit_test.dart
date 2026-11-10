// Retired JHS/SHS app coverage; excluded from the tertiary release suite.
@Tags(['legacy_shs'])
library;

import 'atlas_test_fonts.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skoolatlas/main.dart';
import 'package:skoolatlas/school.dart';
import 'package:skoolatlas/planning.dart';

// Layout isolation: photos use one local placeholder so media decoding and
// third-party network availability cannot determine a page's layout result.
class LayoutAssets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) =>
      RegExp(r'\.(png|jpe?g|webp)$', caseSensitive: false).hasMatch(key)
      ? rootBundle.load('assets/branding/launcher-mark.png')
      : rootBundle.load(key);
}

void main() {
  final pageIds = (Platform.environment['ATLAS_LAYOUT_PAGE'] ?? 'home').split(
    ',',
  );
  final width = double.parse(
    Platform.environment['ATLAS_LAYOUT_WIDTH'] ?? '360',
  );
  final scale = double.parse(
    Platform.environment['ATLAS_LAYOUT_SCALE'] ?? '1.15',
  );
  final dark = Platform.environment['ATLAS_LAYOUT_DARK'] == 'true';
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadAtlas();
    await loadPlanningData();
    for (final id in [
      'methodist-saltpond',
      'kwanyarko-senior-high',
      'bawjiase-community-senior-high',
    ]) {
      atlasStore.compared.add(id);
      atlasStore.saved.add(id);
    }
    await loadAtlasTestFonts();
  });
  for (final pageId in pageIds) {
    testWidgets('layout $pageId at $width and $scale', (tester) async {
      final originalErrorHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        FlutterError.dumpErrorToConsole(details, forceReport: true);
        originalErrorHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalErrorHandler);
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final page = switch (pageId) {
        'shell' => const MainShell(),
        'choices' => MyChoicesHub(onExplore: () {}, onResults: () {}),
        'tools' => const ToolsWorkspacePage(),
        'home' => HomePage(onExploreTap: () {}),
        'explore' => const ExplorePage(),
        'saved' => const ExplorePage(savedOnly: true),
        'compare' => ComparePage(onAddMore: () {}),
        'guides' => const GuidesPage(),
        'checklist' => const GuidesPage(checklistOnly: true),
        'resources' => const ResourcesPage(),
        'pilot' => const PilotFeedbackPage(),
        'placement' => const PlacementCheckerPage(),
        'results' ||
        'results-location' ||
        'results-choices' => const ResultsPlannerPage(),
        'account' => const AccountPage(),
        'careers' => const CareerGuidancePage(),
        'support' => const SupportDirectoryPage(),
        'offline' => const OfflineChoicesPage(),
        'stories' => const CampusStoriesPage(),
        'sources' => const SourceCoveragePage(),
        'portal' => const SchoolPortalPage(),
        'privacy' => const PrivacyHelpPage(),
        'profile' || 'profile-bawjiase' => SchoolDetailsPage(
          school: schools.singleWhere(
            (s) =>
                s.id ==
                (pageId == 'profile'
                    ? 'methodist-saltpond'
                    : 'bawjiase-community-senior-high'),
          ),
        ),
        _ => throw StateError('Unknown audit page: $pageId'),
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: atlasTheme(dark ? Brightness.dark : Brightness.light),
          builder: (context, child) => DefaultAssetBundle(
            bundle: LayoutAssets(),
            child: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
          home: pageId.startsWith('profile') || pageId == 'shell'
              ? page
              : Scaffold(body: page),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      if (pageId == 'home') {
        final entry = find.text('Enter grades & find schools');
        expect(entry, findsOneWidget);
        await tester.ensureVisible(entry);
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(find.byType(ResultsPlannerPage), findsOneWidget);
        expect(find.text('Enter your BECE grades'), findsOneWidget);
      }
      if (pageId == 'results-location' || pageId == 'results-choices') {
        final label = pageId == 'results-location'
            ? '2  Where I live'
            : '3  Find schools';
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        tester.takeException(),
        isNull,
        reason: '$pageId should lay out without overflow',
      );
      final scrollables = find.byType(Scrollable);
      if (scrollables.evaluate().isNotEmpty) {
        for (var i = 0; i < 3; i++) {
          await tester.drag(scrollables.first, const Offset(0, -650));
          await tester.pump(const Duration(milliseconds: 100));
          expect(
            tester.takeException(),
            isNull,
            reason: '$pageId after scrolling',
          );
        }
      }
      await tester.pumpWidget(const SizedBox());
      PaintingBinding.instance.imageCache.clear();
    });
  }
}
