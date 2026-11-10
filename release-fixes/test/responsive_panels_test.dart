import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skoolatlas/main.dart';

void main() {
  testWidgets('secondary page title follows a live theme change', (tester) async {
    final brightness = ValueNotifier(Brightness.light);
    addTearDown(brightness.dispose);
    AppBar? cachedBar;
    await tester.pumpWidget(ValueListenableBuilder<Brightness>(
      valueListenable: brightness,
      builder: (_, value, child) => MaterialApp(
        theme: atlasTheme(value),
        home: Builder(builder: (context) => Scaffold(
          appBar: cachedBar ??= atlasPageBar(context, 'School guidance'),
          body: const SizedBox(),
        )),
      ),
    ));
    brightness.value = Brightness.dark;
    await tester.pumpAndSettle();
    final title = tester.widget<Text>(find.text('School guidance'));
    expect(title.style!.color,
        atlasTheme(Brightness.dark).colorScheme.onSurfaceVariant);
  }, tags: 'legacy_shs');

  testWidgets('disabled outline actions are visibly distinct in both themes', (tester) async {
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(MaterialApp(
        theme: atlasTheme(brightness),
        home: const Scaffold(body: OutlinedButton(
          onPressed: null, child: Text('Save offline pack'),
        )),
      ));
      final label = tester.element(find.text('Save offline pack'));
      final rendered = DefaultTextStyle.of(label).style.color!;
      final scheme = Theme.of(label).colorScheme;
      expect(rendered, scheme.onSurface.withValues(alpha: .38));
      expect(rendered, isNot(scheme.primary));
    }
  });

  testWidgets('school facts keep equal phone columns and wrap long values', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: atlasTheme(Brightness.dark),
      home: const Scaffold(body: Padding(
        padding: EdgeInsets.all(36),
        child: ActionTileGrid(
          twoColumnBreakpoint: 280,
          fourColumnBreakpoint: 840,
          children: [
            InfoBlock(key: ValueKey('fact-a'), title: 'Region', value: 'Greater Accra'),
            InfoBlock(key: ValueKey('fact-b'), title: 'School group', value: 'Public / government'),
          ],
        ),
      )),
    ));
    final a = tester.getRect(find.byKey(const ValueKey('fact-a')));
    final b = tester.getRect(find.byKey(const ValueKey('fact-b')));
    expect(a.top, b.top);
    expect(a.size, b.size);
    expect(b.right, lessThanOrEqualTo(354));
    expect(tester.takeException(), isNull);
  });

  testWidgets('action tiles share row height and stack for larger text', (tester) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<void> show(double scale) => tester.pumpWidget(MaterialApp(
      theme: atlasTheme(Brightness.dark),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: const Scaffold(body: Padding(
          padding: EdgeInsets.all(18),
          child: ActionTileGrid(children: [
            Surface(key: ValueKey('tile-a'), child: Text('Explore')),
            Surface(key: ValueKey('tile-b'), child: Text('Find a school and build an eight-choice draft with your family')),
          ]),
        )),
      ),
    ));
    await show(1);
    expect(tester.getSize(find.byKey(const ValueKey('tile-a'))).height,
        tester.getSize(find.byKey(const ValueKey('tile-b'))).height);
    await show(1.4);
    expect(tester.getTopLeft(find.byKey(const ValueKey('tile-b'))).dy,
        greaterThan(tester.getBottomLeft(find.byKey(const ValueKey('tile-a'))).dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('paired panels support responsive action groups without intrinsic queries',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: atlasTheme(Brightness.dark),
      home: const Scaffold(body: PanelGrid(children: [
        Surface(key: ValueKey('actions-panel'), child: BalancedActions(children: [
          FilledButton(onPressed: null, child: Text('Explore school')),
          OutlinedButton(onPressed: null, child: Text('Watch video')),
        ])),
        Surface(key: ValueKey('text-panel'), child: Text('School information')),
      ])),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(const ValueKey('actions-panel'))).height,
        tester.getSize(find.byKey(const ValueKey('text-panel'))).height);
  });

  for (final width in [320.0, 1024.0]) {
    testWidgets('action styles and unpaired action use available width $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: atlasTheme(Brightness.dark),
        home: Scaffold(body: BalancedActions(children: [
          FilledButton(onPressed: () {}, child: const Text('First')),
          OutlinedButton(onPressed: () {}, child: const Text('Second')),
          TextButton(onPressed: () {}, child: const Text('Third')),
        ])),
      ));
      await tester.pump();
      final third = find.byType(TextButton);
      expect(tester.getSize(third).width, closeTo(width, .1));
      expect(tester.getSize(third).height, greaterThanOrEqualTo(52));
      final context = tester.element(find.byType(FilledButton));
      final style = FilledButtonTheme.of(context).style!;
      expect(style.alignment, Alignment.center);
      expect(style.minimumSize!.resolve({}), const Size(48, 52));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('panel columns collapse when large text needs more room',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<void> show(double scale) => tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: const Scaffold(body: PanelGrid(children: [
          SizedBox(key: ValueKey('a'), height: 80),
          SizedBox(key: ValueKey('b'), height: 120),
        ])),
      ),
    ));
    await show(1);
    expect(tester.getTopLeft(find.byKey(const ValueKey('a'))).dy,
        tester.getTopLeft(find.byKey(const ValueKey('b'))).dy);
    await show(1.5);
    expect(tester.getTopLeft(find.byKey(const ValueKey('b'))).dy,
        greaterThan(tester.getBottomLeft(find.byKey(const ValueKey('a'))).dy));
    expect(tester.takeException(), isNull);
  });
}
