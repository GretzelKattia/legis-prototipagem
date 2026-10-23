import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/legis_logo.dart';
import '../../state/user_controller.dart';
import '../../services/legis_api.dart';
import '../favorites/favorites_screen.dart';
import '../home/home_screen.dart';
import '../notifications/notifications_screen.dart';
import '../onboarding/tutorial_screen.dart';
import '../preferences/preferences_screen.dart';
import '../profile/profile_screen.dart';
import '../search/search_screen.dart';
import '../welcome/welcome_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _destinations = <_Destination>[
    _Destination('Home', Icons.home_outlined, Icons.home_rounded),
    _Destination('Explorar', Icons.search_rounded, Icons.search_rounded),
    _Destination('Favoritos', Icons.bookmark_border_rounded, Icons.bookmark_rounded),
    _Destination('Notificações', Icons.notifications_none_rounded, Icons.notifications_rounded),
    _Destination('Perfil', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  void _openTutorial() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TutorialScreen(onFinished: () => Navigator.of(context).pop()),
      ),
    );
  }

  Future<void> _exitToWelcome() async {
    try { await context.read<LegisApi>().logout(); } catch (_) { /* ainda limpa o token local */ }
    await context.read<UserController>().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  Future<void> _openPreferences() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PreferencesScreen()),
      );

  List<Widget> _pages() => <Widget>[
        const HomeScreen(),
        const SearchScreen(),
        const FavoritesScreen(),
        const NotificationsScreen(),
        ProfileScreen(
          onOpenFavorites: () => setState(() => _index = 2),
          onShowTutorial: _openTutorial,
          onExit: _exitToWelcome,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final c = context.palette;
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        final content = IndexedStack(index: _index, children: _pages());
        return Scaffold(
          backgroundColor: c.background,
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (desktop) _desktopSidebar(context),
              Expanded(
                child: ColoredBox(
                  color: c.background,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: desktop ? 1180 : double.infinity),
                      child: content,
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: desktop
              ? null
              : NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: (index) => setState(() => _index = index),
                  height: 70,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  destinations: const [
                    NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
                    NavigationDestination(icon: Icon(Icons.search_rounded), selectedIcon: Icon(Icons.search_rounded), label: 'Explorar'),
                    NavigationDestination(icon: Icon(Icons.bookmark_border_rounded), selectedIcon: Icon(Icons.bookmark_rounded), label: 'Favoritos'),
                    NavigationDestination(icon: Icon(Icons.notifications_none_rounded), selectedIcon: Icon(Icons.notifications_rounded), label: 'Notif.'),
                    NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Perfil'),
                  ],
                ),
        );
      },
    );
  }

  /// Menu lateral (desktop) em azul-noturno, igual à AppBar.
  Widget _desktopSidebar(BuildContext context) {
    final c = context.palette;
    return Container(
      width: 252,
      decoration: BoxDecoration(
        color: c.navBar,
        border: Border(right: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 19, 18, 15),
              child: Align(alignment: Alignment.centerLeft, child: LegisLogo(compact: true)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 0, 18, 22),
              child: Text('ACOMPANHAMENTO CIDADÃO', style: TextStyle(color: AppColors.tealTint, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1.05)),
            ),
            Divider(height: 1, color: AppColors.offWhite.withValues(alpha: .12)),
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 22, 18, 11),
              child: Text('MENU PRINCIPAL', style: TextStyle(color: AppColors.slate, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .8)),
            ),
            for (var i = 0; i < _destinations.length; i++) _sidebarItem(i),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 8, 13, 8),
              child: Material(
                color: AppColors.offWhite.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _openPreferences,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Row(children: [
                      Icon(Icons.settings_outlined, size: 19, color: AppColors.offWhite),
                      SizedBox(width: 11),
                      Expanded(child: Text('Preferências', style: TextStyle(color: AppColors.offWhite, fontWeight: FontWeight.w600, fontSize: 12.5))),
                      Icon(Icons.chevron_right_rounded, color: AppColors.slate, size: 18),
                    ]),
                  ),
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }

  Widget _sidebarItem(int index) {
    final item = _destinations[index];
    final selected = _index == index;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 3, 12, 3),
      child: Material(
        color: selected ? AppColors.teal : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: () => setState(() => _index = index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            child: Row(
              children: [
                Icon(selected ? item.selectedIcon : item.icon, color: selected ? AppColors.offWhite : AppColors.slate, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(item.label, style: TextStyle(color: selected ? AppColors.offWhite : AppColors.slate, fontSize: 13, fontWeight: selected ? FontWeight.w800 : FontWeight.w600))),
                if (selected) Container(width: 5, height: 5, decoration: const BoxDecoration(color: AppColors.offWhite, shape: BoxShape.circle)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
