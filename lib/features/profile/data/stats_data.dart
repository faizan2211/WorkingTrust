/// Dummy values for the My stats screen.
class StatsData {
  StatsData._();

  static const String earnings = '\$232.00';
  static const String successScore = '98%';
  static const String bidBonus = "You've earned 10 Bids for the next month";

  static const List<String> proposalRanges = [
    'Last 15 Days',
    'Last 30 Days',
    'Last 90 Days',
  ];

  static const List<({String label, int value})> proposalFunnel = [
    (label: 'Proposals sent', value: 20),
    (label: 'Were viewed', value: 12),
    (label: 'Interviews', value: 5),
    (label: 'Hires', value: 3),
  ];

  static const List<String> metricRanges = [
    'Last 7 Days',
    'Last 15 Days',
    'Last 30 Days',
  ];

  static const List<String> metricTabs = [
    'Profile Views',
    'Impression & Clicks',
  ];

  static const Map<String, List<({String label, int value})>> metrics = {
    'Profile Views': [
      (label: 'Jan 01', value: 2),
      (label: 'Jan 02', value: 5),
      (label: 'Jan 03', value: 3),
      (label: 'Jan 04', value: 8),
      (label: 'Jan 05', value: 3),
      (label: 'Jan 06', value: 6),
      (label: 'Jan 07', value: 3),
    ],
    'Impression & Clicks': [
      (label: 'Jan 01', value: 12),
      (label: 'Jan 02', value: 18),
      (label: 'Jan 03', value: 9),
      (label: 'Jan 04', value: 24),
      (label: 'Jan 05', value: 15),
      (label: 'Jan 06', value: 20),
      (label: 'Jan 07', value: 11),
    ],
  };
}
