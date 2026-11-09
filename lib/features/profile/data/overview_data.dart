/// Dummy values for the Overview screen.
class OverviewData {
  OverviewData._();

  static const List<({String label, String amount, int tone})> balances = [
    (label: 'Work in Progress', amount: '\$232.00', tone: 0),
    (label: 'In Review', amount: '\$42.00', tone: 1),
    (label: 'Pending', amount: '\$125.00', tone: 2),
    (label: 'Available Balance', amount: '\$0.00', tone: 3),
  ];

  static const List<
    ({String title, String client, String milestone, String amount})
  >
  inProgress = [
    (
      title: 'Shopify Store Redesign',
      client: 'Greenline Foods',
      milestone: 'Milestone 2 of 3 · Design handoff',
      amount: '\$120.00',
    ),
    (
      title: 'Real Estate Market Data Dashboard',
      client: 'Vertex Realty',
      milestone: 'Milestone 1 of 2 · Data pipeline',
      amount: '\$72.00',
    ),
    (
      title: 'Figma Mobile App UI Kit',
      client: 'Northwind Labs',
      milestone: 'Milestone 3 of 4 · Screen polish',
      amount: '\$40.00',
    ),
  ];

  static const List<
    ({String title, String client, String milestone, String amount})
  >
  inReview = [
    (
      title: 'Product Landing Page Copy',
      client: 'Bright Harbour Co.',
      milestone: 'Delivered · Waiting for approval',
      amount: '\$42.00',
    ),
  ];

  static const List<
    ({String title, String client, String milestone, String amount})
  >
  pending = [
    (
      title: 'React Analytics Dashboard',
      client: 'CloudPeak Systems',
      milestone: 'Proposal submitted 2 days ago',
      amount: '\$125.00',
    ),
  ];
}
