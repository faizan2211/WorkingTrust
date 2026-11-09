/// Dummy values for the My Reports screen.
class ReportsData {
  ReportsData._();

  static const List<({String title, String description, bool locked})>
  reports = [
    (
      title: 'Weekly Summary',
      description:
          'A snapshot of everything that happened on your account this week: '
          'proposals you sent, jobs that moved forward and the earnings that '
          'cleared escrow. Share it with your accountant or keep it for your '
          'own records.',
      locked: false,
    ),
    (
      title: 'Weekly Summary By Client',
      description:
          'The same week broken down per client, so you can see who paid, who '
          'is still reviewing a milestone and where your time really went.',
      locked: true,
    ),
  ];
}
