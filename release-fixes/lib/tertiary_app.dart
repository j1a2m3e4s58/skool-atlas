import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'atlas_controls.dart';
import 'curriculum_planner.dart';
import 'atlas_privacy.dart';
import 'package:url_launcher/url_launcher.dart';
import 'tertiary_data.dart';
import 'student_hub.dart';
import 'tertiary_gallery.dart';
import 'institution_evidence.dart';
import 'pathway_widgets.dart';
import 'pathway_result_card.dart';

const ink = Color(0xFF173F3B);
const gold = Color(0xFFAD813E);
const paper = Color(0xFFF4F3ED);

class TertiaryAtlasApp extends StatelessWidget {
  final TertiaryStore? store;
  const TertiaryAtlasApp({super.key, this.store});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Tertiary Atlas · Ghana',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'SkoolSans',
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ink,
        primary: ink,
        secondary: gold,
        surface: paper,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(height: 1.5, color: ink),
        bodyLarge: TextStyle(height: 1.5, color: ink),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: .8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD9DFD8)),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    ),
    home: TertiaryHome(store: store),
  );
}

class AtlasMark extends StatelessWidget {
  final double size;
  const AtlasMark({super.key, this.size = 42});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: ink,
      borderRadius: BorderRadius.circular(11),
    ),
    child: CustomPaint(painter: _AtlasMarkPainter()),
  );
}

class _AtlasMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFE4C795)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final w = size.width;
    canvas.drawPath(
      Path()
        ..moveTo(w * .22, w * .72)
        ..lineTo(w * .50, w * .21)
        ..lineTo(w * .78, w * .72)
        ..moveTo(w * .37, w * .51)
        ..lineTo(w * .63, w * .51),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(w * .20, w * .79)
        ..quadraticBezierTo(w * .36, w * .69, w * .50, w * .79)
        ..quadraticBezierTo(w * .65, w * .69, w * .80, w * .79),
      p..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.color,
  });
  @override
  Widget build(BuildContext context) {
    final surface = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white.withValues(alpha: .88),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .85)),
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
    // Small screens avoid an offscreen blur layer for every panel.
    if (MediaQuery.sizeOf(context).width < 700 ||
        MediaQuery.disableAnimationsOf(context)) {
      return surface;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: surface,
      ),
    );
  }
}

class TertiaryHome extends StatefulWidget {
  final TertiaryStore? store;
  const TertiaryHome({super.key, this.store});
  @override
  State<TertiaryHome> createState() => _TertiaryHomeState();
}

class _TertiaryHomeState extends State<TertiaryHome>
    with WidgetsBindingObserver {
  late final TertiaryStore store;
  final search = TextEditingController();
  int page = 0;
  int visibleCount = 12;
  String group = 'All institutions';
  String location = 'All regions';
  bool ready = false, syncing = false, showInactive = true;
  String? loadError;
  Timer? timer;
  static const groups = [
    'All institutions',
    'Universities & colleges',
    'Technical universities',
    'Colleges of education',
    'Nursing & health',
    'Skills & fashion',
  ];
  @override
  void initState() {
    super.initState();
    store = widget.store ?? TertiaryStore();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    try {
      if (store.institutions.isEmpty) {
        await store.load();
      }
      if (!mounted) return;
      setState(() {
        ready = true;
        if (Uri.base.queryParameters['journey'] == '1') page = 3;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await sync();
      if (mounted) {
        timer = Timer.periodic(const Duration(minutes: 30), (_) => sync());
      }
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'Tertiary Atlas',
        context: ErrorDescription('while loading the offline catalogue'),
      ));
      if (mounted) {
        setState(
          () => loadError =
              'The offline catalogue could not load. Please reopen the app or reinstall the offline pack.',
        );
      }
    }
  }

  Future<void> sync() async {
    if (syncing) return;
    setState(() => syncing = true);
    await store.refresh();
    if (mounted) setState(() => syncing = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && ready) sync();
  }

  @override
  void dispose() {
    timer?.cancel();
    search.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> save(TertiaryInstitution i) async {
    await store.toggleSaved(i.id);
    if (mounted) setState(() {});
  }

  void navigate(int p) {
    setState(() => page = p);
  }

  List<TertiaryInstitution> get filtered {
    final query = search.text.trim().toLowerCase();
    final list = store.institutions
        .where(
          (i) =>
              (showInactive || i.listedActive) &&
              (page != 3 || store.saved.contains(i.id)) &&
              (group == 'All institutions' || i.group == group) &&
              (location == 'All regions' || i.regions.contains(location)) &&
              (query.isEmpty ||
                  '${i.name} ${i.aliases.join(' ')} ${i.locations.join(' ')} ${i.regions.join(' ')} ${i.courses.join(' ')}'
                      .toLowerCase()
                      .contains(query)),
        )
        .toList();
    const featured = [
      'gtec:881',
      'gtec:876',
      'gtec:875',
      'gtec:878',
      'gtec:874',
      'gtec:877',
      'gtec:837',
      'gtec:884',
      'gtec:879',
      'gtec:880',
      'gtec:882',
      'gtec:883',
      'gtec:900',
      'gtec:899',
      'gtec:912',
      'gtec:922',
      'gtec:942',
      'gtec:998',
      'gtec:823',
      'gtec:824',
      'gtec:825',
      'gtec:826',
      'gtec:827',
      'gtec:828',
      'gtec:829',
      'gtec:830',
      'gtec:831',
      'gtec:832',
      'gtec:920',
      'gtec:869',
      'gtec:935',
      'gtec:651',
    ];
    list.sort((a, b) {
      final x = featured.indexOf(a.mediaKey), y = featured.indexOf(b.mediaKey);
      return (x < 0 ? 99 : x).compareTo(y < 0 ? 99 : y) != 0
          ? (x < 0 ? 99 : x).compareTo(y < 0 ? 99 : y)
          : a.name.compareTo(b.name);
    });
    return page == 0 && query.isEmpty
        ? list.where((i) => i.id != 'gtec:881').toList()
        : list;
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 850;
    final matching = ready && (page == 0 || page == 1)
        ? filtered
        : <TertiaryInstitution>[];
    final featuredCount = wide ? 9 : 3;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(1, -.8),
            radius: 1.5,
            colors: [Color(0xFFDDE8DE), paper, Color(0xFFF1EEE6)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: paper.withValues(alpha: .9),
                  border: const Border(
                    bottom: BorderSide(color: Color(0xFFDFE3DB)),
                  ),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: wide ? 48 : 18,
                  vertical: 18,
                ),
                child: Row(
                  children: [
                    Semantics(
                      label: 'Tertiary Atlas. Long press for owner administration.',
                      child: GestureDetector(
                        key: const ValueKey('admin-logo-entry'),
                        onLongPress: openAdmin,
                        child: const AtlasMark(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TERTIARY ATLAS',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                              color: ink,
                            ),
                          ),
                          Text(
                            'GHANA  /  YOUR NEXT CHAPTER',
                            style: TextStyle(
                              fontSize: 9,
                              letterSpacing: 1.8,
                              color: gold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (wide) ...[
                      for (final (index, label) in [
                        'Discover',
                        'Institutions',
                        'Grade planner',
                        'My journey',
                        'Sources',
                      ].indexed)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: TextButton(
                            onPressed: () => navigate(index),
                            style: TextButton.styleFrom(
                              foregroundColor: page == index
                                  ? ink
                                  : const Color(0xFF667871),
                              backgroundColor: page == index
                                  ? Colors.white.withValues(alpha: .8)
                                  : null,
                            ),
                            child: Text(label),
                          ),
                        ),
                      const SizedBox(width: 20),
                    ] else
                      IconButton(
                        tooltip: 'Data & updates',
                        onPressed: () => navigate(4),
                        icon: const Icon(Icons.cloud_sync_outlined),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: !ready
                    ? Center(
                        child: loadError != null
                            ? Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(loadError!),
                              )
                            : const CircularProgressIndicator(),
                      )
                    : page == 2
                    ? GradePlanner(store: store)
                    : page == 4
                    ? sourcePage()
                    : page == 3
                    ? StudentHub(
                        store: store,
                        onGrades: () => navigate(2),
                        onProfile: profile,
                      )
                    : SingleChildScrollView(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1350),
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                wide ? 48 : 20,
                                wide ? 38 : 24,
                                wide ? 48 : 20,
                                40,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (page == 0)
                                    hero(wide)
                                  else ...[
                                    eyebrow(
                                      page == 3
                                          ? 'YOUR PERSONAL DIRECTORY'
                                          : 'EXPLORE YOUR POSSIBILITIES',
                                    ),
                                    const SizedBox(height: 12),
                                    heading(
                                      page == 3
                                          ? 'A future worth saving.'
                                          : 'Find your place.',
                                      wide ? 44 : 34,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      page == 3
                                          ? 'Your shortlist stays on this device. Save institutions to compare your options.'
                                          : 'Search institutions and their listed programmes across Ghana.',
                                    ),
                                    const SizedBox(height: 28),
                                  ],
                                  if (page == 0) ...[
                                    const SizedBox(height: 32),
                                    regionOverview(),
                                    const SizedBox(height: 36),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: heading(
                                            'Explore your next chapter',
                                            wide ? 28 : 24,
                                          ),
                                        ),
                                        if (wide)
                                          const Text(
                                            'Different paths. One place to begin.',
                                            style: TextStyle(
                                              color: Color(0xFF6B7A72),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 18),
                                  ],
                                  searchBar(wide),
                                  const SizedBox(height: 18),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        for (final g in groups)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              right: 8,
                                            ),
                                            child: ChoiceChip(
                                              label: Text(g),
                                              selected: group == g,
                                              onSelected: (_) =>
                                                  setState(() => group = g),
                                              showCheckmark: false,
                                              selectedColor: ink,
                                              labelStyle: TextStyle(
                                                color: group == g
                                                    ? Colors.white
                                                    : ink,
                                              ),
                                              backgroundColor: Colors.white
                                                  .withValues(alpha: .6),
                                              side: BorderSide(
                                                color: group == g
                                                    ? ink
                                                    : const Color(0xFFD4DDD3),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        page == 0 &&
                                                search.text.trim().isEmpty &&
                                                group == 'All institutions' &&
                                                location == 'All regions'
                                            ? '${store.institutions.length} national profiles · 16 regions'
                                            : '${matching.length} institution profiles',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF61766C),
                                        ),
                                      ),
                                      FilterChip(
                                        label: const Text(
                                          'Include expired / unclear entries',
                                        ),
                                        selected: showInactive,
                                        onSelected: (v) =>
                                            setState(() => showInactive = v),
                                      ),
                                      if (page == 3 && store.saved.isNotEmpty)
                                        TextButton.icon(
                                          onPressed: compare,
                                          icon: const Icon(
                                            Icons.compare_arrows,
                                          ),
                                          label: const Text('Compare saved'),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  if (matching.isEmpty)
                                    const GlassPanel(
                                      child: Text(
                                        'No matching institutions. Try another search or reset the filters.',
                                      ),
                                    )
                                  else
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final columns =
                                            constraints.maxWidth > 1000
                                            ? 3
                                            : constraints.maxWidth > 620
                                            ? 2
                                            : 1;
                                        return Wrap(
                                          spacing: 20,
                                          runSpacing: 20,
                                          children: [
                                            for (final i in matching.take(
                                              page == 0
                                                  ? featuredCount
                                                  : visibleCount,
                                            ))
                                              SizedBox(
                                                width:
                                                    (constraints.maxWidth -
                                                        20 * (columns - 1)) /
                                                    columns,
                                                child: institutionCard(i),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  const SizedBox(height: 22),
                                  if (matching.length >
                                      (page == 0
                                          ? featuredCount
                                          : visibleCount))
                                    TextButton.icon(
                                      onPressed: () {
                                        if (page == 0) {
                                          navigate(1);
                                        } else {
                                          setState(() => visibleCount += 12);
                                        }
                                      },
                                      icon: const Icon(Icons.arrow_forward),
                                      label: Text(
                                        page == 0
                                            ? 'Explore all institutions'
                                            : 'Load 12 more institutions',
                                      ),
                                    ),
                                  const SizedBox(height: 22),
                                  const Divider(),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'An independent guide to Ghana’s tertiary and skills pathways. Duplicate register listings are combined in reviewed profiles. A listing is not an admission offer or proof of every programme’s current approval.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF687B71),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: page,
              onDestinationSelected: navigate,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.explore_outlined),
                  label: 'Discover',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_balance_outlined),
                  label: 'Schools',
                ),
                NavigationDestination(
                  icon: Icon(Icons.tune),
                  label: 'My grades',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bookmark_border),
                  label: 'My journey',
                ),
                NavigationDestination(
                  icon: Icon(Icons.fact_check_outlined),
                  label: 'Sources',
                ),
              ],
            ),
    );
  }

  Widget eyebrow(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 2.2,
      color: gold,
    ),
  );
  String content(String key, String fallback) => store.siteContent[key] ?? fallback;
  Future<void> openAdmin() async {
    final uri = kIsWeb
        ? Uri.base.resolve('/admin')
        : Uri.parse('https://ghana-tertiary-atlas.ghana-tertiary-atlas-host.workers.dev/admin');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication, webOnlyWindowName: '_self');
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open secure administration. Connect to the internet and try again.')));
    }
  }
  Widget heading(String text, double size) => Text(
    text,
    style: TextStyle(
      fontFamily: 'AtlasSerif',
      fontFamilyFallback: const ['serif'],
      fontSize: size,
      height: 1.08,
      color: ink,
      letterSpacing: -.8,
    ),
  );
  Widget hero(bool wide) {
    final left = Container(
      padding: EdgeInsets.all(wide ? 32 : 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .72),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDCE5DB)),
      ),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        eyebrow(content('homeEyebrow', 'AMBITION HAS A DESTINATION.')),
        const SizedBox(height: 18),
        heading(content('homeTitle', 'Your potential.\nA world of possibilities.'), wide ? 52 : 36),
        const SizedBox(height: 18),
        SizedBox(
          width: 430,
          child: Text(
            content('homeIntro', 'Discover universities, colleges and creative pathways across Ghana. Make your next move with clarity.'),
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF5E7268),
              height: 1.7,
            ),
          ),
        ),
        const SizedBox(height: 24),
        AtlasActionRow(children: [
          FilledButton.icon(key: const ValueKey('home-explore-action'), onPressed: () => navigate(1), icon: const Icon(Icons.north_east, size: 16), label: Text(content('primaryActionLabel', 'Explore institutions'), textAlign: TextAlign.center)),
          OutlinedButton.icon(key: const ValueKey('home-pathway-action'), onPressed: () => navigate(2), icon: const Icon(Icons.tune, size: 16), label: Text(content('secondaryActionLabel', 'Find my pathway'), textAlign: TextAlign.center)),
        ]),
        const SizedBox(height: 20),
        if (content('announcement', '').isNotEmpty) ...[
          Text(content('announcement', ''), style: const TextStyle(height: 1.6)),
          const SizedBox(height: 16),
        ],
        const Divider(height: 1, color: Color(0xFFDCE5DB)),
        const SizedBox(height: 16),
        const Row(
          children: [
            Icon(Icons.offline_pin_outlined, size: 17, color: ink),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                'Offline discovery. Source-led decisions.',
                style: TextStyle(fontSize: 12, color: Color(0xFF61766C)),
              ),
            ),
          ],
        ),
      ],
      ),
    );
    final photo = ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: wide ? 480 : 300,
        child: Stack(
          fit: StackFit.expand,
          children: [
            campus('gtec:881'),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xC0153831)],
                ),
              ),
            ),
            Positioned(
              top: 18,
              left: 18,
              child: GlassPanel(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: ink,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'THE NEXT CHAPTER STARTS HERE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 22,
              right: 22,
              bottom: 22,
              child: GlassPanel(
                color: Colors.white.withValues(alpha: .84),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      institutionLogo('gtec:881', size: 42),
                      const Spacer(),
                      IconButton(
                      tooltip: 'Explore University of Ghana',
                      onPressed: () {
                        final matches = store.institutions.where(
                          (i) => i.mediaKey == 'gtec:881',
                        );
                        if (matches.isNotEmpty) profile(matches.first);
                      },
                      icon: const Icon(Icons.north_east),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    const Text(
                      'University of Ghana',
                      key: ValueKey('hero-institution-name'),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                    const SizedBox(height: 4),
                    const Text('Legon · Greater Accra', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 24),
              Expanded(child: photo),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [photo, const SizedBox(height: 24), left],
          );
  }

  Widget institutionLogo(String id, {double size = 56}) {
    final data = (store.media[id] as Map?)?['logo'];
    return Tooltip(
      message: data is Map
          ? 'Official institution logo · source checked'
          : 'Official logo awaiting verification',
      child: Container(
        width: size * 2.1,
        height: size,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: data is Map && data['darkBackground'] == true
              ? ink
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE1E7E0)),
        ),
        child: data is Map
            ? Image.asset(
                data['asset'] as String,
                fit: BoxFit.contain,
                errorBuilder: (_, e, st) => const Icon(Icons.school_outlined),
              )
            : const Center(
                child: Text(
                  'Logo pending',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 9, color: Color(0xFF687B71)),
                ),
              ),
      ),
    );
  }

  Widget campus(String key) {
    final m = store.media[key];
    if (m is Map && m['asset'] is String) {
      return Image.asset(
        m['asset'] as String,
        fit:
            m['sourceDimensions'] is List &&
                (m['sourceDimensions'] as List).length == 2 &&
                m['sourceDimensions'][0] < m['sourceDimensions'][1]
            ? BoxFit.contain
            : BoxFit.cover,
        alignment: key == 'gtec:881' ? Alignment.centerLeft : Alignment.center,
        errorBuilder: (_, error, stack) => placeholder(key),
      );
    }
    return placeholder(key);
  }

  Widget placeholder(String key) {
    final institution = store.institutions
        .where((i) => i.id == key)
        .firstOrNull;
    final initials = (institution?.name ?? 'Atlas')
        .split(' ')
        .where((s) => s.isNotEmpty)
        .take(3)
        .map((s) => s[0])
        .join();
    return Container(
      color: const Color(0xFFE8EDE5),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            initials,
            style: const TextStyle(
              fontFamily: 'AtlasSerif',
              fontSize: 38,
              color: Color(0xFF58746A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            institution?.regions.join(' · ') ?? 'Ghana',
            style: const TextStyle(fontSize: 11, color: Color(0xFF58746A)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Photo awaiting verification',
            style: TextStyle(fontSize: 10, color: Color(0xFF75877C)),
          ),
        ],
      ),
    );
  }

  Widget regionOverview() => GlassPanel(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        eyebrow('EXPLORE BY LOCATION'),
        const SizedBox(height: 12),
        heading(content('regionHeading', 'Across all 16 regions'), 26),
        const SizedBox(height: 10),
        Text(
          '${store.institutions.length} institution profiles. Choose a region to see its full directory.',
          style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF5E7268)),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final regions = store.institutions.expand((i) => i.regions).toSet().toList()..sort();
            final columns = constraints.maxWidth >= 900 ? 4 : constraints.maxWidth >= 600 ? 2 : 1;
            final tileWidth = (constraints.maxWidth - 12 * (columns - 1)) / columns;
            final tileHeight = 106.0 + (MediaQuery.textScalerOf(context).scale(14) - 14) * 4;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final region in regions)
                  SizedBox(
                    key: ValueKey('home-region-$region'),
                    width: tileWidth,
                    height: tileHeight,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(12),
                        backgroundColor: Colors.white.withValues(alpha: .85),
                        side: const BorderSide(color: Color(0xFFD6E0D5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        alignment: Alignment.centerLeft,
                      ),
                      onPressed: () => setState(() {
                        location = region;
                        group = 'All institutions';
                        search.clear();
                        showInactive = true;
                        page = 1;
                      }),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Text(region, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.25))),
                          Row(children: [
                            Expanded(child: Text(
                              '${store.institutions.where((i) => i.regions.contains(region)).length} profiles',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF61766C)),
                            )),
                            const Icon(Icons.north_east, size: 14),
                          ]),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );

  Widget searchBar(bool wide) {
    const locations = [
      'Ahafo',
      'Ashanti',
      'Bono',
      'Bono East',
      'Central',
      'Eastern',
      'Greater Accra',
      'North East',
      'Northern',
      'Oti',
      'Savannah',
      'Upper East',
      'Upper West',
      'Volta',
      'Western',
      'Western North',
    ];
    final text = TextField(
      controller: search,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'Search a university, course or town',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: search.text.isNotEmpty
            ? IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  search.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close),
              )
            : null,
      ),
    );
    final dropdown = AtlasDropdown<String>(
      initialValue: location,
      isExpanded: true,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.location_on_outlined),
      ),
      items: [
        const DropdownMenuItem(
          value: 'All regions',
          child: Text('All regions'),
        ),
        for (final l in locations)
          DropdownMenuItem(
            value: l,
            child: Text(
              '$l (${store.institutions.where((i) => i.regions.contains(l)).length})',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (v) => setState(() => location = v!),
    );
    return wide
        ? Row(
            children: [
              Expanded(flex: 3, child: text),
              const SizedBox(width: 14),
              Expanded(child: dropdown),
            ],
          )
        : Column(children: [text, const SizedBox(height: 10), dropdown]);
  }

  Widget institutionCard(TertiaryInstitution i) {
    final m = store.media[i.id] as Map?;
    final hasPhoto = m?['asset'] is String;
    final hasLogo = m?['logo'] is Map;
    final saveButton = IconButton.filledTonal(
      tooltip: store.saved.contains(i.id)
          ? 'Remove from saved'
          : 'Save institution',
      onPressed: () => save(i),
      icon: Icon(
        store.saved.contains(i.id) ? Icons.bookmark : Icons.bookmark_border,
      ),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: .92),
      ),
    );
    return Semantics(
      container: true,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white),
          boxShadow: [
            BoxShadow(
              color: ink.withValues(alpha: .035),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasPhoto)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                child: SizedBox(
                  height: 172,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      campus(i.id),
                      if (hasLogo)
                        Positioned(
                          left: 12,
                          bottom: 12,
                          child: institutionLogo(i.id),
                        ),
                      Positioned(right: 10, top: 10, child: saveButton),
                    ],
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 10, 0),
                child: Row(
                  children: [
                    if (hasLogo)
                      institutionLogo(i.id)
                    else
                      const Text(
                        'INSTITUTION PROFILE',
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 1.2,
                          color: Color(0xFF74847A),
                        ),
                      ),
                    const Spacer(),
                    saveButton,
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i.group.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.bold,
                      color: gold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 64),
                    child: Text(
                      i.id == 'gtec:875' ? 'GIMPA · ${i.name}' : i.name,
                      style: const TextStyle(
                        fontSize: 17,
                        height: 1.35,
                        color: ink,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 15,
                        color: Color(0xFF74847A),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '${i.location} · ${i.regions.join(' / ')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF74847A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!hasPhoto)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        'Campus photo awaiting verification',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF74847A),
                        ),
                      ),
                    ),
                  if (!i.listedActive)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Approval needs checking',
                        style: TextStyle(
                          fontSize: 11,
                          color: gold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(height: 15),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${i.courses.length} listed ${i.id.startsWith('nmc:') ? 'programme codes' : 'programmes'}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7E71),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => profile(i),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Explore', style: TextStyle(fontSize: 12)),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward, size: 15),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void profile(TertiaryInstitution i) {
    final relevant = store.rules
        .where((r) => store.ruleInstitutionId(r) == i.id)
        .toList();
    showModalBottomSheet<void>(
      context: context,
      constraints: const BoxConstraints(maxWidth: 900),
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: paper,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .85,
        maxChildSize: .95,
        minChildSize: .4,
        builder: (ctx, controller) => SingleChildScrollView(
          controller: controller,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: 'Close institution',
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                    InstitutionGallery(store: store, institution: i),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: institutionLogo(i.id, size: 80),
                    ),
                    const SizedBox(height: 14),
                    eyebrow(i.group.toUpperCase()),
                    const SizedBox(height: 12),
                    heading(i.name, 30),
                    if (i.nameSource != null)
                      TextButton(
                        onPressed: () => openLink(i.nameSource!),
                        child: const Text(
                          'Official name change · register names retained below',
                        ),
                      ),
                    const SizedBox(height: 8),
                    for (final detail in <(IconData, String)>[
                      (Icons.location_on_outlined, i.regions.join(' · ')),
                      (Icons.place_outlined, i.locations.join(' / ')),
                      (Icons.school_outlined, i.category),
                    ])
                      if (detail.$2.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(detail.$1, size: 18, color: const Color(0xFF60736A)),
                              const SizedBox(width: 10),
                              Expanded(child: Text(detail.$2,
                                style: const TextStyle(fontSize: 14, height: 1.5,
                                  color: Color(0xFF60736A)))),
                            ],
                          ),
                        ),
                    const SizedBox(height: 18),
                    LayoutBuilder(builder: (context, constraints) {
                      final actions = <Widget>[
                        if (Uri.tryParse(
                              '${(store.media[i.mediaKey] as Map?)?['website']}',
                            )?.scheme ==
                            'https')
                          OutlinedButton.icon(
                            onPressed: () => openLink(
                              store.media[i.mediaKey]['website'] as String,
                            ),
                            icon: const Icon(Icons.language, size: 16),
                            label: const Text('Institution website'),
                          ),
                        FilledButton.icon(
                          onPressed: () => openLink(i.source),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('Official regulator record', textAlign: TextAlign.center),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            save(i);
                            Navigator.pop(ctx);
                          },
                          icon: Icon(
                            store.saved.contains(i.id)
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                          ),
                          label: Text(
                            store.saved.contains(i.id)
                                ? 'Remove saved'
                                : 'Save institution',
                          ),
                        ),
                      ];
                      return AtlasActionRow(children: actions);
                    }),
                    const SizedBox(height: 22),
                    InstitutionEvidence(
                      institution: i,
                      media: (store.media[i.mediaKey] as Map?) ?? {},
                      onOpen: openLink,
                    ),
                    const SizedBox(height: 24),
                    heading('Admission requirements', 24),
                    const SizedBox(height: 10),
                    if (i.mediaKey == 'gtec:881')
                      TextButton.icon(
                        onPressed: showCutoffs,
                        icon: const Icon(Icons.table_chart_outlined),
                        label: const Text(
                          'View 63 published UG cutoff rows · dated snapshot',
                        ),
                      ),
                    if (relevant.isEmpty)
                      const Text(
                        'Not yet verified for this institution’s exact programmes. No cutoff or eligibility is inferred from its regulator listing.',
                      )
                    else ...[
                      for (final r in relevant)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GlassPanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  r.programme,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '${r.data['note']}',
                                  style: const TextStyle(height: 1.6),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '${r.data['cutoffText']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '${r.data['status'] == 'source_checked' ? 'Source checked' : 'Source needs review'} ${r.checkedAt} · ${r.data['cycle']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    alignment: Alignment.centerLeft,
                                    padding: EdgeInsets.zero,
                                  ),
                                  onPressed: () => openLink(r.source),
                                  child: const Text('Read admission source'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          navigate(2);
                        },
                        child: const Text('Check my WASSCE grades'),
                      ),
                    ],
                    const SizedBox(height: 24),
                    heading('Listed programmes', 24),
                    const SizedBox(height: 12),
                    if (i.courses.isEmpty)
                      const Text(
                        'The snapshot has no undergraduate programme rows for this institution. This does not mean it offers no courses.',
                      )
                    else ...[
                      const Text(
                        'Qualification and title as listed by the regulator. Some routes may need prior qualifications; availability is not confirmed.',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      for (final course in i.courses)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.arrow_outward,
                                size: 16,
                                color: gold,
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(course)),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void compare() {
    final selected = store.institutions
        .where((i) => store.saved.contains(i.id))
        .take(3)
        .toList();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Compare your first 3 saved entries'),
        content: SizedBox(
          width: 800,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Institution')),
                DataColumn(label: Text('Location')),
                DataColumn(label: Text('Pathway')),
                DataColumn(label: Text('Listed programmes')),
              ],
              rows: [
                for (final i in selected)
                  DataRow(
                    cells: [
                      DataCell(SizedBox(width: 190, child: Text(i.name))),
                      DataCell(SizedBox(width: 130, child: Text(i.location))),
                      DataCell(SizedBox(width: 120, child: Text(i.group))),
                      DataCell(Text('${i.courses.length}')),
                    ],
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void showCutoffs() {
    final cutoff = store.cutoffs;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('UG · Published cutoff snapshot'),
        content: SizedBox(
          width: 900,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Checked ${cutoff['checkedAt']} · ${cutoff['cycle']}\n${cutoff['note']}',
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      for (final c in cutoff['columns'] as List)
                        DataColumn(label: Text('$c')),
                    ],
                    rows: [
                      for (final row in cutoff['rows'] as List)
                        DataRow(
                          cells: [
                            for (final c in (row as List).take(5))
                              DataCell(
                                SizedBox(
                                  width: c == row[0] ? 250 : 100,
                                  child: Text(
                                    '$c',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => openLink(cutoff['sourceUrl'] as String),
            child: const Text('Read official table'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget sourcePage() => SingleChildScrollView(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              eyebrow('EVIDENCE BEFORE ASSUMPTIONS'),
              const SizedBox(height: 12),
              AtlasPrivacyButton(email: content('supportEmail', atlasSupportEmail)),
              const SizedBox(height: 16),
              heading('Know what you’re\nplanning with.', 38),
              const SizedBox(height: 22),
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Updates & offline access',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(store.syncMessage),
                    const SizedBox(height: 14),
                    AtlasActionRow(children: [
                    FilledButton.icon(
                      onPressed: syncing ? null : sync,
                      icon: const Icon(Icons.sync),
                      label: Text(syncing ? 'Checking…' : 'Check for updates'),
                    ),
                    if (kIsWeb)
                      TextButton.icon(
                        onPressed: () => openLink(
                          Uri.base.resolve('offline-status.html').toString(),
                        ),
                        icon: const Icon(Icons.download_for_offline_outlined),
                        label: const Text('Manage offline download'),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    const Text(
                      'The catalogue and academic rules are saved for offline access after the initial download. On web, photographs load as you browse; use Manage offline download to save all available images, preferably on Wi-Fi. External admissions links require internet. This app checks its hosted feed on opening, resuming and every 30 minutes. Hosted checks scan every monitored source every 15 minutes. Changes pause affected checks until reviewed. Revised rules, new admission-year pages, institutions and photographs need a reviewed publication; new wording is never automatically treated as an admission requirement. Grades stay in memory; saved institutions stay on this device.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              GlassPanel(
                child: EvidenceReviewPanel(store: store, openSource: openLink),
              ),
              const SizedBox(height: 22),
              OutlinedButton.icon(
                onPressed: showCutoffs,
                icon: const Icon(Icons.table_chart_outlined),
                label: const Text('Read the offline UG cutoff table'),
              ),
              for (final entry in [
                (
                  'GTEC · Universities & colleges',
                  'https://gtec.edu.gh/explore-institutions/',
                ),
                (
                  'CTVET · Technical & creative skills',
                  'https://ctvet.gov.gh/accredited-institutions/',
                ),
                (
                  'NMC · Nursing & midwifery',
                  'https://nmc.gov.gh/web/find-accredited-institutions',
                ),
                (
                  'UG · Published cutoff table',
                  'https://admissions.ug.edu.gh/node/36',
                ),
                (
                  'KNUST · Undergraduate admissions',
                  'https://www.knust.edu.gh/admissions/undergraduate',
                ),
              ])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.$1),
                  subtitle: Text(entry.$2),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => openLink(entry.$2),
                ),
              const SizedBox(height: 18),
              const Text(
                'Coverage & dates',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                '${store.institutions.length} reviewed institution profiles across all 16 regions, retaining 788 source register records. This is coverage of captured registers, not a guarantee that every provider in Ghana is listed. Skills registers include vocational routes outside tertiary degrees. Programme snapshots exclude recognised postgraduate labels, but some top-up or professional courses still require earlier qualifications. Each institution shows its register check date.',
              ),
              const SizedBox(height: 20),
              Text(
                '${store.media.values.where((m) => m is Map && m["asset"] is String).length} institutions with photos · ${store.institutions.fold<int>(0, (sum, i) => sum + galleryPhotos(store, i.id).length)} photographs · ${store.media.values.where((m) => m is Map && m["logo"] is Map).length} official logos verified',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Every region is searchable. Missing media is explicitly labelled and never replaced with another school’s photograph or crest. Counts below include multi-region institutions in each relevant region.',
              ),
              const SizedBox(height: 14),
              AtlasPanelGrid(
                children: [
                  for (final region
                      in (store.institutions
                          .expand((i) => i.regions)
                          .toSet()
                          .toList()
                        ..sort()))
                    GlassPanel(
                        key: ValueKey('source-region-$region'),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              region,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${store.institutions.where((i) => i.regions.contains(region)).length} profiles',
                              style: const TextStyle(fontSize: 15, height: 1.5),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${store.institutions.where((i) => i.regions.contains(region) && (store.media[i.id] as Map?)?["asset"] is String).length} photos · ${store.institutions.where((i) => i.regions.contains(region) && (store.media[i.id] as Map?)?["logo"] is Map).length} logos',
                              style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF5E7268)),
                            ),
                          ],
                        ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '${store.rules.length} published academic rules · ${store.rules.where((r) => r.data['status'] == 'source_checked').length} source-checked; held rules do not support matching. Other programmes show “Not yet verified”. Rules expire for matching after 180 days without a source check. Undated cutoff tables are not presented as current-cycle guarantees. Changed pages need validation before structured rules are published.',
              ),
              const SizedBox(height: 20),
              const Text(
                'Image rights',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Images are attributed to institution websites in each profile. Attribution does not grant a redistribution licence. Release requires media permission review; missing photos use a labelled placeholder.',
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> openLink(String value) async {
  final uri = Uri.tryParse(value);
  if (uri != null && uri.scheme == 'https') {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class LegacyGradePlanner extends StatefulWidget {
  final TertiaryStore store;
  const LegacyGradePlanner({super.key, required this.store});
  @override
  State<LegacyGradePlanner> createState() => _GradePlannerState();
}

class _GradePlannerState extends State<LegacyGradePlanner> {
  Map<String, int> get grades => widget.store.sessionGrades;
  List<String?> electives = [null, null, null, null];
  bool assessed = false;
  String institution = 'All checked institutions';
  String? targetCycle;
  String programmeQuery = '';
  int visibleResults = 4;
  final programmeSearch = TextEditingController();
  String? simulationSubject;
  int? simulationGrade;
  GradeSimulation? simulation;
  List<PathwayRecommendation> recommendations = [];
  List<AdmissionRule>? _rankedRules;
  PathwayPreferences? _rankedPreferences;
  DateTime? _rankedAt;
  @override
  void dispose() {
    programmeSearch.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final selected = grades.keys
        .where(electiveSubjects.contains)
        .take(4)
        .toList();
    electives = [
      ...selected,
      ...List<String?>.filled(4 - selected.length, null),
    ];
  }

  void changed() => setState(() {
    assessed = false;
    recommendations = [];
    _rankedRules = null;
    visibleResults = 4;
    simulation = null;
    simulationSubject = null;
    simulationGrade = null;
  });
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    if (assessed &&
        (!identical(_rankedRules, widget.store.rules) ||
            !identical(_rankedPreferences, widget.store.preferences) ||
            _rankedAt == null ||
            now.difference(_rankedAt!).inMinutes >= 5)) {
      recommendations = rankPathways(
        widget.store,
        grades,
        widget.store.preferences,
        targetCycle: targetCycle,
        resultBasis: widget.store.sessionResultBasis,
        sittings: widget.store.sessionSittings,
        hasAwaitingResults: widget.store.sessionAwaiting.isNotEmpty,
        now: now,
      );
      _rankedRules = widget.store.rules;
      _rankedPreferences = widget.store.preferences;
      _rankedAt = now;
    }
    final rules = recommendations
        .map((r) => r.rule)
        .where(
          (r) =>
              institution == 'All checked institutions' ||
              r.institution == institution,
        )
        .where(
          (r) => r.programme.toLowerCase().contains(
            programmeQuery.toLowerCase().trim(),
          ),
        )
        .toList();
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'YOUR RESULTS. YOUR POSSIBILITIES.',
                  style: TextStyle(
                    letterSpacing: 2,
                    color: gold,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'A clearer path forward.',
                  style: TextStyle(
                    fontFamily: 'AtlasSerif',
                    fontSize: 38,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Enter your WASSCE results to check the available source-backed academic rules. Each institution uses its own subject combination. This is planning guidance, not an admission decision.',
                ),
                const SizedBox(height: 22),
                GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AtlasDropdown<String>(
                        key: ValueKey('assess-institution-$institution'),
                        initialValue: institution,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Institution to assess',
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'All checked institutions',
                            child: Text('All checked institutions'),
                          ),
                          for (final i
                              in widget.store.rules
                                  .map((r) => r.institution)
                                  .toSet())
                            DropdownMenuItem(
                              value: i,
                              child: Text(
                                i,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) {
                          institution = v!;
                          changed();
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Only institutions with structured, source-checked rules appear here. Browse the full directory for other options.',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        key: const ValueKey('programme-search'),
                        controller: programmeSearch,
                        decoration: const InputDecoration(
                          labelText: 'Find a programme or route',
                          hintText: 'For example, Computer Science',
                        ),
                        onChanged: (value) {
                          programmeQuery = value;
                          changed();
                        },
                      ),
                      const SizedBox(height: 18),
                      AtlasDropdown<String>(
                        initialValue: targetCycle,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Admission year for cutoff comparison',
                        ),
                        hint: const Text('Choose a year (optional)'),
                        items: const [
                          DropdownMenuItem(
                            value: '2026/2027',
                            child: Text('2026/2027'),
                          ),
                          DropdownMenuItem(
                            value: '2027/2028',
                            child: Text('2027/2028'),
                          ),
                        ],
                        onChanged: (value) {
                          targetCycle = value;
                          changed();
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Academic requirements and competitive cutoffs are separate. An undated or ambiguous cutoff is never applied as a current admission threshold.',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 24),
                      PreferenceControls(
                        store: widget.store,
                        onChanged: changed,
                      ),
                      const SizedBox(height: 16),
                      AtlasDropdown<String>(
                        key: ValueKey(
                          'basis-${widget.store.sessionResultBasis}',
                        ),
                        initialValue: widget.store.sessionResultBasis,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Results basis',
                        ),
                        items: [
                          for (final value in [
                            'Final results',
                            'Predicted results',
                          ])
                            DropdownMenuItem(value: value, child: Text(value)),
                        ],
                        onChanged: (value) {
                          widget.store.sessionResultBasis = value!;
                          changed();
                        },
                      ),
                      const SizedBox(height: 12),
                      AtlasDropdown<int>(
                        initialValue: widget.store.sessionSittings,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Examination sittings',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 1,
                            child: Text('One sitting'),
                          ),
                          DropdownMenuItem(
                            value: 2,
                            child: Text('Two sittings · combined results'),
                          ),
                        ],
                        onChanged: (value) {
                          widget.store.sessionSittings = value!;
                          changed();
                        },
                      ),
                      if (widget.store.sessionSittings > 1)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Combined results are checked only where a current institution policy explicitly permits them. Otherwise the route remains unverified.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      if (widget.store.sessionResultBasis ==
                          'Predicted results')
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Every result below is provisional. Predicted grades do not establish confirmed eligibility or a cutoff match.',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      const SizedBox(height: 24),
                      const Text(
                        '01 / Core subjects',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (ctx, c) {
                          final width = c.maxWidth > 600
                              ? (c.maxWidth - 16) / 2
                              : c.maxWidth;
                          return Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              for (final s in coreSubjects)
                                SizedBox(width: width, child: gradeField(s)),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 26),
                      const Text(
                        '02 / Elective subjects',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Select three or four distinct electives. The matcher chooses the best allowed combination, including required subjects.',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      for (var index = 0; index < electives.length; index++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: LayoutBuilder(
                            builder: (ctx, c) => Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: c.maxWidth > 500
                                      ? c.maxWidth * .65
                                      : c.maxWidth,
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final available = electiveSubjects
                                          .where(
                                            (subject) =>
                                                !electives.contains(subject) ||
                                                electives[index] == subject,
                                          )
                                          .where(
                                            (subject) =>
                                                subject !=
                                                    'Ghanaian Language' ||
                                                !electives.any(
                                                  namedGhanaianLanguages
                                                      .contains,
                                                ),
                                          )
                                          .where(
                                            (subject) =>
                                                !namedGhanaianLanguages
                                                    .contains(subject) ||
                                                !electives.contains(
                                                  'Ghanaian Language',
                                                ),
                                          )
                                          .toList();
                                      final selected = await showDialog<String>(
                                        context: context,
                                        builder: (_) =>
                                            SubjectPicker(subjects: available),
                                      );
                                      if (selected == null || !mounted) return;
                                      final old = electives[index];
                                      if (old != null) {
                                        grades.remove(old);
                                        widget.store.sessionAwaiting.remove(
                                          old,
                                        );
                                        widget.store.sessionNotTaken.remove(
                                          old,
                                        );
                                      }
                                      electives[index] = selected;
                                      changed();
                                    },
                                    icon: const Icon(Icons.search, size: 18),
                                    label: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Text(
                                        'Elective ${index + 1}: ${electives[index] == null ? 'Choose subject' : subjectDisplayName(electives[index]!)}',
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: c.maxWidth > 500
                                      ? c.maxWidth * .35 - 12
                                      : c.maxWidth,
                                  child: electives[index] == null
                                      ? const SizedBox.shrink()
                                      : gradeField(electives[index]!),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      AtlasActionRow(
 children: [
FilledButton.icon(
                            onPressed: () {
                              FocusScope.of(context).unfocus();
                              setState(() {
                                _rankedRules = null;
                                assessed = true;
                              });
                            },
                            icon: const Icon(
                              Icons.auto_awesome_outlined,
                              size: 18,
                            ),
                            label: const Text('Check my pathways'),
                          ),
                          TextButton(
                            onPressed: () {
                              grades.clear();
                              widget.store.sessionAwaiting.clear();
                              widget.store.sessionNotTaken.clear();
                              electives = [null, null, null, null];
                              changed();
                            },
                            child: const Text('Clear results'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (!assessed)
                  const Text(
                    'Your results are private and are not sent to an admissions service. Editing grades clears previous suggestions.',
                    style: TextStyle(fontSize: 12),
                  )
                else ...[
                  Text(
                    widget.store.sessionResultBasis == 'Predicted results'
                        ? 'Your provisional programme checks'
                        : 'Your programme academic checks',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${rules.where((r) => r.data['scope'] != 'institution_general').length} programme routes · ${rules.where((r) => r.data['scope'] == 'institution_general').length} general entry checks. Coverage is still limited; a missing programme is not a rejection.',
                  ),
                  const SizedBox(height: 12),
                  GlassPanel(
                    padding: const EdgeInsets.all(18),
                    child: simulationPanel(),
                  ),
                  const SizedBox(height: 24),
                  for (final r
                      in rules
                          .where(
                            (r) => r.data['scope'] != 'institution_general',
                          )
                          .take(visibleResults))
                    assessmentCard(r),
                  if (rules
                          .where(
                            (r) => r.data['scope'] != 'institution_general',
                          )
                          .length >
                      visibleResults)
                    TextButton.icon(
                      onPressed: () => setState(() => visibleResults += 4),
                      icon: const Icon(Icons.expand_more),
                      label: const Text('Show more programme checks'),
                    ),
                  if (rules.any(
                    (r) => r.data['scope'] == 'institution_general',
                  ))
                    AtlasDisclosure(
                      title: const Text('General institutional entry checks'),
                      leading: const Icon(Icons.account_balance_outlined),
                      subtitle: const Text(
                        'These do not establish eligibility for a particular programme.',
                      ),
                      children: [
                        for (final r in rules.where(
                          (r) => r.data['scope'] == 'institution_general',
                        ))
                          assessmentCard(r),
                      ],
                    ),
                ],
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget gradeField(String subject) => AtlasDropdown<int>(
    key: ValueKey(
      'grade-$subject-${grades[subject] ?? (widget.store.sessionAwaiting.contains(subject)
              ? 0
              : widget.store.sessionNotTaken.contains(subject)
              ? -2
              : null)}',
    ),
    initialValue:
        grades[subject] ??
        (widget.store.sessionAwaiting.contains(subject)
            ? 0
            : widget.store.sessionNotTaken.contains(subject)
            ? -2
            : null),
    isExpanded: true,
    decoration: InputDecoration(labelText: subject),
    items: [
      const DropdownMenuItem(value: -1, child: Text('Not entered')),
      const DropdownMenuItem(value: 0, child: Text('Awaiting result')),
      const DropdownMenuItem(value: -2, child: Text('Not taken')),
      for (var i = 0; i < gradeNames.length; i++)
        DropdownMenuItem(value: i + 1, child: Text(gradeNames[i])),
    ],
    onChanged: (v) {
      widget.store.sessionAwaiting.remove(subject);
      widget.store.sessionNotTaken.remove(subject);
      if (v != null && v > 0) {
        grades[subject] = v;
      } else {
        grades.remove(subject);
        if (v == 0) widget.store.sessionAwaiting.add(subject);
        if (v == -2) widget.store.sessionNotTaken.add(subject);
      }
      changed();
    },
  );
  Widget simulationPanel() {
    final subjects = {
      ...grades.keys,
      ...widget.store.sessionAwaiting,
      ...widget.store.sessionNotTaken,
    }.toList()..sort();
    return AtlasDisclosure(
      tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      title: const Text('What if I improve a grade?'),
      leading: const Icon(Icons.insights_outlined),
      subtitle: const Text(
        'A separate hypothetical scenario; your entered results stay unchanged',
      ),
      children: [
        AtlasDropdown<String>(
          key: ValueKey('simulate-subject-$simulationSubject'),
          initialValue: subjects.contains(simulationSubject)
              ? simulationSubject
              : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Subject to simulate'),
          items: [
            for (final s in subjects)
              DropdownMenuItem(value: s, child: Text(s)),
          ],
          onChanged: (v) => setState(() {
            simulationSubject = v;
            simulationGrade = null;
            simulation = null;
          }),
        ),
        const SizedBox(height: 12),
        AtlasDropdown<int>(
          key: ValueKey('simulate-grade-$simulationSubject-$simulationGrade'),
          initialValue: simulationGrade,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Hypothetical grade'),
          items: [
            for (var grade = 1; grade <= 9; grade++)
              if (simulationSubject == null ||
                  grades[simulationSubject] == null ||
                  grade < grades[simulationSubject]!)
                DropdownMenuItem(
                  value: grade,
                  child: Text(gradeNames[grade - 1]),
                ),
          ],
          onChanged: (v) => setState(() {
            simulationGrade = v;
            simulation = null;
          }),
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: simulationSubject == null || simulationGrade == null
              ? null
              : () {
                  try {
                    setState(
                      () => simulation = simulateGrade(
                        widget.store,
                        grades,
                        widget.store.preferences,
                        simulationSubject!,
                        simulationGrade!,
                        targetCycle: targetCycle,
                        sittings: widget.store.sessionSittings,
                      ),
                    );
                  } catch (_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Choose a supported subject and a better grade.',
                        ),
                      ),
                    );
                  }
                },
          child: const Text('Try this grade'),
        ),
        const SizedBox(height: 10),
        const Text(
          'This changes a hypothetical grade only. It does not establish eligibility to resit, combine certificates, or receive an offer.',
          style: TextStyle(fontSize: 12),
        ),
        if (simulation != null) ...[
          Text(
            '${simulation!.subject}: ${simulation!.previous == null ? 'no result' : gradeNames[simulation!.previous! - 1]} → ${gradeNames[simulation!.proposed - 1]}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            '${simulation!.newlyMatched.length} additional programme routes meet the academic check in this hypothetical scenario. Your original results have not changed.',
          ),
          if (simulation!.newlyMatched.isEmpty)
            const Text(
              'No additional verified route opens with this one change. Other subjects, source review or sitting-policy confirmation may still be needed.',
            ),
          for (final r in simulation!.newlyMatched.take(6))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(r.rule.programme),
              subtitle: Text(
                '${r.rule.institution} · hypothetical aggregate ${r.assessment.aggregate}',
              ),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => openLink(r.rule.source),
            ),
        ],
      ],
    );
  }

  Widget assessmentCard(AdmissionRule rule) {
    final recommendation = recommendations.firstWhere(
      (r) => r.rule.id == rule.id,
    );
    final result = recommendation.assessment;
    return PathwayResultCard(
      recommendation: recommendation,
      confirmed:
          result.academicPass &&
          rule.data['scope'] != 'institution_general' &&
          widget.store.sessionResultBasis == 'Final results',
      awaiting: widget.store.sessionAwaiting.toList(),
      notTaken: widget.store.sessionNotTaken.toList(),
      nextSteps: !result.academicPass && rule.data['scope'] == 'programme'
          ? singleSubjectNextSteps(
              rule,
              grades,
              targetCycle: targetCycle,
              sittings: widget.store.sessionSittings,
            )
          : [],
      alternatives: alternativeProgrammes(rule, recommendations),
      openSource: openLink,
      openAlternative: (alternative) {
        programmeSearch.text = alternative.programme;
        programmeQuery = alternative.programme;
        institution = alternative.institution;
        setState(() => visibleResults = 4);
      },
      track: widget.store.ruleInstitutionId(rule) == null
          ? null
          : () async {
              try {
                final institutionId = widget.store.ruleInstitutionId(rule)!;
                final existing = widget.store.journey.applications
                    .where(
                      (a) =>
                          a.institutionId == institutionId &&
                          rule.matchesProgramme(a.programme),
                    )
                    .firstOrNull;
                await widget.store.journey.track(
                  institutionId,
                  existing?.programme ?? rule.programme,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Programme saved to My journey.'),
                    ),
                  );
                }
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Could not save your programme on this device.',
                      ),
                    ),
                  );
                }
              }
            },
    );
  }
}

class GradePlanner extends StatefulWidget {
  final TertiaryStore store;
  const GradePlanner({super.key, required this.store});
  @override
  State<GradePlanner> createState() => _CurriculumGradePlannerState();
}

class _CurriculumGradePlannerState extends State<GradePlanner> {
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Row(children: [
            for (final isNew in [true, false]) ...[
              if (!isNew) const SizedBox(width: 10),
              Expanded(child: Semantics(
                selected: widget.store.sessionNewCurriculum == isNew,
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.store.sessionNewCurriculum == isNew
                        ? ink : const Color(0xFFE5EBE7),
                    foregroundColor: widget.store.sessionNewCurriculum == isNew
                        ? Colors.white : ink,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  ),
                  onPressed: () => setState(() {
                    widget.store.sessionNewCurriculum = isNew;
                  }),
                  child: Text(isNew ? 'New curriculum' : 'Old curriculum',
                      textAlign: TextAlign.center),
                ),
              )),
            ],
          ]),
        ),
      ),
      Expanded(child: widget.store.sessionNewCurriculum
          ? NewCurriculumPlanner(store: widget.store)
          : LegacyGradePlanner(store: widget.store)),
    ],
  );
}
