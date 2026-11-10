// Retired JHS/SHS app coverage; excluded from the tertiary release suite.
@Tags(['legacy_shs'])
library;

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skoolatlas/main.dart';
import 'package:skoolatlas/school.dart';
import 'package:skoolatlas/planning.dart';
import 'atlas_test_fonts.dart';
import 'page_layout_audit_test.dart' show LayoutAssets;

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await loadAtlas();
    await loadPlanningData();
    await loadAtlasTestFonts();
  });
  for (final width in [320.0, 390.0, 1024.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('balanced choice panels $width ${brightness.name}', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 960);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final previousErrorHandler = FlutterError.onError;
        FlutterError.onError = (details) {
          FlutterError.dumpErrorToConsole(details, forceReport: true);
          previousErrorHandler?.call(details);
        };
        addTearDown(() => FlutterError.onError = previousErrorHandler);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: atlasTheme(brightness),
            builder: (context, child) => DefaultAssetBundle(
              bundle: LayoutAssets(),
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(width == 320 ? 1.4 : 1),
                ),
                child: RepaintBoundary(key: boundary, child: child!),
              ),
            ),
            home: MainShell(key: atlasShellKey),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(AtlasPrimaryNavigation),
            matching: find.text('My choices'),
          ),
        );
        await tester.pumpAndSettle();
        final group = find.byKey(const ValueKey('shortlist-actions'));
        final primary = find.descendant(
          of: group,
          matching: find.byType(FilledButton),
        );
        final secondary = find.descendant(
          of: group,
          matching: find.byType(OutlinedButton),
        );
        expect(
          tester.getSize(primary).width,
          closeTo(tester.getSize(secondary).width, .1),
        );
        if (width < 600) {
          expect(
            tester.getTopLeft(primary).dx,
            tester.getTopLeft(secondary).dx,
          );
          expect(
            tester.getBottomRight(primary).dx,
            tester.getBottomRight(secondary).dx,
          );
        } else {
          expect(
            tester.getTopLeft(primary).dy,
            tester.getTopLeft(secondary).dy,
          );
          expect(
            tester.getSize(primary).height,
            tester.getSize(secondary).height,
          );
        }
        // My Choices already has a planner action; the toolkit must not repeat it.
        expect(find.text('Results & choice planner'), findsNothing);
        expect(find.text('Open results planner'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final output = Platform.environment['ATLAS_PANEL_PREVIEWS'];
        if (output != null && width == 390) {
          Future<void> capture(String suffix) async {
            await tester.runAsync(
              () => precacheImage(
                const AssetImage('assets/branding/launcher-mark.png'),
                tester.element(find.byType(AtlasBrand).first),
              ),
            );
            await tester.pumpAndSettle();
            final render =
                boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await render.toImage(pixelRatio: 1.5);
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              final file = File(
                '$output/choices-${brightness.name}-$suffix.png',
              );
              file.parent.createSync(recursive: true);
              file.writeAsBytesSync(bytes.buffer.asUint8List());
              image.dispose();
            });
          }

          await capture('top');
          await tester.ensureVisible(
            find.text('Offline & family sharing').last,
          );
          await tester.pumpAndSettle();
          await capture('toolkit');
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
