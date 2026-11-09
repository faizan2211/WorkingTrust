import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/routes/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimensions.dart';
import '../../../core/constants/asset_constants.dart';
import '../../find_work/screens/find_work_screen.dart';
import '../../messages/screens/messages_screen.dart';
import '../../notifications/controller/notification_controller.dart';
import '../../notifications/services/fcm_push_service.dart';
import '../../profile/controller/profile_controller.dart';
import '../../profile/screens/profile_menu_screen.dart';
import 'dashboard_screen.dart';

/// Four-tab shell. The tabs sit in a horizontal [PageView], so a swipe moves
/// between them and the navigation bar follows, and vice versa. Only the pages
/// the viewport reaches are mounted, which keeps a sign-in down to one screen
/// and one set of reads; the page a swipe came from is kept alive, so the
/// board's search text and filters survive a round trip.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialTab = 0});

  /// Defaults to the dashboard, because that is what a sign-in lands on.
  final int initialTab;

  /// Membership Plan is not a destination here; it is one of the Profile
  /// modules, so the bar carries the four places a session is actually spent.
  static const List<_ShellTab> _tabs = [
    _ShellTab('Home', Icons.home_outlined, Icons.home, showsBell: true),
    _ShellTab(
      'Messages',
      Icons.chat_bubble_outline,
      Icons.chat_bubble,
      showsBell: true,
    ),
    _ShellTab('Find Work', Icons.work_outline, Icons.work, showsBell: true),
    _ShellTab('Profile', Icons.person_outline, Icons.person),
  ];

  @override
  State<HomeScreen> createState() => _HomeScreenState();

  /// The board, by its number in [_tabs].
  static const int boardTab = 2;

  /// The tab a pushed screen wants the shell to show, or null when the request
  /// has been taken. A screen the account reaches from a module — the wallet's
  /// "Find work", say — asks the shell it already runs under to move, rather
  /// than mounting a second shell over the first.
  static final ValueNotifier<int?> _requestedTab = ValueNotifier<int?>(null);

  /// Returns to the shell with [tab] showing.
  static void openTab(BuildContext context, int tab) {
    // Cleared first so a second request for the same tab still notifies.
    _requestedTab.value = null;
    _requestedTab.value = tab;
    Navigator.popUntil(context, (route) => route.isFirst);
  }
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late int _index = widget.initialTab;

  /// Drives the tab pages. `keepPage` is on by default, so the page a swipe
  /// moves off keeps its own state instead of being thrown away.
  late final PageController _pages = PageController(
    initialPage: widget.initialTab,
  );

  /// The shell owns the notification feed: it reads once for a signed-in
  /// session and re-reads when the app returns to the foreground.
  @override
  void initState() {
    super.initState();
    HomeScreen._requestedTab.addListener(_openRequestedTab);
    WidgetsBinding.instance.addObserver(this);
    NotificationController.instance.startSession();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FcmPushService.instance.markNavigationReady();
      // The board ranks its "Best Matches" tab from the profile title and
      // shows the bid count, so the session read belongs to the shell rather
      // than to a tab body the account has not opened yet. Deferred to after
      // the frame because the controller notifies listeners inside this one.
      ProfileController.instance.load();
    });
  }

  @override
  void dispose() {
    HomeScreen._requestedTab.removeListener(_openRequestedTab);
    _pages.dispose();
    WidgetsBinding.instance.removeObserver(this);
    NotificationController.instance.endSession();
    super.dispose();
  }

  void _openRequestedTab() {
    final tab = HomeScreen._requestedTab.value;
    if (tab == null) return;
    _goToTab(tab);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    NotificationController.instance.handleLifecycle(state);
  }

  /// The body of one tab, in the order [HomeScreen._tabs] lists them.
  Widget _body(int tab) => switch (tab) {
    0 => const DashboardScreen(),
    1 => const MessagesScreen(),
    2 => const FindWorkScreen(),
    _ => const ProfileMenuScreen(),
  };

  void _goToTab(int value) {
    if (value == _index) return;
    // The bar answers first, then the pages slide to it. A swipe lands through
    // [PageView.onPageChanged] and moves the bar the same way.
    setState(() => _index = value);
    _pages.animateToPage(
      value,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tab = HomeScreen._tabs[_index];
    return Scaffold(
      appBar: AppBar(
        // One tinted strip for every tab. The per-tab word is gone: each body
        // already names itself, and the icons under the bar carry the names as
        // tooltips and accessibility labels.
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        // The bar is dark, so the clock and battery have to be light.
        systemOverlayStyle: SystemUiOverlayStyle.light,
        // Without this the bar takes on the theme's scroll tint as soon as a
        // tab's list moves under it.
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: const _BrandMark(),
        actions: [
          if (tab.showsBell)
            ListenableBuilder(
              listenable: NotificationController.instance,
              builder: (context, _) {
                final unread = NotificationController.instance.unread;
                return IconButton(
                  tooltip: 'Notifications',
                  onPressed: () =>
                      Navigator.pushNamed(context, RouteNames.notifications),
                  // Same rule as before: the bell only appears with something
                  // to show, but the count is now the server's own.
                  icon: unread > 0
                      ? Badge(
                          backgroundColor: AppColors.error,
                          label: Text('$unread'),
                          child: const Icon(
                            Icons.notifications_none,
                            color: AppColors.textOnPrimary,
                          ),
                        )
                      : const Icon(
                          Icons.notifications_none,
                          color: AppColors.textOnPrimary,
                        ),
                );
              },
            ),
        ],
      ),
      body: PageView(
        controller: _pages,
        onPageChanged: (value) => setState(() => _index = value),
        children: [
          for (int tab = 0; tab < HomeScreen._tabs.length; tab++) _body(tab),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        height: AppDimensions.bottomNavHeight,
        indicatorColor: AppColors.accent,
        // Icons only: the four destinations read faster as shapes than as
        // words, and the row of labels cost height a tab body needs.
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        onDestinationSelected: _goToTab,
        destinations: [
          for (final item in HomeScreen._tabs)
            // A hidden label is not lost: [NavigationBar] puts each one back on
            // as the destination's tooltip and accessibility name.
            NavigationDestination(
              icon: Icon(item.icon, color: AppColors.textSecondary),
              selectedIcon: Icon(item.activeIcon, color: AppColors.primary),
              label: item.title,
            ),
        ],
      ),
    );
  }
}

class _ShellTab {
  final String title;
  final IconData icon;
  final IconData activeIcon;
  final bool showsBell;

  const _ShellTab(
    this.title,
    this.icon,
    this.activeIcon, {
    this.showsBell = false,
  });
}

/// The brand mark on a white tile. The logo is a two-tone flat artwork, so it
/// keeps its own colours instead of being flattened to white on the teal bar.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppDimensions.xl,
      height: AppDimensions.xl,
      padding: const EdgeInsets.all(AppDimensions.xs),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      ),
      child: Image.asset(
        AssetConstants.logo,
        fit: BoxFit.contain,
        semanticLabel: 'WorkingTrust',
        errorBuilder: (context, error, stack) => const Icon(
          Icons.workspace_premium_outlined,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
