import 'package:flutter/material.dart';

void main() {
  runApp(const SkoolAtlasApp());
}

class SkoolAtlasApp extends StatelessWidget {
  const SkoolAtlasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skool Atlas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        scaffoldBackgroundColor: const Color(0xFFF4F6F3),
      ),
      home: const MainShell(),
    );
  }
}

class AppColors {
  // Main navy colors
  static const primary = Color(0xFF1E3A8A);
  static const primaryDark = Color(0xFF162B66);
  static const primarySoft = Color(0xFFE8EDFA);

  // Extra accents
  static const accent = Color(0xFF3B82F6);
  static const success = Color(0xFF2563EB);
  static const danger = Color(0xFFDC2626);

  // Neutrals
  static const dark = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const chipBg = Color(0xFFEAF1FF);
  static const cardBg = Colors.white;
  static const lightBg = Color(0xFFF8FAFC);
}
class HoverLift extends StatefulWidget {
  final Widget child;
  final double translateY;
  final Duration duration;

  const HoverLift({
    super.key,
    required this.child,
    this.translateY = -6,
    this.duration = const Duration(milliseconds: 180),
  });

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          isHovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          isHovered = false;
        });
      },
      child: AnimatedContainer(
        duration: widget.duration,
        transform: Matrix4.identity()
          ..translate(0.0, isHovered ? widget.translateY : 0.0),
        child: widget.child,
      ),
    );
  }
}
class School {
  final String name;
  final String region;
  final String category;
  final String type;
  final int cutoff;
  final List<String> programs;

  const School({
    required this.name,
    required this.region,
    required this.category,
    required this.type,
    required this.cutoff,
    required this.programs,
  });
}

const List<School> schools = [
  School(
    name: "Prempeh College",
    region: "Ashanti Region",
    category: "Category A",
    type: "Boys • Boarding",
    cutoff: 7,
    programs: ["Science", "Business"],
  ),
  School(
    name: "St Louis SHS",
    region: "Ashanti Region",
    category: "Category A",
    type: "Girls • Boarding",
    cutoff: 8,
    programs: ["Science", "General Arts"],
  ),
  School(
    name: "Aburi Girls SHS",
    region: "Eastern Region",
    category: "Category A",
    type: "Girls • Boarding",
    cutoff: 8,
    programs: ["Science", "Business", "Home Economics"],
  ),
  School(
    name: "Achimota School",
    region: "Greater Accra Region",
    category: "Category A",
    type: "Mixed • Boarding/Day",
    cutoff: 6,
    programs: ["Science", "General Arts", "Business"],
  ),
  School(
    name: "Opoku Ware SHS",
    region: "Ashanti Region",
    category: "Category A",
    type: "Boys • Boarding",
    cutoff: 7,
    programs: ["Science", "Business"],
  ),
  School(
    name: "Tamale SHS",
    region: "Northern Region",
    category: "Category B",
    type: "Mixed • Day/Boarding",
    cutoff: 12,
    programs: ["General Arts", "Business"],
  ),
];

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int selectedPage = 0;
  final List<School> compareList = [];

  void addToCompare(School school) {
    if (compareList.contains(school)) return;
    if (compareList.length >= 3) return;
    setState(() {
      compareList.add(school);
      selectedPage = 2;
    });
  }

  void removeFromCompare(School school) {
    setState(() {
      compareList.remove(school);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        onExploreTap: () {
          setState(() => selectedPage = 1);
        },
      ),
      ExplorePage(
        onAddToCompare: addToCompare,
      ),
      ComparePage(
        compareList: compareList,
        onRemove: removeFromCompare,
        onAddMore: () {
          setState(() => selectedPage = 1);
        },
      ),
      const GuidesPage(),
      const ResourcesPage(),
      const PlacementCheckerPage(),
      const SignInPage(),
      const SignUpPage(),
    ];

    return Scaffold(
      body: Column(
        children: [
          PremiumNavBar(
            selectedIndex: selectedPage,
            onItemTap: (index) {
              setState(() => selectedPage = index);
            },
            onSignInTap: () {
              setState(() => selectedPage = 6);
            },
            onSignUpTap: () {
              setState(() => selectedPage = 7);
            },
          ),
          Expanded(child: pages[selectedPage]),
        ],
      ),
    );
  }
}
class PremiumNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTap;
  final VoidCallback onSignInTap;
  final VoidCallback onSignUpTap;

  const PremiumNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTap,
    required this.onSignInTap,
    required this.onSignUpTap,
  });
PopupMenuItem<int> _buildMenuItem({
  required int value,
  required IconData icon,
  required String text,
}) {
  return PopupMenuItem<int>(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryDark),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.dark,
          ),
        ),
      ],
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 1180;

    return Container(
      color: const Color(0xFFF4F6F3),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1320),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 28,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryDark, AppColors.primary],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "SKOOL ATLAS",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                          letterSpacing: 0.4,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Smart SHS Discovery Platform",
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 12),
              if (!isMobile) ...[
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PremiumNavItem(
                        title: "Home",
                        selected: selectedIndex == 0,
                        onTap: () => onItemTap(0),
                        icon: Icons.home_rounded,
                      ),
                      PremiumNavItem(
                        title: "Explore Schools",
                        selected: selectedIndex == 1,
                        onTap: () => onItemTap(1),
                        icon: Icons.travel_explore_rounded,
                      ),
                      PremiumNavItem(
                        title: "Compare",
                        selected: selectedIndex == 2,
                        onTap: () => onItemTap(2),
                        icon: Icons.compare_arrows_rounded,
                      ),
                      PremiumNavItem(
                        title: "Guides",
                        selected: selectedIndex == 3,
                        onTap: () => onItemTap(3),
                        icon: Icons.menu_book_rounded,
                      ),
                      PremiumNavItem(
                        title: "Resources",
                        selected: selectedIndex == 4,
                        onTap: () => onItemTap(4),
                        icon: Icons.folder_copy_rounded,
                      ),
                      PremiumNavItem(
                        title: "Placement Checker",
                        selected: selectedIndex == 5,
                        onTap: () => onItemTap(5),
                        icon: Icons.verified_user_rounded,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: onSignInTap,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: AppColors.primaryDark,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    "Sign In",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onSignUpTap,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    "Sign Up",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ] else
                const Spacer(),
              if (isMobile)
  PopupMenuButton<int>(
    tooltip: "Open menu",
    icon: const Icon(
      Icons.menu_rounded,
      size: 30,
      color: AppColors.dark,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    color: Colors.white,
    elevation: 12,
    onSelected: (value) {
      if (value == 6) {
        onSignInTap();
      } else if (value == 7) {
        onSignUpTap();
      } else {
        onItemTap(value);
      }
    },
    itemBuilder: (context) => [
      _buildMenuItem(
        value: 0,
        icon: Icons.home_rounded,
        text: "Home",
      ),
      _buildMenuItem(
        value: 1,
        icon: Icons.travel_explore_rounded,
        text: "Explore Schools",
      ),
      _buildMenuItem(
        value: 2,
        icon: Icons.compare_arrows_rounded,
        text: "Compare",
      ),
      _buildMenuItem(
        value: 3,
        icon: Icons.menu_book_rounded,
        text: "Guides",
      ),
      _buildMenuItem(
        value: 4,
        icon: Icons.folder_copy_rounded,
        text: "Resources",
      ),
      _buildMenuItem(
        value: 5,
        icon: Icons.verified_user_rounded,
        text: "Placement Checker",
      ),
      const PopupMenuDivider(),
      _buildMenuItem(
        value: 6,
        icon: Icons.login_rounded,
        text: "Sign In",
      ),
      _buildMenuItem(
        value: 7,
        icon: Icons.person_add_alt_1_rounded,
        text: "Sign Up",
      ),
    ],
  ),
            ],
          ),
        ),
      ),
    );
  }
}

class PremiumNavItem extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback? onTap;
  final IconData icon;

  const PremiumNavItem({
    super.key,
    required this.title,
    this.selected = false,
    this.onTap,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: selected
                ? Border.all(color: const Color(0xFFCDE2D2))
                : Border.all(color: Colors.transparent),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? AppColors.primary : AppColors.dark,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  color: selected ? AppColors.primary : AppColors.dark,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final VoidCallback onExploreTap;

  const HomePage({
    super.key,
    required this.onExploreTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 980;

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 18 : 22,
              vertical: 18,
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryDark, AppColors.primary],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x221F7A4C),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Text(
                    "2026 placement guidelines are now available. Explore schools, compare wisely, and check resources before final selection.",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                isMobile
                    ? Column(
                        children: [
                          HeroPremiumSection(onExploreTap: onExploreTap),
                          const SizedBox(height: 24),
                          const RecommendationPanel(),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 7,
                            child: HeroPremiumSection(onExploreTap: onExploreTap),
                          ),
                          const SizedBox(width: 24),
                          const Expanded(
                            flex: 4,
                            child: RecommendationPanel(),
                          ),
                        ],
                      ),
                const SizedBox(height: 30),
                const SectionTitle(
                  title: "Why Skool Atlas feels easier to use",
                  subtitle:
                      "Built with clear hierarchy, reliable information layout, and a calm premium interface for students and parents.",
                ),
                const SizedBox(height: 22),
                isMobile
                    ? const Column(
                        children: [
                          FeatureCard(
                            icon: Icons.account_tree_rounded,
                            title: "Structured school discovery",
                            text:
                                "Browse strong school options by region, type, category, and available programs with confidence.",
                          ),
                          SizedBox(height: 16),
                          FeatureCard(
                            icon: Icons.auto_graph_rounded,
                            title: "Side-by-side comparison",
                            text:
                                "Compare schools quickly using cut-off points, type, region, and available study programs.",
                          ),
                          SizedBox(height: 16),
                          FeatureCard(
                            icon: Icons.workspace_premium_rounded,
                            title: "Professional decision support",
                            text:
                                "The interface is designed to feel trustworthy, simple, and polished for academic use.",
                          ),
                        ],
                      )
                    : const Row(
                        children: [
                          Expanded(
                            child: FeatureCard(
                              icon: Icons.account_tree_rounded,
                              title: "Structured school discovery",
                              text:
                                  "Browse strong school options by region, type, category, and available programs with confidence.",
                            ),
                          ),
                          SizedBox(width: 18),
                          Expanded(
                            child: FeatureCard(
                              icon: Icons.auto_graph_rounded,
                              title: "Side-by-side comparison",
                              text:
                                  "Compare schools quickly using cut-off points, type, region, and available study programs.",
                            ),
                          ),
                          SizedBox(width: 18),
                          Expanded(
                            child: FeatureCard(
                              icon: Icons.workspace_premium_rounded,
                              title: "Professional decision support",
                              text:
                                  "The interface is designed to feel trustworthy, simple, and polished for academic use.",
                            ),
                          ),
                        ],
                      ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HeroPremiumSection extends StatelessWidget {
  final VoidCallback onExploreTap;

  const HeroPremiumSection({
    super.key,
    required this.onExploreTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isSmall = width < 760;

    return Container(
      padding: EdgeInsets.all(isSmall ? 24 : 34),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
  colors: [AppColors.primaryDark, AppColors.primary],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26162B66),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white24),
            ),
            child: const Text(
              "Trusted by students & parents",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            "Choose the right SHS with confidence and clarity.",
            style: TextStyle(
              fontSize: isSmall ? 34 : 52,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Explore senior high schools across Ghana, review programs, compare strong options, and make better school choices through a calm and premium interface.",
            style: TextStyle(
              fontSize: isSmall ? 16 : 19,
              height: 1.7,
              color: const Color(0xFFEAF6EE),
            ),
          ),
          const SizedBox(height: 28),
          isSmall
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: onExploreTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryDark,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 18,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "Start School Search",
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 18,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "How it works",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    ElevatedButton(
                      onPressed: onExploreTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryDark,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 18,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "Start School Search",
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 14),
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 18,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "How it works",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: const [
              HeroStatCard(value: "500+", label: "School Profiles"),
              HeroStatCard(value: "16", label: "Regions Covered"),
              HeroStatCard(value: "Fast", label: "Smart Comparison"),
            ],
          )
        ],
      ),
    );
  }
}
class HeroStatCard extends StatelessWidget {
  final String value;
  final String label;

  const HeroStatCard({
    super.key,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 155,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFEAF6EE),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class RecommendationPanel extends StatelessWidget {
  const RecommendationPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Top matches for your ward",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Suggested options based on school type, interest, and performance indicators.",
            style: TextStyle(
              color: AppColors.muted,
              height: 1.6,
            ),
          ),
          SizedBox(height: 18),
          SchoolTile(
            name: "Prempeh College",
            tags: ["Science", "Boys", "Boarding"],
            cutoff: "07",
          ),
          SizedBox(height: 14),
          SchoolTile(
            name: "Opoku Ware SHS",
            tags: ["Science", "Boys", "Boarding"],
            cutoff: "07",
          ),
          SizedBox(height: 14),
          SchoolTile(
            name: "St Louis SHS",
            tags: ["Science", "Girls", "Boarding"],
            cutoff: "08",
          ),
        ],
      ),
    );
  }
}

class SchoolTile extends StatelessWidget {
  final String name;
  final List<String> tags;
  final String cutoff;

  const SchoolTile({
    super.key,
    required this.name,
    required this.tags,
    required this.cutoff,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.lightBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: tags.map((tag) => TagChip(label: tag)).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7EE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                const Text(
                  "Cut-off",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  cutoff,
                  style: const TextStyle(
                    fontSize: 22,
                    color: AppColors.success,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class ExplorePage extends StatefulWidget {
  final Function(School) onAddToCompare;

  const ExplorePage({
    super.key,
    required this.onAddToCompare,
  });

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  String searchQuery = '';
  String selectedRegion = 'Any region';
  String selectedProgram = 'Any program';
  String selectedSchoolType = 'Any type';
  String selectedBoarding = 'Any';
  String selectedCategory = 'Any category';
  School? selectedSchool;

  List<School> get filteredSchools {
    return schools.where((school) {
      final query = searchQuery.toLowerCase().trim();

      final matchesSearch = query.isEmpty ||
          school.name.toLowerCase().contains(query) ||
          school.region.toLowerCase().contains(query) ||
          school.category.toLowerCase().contains(query) ||
          school.type.toLowerCase().contains(query) ||
          school.programs.any(
            (program) => program.toLowerCase().contains(query),
          );

      final matchesRegion =
          selectedRegion == 'Any region' || school.region == selectedRegion;

      final matchesProgram = selectedProgram == 'Any program' ||
          school.programs.contains(selectedProgram);

      final lowerType = school.type.toLowerCase();

      final matchesSchoolType = selectedSchoolType == 'Any type' ||
          (selectedSchoolType == 'Boys' && lowerType.contains('boys')) ||
          (selectedSchoolType == 'Girls' && lowerType.contains('girls')) ||
          (selectedSchoolType == 'Mixed' && lowerType.contains('mixed'));

      final matchesBoarding = selectedBoarding == 'Any' ||
          (selectedBoarding == 'Boarding' &&
              lowerType.contains('boarding') &&
              !lowerType.contains('day/boarding') &&
              !lowerType.contains('boarding/day')) ||
          (selectedBoarding == 'Day' &&
              lowerType.contains('day') &&
              !lowerType.contains('day/boarding') &&
              !lowerType.contains('boarding/day')) ||
          (selectedBoarding == 'Day/Boarding' &&
              (lowerType.contains('day/boarding') ||
                  lowerType.contains('boarding/day')));

      final matchesCategory =
          selectedCategory == 'Any category' || school.category == selectedCategory;

      return matchesSearch &&
          matchesRegion &&
          matchesProgram &&
          matchesSchoolType &&
          matchesBoarding &&
          matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (selectedSchool != null) {
      return SchoolDetailsPage(
        school: selectedSchool!,
        onBack: () {
          setState(() {
            selectedSchool = null;
          });
        },
        onAddToCompare: () {
          widget.onAddToCompare(selectedSchool!);
        },
      );
    }

    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 1050;

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 18 : 22,
              vertical: 22,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PremiumPageHeader(
                  title: "Explore Senior High Schools",
                  subtitle:
                      "Filter by region, program and school type to find strong school options for your ward.",
                ),
                const SizedBox(height: 24),
                isMobile
                    ? Column(
                        children: [
                          FilterPanel(
                            selectedRegion: selectedRegion,
                            selectedProgram: selectedProgram,
                            selectedSchoolType: selectedSchoolType,
                            selectedBoarding: selectedBoarding,
                            selectedCategory: selectedCategory,
                            onRegionChanged: (value) {
                              setState(() {
                                selectedRegion = value;
                              });
                            },
                            onProgramChanged: (value) {
                              setState(() {
                                selectedProgram = value;
                              });
                            },
                            onSchoolTypeChanged: (value) {
                              setState(() {
                                selectedSchoolType = value;
                              });
                            },
                            onBoardingChanged: (value) {
                              setState(() {
                                selectedBoarding = value;
                              });
                            },
                            onCategoryChanged: (value) {
                              setState(() {
                                selectedCategory = value;
                              });
                            },
                            onClearFilters: () {
                              setState(() {
                                searchQuery = '';
                                selectedRegion = 'Any region';
                                selectedProgram = 'Any program';
                                selectedSchoolType = 'Any type';
                                selectedBoarding = 'Any';
                                selectedCategory = 'Any category';
                              });
                            },
                          ),
                          const SizedBox(height: 22),
                          SearchAndGrid(
                            schoolsToShow: filteredSchools,
                            searchQuery: searchQuery,
                            onSearchChanged: (value) {
                              setState(() {
                                searchQuery = value;
                              });
                            },
                            onViewDetails: (school) {
                              setState(() {
                                selectedSchool = school;
                              });
                            },
                            onAddToCompare: widget.onAddToCompare,
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 320,
                            child: FilterPanel(
                              selectedRegion: selectedRegion,
                              selectedProgram: selectedProgram,
                              selectedSchoolType: selectedSchoolType,
                              selectedBoarding: selectedBoarding,
                              selectedCategory: selectedCategory,
                              onRegionChanged: (value) {
                                setState(() {
                                  selectedRegion = value;
                                });
                              },
                              onProgramChanged: (value) {
                                setState(() {
                                  selectedProgram = value;
                                });
                              },
                              onSchoolTypeChanged: (value) {
                                setState(() {
                                  selectedSchoolType = value;
                                });
                              },
                              onBoardingChanged: (value) {
                                setState(() {
                                  selectedBoarding = value;
                                });
                              },
                              onCategoryChanged: (value) {
                                setState(() {
                                  selectedCategory = value;
                                });
                              },
                              onClearFilters: () {
                                setState(() {
                                  searchQuery = '';
                                  selectedRegion = 'Any region';
                                  selectedProgram = 'Any program';
                                  selectedSchoolType = 'Any type';
                                  selectedBoarding = 'Any';
                                  selectedCategory = 'Any category';
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 22),
                          Expanded(
                            child: SearchAndGrid(
                              schoolsToShow: filteredSchools,
                              searchQuery: searchQuery,
                              onSearchChanged: (value) {
                                setState(() {
                                  searchQuery = value;
                                });
                              },
                              onViewDetails: (school) {
                                setState(() {
                                  selectedSchool = school;
                                });
                              },
                              onAddToCompare: widget.onAddToCompare,
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PremiumPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const PremiumPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isSmall = width < 760;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmall ? 22 : 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFCFFFD), Color(0xFFF1F6F2)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: isSmall ? 30 : 38,
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: isSmall ? 15 : 17,
              color: AppColors.muted,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}
class FilterPanel extends StatelessWidget {
  final String selectedRegion;
  final String selectedProgram;
  final String selectedSchoolType;
  final String selectedBoarding;
  final String selectedCategory;

  final ValueChanged<String> onRegionChanged;
  final ValueChanged<String> onProgramChanged;
  final ValueChanged<String> onSchoolTypeChanged;
  final ValueChanged<String> onBoardingChanged;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onClearFilters;

  const FilterPanel({
    super.key,
    required this.selectedRegion,
    required this.selectedProgram,
    required this.selectedSchoolType,
    required this.selectedBoarding,
    required this.selectedCategory,
    required this.onRegionChanged,
    required this.onProgramChanged,
    required this.onSchoolTypeChanged,
    required this.onBoardingChanged,
    required this.onCategoryChanged,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Filter schools",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 20),
          const FilterLabel("Region"),
          FilterDropdown(
            items: const [
              "Any region",
              "Ashanti Region",
              "Eastern Region",
              "Greater Accra Region",
              "Northern Region"
            ],
            value: selectedRegion,
            onChanged: onRegionChanged,
          ),
          const SizedBox(height: 16),
          const FilterLabel("Program"),
          FilterDropdown(
            items: const [
              "Any program",
              "Science",
              "Business",
              "General Arts",
              "Home Economics"
            ],
            value: selectedProgram,
            onChanged: onProgramChanged,
          ),
          const SizedBox(height: 16),
          const FilterLabel("School type"),
          FilterDropdown(
            items: const [
              "Any type",
              "Boys",
              "Girls",
              "Mixed"
            ],
            value: selectedSchoolType,
            onChanged: onSchoolTypeChanged,
          ),
          const SizedBox(height: 16),
          const FilterLabel("Boarding / Day"),
          FilterDropdown(
            items: const [
              "Any",
              "Boarding",
              "Day",
              "Day/Boarding"
            ],
            value: selectedBoarding,
            onChanged: onBoardingChanged,
          ),
          const SizedBox(height: 16),
          const FilterLabel("Category"),
          FilterDropdown(
            items: const [
              "Any category",
              "Category A",
              "Category B",
              "Category C"
            ],
            value: selectedCategory,
            onChanged: onCategoryChanged,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                "Filters Applied Live",
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onClearFilters,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                "Clear Filters",
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FilterLabel extends StatelessWidget {
  final String text;

  const FilterLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: AppColors.dark,
      ),
    );
  }
}

class FilterDropdown extends StatelessWidget {
  final List<String> items;
  final String value;
  final ValueChanged<String> onChanged;

  const FilterDropdown({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.lightBg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        items: items
            .map(
              (item) => DropdownMenuItem<String>(
                value: item,
                child: Text(item),
              ),
            )
            .toList(),
        onChanged: (newValue) {
          if (newValue != null) {
            onChanged(newValue);
          }
        },
      ),
    );
  }
}

class SearchAndGrid extends StatelessWidget {
  final Function(School) onAddToCompare;
  final Function(School) onViewDetails;
  final List<School> schoolsToShow;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;

  const SearchAndGrid({
    super.key,
    required this.onAddToCompare,
    required this.onViewDetails,
    required this.schoolsToShow,
    required this.searchQuery,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    int columns = 2;
    if (width < 760) columns = 1;
    if (width > 1450) columns = 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            hintText: "Search by school name, region, type or program...",
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: searchQuery.isNotEmpty
                ? IconButton(
                    onPressed: () => onSearchChanged(''),
                    icon: const Icon(Icons.close_rounded),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.4),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          "Showing ${schoolsToShow.length} school${schoolsToShow.length == 1 ? '' : 's'}",
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.dark,
          ),
        ),
        const SizedBox(height: 18),
        if (schoolsToShow.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "No schools found",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  "Try another search term such as a school name, region, type, category, or program.",
                  style: TextStyle(
                    color: AppColors.muted,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          )
        else
          GridView.builder(
            itemCount: schoolsToShow.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 18,
              mainAxisSpacing: 18,
              childAspectRatio: 1.12,
            ),
            itemBuilder: (context, index) {
              final school = schoolsToShow[index];
              return ExploreSchoolCard(
                school: school,
                onViewDetails: () => onViewDetails(school),
                onAddToCompare: () => onAddToCompare(school),
              );
            },
          ),
      ],
    );
  }
}
class ExploreSchoolCard extends StatelessWidget {
  final School school;
  final VoidCallback onAddToCompare;
  final VoidCallback onViewDetails;

  const ExploreSchoolCard({
    super.key,
    required this.school,
    required this.onAddToCompare,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      translateY: -8,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    school.name,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: AppColors.dark,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    school.category,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              school.region,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: school.programs
                  .map((program) => TagChip(label: program))
                  .toList(),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: InfoBlock(
                    title: "Type",
                    value: school.type,
                  ),
                ),
                const SizedBox(width: 12),
                InfoBlock(
                  title: "Cut-off",
                  value: school.cutoff.toString(),
                  valueColor: AppColors.success,
                ),
              ],
            ),
            const Spacer(),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onViewDetails,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryDark,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      "View Details",
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAddToCompare,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      "Add to Compare",
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
class SchoolDetailsPage extends StatelessWidget {
  final School school;
  final VoidCallback onBack;
  final VoidCallback onAddToCompare;

  const SchoolDetailsPage({
    super.key,
    required this.school,
    required this.onBack,
    required this.onAddToCompare,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 980;

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 18 : 22,
              vertical: 22,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text("Back to Explore"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SchoolDetailsHero(
                  school: school,
                  onAddToCompare: onAddToCompare,
                ),
                const SizedBox(height: 24),
                isMobile
                    ? Column(
                        children: [
                          SchoolDetailsOverviewCard(school: school),
                          const SizedBox(height: 18),
                          SchoolProgramsCard(school: school),
                          const SizedBox(height: 18),
                          const SchoolHighlightsCard(),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                SchoolDetailsOverviewCard(school: school),
                                const SizedBox(height: 18),
                                SchoolProgramsCard(school: school),
                              ],
                            ),
                          ),
                          const SizedBox(width: 18),
                          const Expanded(
                            flex: 4,
                            child: SchoolHighlightsCard(),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SchoolDetailsHero extends StatelessWidget {
  final School school;
  final VoidCallback onAddToCompare;

  const SchoolDetailsHero({
    super.key,
    required this.school,
    required this.onAddToCompare,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isSmall = width < 760;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmall ? 22 : 30),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26162B66),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroBadge(label: school.category),
              _HeroBadge(label: school.region),
              _HeroBadge(label: school.type),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            school.name,
            style: TextStyle(
              fontSize: isSmall ? 30 : 42,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            "Review this school’s academic direction, entry profile, and placement suitability through a clean premium details view.",
            style: TextStyle(
              fontSize: 17,
              height: 1.7,
              color: Color(0xFFEAF6EE),
            ),
          ),
          const SizedBox(height: 22),
          isSmall
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Cut-off",
                            style: TextStyle(
                              color: Color(0xFFEAF6EE),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            school.cutoff.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: onAddToCompare,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryDark,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 18,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "Add to Compare",
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Cut-off",
                            style: TextStyle(
                              color: Color(0xFFEAF6EE),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            school.cutoff.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    ElevatedButton(
                      onPressed: onAddToCompare,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryDark,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 18,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "Add to Compare",
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  final String label;

  const _HeroBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class SchoolDetailsOverviewCard extends StatelessWidget {
  final School school;

  const SchoolDetailsOverviewCard({
    super.key,
    required this.school,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "School overview",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 18),
          CompareRow(title: "School Name", value: school.name),
          CompareRow(title: "Region", value: school.region),
          CompareRow(title: "Category", value: school.category),
          CompareRow(title: "Type", value: school.type),
          CompareRow(
            title: "Cut-off Point",
            value: school.cutoff.toString(),
            valueColor: AppColors.success,
          ),
        ],
      ),
    );
  }
}

class SchoolProgramsCard extends StatelessWidget {
  final School school;

  const SchoolProgramsCard({
    super.key,
    required this.school,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Available programs",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "These are the program pathways currently listed for this school in your capstone dataset.",
            style: TextStyle(
              color: AppColors.muted,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: school.programs
                .map((program) => TagChip(label: program))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class SchoolHighlightsCard extends StatelessWidget {
  const SchoolHighlightsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Decision highlights",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
            ),
          ),
          SizedBox(height: 18),
          GuideStepTile(
            step: "01",
            title: "Review academic fit",
            text:
                "Check whether the listed programs match the student’s interests and long-term academic direction.",
          ),
          SizedBox(height: 14),
          GuideStepTile(
            step: "02",
            title: "Compare entry competitiveness",
            text:
                "Use the cut-off value as a guide when comparing this school against other schools in your shortlist.",
          ),
          SizedBox(height: 14),
          GuideStepTile(
            step: "03",
            title: "Consider logistics carefully",
            text:
                "School type, location, and boarding arrangement should all be reviewed before final choice submission.",
          ),
        ],
      ),
    );
  }
}
class ComparePage extends StatelessWidget {
  final List<School> compareList;
  final Function(School) onRemove;
  final VoidCallback onAddMore;

  const ComparePage({
    super.key,
    required this.compareList,
    required this.onRemove,
    required this.onAddMore,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 1000;

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 18 : 22,
              vertical: 22,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PremiumPageHeader(
                  title: "Compare Schools",
                  subtitle:
                      "Review selected schools side by side and make a better final decision for your ward.",
                ),
                const SizedBox(height: 22),
                width < 700
    ? Column(
        children: [
          StatBox(
            title: "Schools Selected",
            value: compareList.length.toString(),
          ),
          const SizedBox(height: 14),
          const StatBox(
            title: "Max Allowed",
            value: "3",
          ),
        ],
      )
    : Row(
        children: [
          StatBox(
            title: "Schools Selected",
            value: compareList.length.toString(),
          ),
          const SizedBox(width: 14),
          const StatBox(
            title: "Max Allowed",
            value: "3",
          ),
        ],
      ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: onAddMore,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text("Add More Schools"),
                ),
                const SizedBox(height: 22),
                if (compareList.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 16,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Text(
                      "No schools added yet. Go to Explore Schools and click 'Add to Compare'.",
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.muted,
                      ),
                    ),
                  )
                else
                  isMobile
                      ? Column(
                          children: compareList
                              .map(
                                (school) => Padding(
                                  padding: const EdgeInsets.only(bottom: 18),
                                  child: CompareCard(
                                    school: school,
                                    onRemove: () => onRemove(school),
                                  ),
                                ),
                              )
                              .toList(),
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: compareList
                              .map(
                                (school) => Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 16),
                                    child: CompareCard(
                                      school: school,
                                      onRemove: () => onRemove(school),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GuidesPage extends StatelessWidget {
  const GuidesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 1050;

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 18 : 22,
              vertical: 22,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PremiumPageHeader(
                  title: "Student & Parent Guides",
                  subtitle:
                      "Understand school selection, placement steps, and better decision-making through clear premium guidance cards.",
                ),
                const SizedBox(height: 24),
                isMobile
                    ? const Column(
                        children: [
                          GuideInfoCard(
                            icon: Icons.route_rounded,
                            title: "How to choose the right school",
                            text:
                                "Start with program interest, location, boarding preference, and recent academic performance before making a final choice.",
                          ),
                          SizedBox(height: 18),
                          GuideInfoCard(
                            icon: Icons.checklist_rounded,
                            title: "Simple selection checklist",
                            text:
                                "Compare cut-off points, school type, category, and available programs so your choices stay realistic and balanced.",
                          ),
                          SizedBox(height: 18),
                          GuideInfoCard(
                            icon: Icons.family_restroom_rounded,
                            title: "Parent decision support",
                            text:
                                "Parents can use Skool Atlas to narrow options, review trade-offs, and guide wards toward stronger school fits.",
                          ),
                        ],
                      )
                    : const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: GuideInfoCard(
                              icon: Icons.route_rounded,
                              title: "How to choose the right school",
                              text:
                                  "Start with program interest, location, boarding preference, and recent academic performance before making a final choice.",
                            ),
                          ),
                          SizedBox(width: 18),
                          Expanded(
                            child: GuideInfoCard(
                              icon: Icons.checklist_rounded,
                              title: "Simple selection checklist",
                              text:
                                  "Compare cut-off points, school type, category, and available programs so your choices stay realistic and balanced.",
                            ),
                          ),
                          SizedBox(width: 18),
                          Expanded(
                            child: GuideInfoCard(
                              icon: Icons.family_restroom_rounded,
                              title: "Parent decision support",
                              text:
                                  "Parents can use Skool Atlas to narrow options, review trade-offs, and guide wards toward stronger school fits.",
                            ),
                          ),
                        ],
                      ),
                const SizedBox(height: 26),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: AppColors.border),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Step-by-step school selection guide",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.dark,
                        ),
                      ),
                      SizedBox(height: 18),
                      GuideStepTile(
                        step: "01",
                        title: "Know the preferred program",
                        text:
                            "Decide whether the student prefers Science, Business, General Arts, Home Economics, or another available pathway.",
                      ),
                      SizedBox(height: 14),
                      GuideStepTile(
                        step: "02",
                        title: "Check realistic cut-off ranges",
                        text:
                            "Use school comparisons to see whether the selected options fit the student’s academic performance range.",
                      ),
                      SizedBox(height: 14),
                      GuideStepTile(
                        step: "03",
                        title: "Balance ambition and safety",
                        text:
                            "Choose some highly competitive schools, some moderate options, and safer alternatives for a better final list.",
                      ),
                      SizedBox(height: 14),
                      GuideStepTile(
                        step: "04",
                        title: "Review boarding, distance, and support",
                        text:
                            "Consider location, transport, student comfort, and family support before submitting a final selection.",
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ResourcesPage extends StatelessWidget {
  const ResourcesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 1050;

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 18 : 22,
              vertical: 22,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PremiumPageHeader(
                  title: "Resources",
                  subtitle:
                      "Access useful materials, downloadable support content, and helpful references for school selection and placement understanding.",
                ),
                const SizedBox(height: 24),
                GridView.count(
                  crossAxisCount: isMobile ? 1 : 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 18,
                  mainAxisSpacing: 18,
                  childAspectRatio: isMobile ? 1.6 : 1.18,
                  children: const [
                    ResourceCard(
                      icon: Icons.picture_as_pdf_rounded,
                      title: "Placement Guide PDF",
                      text:
                          "A clean summary of placement stages, school decision steps, and what students should review before submission.",
                      buttonText: "Open Guide",
                    ),
                    ResourceCard(
                      icon: Icons.school_outlined,
                      title: "School Programs Directory",
                      text:
                          "A quick academic overview showing examples of Science, Business, Arts, and Home Economics pathways.",
                      buttonText: "Browse Directory",
                    ),
                    ResourceCard(
                      icon: Icons.fact_check_rounded,
                      title: "Choice Preparation Checklist",
                      text:
                          "A simple checklist for students and parents to review before finalizing school selections.",
                      buttonText: "Use Checklist",
                    ),
                    ResourceCard(
                      icon: Icons.quiz_rounded,
                      title: "Frequently Asked Questions",
                      text:
                          "Answers to common student and parent questions about SHS selection, comparison, and placement support.",
                      buttonText: "Read FAQs",
                    ),
                    ResourceCard(
                      icon: Icons.download_rounded,
                      title: "Downloadable Templates",
                      text:
                          "Printable sheets that help families compare school options and track program preferences clearly.",
                      buttonText: "Download",
                    ),
                    ResourceCard(
                      icon: Icons.tips_and_updates_rounded,
                      title: "Application Tips",
                      text:
                          "Practical guidance on narrowing school choices and improving the quality of a final school list.",
                      buttonText: "View Tips",
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PlacementCheckerPage extends StatefulWidget {
  const PlacementCheckerPage({super.key});

  @override
  State<PlacementCheckerPage> createState() => _PlacementCheckerPageState();
}

class _PlacementCheckerPageState extends State<PlacementCheckerPage> {
  final TextEditingController indexController = TextEditingController();
  final TextEditingController pinController = TextEditingController();
  bool showResult = false;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 980;

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 18 : 22,
              vertical: 22,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PremiumPageHeader(
                  title: "Placement Checker",
                  subtitle:
                      "Check and preview a sample placement result through a premium form interface designed for clarity and ease.",
                ),
                const SizedBox(height: 24),
                isMobile
                    ? Column(
                        children: [
                          PlacementFormCard(
                            indexController: indexController,
                            pinController: pinController,
                            onCheck: () {
                              setState(() {
                                showResult = true;
                              });
                            },
                          ),
                          const SizedBox(height: 22),
                          if (showResult) const PlacementResultCard(),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: PlacementFormCard(
                              indexController: indexController,
                              pinController: pinController,
                              onCheck: () {
                                setState(() {
                                  showResult = true;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 22),
                          Expanded(
                            flex: 4,
                            child: showResult
                                ? const PlacementResultCard()
                                : const PlacementEmptyCard(),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PlacementFormCard extends StatelessWidget {
  final TextEditingController indexController;
  final TextEditingController pinController;
  final VoidCallback onCheck;

  const PlacementFormCard({
    super.key,
    required this.indexController,
    required this.pinController,
    required this.onCheck,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Enter student details",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "This is a sample UI for your capstone. Later, you can connect it to real backend data.",
            style: TextStyle(
              color: AppColors.muted,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 22),
          const InputLabel("Index Number"),
          const SizedBox(height: 8),
          PremiumTextField(
            controller: indexController,
            hintText: "Enter index number",
            icon: Icons.badge_rounded,
          ),
          const SizedBox(height: 18),
          const InputLabel("Checker PIN"),
          const SizedBox(height: 8),
          PremiumTextField(
            controller: pinController,
            hintText: "Enter checker PIN",
            icon: Icons.lock_rounded,
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onCheck,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                "Check Placement",
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PlacementResultCard extends StatelessWidget {
  const PlacementResultCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primarySoft,
                child: Icon(
                  Icons.verified_rounded,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  "Placement Result",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 22),
          CompareRow(title: "Student Name", value: "Ama Mensah"),
          CompareRow(title: "Placed School", value: "Achimota School"),
          CompareRow(title: "Program", value: "General Arts"),
          CompareRow(title: "Status", value: "Qualified", valueColor: AppColors.success),
          SizedBox(height: 12),
          Text(
            "This is a sample result card for your project interface. Later, you can connect it to dynamic placement data.",
            style: TextStyle(
              color: AppColors.muted,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

class PlacementEmptyCard extends StatelessWidget {
  const PlacementEmptyCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.dashboard_customize_rounded,
            size: 38,
            color: AppColors.primary,
          ),
          SizedBox(height: 16),
          Text(
            "Result preview panel",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
            ),
          ),
          SizedBox(height: 10),
          Text(
            "Enter student details and click “Check Placement” to display a sample premium result panel here.",
            style: TextStyle(
              color: AppColors.muted,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

class GuideInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const GuideInfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primarySoft,
              child: Icon(icon, color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                height: 1.7,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class GuideStepTile extends StatelessWidget {
  final String step;
  final String title;
  final String text;

  const GuideStepTile({
    super.key,
    required this.step,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.lightBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryDark, AppColors.primary],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                step,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  text,
                  style: const TextStyle(
                    color: AppColors.muted,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ResourceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final String buttonText;

  const ResourceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
    required this.buttonText,
  });

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primarySoft,
              child: Icon(icon, color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: AppColors.muted,
                  height: 1.7,
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  buttonText,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InputLabel extends StatelessWidget {
  final String text;

  const InputLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: AppColors.dark,
      ),
    );
  }
}

class PremiumTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;

  const PremiumTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: AppColors.lightBg,
        prefixIcon: Icon(icon),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
    );
  }
}

class StatBox extends StatelessWidget {
  final String title;
  final String value;

  const StatBox({
    super.key,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 110, maxWidth: 180),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class CompareCard extends StatelessWidget {
  final School school;
  final VoidCallback onRemove;

  const CompareCard({
    super.key,
    required this.school,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  school.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                  ),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.danger,
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          CompareRow(title: "Region", value: school.region),
          CompareRow(title: "Category", value: school.category),
          CompareRow(title: "Type", value: school.type),
          CompareRow(
            title: "Cut-off",
            value: school.cutoff.toString(),
            valueColor: AppColors.success,
          ),
          const SizedBox(height: 12),
          const Text(
            "Programs",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                school.programs.map((program) => TagChip(label: program)).toList(),
          ),
        ],
      ),
    );
  }
}

class CompareRow extends StatelessWidget {
  final String title;
  final String value;
  final Color? valueColor;

  const CompareRow({
    super.key,
    required this.title,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.lightBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: valueColor ?? AppColors.dark,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InfoBlock extends StatelessWidget {
  final String title;
  final String value;
  final Color? valueColor;

  const InfoBlock({
    super.key,
    required this.title,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.lightBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.dark,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }
}

class TagChip extends StatelessWidget {
  final String label;

  const TagChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.chipBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const SectionTitle({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: AppColors.dark,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 17,
            color: AppColors.muted,
            height: 1.7,
          ),
        ),
      ],
    );
  }
}

class FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.primarySoft,
              child: Icon(icon, color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                height: 1.7,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 1100;

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 18 : 22,
              vertical: 22,
            ),
            child: isMobile
                ? const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PremiumPageHeader(
                        title: "Sign In",
                        subtitle:
                            "Welcome back to Skool Atlas. Access your school choices, comparison list, and guidance tools through a clean premium sign-in experience.",
                      ),
                      SizedBox(height: 24),
                      AuthFormCard(
                        title: "Sign in to your account",
                        subtitle:
                            "Enter your email and password to continue using your saved school tools.",
                        buttonText: "Sign In",
                        isSignUp: false,
                      ),
                      SizedBox(height: 22),
                      AuthSideInfoCard(
                        title: "Why sign in?",
                        points: [
                          "Save school comparisons",
                          "Track preferred schools",
                          "Access placement tools faster",
                          "Enjoy a more personalized dashboard",
                        ],
                      ),
                    ],
                  )
                : const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PremiumPageHeader(
                        title: "Sign In",
                        subtitle:
                            "Welcome back to Skool Atlas. Access your school choices, comparison list, and guidance tools through a clean premium sign-in experience.",
                      ),
                      SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: AuthFormCard(
                              title: "Sign in to your account",
                              subtitle:
                                  "Enter your email and password to continue using your saved school tools.",
                              buttonText: "Sign In",
                              isSignUp: false,
                            ),
                          ),
                          SizedBox(width: 22),
                          Expanded(
                            flex: 4,
                            child: AuthSideInfoCard(
                              title: "Why sign in?",
                              points: [
                                "Save school comparisons",
                                "Track preferred schools",
                                "Access placement tools faster",
                                "Enjoy a more personalized dashboard",
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 1100;

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 18 : 22,
              vertical: 22,
            ),
            child: isMobile
                ? const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PremiumPageHeader(
                        title: "Sign Up",
                        subtitle:
                            "Create your Skool Atlas account and begin tracking schools, saving comparisons, and using student support tools in one place.",
                      ),
                      SizedBox(height: 24),
                      AuthFormCard(
                        title: "Create your account",
                        subtitle:
                            "Fill in your details to get started with a premium and student-friendly school discovery experience.",
                        buttonText: "Create Account",
                        isSignUp: true,
                      ),
                      SizedBox(height: 22),
                      AuthSideInfoCard(
                        title: "What you get",
                        points: [
                          "Personal school shortlist",
                          "Saved comparison history",
                          "Guides and resources access",
                          "Future-ready student dashboard",
                        ],
                      ),
                    ],
                  )
                : const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PremiumPageHeader(
                        title: "Sign Up",
                        subtitle:
                            "Create your Skool Atlas account and begin tracking schools, saving comparisons, and using student support tools in one place.",
                      ),
                      SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: AuthFormCard(
                              title: "Create your account",
                              subtitle:
                                  "Fill in your details to get started with a premium and student-friendly school discovery experience.",
                              buttonText: "Create Account",
                              isSignUp: true,
                            ),
                          ),
                          SizedBox(width: 22),
                          Expanded(
                            flex: 4,
                            child: AuthSideInfoCard(
                              title: "What you get",
                              points: [
                                "Personal school shortlist",
                                "Saved comparison history",
                                "Guides and resources access",
                                "Future-ready student dashboard",
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class AuthFormCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String buttonText;
  final bool isSignUp;

  const AuthFormCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.isSignUp,
  });

  @override
  State<AuthFormCard> createState() => _AuthFormCardState();
}

class _AuthFormCardState extends State<AuthFormCard> {
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.subtitle,
            style: const TextStyle(
              color: AppColors.muted,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 24),
          if (widget.isSignUp) ...[
            const InputLabel("Full Name"),
            const SizedBox(height: 8),
            PremiumTextField(
              controller: fullNameController,
              hintText: "Enter your full name",
              icon: Icons.person_rounded,
            ),
            const SizedBox(height: 18),
          ],
          const InputLabel("Email Address"),
          const SizedBox(height: 8),
          PremiumTextField(
            controller: emailController,
            hintText: "Enter your email address",
            icon: Icons.email_rounded,
          ),
          const SizedBox(height: 18),
          const InputLabel("Password"),
          const SizedBox(height: 8),
          PremiumPasswordField(
            controller: passwordController,
            hintText: "Enter your password",
            obscureText: obscurePassword,
            onToggle: () {
              setState(() {
                obscurePassword = !obscurePassword;
              });
            },
          ),
          if (widget.isSignUp) ...[
            const SizedBox(height: 18),
            const InputLabel("Confirm Password"),
            const SizedBox(height: 8),
            PremiumPasswordField(
              controller: confirmPasswordController,
              hintText: "Confirm your password",
              obscureText: obscureConfirmPassword,
              onToggle: () {
                setState(() {
                  obscureConfirmPassword = !obscureConfirmPassword;
                });
              },
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                widget.buttonText,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.lightBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              widget.isSignUp
                  ? "This is a front-end signup UI for your capstone. We can connect it to real authentication later."
                  : "This is a front-end signin UI for your capstone. We can connect it to real authentication later.",
              style: const TextStyle(
                color: AppColors.muted,
                height: 1.7,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthSideInfoCard extends StatelessWidget {
  final String title;
  final List<String> points;

  const AuthSideInfoCard({
    super.key,
    required this.title,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x221F7A4C),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            "Skool Atlas is designed to make school discovery, comparison, and placement support feel modern, clear, and trusted.",
            style: TextStyle(
              color: Color(0xFFEAF6EE),
              height: 1.7,
            ),
          ),
          const SizedBox(height: 24),
          ...points.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      point,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PremiumPasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final VoidCallback onToggle;

  const PremiumPasswordField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.obscureText,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: AppColors.lightBg,
        prefixIcon: const Icon(Icons.lock_rounded),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
    );
  }
}