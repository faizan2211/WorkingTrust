/// Dummy values for the My proposals screen.
class ProposalsData {
  ProposalsData._();

  static const List<String> ranges = [
    'Last 7 Days',
    'Last 15 Days',
    'Last 30 Days',
  ];

  static const List<({String title, String date, String note, String profile})>
  archived = [
    (
      title:
          'Shopify Store Redesign – Modern & User-Friendly E-Commerce Website',
      date: 'Oct 07, 2026',
      note: 'Job is close',
      profile: 'General Profile',
    ),
    (
      title: 'Real Estate Market Data Analyst & Dashboard Developer',
      date: 'Oct 05, 2026',
      note: 'Job is close',
      profile: 'General Profile',
    ),
    (
      title: 'Shopify Store Setup & Theme Customisation',
      date: 'Oct 03, 2026',
      note: 'Client went quiet',
      profile: 'Design Profile',
    ),
    (
      title: 'Figma Mobile App UI Kit Cleanup',
      date: 'Sep 29, 2026',
      note: 'Job is close',
      profile: 'General Profile',
    ),
    (
      title: 'Product Landing Page Copy Refresh',
      date: 'Sep 26, 2026',
      note: 'Not selected',
      profile: 'Writing Profile',
    ),
    (
      title: 'React Analytics Dashboard Build',
      date: 'Sep 22, 2026',
      note: 'Job is close',
      profile: 'General Profile',
    ),
    (
      title: 'Brand Guidelines & Icon Set',
      date: 'Sep 18, 2026',
      note: 'Client went quiet',
      profile: 'Design Profile',
    ),
    (
      title: 'Booking Flow UX Audit',
      date: 'Sep 14, 2026',
      note: 'Job is close',
      profile: 'General Profile',
    ),
  ];

  /// The panel header shows the client-reported total, not the sample rows.
  static const int archivedCount = 28;
}
