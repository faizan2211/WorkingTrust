import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:working_trust/app/routes/app_routes.dart';
import 'package:working_trust/app/routes/route_names.dart';
import 'package:working_trust/app/theme/app_colors.dart';
import 'package:working_trust/core/widgets/app_text_field.dart';
import 'package:working_trust/features/find_work/controller/find_work_controller.dart';
import 'package:working_trust/features/find_work/screens/find_work_screen.dart';
import 'package:working_trust/features/home/screens/dashboard_screen.dart';
import 'package:working_trust/features/home/screens/home_screen.dart';
import 'package:working_trust/features/membership/screens/membership_plan_screen.dart';
import 'package:working_trust/features/messages/screens/messages_screen.dart';
import 'package:working_trust/features/profile/controller/profile_controller.dart';
import 'package:working_trust/features/profile/screens/profile_menu_screen.dart';
import 'package:working_trust/features/profile/screens/profile_screen.dart';

import 'fake_backend.dart';

/// The account the fake session answers with.
const String _sessionName = 'Someone';
final FakeBackend _backend = FakeBackend();

/// A tall, phone-width surface keeps every section reachable without scrolling.
Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  double width = 400,
  double height = 1500,
}) async {
  tester.view.physicalSize = Size(width * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  // The shell supplies the Scaffold; feature screens are bare bodies, so give
  // them the same Material ancestor when mounted on their own.
  final wrapped = screen is HomeScreen || screen is Scaffold
      ? screen
      : Scaffold(body: screen);
  // The app's own table, minus "/" because `home` already owns it.
  final table = Map<String, WidgetBuilder>.of(AppRoutes.routes)
    ..remove(Navigator.defaultRouteName);
  await tester.pumpWidget(MaterialApp(routes: table, home: wrapped));
  // One frame mounts the screen, the next lets its session read answer.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// A tap needs one frame before the clock moves, otherwise the callback lands
/// after the last pumped frame.
Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.tap(target);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Moves the clock past the search debounce and lets the read it triggers land.
Future<void> _settled(WidgetTester tester) async {
  await tester.pump(FindWorkController.searchDelay);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
}

/// The bar carries icons only, so a destination is reached by its position.
Future<void> _tapTab(WidgetTester tester, int index) =>
    _tap(tester, find.byType(NavigationDestination).at(index));

/// Home, Messages, Find Work, Profile.
const int _home = 0, _messages = 1, _findWork = 2, _profile = 3;

/// The Messages tab draws its rows from the feed the shell reads, so reaching a
/// thread the way the app does means opening the shell first.
Future<void> _openMessages(WidgetTester tester, {double width = 400}) async {
  await _pump(tester, const HomeScreen(), width: width);
  await _tapTab(tester, _messages);
}

Finder _appBarTitle(String title) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(title));

/// The header's brand tile, i.e. the artwork the bar shows instead of a word.
Finder _brandMark() =>
    find.descendant(of: find.byType(AppBar), matching: find.byType(Image));

/// Which destination the icons-only bar has lit up.
void _expectSelected(WidgetTester tester, int index) => expect(
  tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
  index,
);

/// The dialog's Overview field, identified by the start of its hint.
Finder _overviewField() => find.byWidgetPredicate(
  (widget) =>
      widget is TextField &&
      (widget.decoration?.hintText ?? '').startsWith('Ex. Clean'),
);

void main() {
  setUp(() async {
    await _backend.install();
    // A signed-in device: the profile may only show what the session returns.
    _backend.issueSessionCookie();
    ProfileController.instance.clear();
    // The board is one shared instance, so a bookmark or application made by a
    // previous test must not carry into this one.
    FindWorkController.instance.clear();
  });

  testWidgets('shell opens on the dashboard and lists the four tabs in order', (
    tester,
  ) async {
    await _pump(tester, const HomeScreen());

    expect(_brandMark(), findsOneWidget);
    expect(find.text('Performances'), findsOneWidget);
    final destinations = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .toList();
    expect(destinations.map((item) => item.label).toList(), [
      'Home',
      'Messages',
      'Find Work',
      'Profile',
    ], reason: 'Membership Plan left the bar');
    expect(destinations.map((item) => (item.icon as Icon).icon).toList(), [
      Icons.home_outlined,
      Icons.chat_bubble_outline,
      Icons.work_outline,
      Icons.person_outline,
    ]);
    // The names are only carried by the tooltips and the semantics, never as
    // visible label text under the bar.
    for (final name in ['Home', 'Messages', 'Find Work', 'Profile']) {
      expect(find.byTooltip(name), findsWidgets, reason: name);
    }
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(
      bar.labelBehavior,
      NavigationDestinationLabelBehavior.alwaysHide,
      reason: 'icons only',
    );
    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the header is one tinted brand strip, not a per-tab word', (
    tester,
  ) async {
    await _pump(tester, const HomeScreen());

    final bar = tester.widget<AppBar>(find.byType(AppBar));
    expect(bar.backgroundColor, AppColors.primary, reason: 'the tint');
    expect(_brandMark(), findsOneWidget);
    // The names live under the bar as icons; repeating each one in the header
    // was the part that read like a form field.
    for (final name in ['Home', 'Messages', 'Find Work', 'Profile']) {
      expect(_appBarTitle(name), findsNothing, reason: name);
    }

    await _tapTab(tester, _findWork);
    expect(_brandMark(), findsOneWidget, reason: 'one strip, every tab');
    expect(
      tester.widget<Icon>(find.byIcon(Icons.notifications_none)).color,
      AppColors.textOnPrimary,
      reason: "the bell flips to the bar's foreground",
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the tinted header stays inside a narrow phone', (tester) async {
    await _pump(tester, const HomeScreen(), width: 320, height: 700);

    expect(_brandMark(), findsOneWidget);
    expect(tester.getRect(_brandMark()).right, lessThanOrEqualTo(320));
    expect(find.byTooltip('Notifications'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login lands on the dashboard tab', (tester) async {
    await _pump(tester, const HomeScreen());

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
      reason: 'the shell opens on Home after login',
    );
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('membership plan is a profile module, not a tab', (tester) async {
    await _pump(tester, const HomeScreen());

    expect(
      find.byType(MembershipPlanScreen, skipOffstage: false),
      findsNothing,
      reason: 'it left the bottom navigation',
    );
    expect(AppRoutes.routes.containsKey(RouteNames.membershipPlan), isTrue);

    await _tapTab(tester, _profile);
    await _tap(tester, find.text('Membership Plan'));
    expect(_appBarTitle('Membership Plan'), findsOneWidget);
    expect(find.text('Simple, Honest Pricing'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the feed is read on an open, not while the shell idles', (
    tester,
  ) async {
    await _pump(tester, const HomeScreen());
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(
      _backend.countOf('/api/notifications'),
      1,
      reason: 'the shell reads once when it opens',
    );

    // Swiping to Messages draws from that read; it asks the server again on
    // every visit, which is the traffic that reads as a bug.
    await _tapTab(tester, _messages);
    await _tapTab(tester, _findWork);
    await _tapTab(tester, _messages);
    expect(_backend.countOf('/api/notifications'), 1);

    // The bell's screen is the one that re-reads, because opening it is a
    // request for what arrived since.
    await _tap(tester, find.byTooltip('Notifications'));
    expect(
      _backend.countOf('/api/notifications'),
      2,
      reason: 'opening the notifications screen',
    );
  });

  testWidgets('a sign-in builds only the page it opens on', (tester) async {
    await _pump(tester, const HomeScreen());

    expect(find.byType(DashboardScreen), findsOneWidget);
    // A [PageView] mounts only the pages its viewport reaches, so on the frame
    // a sign-in lands the other three tabs are still absent.
    expect(find.byType(MessagesScreen, skipOffstage: false), findsNothing);
    expect(find.byType(FindWorkScreen, skipOffstage: false), findsNothing);
    expect(find.byType(ProfileMenuScreen, skipOffstage: false), findsNothing);
    // The dashboard greeting and the board's Matches ranking both read the
    // session, so the shell asks for it even though Profile was never opened.
    expect(_backend.countOf('/api/auth/session'), greaterThan(0));

    await _tapTab(tester, _profile);
    expect(find.byType(ProfileMenuScreen), findsOneWidget);
    expect(find.text('Profile Modules'), findsOneWidget);
  });

  testWidgets('a swipe moves between the tabs and the bar follows', (
    tester,
  ) async {
    await _pump(tester, const HomeScreen());

    await tester.fling(find.byType(PageView), const Offset(-250, 0), 900);
    await tester.pumpAndSettle();
    expect(find.byType(MessagesScreen), findsOneWidget);
    _expectSelected(tester, 1);

    await tester.fling(find.byType(PageView), const Offset(250, 0), 900);
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);
    _expectSelected(tester, _home);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every tab navigates and keeps its own state', (tester) async {
    await _pump(tester, const HomeScreen());

    await _tapTab(tester, _findWork);
    final search = find.byType(TextField).first;
    await tester.enterText(search, 'React');
    await tester.pump();

    await _tapTab(tester, _profile);
    _expectSelected(tester, _profile);
    expect(find.text('Profile Modules'), findsOneWidget);

    await _tapTab(tester, _messages);
    _expectSelected(tester, _messages);
    expect(find.byType(MessagesScreen), findsOneWidget);

    await _tapTab(tester, _home);
    _expectSelected(tester, _home);
    expect(find.text('Earnings'), findsOneWidget);

    await _tapTab(tester, _findWork);
    _expectSelected(tester, _findWork);
    expect(find.byType(FindWorkScreen), findsOneWidget);
    // The page a swipe came from is kept alive, so the draft search survives.
    expect(find.widgetWithText(AppTextField, 'React'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'the board reads open projects and a word is searched server-side',
    (tester) async {
      await _pump(tester, const FindWorkScreen());

      expect(_backend.paths, contains('/api/tasks'));
      expect(find.textContaining('Shopify Store Redesign'), findsOneWidget);
      expect(find.textContaining('Copywriting'), findsOneWidget);
      expect(find.text('Proposals: 12'), findsOneWidget);

      // Typing waits out the debounce, then the server's `q` answer lands.
      await tester.enterText(find.byType(TextField).first, 'copywriting');
      await _settled(tester);
      expect(find.textContaining('Shopify Store Redesign'), findsNothing);
      expect(find.textContaining('Copywriting'), findsOneWidget);
      expect(
        _backend.requests.last.url.queryParameters['q'],
        'copywriting',
        reason: 'the keyword is the route\'s own filter',
      );

      await tester.enterText(find.byType(TextField).first, 'zzzz');
      await _settled(tester);
      expect(find.text('No open project matches this search.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '');
      await _settled(tester);
      expect(find.textContaining('Shopify Store Redesign'), findsOneWidget);

      // A bookmark is device state: no route stores it, so the tab is local.
      await _tap(tester, find.byIcon(Icons.bookmark_add_outlined).first);
      await _tap(tester, find.text('Save Jobs (1)'));
      expect(find.textContaining('Shopify Store Redesign'), findsOneWidget);
      expect(find.textContaining('Copywriting'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a proposal goes to the bid route and marks the card Applied', (
    tester,
  ) async {
    await _pump(tester, const FindWorkScreen());

    final card = find.textContaining('Dashboard Developer').first;
    await tester.ensureVisible(card);
    await tester.pump();
    await _tap(tester, card);
    expect(find.text('Apply Now'), findsOneWidget);

    await _tap(tester, find.text('Apply Now'));
    expect(find.text('Submit a proposal'), findsOneWidget);

    final cover = find.widgetWithText(
      TextField,
      'Tell the client why you are the right fit',
    );
    await tester.enterText(cover, 'I shipped four dashboards this quarter.');
    // The signed-in profile carries no hourly rate the app can read, so the
    // bid starts at the route's minimum and has to be typed.
    await tester.enterText(find.widgetWithText(TextField, '0.00'), '25');
    await tester.pump();
    await _tap(tester, find.text('Submit Proposal'));
    await _settled(tester);

    expect(
      _backend.paths,
      contains('/api/tasks/t2/bid'),
      reason: 'the real bid route',
    );
    expect(find.text('Proposal sent. 25 Bids deducted.'), findsOneWidget);
    expect(find.text('Applied'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('messages opens a thread, clears unread and sends', (
    tester,
  ) async {
    await _openMessages(tester);

    expect(find.text('Messages'), findsWidgets);
    // The only row the backend can offer: a CHAT_MESSAGE that names its task.
    expect(find.text('Hana'), findsOneWidget);

    await _tap(tester, find.text('Hana'));
    final composer = find.widgetWithText(TextField, 'Write a message');
    expect(composer, findsOneWidget);
    expect(
      find.text('Can you share the Figma link before we start?'),
      findsOneWidget,
    );
    expect(_backend.paths, contains('/api/tasks/t9/chat'));

    await tester.enterText(composer, 'I can start Monday.');
    await tester.pump();
    await _tap(tester, find.byTooltip('Send'));

    expect(find.text('I can start Monday.'), findsOneWidget);
    expect(
      _backend.paths.where((path) => path == '/api/tasks/t9/chat').length,
      2,
      reason: 'one read, one send',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile shows the signed-in identity and empty sections', (
    tester,
  ) async {
    await _pump(tester, const ProfileScreen());

    expect(find.text(_sessionName), findsOneWidget);
    expect(find.text('someone@gmail.com'), findsOneWidget);
    // Nothing here answers the fabricated mock values any more.
    expect(find.textContaining('Lahore, Pakistan'), findsNothing);
    expect(find.textContaining('Member since'), findsNothing);
    expect(find.text('Total Earning'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(3));
    expect(find.text('Portfolio'), findsOneWidget);
    expect(find.text('No projects added yet.'), findsOneWidget);
    expect(find.text('Work History'), findsOneWidget);
    expect(find.text('No completed projects yet.'), findsOneWidget);
    expect(find.text('Skills'), findsOneWidget);
    expect(find.text('No skills added yet.'), findsOneWidget);
    expect(find.text('Certifications'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the profile details dialog saves to the shared store and '
      'cancels discard', (tester) async {
    await _pump(tester, const ProfileScreen());

    await _tap(tester, find.byTooltip('Edit profile details'));
    expect(find.text('Edit Title, Hourly Rate & Description'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Ex. Senior Web Developer...'),
      '',
    );
    await _tap(tester, find.widgetWithText(ElevatedButton, 'Save changes'));
    expect(find.text('This field is required'), findsWidgets);

    await tester.enterText(
      find.widgetWithText(TextField, 'Ex. Senior Web Developer...'),
      'Brand Designer',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '\$50.00 /hr'),
      '\$45/hr',
    );
    await tester.enterText(
      _overviewField(),
      'Designs storefronts that sell in one screen.',
    );
    await _tap(tester, find.widgetWithText(ElevatedButton, 'Save changes'));
    expect(find.text('Brand Designer'), findsOneWidget);
    expect(find.text('\$45/hr'), findsOneWidget);
    expect(ProfileController.instance.title, 'Brand Designer');
    // The write really went out: name is mandatory and the rate travels as the
    // number the column stores.
    expect(_backend.profileUpdate, isNotNull);
    expect(_backend.profileUpdate!['name'], _sessionName);
    expect(_backend.profileUpdate!['title'], 'Brand Designer');
    expect(_backend.profileUpdate!['hourlyRate'], 45);

    await _tap(tester, find.byTooltip('Edit profile details'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Ex. Senior Web Developer...'),
      'Discarded Name',
    );
    await _tap(tester, find.widgetWithText(TextButton, 'Cancel'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Discarded Name'), findsNothing);
    expect(ProfileController.instance.title, 'Brand Designer');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the details dialog stays usable on a short screen', (
    tester,
  ) async {
    // The 129-pixel bottom overflow was a six-line overview that no longer fit
    // once the dialog was given a short screen: the form now scrolls, so every
    // field and both buttons stay reachable.
    await _pump(tester, const ProfileScreen(), width: 360, height: 420);
    await _tap(tester, find.byTooltip('Edit profile details'));
    expect(find.text('Edit Title, Hourly Rate & Description'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Ex. Senior Web Developer...'),
      'Brand Designer',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '\$50.00 /hr'),
      '\$45/hr',
    );
    await tester.enterText(
      _overviewField(),
      'Designs storefronts that sell in one screen, and landing pages that '
      'carry the same argument from the first headline down to the last '
      'button, without a meeting to explain it.',
    );

    final save = find.widgetWithText(ElevatedButton, 'Save changes');
    await tester.ensureVisible(save);
    await _tap(tester, save);
    expect(tester.takeException(), isNull);
    expect(_backend.profileUpdate!['bio'], startsWith('Designs storefronts'));
    expect(ProfileController.instance.bio, startsWith('Designs storefronts'));
  });

  testWidgets('the overview stays reachable with the keyboard open', (
    tester,
  ) async {
    // The reported case: typing in the overview raises the keyboard over the
    // dialog, and the form has to shrink and scroll instead of overflowing.
    await _pump(tester, const ProfileScreen(), width: 400, height: 720);
    await _tap(tester, find.byTooltip('Edit profile details'));
    tester.view.viewInsets = FakeViewPadding(bottom: 340);
    await tester.pump();

    await tester.enterText(_overviewField(), 'Designs storefronts that sell.');
    final save = find.widgetWithText(ElevatedButton, 'Save changes');
    await tester.ensureVisible(save);
    await _tap(tester, save);
    expect(tester.takeException(), isNull);
    expect(find.text('Edit Title, Hourly Rate & Description'), findsOneWidget);
  });

  testWidgets('the shell survives narrow and wide layouts', (tester) async {
    for (final width in [320.0, 700.0, 1200.0]) {
      await _pump(tester, const HomeScreen(), width: width);
      for (final tab in [_home, _messages, _findWork, _profile]) {
        await _tapTab(tester, tab);
        expect(
          tester.takeException(),
          isNull,
          reason: 'shell at ${width}dp on tab $tab',
        );
      }
    }
  });

  testWidgets('project detail stays usable at 320dp', (tester) async {
    await _pump(tester, const FindWorkScreen(), width: 320);
    // A row is built when it is scrolled near, so this card has to be reached
    // rather than assumed to already be on screen.
    final card = find.textContaining('Mobile App UI Design');
    await tester.dragUntilVisible(
      card,
      find.byType(CustomScrollView).first,
      const Offset(0, -300),
    );
    await tester.pump();
    await _tap(tester, card.first);
    expect(find.text('Apply Now'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'detail at 320dp');
  });

  testWidgets('the client card wraps long client text at 320dp', (
    tester,
  ) async {
    // A client's name and country are free text on the backend, and neither
    // still fits beside its label on a narrow phone.
    _backend.seedTask(
      'tlong',
      title: 'Long Names Board Check',
      clientName: 'Christopher Alexander Whitmore-Johnson',
      clientCountry: 'United Kingdom of Great Britain and Northern Ireland',
    );
    await _pump(tester, const FindWorkScreen(), width: 320);
    final card = find.textContaining('Long Names Board Check');
    await tester.dragUntilVisible(
      card,
      find.byType(CustomScrollView).first,
      const Offset(0, -300),
    );
    await tester.pump();
    await _tap(tester, card.first);

    expect(find.text('About the client'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'client card at 320dp');
  });

  testWidgets('messages opens a thread at 320dp', (tester) async {
    await _openMessages(tester, width: 320);
    await _tap(tester, find.text('Hana'));
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Write a message'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'chat at 320dp');
  });
}
