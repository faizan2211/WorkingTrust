import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:working_trust/app/routes/app_routes.dart';
import 'package:working_trust/app/routes/route_names.dart';
import 'package:working_trust/features/profile/controller/profile_controller.dart';
import 'package:working_trust/features/profile/models/profile_entries.dart';

import 'fake_backend.dart';

final FakeBackend _backend = FakeBackend();

/// The account these screens open on: the same work as the backend's tables hold
/// it, so `GET /api/profile` answers with it and the read agrees with what the
/// screens are built on.
const _portfolio = <PortfolioItem>[
  (
    id: 'p1',
    title: 'Frenco – Landing Page UI/UX Design',
    image: '',
    kind: 'image',
    link: '',
    status: 'PUBLISHED',
    role: '',
    skills: [],
    description: '',
  ),
  (
    id: 'p2',
    title: 'SkillVexa – Landing Page UI/UX Design',
    image: '',
    kind: 'image',
    link: '',
    status: 'PUBLISHED',
    role: '',
    skills: [],
    description: '',
  ),
  (
    id: 'p3',
    title: 'MOKO – Landing Page UI/UX Design',
    image: '',
    kind: 'image',
    link: '',
    status: 'PUBLISHED',
    role: '',
    skills: [],
    description: '',
  ),
];

const _skills = <String>['Figma', 'UI/UX Design', 'Mobile App Design'];

const _certifications = <Certification>[
  (
    id: 'c1',
    title: 'UI/UX Design',
    provider: 'Kamyab Freelancer Program (KFP)',
    issued: 'August 2025',
    credentialId: 'JCX31196',
    description: 'A program on research-led interface design.',
  ),
];

const _employment = <Employment>[
  (
    id: 'e1',
    role: 'Senior UI/UX Designer',
    company: 'MilestoneZero',
    period: 'Aug 10, 2026 – Present',
    startDate: '2026-08-10',
    endDate: '',
    description: 'Leads the design system for the flagship product.',
  ),
  (
    id: 'e2',
    role: 'UI/UX Designer',
    company: 'Frenco LTD',
    period: 'Aug 10, 2026 – Present',
    startDate: '2026-08-10',
    endDate: '',
    description: 'Designs landing pages for e-commerce clients.',
  ),
];

Future<void> _open(
  WidgetTester tester,
  String route, {
  double width = 400,
  double height = 1800,
}) async {
  tester.view.physicalSize = Size(width * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final table = Map<String, WidgetBuilder>.of(AppRoutes.routes)
    ..remove(Navigator.defaultRouteName);
  await tester.pumpWidget(MaterialApp(routes: table, initialRoute: route));
  await _settle(tester);
  expect(tester.takeException(), isNull, reason: route);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await _settle(tester);
}

Future<void> _type(WidgetTester tester, String hint, String value) async {
  await tester.enterText(find.widgetWithText(TextField, hint), value);
  await _settle(tester);
}

/// Chooses [day] in the calendar the period field opens and confirms it. The
/// picker is left on the current month, so a day number is the only cell that
/// can be meant.
Future<void> _pickDay(WidgetTester tester, int day) async {
  await _settle(tester);
  await tester.tap(
    find.descendant(
      of: find.byType(DatePickerDialog),
      matching: find.text('$day'),
    ),
  );
  await _settle(tester);
  await tester.tap(find.widgetWithText(TextButton, 'OK'));
  await _settle(tester);
}

void main() {
  setUp(() async {
    await _backend.install();
    _backend.issueSessionCookie();
    final profile = ProfileController.instance..clear();
    profile.portfolio.addAll(_portfolio);
    profile.skills.addAll(_skills);
    profile.certifications.addAll(_certifications);
    profile.employment.addAll(_employment);
    // The server's copy of the same account, in its own column names: opening
    // any of these screens reads it back over the list above.
    _backend.storedSkills = _skills.join(', ');
    _backend.profileOwner = 'u1';
    _backend.seedSection('portfolio', [
      for (final row in _portfolio)
        {
          'id': row.id,
          'title': row.title,
          'imageUrl': row.image,
          'mediaType': row.kind,
          'linkUrl': row.link,
          'status': row.status,
          'role': row.role,
          'skills': row.skills,
          'description': row.description,
        },
    ]);
    _backend.seedSection('certifications', [
      for (final row in _certifications)
        {
          'id': row.id,
          'title': row.title,
          'provider': row.provider,
          'issuedAt': isoDateFromText(row.issued),
          'certificateId': row.credentialId,
          'description': row.description,
        },
    ]);
    _backend.seedSection('employment', [
      for (final row in _employment)
        {
          'id': row.id,
          'title': row.role,
          'company': row.company,
          'startDate': row.startDate,
          'endDate': row.endDate,
          'description': row.description,
        },
    ]);
  });

  testWidgets('certifications and employment work are separate sections', (
    tester,
  ) async {
    await _open(tester, RouteNames.profile);
    expect(find.text('Certifications'), findsOneWidget);
    expect(find.text('Employment work'), findsOneWidget);
    expect(find.byTooltip('Add a certification'), findsOneWidget);
    expect(find.byTooltip('Add employment work'), findsOneWidget);
    expect(find.text('Kamyab Freelancer Program (KFP)'), findsOneWidget);
    expect(find.text('Senior UI/UX Designer'), findsOneWidget);
    expect(find.text('MilestoneZero'), findsOneWidget);
  });

  testWidgets('a certification needs a title and an organisation', (
    tester,
  ) async {
    await _open(tester, RouteNames.profile);
    await _tap(tester, find.byTooltip('Add a certification'));
    expect(find.text('Add certification'), findsOneWidget);

    await _tap(tester, find.widgetWithText(TextButton, 'Save'));
    expect(find.text('This field is required'), findsNWidgets(2));

    await _type(tester, 'Certification title', 'Cloud Architecture');
    await _type(tester, 'Issuing organisation', 'Amazon');
    await _type(tester, 'Issued', 'March 2026');
    await _type(tester, 'Credential ID', 'AWS-99');
    await _tap(tester, find.widgetWithText(TextButton, 'Save'));
    await _settle(tester);
    expect(find.text('Cloud Architecture'), findsOneWidget);
    expect(
      ProfileController.instance.certifications.last.title,
      'Cloud Architecture',
    );
    // The row went to the certifications route with the date read into the form
    // the backend stores, and the id it answered with is what the app kept.
    expect(_backend.bodyFor('/api/profile/certifications'), {
      'title': 'Cloud Architecture',
      'provider': 'Amazon',
      'issuedAt': '2026-03-01',
      'certificateId': 'AWS-99',
      'description': '',
    });
    expect(_backend.countOf('/api/profile/certifications'), 1);

    await _tap(tester, find.byTooltip('Remove Cloud Architecture'));
    expect(find.text('Cloud Architecture'), findsNothing);
    expect(ProfileController.instance.certifications, hasLength(1));
    expect(
      _backend.paths.where(
        (path) => path.startsWith('/api/profile/certifications/r'),
      ),
      isNotEmpty,
    );
  });

  testWidgets('an unparseable issued date is never sent', (tester) async {
    await _open(tester, RouteNames.profile);
    await _tap(tester, find.byTooltip('Add a certification'));
    await _type(tester, 'Certification title', 'Data Analytics');
    await _type(tester, 'Issuing organisation', 'Google');
    await _type(tester, 'Issued', 'Summer twentytwentyfive');
    await _tap(tester, find.widgetWithText(TextButton, 'Save'));
    await _settle(tester);

    expect(_backend.bodyFor('/api/profile/certifications')['issuedAt'], '');
    expect(ProfileController.instance.certifications, hasLength(2));
  });

  testWidgets('employment work can be added and edited away', (tester) async {
    await _open(tester, RouteNames.profile);
    await _tap(tester, find.byTooltip('Add employment work'));
    expect(find.text('Add employment work'), findsOneWidget);

    await _type(tester, 'Job title', 'Frontend Developer');
    await _tap(tester, find.widgetWithText(TextButton, 'Save'));
    // Company and a start date are both required by the route.
    expect(find.text('This field is required'), findsNWidgets(2));

    await _type(tester, 'Company', 'Nexwa Studio');

    // The period is picked from the calendar, so the only values that can reach
    // the route are dates it can read.
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 4);
    final end = DateTime(now.year, now.month, 18);
    await _tap(tester, find.byTooltip('Choose from calendar').first);
    await _pickDay(tester, 4);
    await _tap(tester, find.byTooltip('Choose from calendar').last);
    await _pickDay(tester, 18);

    expect(find.widgetWithText(TextField, dateLabel(start)), findsOneWidget);
    await _tap(tester, find.widgetWithText(TextButton, 'Save'));
    await _settle(tester);
    expect(find.text('Frontend Developer'), findsOneWidget);
    expect(find.text('Nexwa Studio'), findsOneWidget);
    expect(
      find.text(periodLabel(start, end)),
      findsOneWidget,
      reason: 'the card shows the picked range',
    );
    expect(_backend.bodyFor('/api/profile/employment'), {
      'title': 'Frontend Developer',
      'company': 'Nexwa Studio',
      'startDate': isoDate(start),
      'endDate': isoDate(end),
      'description': '',
    });

    await _tap(tester, find.byTooltip('Edit Frontend Developer'));
    expect(find.text('Edit employment work'), findsOneWidget);
    await _tap(tester, find.widgetWithText(TextButton, 'Remove'));
    expect(find.text('Frontend Developer'), findsNothing);
    expect(ProfileController.instance.employment, hasLength(2));
  });

  testWidgets('a current job is stored with no end date', (tester) async {
    await _open(tester, RouteNames.profile);
    await _tap(tester, find.byTooltip('Add employment work'));
    await _type(tester, 'Job title', 'Product Designer');
    await _type(tester, 'Company', 'Frenco LTD');
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 2);
    await _tap(tester, find.byTooltip('Choose from calendar').first);
    await _pickDay(tester, 2);
    await _tap(tester, find.widgetWithText(TextButton, 'Save'));
    await _settle(tester);

    // The end field is left blank, which is what the route reads as a job that
    // is still running.
    expect(_backend.bodyFor('/api/profile/employment')['endDate'], '');
    expect(
      ProfileController.instance.employment.last.period,
      periodLabel(start, null),
    );
  });

  testWidgets('a picked end date is cleared again for a current job', (
    tester,
  ) async {
    await _open(tester, RouteNames.profile);
    await _tap(tester, find.byTooltip('Add employment work'));
    await _type(tester, 'Job title', 'UI Designer');
    await _type(tester, 'Company', 'MilestoneZero');
    await _tap(tester, find.byTooltip('Choose from calendar').first);
    await _pickDay(tester, 3);
    await _tap(tester, find.byTooltip('Choose from calendar').last);
    await _pickDay(tester, 9);
    await _tap(tester, find.byTooltip('Clear end date'));
    await _settle(tester);
    expect(find.byTooltip('Clear end date'), findsNothing);

    await _tap(tester, find.widgetWithText(TextButton, 'Save'));
    await _settle(tester);
    final saved = ProfileController.instance.employment.last;
    expect(saved.endDate, '');
    expect(saved.period, endsWith('Present'));
  });

  testWidgets('moving the start date past the end clears the end date', (
    tester,
  ) async {
    await _open(tester, RouteNames.profile);
    await _tap(tester, find.byTooltip('Add employment work'));
    await _type(tester, 'Job title', 'Analyst');
    await _type(tester, 'Company', 'Kamyab');
    await _tap(tester, find.byTooltip('Choose from calendar').last);
    await _pickDay(tester, 5);
    expect(find.byTooltip('Clear end date'), findsOneWidget);

    await _tap(tester, find.byTooltip('Choose from calendar').first);
    await _pickDay(tester, 20);
    // A range that ends before it starts cannot be stored, so the end the user
    // picked is dropped rather than sent as an invalid pair.
    expect(find.byTooltip('Clear end date'), findsNothing);

    await _tap(tester, find.widgetWithText(TextButton, 'Save'));
    await _settle(tester);
    final saved = ProfileController.instance.employment.last;
    final now = DateTime.now();
    expect(saved.startDate, isoDate(DateTime(now.year, now.month, 20)));
    expect(saved.endDate, '');
  });

  testWidgets('the certification form fits a short screen', (tester) async {
    // The dialog the 22-pixel bottom overflow came from: the field list has to
    // scroll instead of running past the edge.
    await _open(tester, RouteNames.profile, width: 360, height: 460);
    await _tap(tester, find.byTooltip('Add a certification'));
    await _type(tester, 'Certification title', 'Cloud Architecture');
    await _type(tester, 'Issuing organisation', 'Amazon');
    await _type(tester, 'Issued', 'March 2026');
    await _type(tester, 'Credential ID', 'AWS-99');
    await _type(
      tester,
      'What the certification covers',
      'Designs and ships resilient workloads across regions, with cost and security reviewed at every step.',
    );
    await _tap(tester, find.widgetWithText(TextButton, 'Save'));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(_backend.countOf('/api/profile/certifications'), 1);
  });

  testWidgets('the skills dialog saves chips to the shared profile', (
    tester,
  ) async {
    await _open(tester, RouteNames.profile);
    await _tap(tester, find.byTooltip('Add a skill'));
    expect(find.text('Edit Skills'), findsOneWidget);
    expect(find.byTooltip('Remove Figma'), findsOneWidget);

    await _tap(tester, find.byTooltip('Remove Figma'));
    await _type(tester, 'Search Skills', 'Motion Design');
    await _tap(tester, find.widgetWithText(ElevatedButton, 'Save changes'));
    await _settle(tester);

    expect(ProfileController.instance.skills, contains('Motion Design'));
    expect(ProfileController.instance.skills, isNot(contains('Figma')));
    expect(find.text('Motion Design'), findsOneWidget);

    await _tap(tester, find.byTooltip('Add a skill'));
    expect(find.byTooltip('Remove Motion Design'), findsOneWidget);
    await _tap(tester, find.widgetWithText(TextButton, 'Cancel'));
  });

  testWidgets('the portfolio form shows the counters and needs a media file', (
    tester,
  ) async {
    await _open(tester, RouteNames.profile);
    await _tap(tester, find.byTooltip('Create a new portfolio project'));
    expect(find.text('Add A New Portfolio Project'), findsOneWidget);
    expect(
      find.text('All fields are required unless otherwise indicated.'),
      findsOneWidget,
    );
    expect(find.text('70 characters left'), findsOneWidget);
    expect(find.text('100 characters left'), findsOneWidget);
    expect(find.text('5 skills left'), findsOneWidget);
    expect(find.text('1000 characters left'), findsOneWidget);
    expect(find.text('Your Content'), findsOneWidget);
    expect(find.byTooltip('Add Image'), findsOneWidget);
    expect(find.byTooltip('Add Audio'), findsOneWidget);

    await _tap(tester, find.text('Publish'));
    expect(find.text('This field is required'), findsNWidgets(2));

    await _type(
      tester,
      'Enter a brief but descriptive title.',
      'Orbita Design System',
    );
    await _type(
      tester,
      'Briefly describe the project\'s goals, your solution and the impact.',
      'A design system for a SaaS product.',
    );
    await _type(tester, 'Enter a brief but descriptive role.', 'Lead Designer');
    await _type(tester, 'Type to add skills relevant to this project', 'Figma');
    await _tap(tester, find.text('Publish'));
    expect(find.text('Content is required.'), findsOneWidget);

    await _tap(tester, find.byTooltip('Add Link'));
    expect(find.text('Add Link'), findsOneWidget);
    await _tap(tester, find.widgetWithText(TextButton, 'Save'));
    expect(find.text('This field is required'), findsOneWidget);
    await _type(tester, 'Paste a link', 'https://orbita.app');
    await _tap(tester, find.widgetWithText(TextButton, 'Save'));
    expect(find.text('https://orbita.app'), findsOneWidget);

    // A project is only stored once it points at a file, and no widget test can
    // run the device picker, so the refusal is what this checks.
    await _tap(tester, find.text('Publish'));
    await _settle(tester);
    expect(
      find.text('Add a picture — a project needs a media file.'),
      findsOneWidget,
    );
    expect(_backend.countOf('/api/profile/portfolio'), 0);
    expect(
      ProfileController.instance.portfolio.map((item) => item.id),
      orderedEquals(['p1', 'p2', 'p3']),
    );
  });

  testWidgets('the new sections stay usable from phone to desktop width', (
    tester,
  ) async {
    for (final width in [320.0, 700.0, 1200.0]) {
      await _open(tester, RouteNames.profile, width: width);
      expect(find.text('Employment work'), findsOneWidget, reason: '$width');
      expect(find.text('Certifications'), findsOneWidget, reason: '$width');
      await _tap(tester, find.byTooltip('Create a new portfolio project'));
      expect(find.text('Add A New Portfolio Project'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Back'));
      await _settle(tester);
    }
  });
}
